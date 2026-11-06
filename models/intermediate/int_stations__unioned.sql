-- Todas las veces que aparece cada estación, como origen o como destino.
-- Base para dim_stations: una estación puede cambiar de nombre (JC118 tiene dos)
-- y las coordenadas de cada viaje varían unos metros según el GPS de la bici.

with trips as (

    select * from {{ ref('stg_citibike__trips') }}

)

select start_station_id as station_id, start_station_name as station_name,
       start_lat as lat, start_lng as lng, started_at as seen_at
from trips
where start_station_id is not null

union all

select end_station_id, end_station_name, end_lat, end_lng, ended_at
from trips
where end_station_id is not null
