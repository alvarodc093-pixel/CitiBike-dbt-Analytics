-- Calendario del periodo con el tipo de día y el tiempo que hizo.
-- Se genera a partir de las fechas, no de los viajes: así un día sin viajes
-- (p. ej. una nevada que cierra el sistema) también aparece, con 0.

with spine as (

    select cast(d as date) as date_day
    from range(
        date '{{ var("periodo_inicio") }}',
        date '{{ var("periodo_fin") }}',
        interval 1 day
    ) as t(d)

),

weather as (

    select * from {{ ref('stg_openmeteo__weather_daily') }}

),

-- La meteorología de los días previos: hace falta para saber si un día "seco" llega
-- justo después de una nevada fuerte (calles y carriles bici todavía cubiertos).
weather_context as (

    select
        *,
        bool_or(snowfall_cm >= {{ var('umbral_nevada_fuerte_cm') }}) over (
            order by weather_date
            rows between {{ var('dias_tras_nevada') }} preceding and 1 preceding
        )                                                as follows_heavy_snow
    from weather

),

holidays as (

    select cast(holiday_date as date) as holiday_date, holiday_name
    from {{ ref('us_holidays') }}

)

select
    s.date_day,
    extract(year from s.date_day)::integer               as year,
    extract(month from s.date_day)::integer              as month,
    strftime(s.date_day, '%Y-%m')                        as year_month,
    isodow(s.date_day)                                   as iso_weekday,
    case isodow(s.date_day)
        when 1 then 'lunes' when 2 then 'martes' when 3 then 'miércoles'
        when 4 then 'jueves' when 5 then 'viernes' when 6 then 'sábado'
        else 'domingo'
    end                                                  as weekday_name,
    case
        when extract(month from s.date_day) in (12, 1, 2) then 'invierno'
        when extract(month from s.date_day) in (3, 4, 5)  then 'primavera'
        when extract(month from s.date_day) in (6, 7, 8)  then 'verano'
        else 'otoño'
    end                                                  as season,
    h.holiday_name,
    case
        when h.holiday_date is not null    then 'festivo'
        when isodow(s.date_day) >= 6       then 'fin de semana'
        else 'laborable'
    end                                                  as day_type,
    w.temp_max_c,
    w.temp_min_c,
    w.precipitation_mm,
    w.snowfall_cm,
    w.wind_max_kmh,
    case
        when w.snowfall_cm >= {{ var('umbral_nieve_cm') }}              then 'nieve'
        when w.precipitation_mm >= {{ var('umbral_lluvia_fuerte_mm') }} then 'lluvia fuerte'
        when w.precipitation_mm >= {{ var('umbral_lluvia_mm') }}        then 'lluvia'
        else 'seco'
    end                                                  as weather_category,
    coalesce(w.follows_heavy_snow, false)                as follows_heavy_snow
from spine as s
left join weather_context as w on w.weather_date = s.date_day
left join holidays as h on h.holiday_date = s.date_day
