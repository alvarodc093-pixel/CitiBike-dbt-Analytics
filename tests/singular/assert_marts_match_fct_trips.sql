-- Las tablas agregadas suman lo mismo que la tabla de hechos:
--   - viajes de mart_daily_demand = viajes de fct_trips
--   - viajes de mart_od_flows      = viajes de fct_trips
--   - salidas de mart_station_daily_balance  = viajes que salen de una estación propia
--   - salidas de mart_station_hourly_profile = lo mismo, contado por horas
-- (todas las salidas son de estaciones propias, pero se comprueba igualmente).

with fct as (
    select
        count(*) as trips,
        count(*) filter (where start_area_code in ('JC', 'HB')) as home_departures
    from {{ ref('fct_trips') }}
),

daily as (select sum(trips) as trips from {{ ref('mart_daily_demand') }}),
od    as (select sum(trips) as trips from {{ ref('mart_od_flows') }}),
bal   as (select sum(departures) as departures from {{ ref('mart_station_daily_balance') }}),
hrs   as (select sum(departures) as departures from {{ ref('mart_station_hourly_profile') }})

select fct.trips, fct.home_departures, daily.trips as daily_trips,
       od.trips as od_trips, bal.departures as balance_departures,
       hrs.departures as hourly_departures
from fct, daily, od, bal, hrs
where daily.trips <> fct.trips
   or od.trips <> fct.trips
   or bal.departures <> fct.home_departures
   or hrs.departures <> fct.home_departures
