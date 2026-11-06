{#- Falla con cada fila cuyo valor queda fuera de [min_value, max_value].
    Los nulos no cuentan (para eso está not_null). Hecho a mano en vez de usar
    dbt_utils para no depender de paquetes externos. -#}
{% test accepted_range(model, column_name, min_value=none, max_value=none, inclusive=true) %}
    {%- set ge = '>=' if inclusive else '>' -%}
    {%- set le = '<=' if inclusive else '<' -%}
select *
from {{ model }}
where {{ column_name }} is not null
  and not (
      true
      {% if min_value is not none %} and {{ column_name }} {{ ge }} {{ min_value }} {% endif %}
      {% if max_value is not none %} and {{ column_name }} {{ le }} {{ max_value }} {% endif %}
  )
{% endtest %}
