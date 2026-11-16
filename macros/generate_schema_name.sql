{#- Esquemas staging, core... en vez de main_staging: más legibles en DuckDB, donde no
    hay entornos que separar por prefijo. -#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}{{ target.schema }}{%- else -%}{{ custom_schema_name | trim }}{%- endif -%}
{%- endmacro %}
