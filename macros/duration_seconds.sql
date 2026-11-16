{#- Segundos entre dos marcas de hora LOCAL (sin zona), teniendo en cuenta el cambio de hora.

    Citi Bike publica la hora local de Nueva York sin zona horaria. Restarlas tal cual
    falla dos noches al año:
      - Marzo (se adelanta la hora): de 01:55 a 03:05 parecen 70 min y son 10.
        Se resuelve pasando las dos marcas a UTC antes de restar.
      - Noviembre (se retrasa la hora): la hora 01:00-01:59 ocurre dos veces. Un viaje
        de 01:57 (horario de verano) a 01:03 (horario de invierno) sale con duración
        negativa (DuckDB interpreta la hora ambigua como la segunda pasada). Si la
        duración en UTC es negativa y hay un cambio de hora a menos de 1 h del inicio,
        el viaje empezó en la primera pasada: se suma 1 h.
    Un viaje que empieza y termina dentro de la hora repetida sigue siendo ambiguo;
    son muy pocos y se documenta como limitación. -#}
{% macro duration_seconds(start_ts, end_ts, tz='America/New_York') -%}
    (
        datediff('second', timezone('{{ tz }}', {{ start_ts }}), timezone('{{ tz }}', {{ end_ts }}))
        + case
            when datediff('second', timezone('{{ tz }}', {{ start_ts }}), timezone('{{ tz }}', {{ end_ts }})) < 0
             -- Entre 1 h antes y 1 h después del inicio no pasan 2 h: hay cambio de hora.
             and datediff('second', timezone('{{ tz }}', {{ start_ts }} - interval 1 hour),
                          timezone('{{ tz }}', {{ start_ts }} + interval 1 hour)) <> 7200
            then 3600
            else 0
          end
    )
{%- endmacro %}
