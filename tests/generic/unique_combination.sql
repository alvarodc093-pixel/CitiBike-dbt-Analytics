{#- Falla con cada combinación de columnas que aparece más de una vez:
    sirve para comprobar el grano de las tablas agregadas. -#}
{% test unique_combination(model, columns) %}
select {{ columns | join(', ') }}, count(*) as n
from {{ model }}
group by {{ columns | join(', ') }}
having count(*) > 1
{% endtest %}
