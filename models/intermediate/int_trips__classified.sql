-- Clasifica cada viaje como válido o no y explica el motivo de exclusión.
-- Es el único sitio donde se decide qué cuenta como viaje: fct_trips y la tabla
-- de calidad de datos leen de aquí, así que las dos cifras siempre cuadran.

with trips as (

    select * from {{ ref('stg_citibike__trips') }}

),

enriched as (

    select
        *,
        {{ station_area_code('start_station_id') }}        as start_area_code,
        {{ station_area_code('end_station_id') }}          as end_area_code,
        round({{ haversine_km('start_lat', 'start_lng', 'end_lat', 'end_lng') }}, 3)
                                                           as distance_km
    from trips

),

classified as (

    select
        *,
        -- El orden importa: se asigna el primer motivo que se cumple.
        case
            when started_at <  date '{{ var("periodo_inicio") }}'
              or started_at >= date '{{ var("periodo_fin") }}'      then 'fuera_de_periodo'
            when duration_s < 0                                     then 'duracion_negativa'
            when duration_s < {{ var('duracion_min_s') }}           then 'falso_arranque'
            when duration_s > {{ var('duracion_max_s') }}           then 'mas_de_24h'
            when start_station_id is null                           then 'sin_estacion_origen'
            when end_station_id is null                             then 'sin_estacion_destino'
        end                                                        as exclusion_reason
    from enriched

)

select
    *,
    exclusion_reason is null                                       as is_valid,
    start_station_id = end_station_id                              as is_round_trip,
    coalesce(start_area_code <> end_area_code, false)              as is_cross_area
from classified
