select
    cast("time" as date)                    as weather_date,
    "temperature_2m_max (°C)"               as temp_max_c,
    "temperature_2m_min (°C)"               as temp_min_c,
    "precipitation_sum (mm)"                as precipitation_mm,
    "snowfall_sum (cm)"                     as snowfall_cm,
    "wind_speed_10m_max (km/h)"             as wind_max_kmh
from {{ source('openmeteo', 'weather_daily') }}
