-- Resumen por estación para planificar el reparto de bicis: cuánto se vacía o se
-- llena de media, y con qué frecuencia el desequilibrio es grande.

with balance as (

    select * from {{ ref('mart_station_daily_balance') }}

),

-- Una estación activa es la que tuvo algún movimiento ese día: así no penalizamos
-- las estaciones abiertas a mitad de periodo con meses de ceros.
active_days as (

    select * from balance where departures + arrivals > 0

),

-- Desequilibrio medio en las horas punta de un laborable: es lo que decide a qué
-- estaciones tiene que ir el camión antes de las 6 y a media tarde.
peaks as (

    select
        station_id,
        sum(avg_net_flow) filter (where hour between 6 and 9)    as am_peak_net_flow,
        sum(avg_net_flow) filter (where hour between 16 and 19)  as pm_peak_net_flow
    from {{ ref('mart_station_hourly_profile') }}
    where day_group = 'laborable'
    group by station_id

),

summary as (

    select
        station_id,
        any_value(station_name)                                         as station_name,
        any_value(area_code)                                            as area_code,
        count(*)                                                        as active_days,
        sum(departures)                                                 as departures,
        sum(arrivals)                                                   as arrivals,
        sum(net_flow)                                                   as net_flow,
        round(avg(net_flow), 2)                                         as avg_daily_net_flow,
        round(avg(net_flow) filter (where day_type = 'laborable'), 2)   as avg_net_flow_weekday,
        round(avg(abs(net_flow)), 2)                                    as avg_abs_net_flow,
        round(avg(case when net_flow <= -{{ var('umbral_desequilibrio', 10) }} then 1 else 0 end), 4)
                                                                        as share_days_draining,
        round(avg(case when net_flow >=  {{ var('umbral_desequilibrio', 10) }} then 1 else 0 end), 4)
                                                                        as share_days_filling,
        case
            when avg(net_flow) <= -3 then 'se vacía'
            when avg(net_flow) >=  3 then 'se llena'
            else 'equilibrada'
        end                                                             as daily_balance_profile
    from active_days
    group by station_id

)

select
    s.*,
    round(p.am_peak_net_flow, 1)                                    as am_peak_net_flow,
    round(p.pm_peak_net_flow, 1)                                    as pm_peak_net_flow,
    case
        when p.am_peak_net_flow >=  {{ var('umbral_desequilibrio', 10) }} then 'se llena por la mañana'
        when p.am_peak_net_flow <= -{{ var('umbral_desequilibrio', 10) }} then 'se vacía por la mañana'
        else 'estable en punta'
    end                                                             as peak_profile
from summary as s
left join peaks as p using (station_id)
