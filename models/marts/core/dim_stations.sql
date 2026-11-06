-- Una fila por estación. El nombre es el último con el que aparece (por si se ha
-- renombrado) y la posición es la mediana de las coordenadas de todos sus viajes,
-- que es robusta frente a lecturas GPS erróneas.

with appearances as (

    select * from {{ ref('int_stations__unioned') }}

),

latest_name as (

    select station_id, station_name
    from appearances
    where station_name is not null
    qualify row_number() over (partition by station_id order by seen_at desc) = 1

),

stats as (

    select
        station_id,
        round(median(lat), 6)                 as lat,
        round(median(lng), 6)                 as lng,
        count(distinct station_name)          as n_names,
        cast(min(seen_at) as date)            as first_seen_date,
        cast(max(seen_at) as date)            as last_seen_date,
        count(*)                              as n_appearances
    from appearances
    group by station_id

)

select
    s.station_id,
    n.station_name,
    {{ station_area_code('s.station_id') }}  as area_code,
    a.area_name,
    a.is_home_system,
    s.lat,
    s.lng,
    s.n_names,
    s.first_seen_date,
    s.last_seen_date,
    s.n_appearances
from stats as s
left join latest_name as n using (station_id)
left join {{ ref('station_areas') }} as a
    on a.area_code = {{ station_area_code('s.station_id') }}
