{% docs __overview__ %}
# Citi Bike Jersey City · pipeline dbt

Documentación generada automáticamente por dbt para el proyecto
[CitiBike-dbt-Analytics](https://github.com/alvarodc093-pixel/CitiBike-dbt-Analytics).

**Qué hay aquí:** 966.000 viajes de bici compartida en Jersey City y Hoboken
(octubre de 2025 a septiembre de 2026) y la meteorología diaria, transformados en
tablas listas para analizar.

**Capas**

| Capa | Qué hace | Modelos |
|---|---|---|
| `staging` | Limpia nombres y tipos y elimina duplicados. 1:1 con el origen | `stg_citibike__trips`, `stg_openmeteo__weather_daily` |
| `intermediate` | Reglas de negocio: qué viaje es válido y por qué se excluye | `int_trips__classified`, `int_stations__unioned` |
| `core` | Modelo en estrella: hechos y dimensiones | `fct_trips` (incremental, con contrato), `dim_stations`, `dim_date` |
| `analytics` | Tablas para responder preguntas concretas | demanda diaria, efecto de la meteorología, perfil horario, reparto de bicis, flujos origen-destino, calidad de datos |

**Cómo navegar:** pulsa el botón azul de abajo a la derecha para ver el grafo de
linaje completo, o elige un modelo en el panel de la izquierda para ver sus columnas,
tests y el SQL compilado.
{% enddocs %}
