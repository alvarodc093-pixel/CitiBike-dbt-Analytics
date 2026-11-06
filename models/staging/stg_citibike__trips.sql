-- Se materializa como tabla (el resto de staging son vistas) porque leer los 12 CSV
-- cuesta unos segundos y la consultan varios modelos y tests.
{{ config(materialized='table') }}

-- Viajes de Citi Bike con nombres y tipos limpios, sin duplicados.
-- No se descarta ningún viaje por calidad aquí: eso se decide en intermediate,
-- para poder medir cuántos se excluyen y por qué.

with source as (

    select * from {{ source('citibike', 'trips') }}

),

renamed as (

    select
        ride_id,
        rideable_type,
        member_casual                              as rider_type,
        cast(started_at as timestamp)              as started_at,
        cast(ended_at as timestamp)                as ended_at,
        nullif(trim(start_station_id), '')         as start_station_id,
        nullif(trim(start_station_name), '')       as start_station_name,
        nullif(trim(end_station_id), '')           as end_station_id,
        nullif(trim(end_station_name), '')         as end_station_name,
        try_cast(nullif(start_lat, '') as double)  as start_lat,
        try_cast(nullif(start_lng, '') as double)  as start_lng,
        try_cast(nullif(end_lat, '') as double)    as end_lat,
        try_cast(nullif(end_lng, '') as double)    as end_lng,
        regexp_extract(filename, 'JC-(\d{6})', 1)  as source_file_month

    from source

),

deduplicated as (

    -- Un viaje que empieza el último día del mes y termina el día 1 aparece en los
    -- dos ficheros mensuales. Son filas idénticas; se queda la del primer fichero.
    select *
    from renamed
    qualify row_number() over (partition by ride_id order by source_file_month) = 1

)

select
    *,
    datediff('second', started_at, ended_at)       as duration_s
from deduplicated
