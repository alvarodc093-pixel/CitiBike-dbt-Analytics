{#- Usa el nombre de esquema tal cual (staging, core...) en vez de "main_staging".
    Es la convención habitual en proyectos dbt de producción. -#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}{{ target.schema }}{%- else -%}{{ custom_schema_name | trim }}{%- endif -%}
{%- endmacro %}
