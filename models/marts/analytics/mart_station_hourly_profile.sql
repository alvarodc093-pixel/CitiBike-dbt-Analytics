-- Perfil horario medio de cada estación propia: cuántas bicis salen y llegan, de
-- media, a cada hora de un laborable y de un fin de semana o festivo.
-- El balance diario esconde el problema real: una estación junto al tren se llena
-- por la mañana y se vacía por la tarde, y en el total del día se compensa.

with trips as (

    select * from {{ ref('fct_trips') }}

),

dates as (

    select
        date_day,
        case when day_type = 'laborable' then 'laborable' else 'fin de semana o festivo' end as day_group
    from {{ ref('dim_date') }}

),

stations as (

    select station_id, station_name, area_code, first_seen_date, last_seen_date
    from {{ ref('dim_stations') }}
    where is_home_system

),

-- Días de cada tipo en que la estación existía (de su primer a su último viaje).
-- Si se dividiera entre todo el año, una estación abierta en agosto saldría con
-- medias artificialmente bajas.
n_days as (

    select s.station_id, d.day_group, count(*) as n_days
    from stations as s
    join dates as d on d.date_day between s.first_seen_date and s.last_seen_date
    group by all

),

events as (

    -- Cada viaje genera una salida (en su hora y día de inicio) y una llegada (en su
    -- hora y día de fin), cada una con el tipo de día que le corresponde.
    select start_station_id as station_id, cast(started_at as date) as d,
           extract(hour from started_at)::integer as hour, -1 as delta
    from trips
    union all
    select end_station_id, cast(ended_at as date),
           extract(hour from ended_at)::integer, 1
    from trips

),

hourly as (

    select
        e.station_id,
        dt.day_group,
        e.hour,
        count(*) filter (where e.delta = -1)    as departures,
        count(*) filter (where e.delta =  1)    as arrivals
    from events as e
    join dates as dt on dt.date_day = e.d       -- descarta llegadas posteriores al periodo
    group by all

),

grid as (

    select s.station_id, s.station_name, s.area_code, n.day_group, n.n_days, h.hour
    from stations as s
    join n_days as n using (station_id)
    cross join range(24) as h(hour)

)

select
    g.station_id,
    g.station_name,
    g.area_code,
    g.day_group,
    g.hour,
    g.n_days,
    coalesce(h.departures, 0)                                             as departures,
    coalesce(h.arrivals, 0)                                               as arrivals,
    round(coalesce(h.departures, 0) / g.n_days, 2)                        as avg_departures,
    round(coalesce(h.arrivals, 0) / g.n_days, 2)                          as avg_arrivals,
    round((coalesce(h.arrivals, 0) - coalesce(h.departures, 0)) / g.n_days, 2)
                                                                          as avg_net_flow
from grid as g
left join hourly as h using (station_id, day_group, hour)
