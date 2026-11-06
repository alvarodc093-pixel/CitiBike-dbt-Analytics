-- Matriz origen-destino: los trayectos más repetidos entre estaciones.

with trips as (

    select * from {{ ref('fct_trips') }}

)

select
    t.start_station_id,
    s.station_name                                   as start_station_name,
    t.end_station_id,
    e.station_name                                   as end_station_name,
    t.start_area_code,
    t.end_area_code,
    count(*)                                         as trips,
    round(count(*) filter (where t.rider_type = 'member') / count(*), 4)
                                                     as share_member,
    round(median(t.duration_min), 2)                 as median_duration_min,
    round(any_value(t.distance_km), 3)               as approx_distance_km,
    rank() over (order by count(*) desc)             as flow_rank
from trips as t
left join {{ ref('dim_stations') }} as s on s.station_id = t.start_station_id
left join {{ ref('dim_stations') }} as e on e.station_id = t.end_station_id
group by all
