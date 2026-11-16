-- Carga de reparto de cada laborable: cuántas bicis acumulan entre las 6:00 y las 9:59
-- las estaciones que "se llenan por la mañana" (ver mart_station_rebalancing). Es lo que
-- el camión tiene que retirar de ellas antes de que se queden sin anclajes libres.
--
-- Se calcula día a día, no sumando las medias por estación: una estación reubicada
-- (HB106 River St & Newark St pasó a ser HB107 Hudson Pl & Hoboken Terminal, a 116 m,
-- el 31/07/2026) aparece como dos estaciones que nunca coexistieron, y sumar sus
-- medias contaría dos veces el mismo punto (~240 bicis en vez de ~210).

with trips as (

    select * from {{ ref('fct_trips') }}

),

filling_stations as (

    select station_id
    from {{ ref('mart_station_rebalancing') }}
    where peak_profile = 'se llena por la mañana'

),

events as (

    select start_station_id as station_id, cast(started_at as date) as date_day,
           extract(hour from started_at)::integer as hour, -1 as delta
    from trips
    union all
    select end_station_id, cast(ended_at as date), extract(hour from ended_at)::integer, 1
    from trips

),

am_by_station as (

    select station_id, date_day, sum(delta) as am_net_flow
    from events
    where hour between 6 and 9
    group by all

),

weekdays as (

    select date_day, weekday_name, weather_category
    from {{ ref('dim_date') }}
    where day_type = 'laborable'

)

select
    w.date_day,
    w.weekday_name,
    w.weather_category,
    count(distinct a.station_id) filter (where f.station_id is not null)   as filling_stations_active,
    coalesce(sum(a.am_net_flow) filter (where f.station_id is not null), 0) as am_bikes_accumulated,
    -- Cota superior: todo lo que ganan, en la punta, las estaciones propias que ganan bicis.
    coalesce(sum(greatest(a.am_net_flow, 0))
             filter (where a.station_id like 'JC%' or a.station_id like 'HB%'), 0)
                                                                           as am_bikes_accumulated_all_stations
from weekdays as w
left join am_by_station as a using (date_day)
left join filling_stations as f using (station_id)
group by all
