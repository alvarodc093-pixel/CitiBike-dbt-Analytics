-- Cuánto baja la demanda con lluvia o nieve.
-- Comparar la media de días lluviosos con la de días secos engaña: llueve y nieva
-- más en invierno, cuando ya se usa menos la bici. Por eso cada día se compara con
-- la media de los días SECOS del mismo mes y del mismo tipo de día (laborable o no).

with days as (

    select
        *,
        case when day_type = 'laborable' then 'laborable' else 'fin de semana o festivo' end as day_group
    from {{ ref('mart_daily_demand') }}

),

baseline as (

    select year_month, day_group, avg(trips) as dry_avg_trips, count(*) as dry_days
    from days
    where weather_category = 'seco'
    group by all

),

compared as (

    select
        d.weather_category,
        d.trips,
        b.dry_avg_trips,
        d.trips / b.dry_avg_trips - 1 as pct_vs_dry
    from days as d
    join baseline as b using (year_month, day_group)
    -- Se exige una base de al menos 3 días secos para que la comparación sea estable.
    where b.dry_days >= 3

)

select
    weather_category,
    count(*)                              as n_days,
    round(avg(trips))                     as avg_trips,
    round(avg(dry_avg_trips))             as avg_dry_baseline,
    round(avg(pct_vs_dry), 4)             as avg_pct_vs_dry,
    round(median(pct_vs_dry), 4)          as median_pct_vs_dry
from compared
group by weather_category
