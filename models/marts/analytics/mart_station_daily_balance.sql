-- Salidas y llegadas de cada estación cada día. Si una estación pierde bicis
-- (más salidas que llegadas) hay que reponerlas con camión: es el coste
-- operativo principal de un sistema de bici compartida.
-- Solo estaciones del propio sistema (Jersey City y Hoboken).

with trips as (

    select * from {{ ref('fct_trips') }}

),

departures as (

    select start_station_id as station_id, trip_date, count(*) as departures
    from trips
    group by all

),

arrivals as (

    -- La llegada se asigna al día en que termina el viaje, no al día en que empieza.
    select end_station_id as station_id, cast(ended_at as date) as trip_date, count(*) as arrivals
    from trips
    where cast(ended_at as date) < date '{{ var("periodo_fin") }}'
    group by all

),

home_stations as (

    select station_id, station_name, area_code
    from {{ ref('dim_stations') }}
    where is_home_system

),

-- Todas las combinaciones estación x día, para que un día sin movimiento cuente como 0.
grid as (

    select s.station_id, s.station_name, s.area_code, d.date_day as trip_date, d.day_type
    from home_stations as s
    cross join {{ ref('dim_date') }} as d

)

select
    g.station_id,
    g.station_name,
    g.area_code,
    g.trip_date,
    g.day_type,
    coalesce(dep.departures, 0)                                  as departures,
    coalesce(arr.arrivals, 0)                                    as arrivals,
    coalesce(arr.arrivals, 0) - coalesce(dep.departures, 0)      as net_flow
from grid as g
left join departures as dep using (station_id, trip_date)
left join arrivals   as arr using (station_id, trip_date)
