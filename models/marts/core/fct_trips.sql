{{
    config(
        materialized = 'incremental',
        unique_key = 'ride_id',
        incremental_strategy = 'delete+insert',
        on_schema_change = 'fail'
    )
}}

-- Tabla de hechos: un registro por viaje válido.
-- Es incremental: cuando se añade un mes nuevo solo procesa los viajes recientes.
-- Se reprocesan los 3 últimos días ya cargados porque un viaje que cruza la
-- medianoche del fin de mes puede llegar en el fichero del mes siguiente.

with trips as (

    select * from {{ ref('int_trips__classified') }}
    where is_valid
    {% if is_incremental() %}
      and started_at >= (select max(started_at) - interval 3 day from {{ this }})
    {% endif %}

)

select
    ride_id,
    cast(started_at as date)                as trip_date,
    extract(hour from started_at)::integer  as start_hour,
    started_at,
    ended_at,
    duration_s,
    round(duration_s / 60.0, 2)             as duration_min,
    rideable_type,
    rider_type,
    start_station_id,
    end_station_id,
    start_area_code,
    end_area_code,
    distance_km,
    is_round_trip,
    is_cross_area
from trips
