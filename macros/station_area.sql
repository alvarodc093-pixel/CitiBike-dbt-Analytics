{#- Zona de una estación a partir del prefijo de su id: JC = Jersey City, HB = Hoboken,
    id numérico = estación de Nueva York (viaje que cruza el río Hudson). -#}
{% macro station_area_code(station_id) -%}
    case
        when {{ station_id }} is null then null
        when {{ station_id }} like 'JC%' then 'JC'
        when {{ station_id }} like 'HB%' then 'HB'
        when regexp_matches({{ station_id }}, '^[0-9]') then 'NYC'
        else 'OTRA'
    end
{%- endmacro %}
