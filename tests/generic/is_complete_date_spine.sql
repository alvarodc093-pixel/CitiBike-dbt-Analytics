{#- Falla si a la serie de fechas le falta algún día entre su mínimo y su máximo. -#}
{% test is_complete_date_spine(model, column_name) %}
with limites as (
    select min({{ column_name }}) as d0, max({{ column_name }}) as d1,
           count(distinct {{ column_name }}) as n
    from {{ model }}
)
select *
from limites
where n <> datediff('day', d0, d1) + 1
{% endtest %}
