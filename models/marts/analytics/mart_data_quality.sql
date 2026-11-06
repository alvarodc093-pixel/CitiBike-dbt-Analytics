-- Cuántas filas llegan, cuántas se descartan y por qué, por fichero mensual.
-- Sirve para vigilar la calidad de cada carga y para explicar las cifras finales.

with raw as (

    select regexp_extract(filename, 'JC-(\d{6})', 1) as source_file_month, count(*) as raw_rows
    from {{ source('citibike', 'trips') }}
    group by all

),

classified as (

    select
        source_file_month,
        count(*)                                                                  as deduplicated_rows,
        count(*) filter (where is_valid)                                          as valid_trips,
        count(*) filter (where exclusion_reason = 'fuera_de_periodo')             as excl_out_of_period,
        count(*) filter (where exclusion_reason = 'duracion_negativa')            as excl_negative_duration,
        count(*) filter (where exclusion_reason = 'falso_arranque')               as excl_false_start,
        count(*) filter (where exclusion_reason = 'mas_de_24h')                   as excl_over_24h,
        count(*) filter (where exclusion_reason = 'sin_estacion_origen')          as excl_no_start_station,
        count(*) filter (where exclusion_reason = 'sin_estacion_destino')         as excl_no_end_station
    from {{ ref('int_trips__classified') }}
    group by all

)

select
    r.source_file_month,
    r.raw_rows,
    r.raw_rows - c.deduplicated_rows                       as duplicates_removed,
    c.* exclude (source_file_month),
    round(c.valid_trips / r.raw_rows, 4)                   as share_valid
from raw as r
join classified as c using (source_file_month)
order by r.source_file_month
