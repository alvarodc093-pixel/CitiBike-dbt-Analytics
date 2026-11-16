-- Cuánto baja la demanda con lluvia o nieve.
-- Comparar la media de días lluviosos con la de días secos engaña: llueve y nieva
-- más en invierno, cuando ya se usa menos la bici. Por eso cada día se compara con
-- la media de los días SECOS del mismo mes y del mismo tipo de día (laborable o no).
--
-- Los días secos que siguen a una nevada fuerte no sirven de referencia: no llueve,
-- pero las calles siguen cubiertas (el 24/02/2026, seco, tuvo 170 viajes). Se separan
-- en su propia categoría, "seco tras nevada", y así también se mide cuánto dura el efecto.

with days as (

    select
        *,
        case when day_type = 'laborable' then 'laborable' else 'fin de semana o festivo' end as day_group,
        case
            when weather_category = 'seco' and follows_heavy_snow then 'seco tras nevada'
            else weather_category
        end                                                                          as impact_category
    from {{ ref('mart_daily_demand') }}

),

baseline as (

    select year_month, day_group, avg(trips) as dry_avg_trips, count(*) as dry_days
    from days
    where impact_category = 'seco'
    group by all

),

compared as (

    select
        d.impact_category,
        d.trips,
        b.dry_avg_trips,
        d.trips / b.dry_avg_trips - 1 as pct_vs_dry
    from days as d
    join baseline as b using (year_month, day_group)
    -- Se exige una base de al menos 3 días secos para que la comparación sea estable.
    where b.dry_days >= 3

)

select
    impact_category                                       as weather_category,
    count(*)                                              as n_days,
    round(avg(trips))                                     as avg_trips,
    round(avg(dry_avg_trips))                             as avg_dry_baseline,
    round(avg(pct_vs_dry), 4)                             as avg_pct_vs_dry,
    round(median(pct_vs_dry), 4)                          as median_pct_vs_dry,
    -- Intervalo de confianza del 95 % de la media (aproximación normal). Con pocos días
    -- el intervalo es ancho: indica cuánto fiarse de la cifra.
    round(avg(pct_vs_dry) - 1.96 * stddev_samp(pct_vs_dry) / sqrt(count(*)), 4)
                                                          as ci95_low,
    round(avg(pct_vs_dry) + 1.96 * stddev_samp(pct_vs_dry) / sqrt(count(*)), 4)
                                                          as ci95_high
from compared
group by impact_category
