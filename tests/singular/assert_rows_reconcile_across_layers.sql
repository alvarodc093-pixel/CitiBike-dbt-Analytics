-- Ninguna fila se pierde sin explicación entre capas:
--   filas del CSV = duplicados + viajes válidos + viajes excluidos (por motivo)
--   viajes válidos en mart_data_quality = filas de fct_trips
-- Devuelve filas (= falla) si alguna de las dos igualdades no se cumple.

with dq as (

    select
        sum(raw_rows)                                  as raw_rows,
        sum(duplicates_removed)                        as duplicates,
        sum(valid_trips)                               as valid_trips,
        sum(excl_out_of_period + excl_negative_duration + excl_false_start
            + excl_over_24h + excl_no_start_station + excl_no_end_station) as excluded
    from {{ ref('mart_data_quality') }}

),

fct as (

    select count(*) as fct_rows from {{ ref('fct_trips') }}

)

select *
from dq cross join fct
where raw_rows <> duplicates + valid_trips + excluded
   or valid_trips <> fct_rows
