-- Demanda diaria con el tipo de día y la meteorología, lista para un dashboard
-- o para medir el efecto de la lluvia. Un día por fila; los días sin viajes salen con 0.

with trips as (

    select * from {{ ref('fct_trips') }}

),

daily as (

    select
        trip_date,
        count(*)                                                  as trips,
        count(*) filter (where rider_type = 'member')             as trips_member,
        count(*) filter (where rider_type = 'casual')             as trips_casual,
        count(*) filter (where rideable_type = 'electric_bike')   as trips_electric,
        count(*) filter (where is_cross_area)                     as trips_cross_area,
        round(median(duration_min), 2)                            as median_duration_min,
        round(median(distance_km) filter (where not is_round_trip), 3)
                                                                  as median_distance_km
    from trips
    group by trip_date

)

select
    d.date_day,
    d.year_month,
    d.iso_weekday,
    d.weekday_name,
    d.season,
    d.day_type,
    d.holiday_name,
    d.temp_max_c,
    d.precipitation_mm,
    d.snowfall_cm,
    d.weather_category,
    coalesce(t.trips, 0)                                          as trips,
    coalesce(t.trips_member, 0)                                   as trips_member,
    coalesce(t.trips_casual, 0)                                   as trips_casual,
    coalesce(t.trips_electric, 0)                                 as trips_electric,
    coalesce(t.trips_cross_area, 0)                               as trips_cross_area,
    round(t.trips_electric / nullif(t.trips, 0), 4)               as share_electric,
    round(t.trips_member / nullif(t.trips, 0), 4)                 as share_member,
    t.median_duration_min,
    t.median_distance_km
from {{ ref('dim_date') }} as d
left join daily as t on t.trip_date = d.date_day
