# Citi Bike Jersey City: pipeline de datos con dbt

Pipeline de analytics engineering (dbt + DuckDB) sobre 972.000 viajes reales de bici compartida y la meteorología diaria: modelo en estrella, 85 tests, carga incremental verificada en CI y documentación publicada.

**Documentación y linaje:** [demo en GitHub Pages](https://alvarodc093-pixel.github.io/CitiBike-dbt-Analytics/)

[![CI](https://github.com/alvarodc093-pixel/CitiBike-dbt-Analytics/actions/workflows/ci.yml/badge.svg)](https://github.com/alvarodc093-pixel/CitiBike-dbt-Analytics/actions/workflows/ci.yml) ![dbt](https://img.shields.io/badge/dbt-1.12-FF694B?style=flat-square&logo=dbt&logoColor=white) ![DuckDB](https://img.shields.io/badge/DuckDB-2.0-FFF000?style=flat-square&logo=duckdb&logoColor=black) ![Python](https://img.shields.io/badge/Python-3.13-3776AB?style=flat-square&logo=python&logoColor=white)

![Grove St PATH: se llena por la mañana y se vacía por la tarde](docs/img/grove_st_perfil.png)

## Qué es

- **Problema:** un sistema de bici compartida tiene que saber cuánta demanda habrá, qué la frena y, sobre todo, **dónde se acumulan las bicis y dónde faltan**: el reparto con camiones es su mayor coste operativo. Para responderlo hace falta primero un modelo de datos limpio, probado y documentado, que es el objetivo de este proyecto.
- **Datos:** 12 meses (octubre de 2025 a septiembre de 2026) de [viajes de Citi Bike en Jersey City y Hoboken](https://citibikenyc.com/system-data), 12 CSV mensuales, más la meteorología diaria de [Open-Meteo](https://open-meteo.com/).
- **dbt:** 15 modelos en cuatro capas (staging → intermediate → core → analytics), un hecho **incremental** con **contrato de datos**, **85 tests** (83 de datos y 2 de cuadre entre capas) y **2 unit tests** (reglas de exclusión y cambio de hora). Además, macros propias, 3 *seeds*, variables de proyecto, *exposures*, todas las columnas de los marts documentadas y documentación publicada en GitHub Pages en cada push.
- **Resultado:** unas pocas estaciones, casi todas junto al tren, acumulan **~210 bicis cada mañana laborable** y las devuelven por la tarde. Grove St PATH gana en la punta **1,5 veces sus anclajes**. Frente a un día seco comparable, un día de lluvia fuerte tiene **un 35 %** menos viajes, uno de nieve **un 55 %** menos, y los días secos tras una nevada siguen **un 45 %** por debajo. El 99,4 % de las filas de origen son válidas, y cada fila descartada tiene su motivo registrado.

## Hallazgos

| # | Pregunta | Respuesta corta | Modelo |
|---|---|---|---|
| 1 | ¿Cuándo se usa la bici? | Los laborables tienen dos picos de trabajo: **8:00 (228 viajes/h)** y **17:00 (312 viajes/h)**. El fin de semana no hay picos: una meseta de ocio de 11 a 18 h. Un laborable medio tiene 2.814 viajes y un día de fin de semana, 2.323. | [`fct_trips`](models/marts/core/fct_trips.sql) + [`dim_date`](models/marts/core/dim_date.sql) |
| 2 | ¿Dónde se acumulan las bicis? | El balance del día engaña: casi todas las estaciones parecen "equilibradas" porque lo que entra por la mañana sale por la tarde. Por horas, **Grove St PATH gana 61 bicis de 6 a 10 h y pierde 54 de 16 a 20 h**. Gana más bicis que anclajes tiene (61 frente a 42, 1,46 por anclaje): **hay que retirar bicis durante la propia punta**. Lo mismo, a menor escala, en otras estaciones junto a Hoboken Terminal, Exchange Pl o Bergen Ave. Contado día a día, suman **~210 bicis** cada mañana laborable (mediana: 226). | [`mart_station_rebalancing`](models/marts/analytics/mart_station_rebalancing.sql) + [`mart_weekday_peak_load`](models/marts/analytics/mart_weekday_peak_load.sql) |
| 3 | ¿Cuánto frena la meteorología? | Frente a un día seco del mismo mes y tipo de día: lluvia ligera **−8 %**, lluvia fuerte (≥ 10 mm) **−35 %** y nieve (≥ 1 cm) **−55 %** (IC 95 %: de −73 % a −37 %, 12 días). El efecto no acaba cuando deja de nevar: los 3 días secos tras una nevada fuerte siguen un **−45 %**. El 23 de febrero de 2026, con 14 cm de nieve, no se registró **ni un viaje**. | [`mart_weather_impact`](models/marts/analytics/mart_weather_impact.sql) |
| 4 | ¿Cuánto pesa la estacionalidad? | De **907 viajes/día en febrero a 3.578 en verano**: casi 4 veces más. | [`mart_daily_demand`](models/marts/analytics/mart_daily_demand.sql) |
| 5 | ¿Quién usa el sistema? | El **77 %** de los viajes son de abonados, con viajes cortos y de rutina (mediana de 5,7 min). Los ocasionales hacen viajes más largos (8,1 min) y pasan del 20 % de los viajes en laborable al **32 % en fin de semana**. El **64 %** de los viajes son en bici eléctrica. | [`fct_trips`](models/marts/core/fct_trips.sql) |
| 6 | ¿Se mueve la gente entre ciudades? | El 12 % de los viajes van de Jersey City a Hoboken o al revés. Solo 3.048 (0,3 %) cruzan el río hasta Manhattan, a 384 estaciones distintas. | [`mart_od_flows`](models/marts/analytics/mart_od_flows.sql) |
| 7 | ¿Qué calidad tienen los datos? | De 972.092 filas, **966.469 son viajes válidos (99,4 %)**. Se descartan 5.024 sin estación de destino, 561 de más de 24 h, 18 duplicados, 16 de fuera del periodo y 4 sin estación de origen. Los 7 viajes que parecían tener duración negativa eran viajes normales de la noche del cambio de hora y se recuperan. | [`mart_data_quality`](models/marts/analytics/mart_data_quality.sql) |

![Punta de mañana por estación](docs/img/estaciones_punta.png)

## Recomendaciones de negocio

1. **Planificar el reparto por horas, no por días.** Un informe diario diría que el sistema está equilibrado. El camión tiene que vaciar Grove St PATH, las de Hoboken Terminal y Bergen Ave & Sip Ave **antes de las 9:00** y volver a llenarlas **antes de las 16:00**: unas 210 bicis cada laborable.
2. **Ampliar los anclajes de Grove St PATH antes que mover más bicis.** Gana 61 bicis en la punta y tiene 42 anclajes: aunque el camión la deje vacía a las 6:00, hay que volver a retirar bicis antes de las 10:00. Ninguna otra estación pasa de 0,7 bicis por anclaje. Una estación llena a las 8:30 deja sin sitio a quien viene a coger el tren y se pierde ese cliente.
3. **Usar la previsión del tiempo para dimensionar la plantilla.** Un día de lluvia fuerte tiene un tercio menos de viajes y uno de nieve, la mitad: menos reparto y buen momento para el mantenimiento. Tras una nevada fuerte, la demanda sigue un 45 % por debajo durante 3 días: limpiar primero los accesos a las estaciones de tren puede adelantar la recuperación.
4. **Convertir a los ocasionales del fin de semana en abonados.** Hacen viajes más largos, sobre todo en eléctrica, y el fin de semana pasan del 20 % al 32 % de los viajes. Una oferta de primer mes de abono tras su segundo viaje de fin de semana es el embudo natural.

## Cómo está montado

```mermaid
flowchart LR
    subgraph Origen
        A[(12 CSV de Citi Bike)]
        B[(Open-Meteo)]
        S1[/seed: station_areas/]
        S2[/seed: us_holidays/]
        S3[/seed: station_capacity/]
    end
    subgraph staging
        C[stg_citibike__trips]
        D[stg_openmeteo__weather_daily]
    end
    subgraph intermediate
        E[int_trips__classified]
        F[int_stations__unioned]
    end
    subgraph core
        G[fct_trips<br/>incremental + contrato]
        H[dim_stations]
        I[dim_date]
    end
    subgraph analytics
        J[mart_daily_demand]
        K[mart_weather_impact]
        L[mart_station_hourly_profile]
        M[mart_station_rebalancing]
        N[mart_od_flows]
        O[mart_data_quality]
        P[mart_weekday_peak_load]
    end
    A --> C --> E --> G
    C --> F --> H
    B --> D --> I
    S1 --> E
    S1 --> H
    S2 --> I
    S3 --> H
    M --> P
    G --> J & L & N
    I --> J --> K
    H --> L --> M
    E --> O
```

| Capa | Materialización | Qué hace |
|---|---|---|
| `staging` | vista (y tabla en `stg_citibike__trips`) | Renombra, fija tipos y elimina duplicados. No descarta ningún viaje: eso se decide después, para poder contarlo. |
| `intermediate` | vista | Reglas de negocio. `int_trips__classified` es el **único** sitio donde se decide qué viaje es válido, así que la tabla de hechos y la de calidad siempre cuadran. |
| `core` | tabla / incremental | Modelo en estrella. `fct_trips` es incremental y tiene **contrato**: si una columna cambia de tipo o de nombre, dbt falla al construirla en vez de romper los informes. |
| `analytics` | tabla | Una tabla por pregunta de negocio, que leen los gráficos (declarados como *exposure*). |

### Calidad: qué prueba cada test

| Tipo | Ejemplos |
|---|---|
| **Genéricos de dbt** | `unique` y `not_null` en cada clave, `accepted_values` en categorías y `relationships` de los hechos con sus dimensiones. |
| **Genéricos propios** ([`tests/generic`](tests/generic)) | `accepted_range` (duración entre 60 s y 24 h, coordenadas dentro del área, hora entre 0 y 23), `unique_combination` (grano de las tablas agregadas) e `is_complete_date_spine` (que no falte ningún día). Escritos a mano, sin depender de `dbt_utils`. |
| **Singulares de cuadre** ([`tests/singular`](tests/singular)) | Filas del CSV = duplicados + válidos + excluidos por motivo. Las tablas de analytics suman lo mismo que `fct_trips`. |
| **Unit tests** | [`clasifica_cada_motivo_de_exclusion`](models/intermediate/_intermediate.yml): 8 viajes inventados, uno por cada caso límite (59 s, 60 s, sin destino, de diciembre, a Manhattan…), con el resultado esperado. [`duracion_con_cambio_de_hora`](models/staging/_staging.yml): viajes que cruzan el adelanto de hora de marzo o la hora repetida de noviembre, y un viaje duplicado entre dos ficheros. |
| **Aviso, no error** | Si un fichero mensual baja del 95 % de filas válidas, el test avisa (`severity: warn`) para revisarlo sin bloquear la carga. |
| **Incremental = completa** | El CI carga hasta agosto, añade septiembre en modo incremental y comprueba fila a fila y columna a columna que el resultado es idéntico a una carga completa ([`comprobar_incremental.py`](comprobar_incremental.py)). |

### Decisiones y trampas evitadas

- **Duplicados entre ficheros.** Un viaje que empieza el 30 de abril a las 23:56 y termina el 1 de mayo aparece en los ficheros de los dos meses. Se eliminan con `QUALIFY ROW_NUMBER()` sobre `ride_id`.
- **Filtrar por fecha, no por fichero.** El fichero de octubre trae 16 viajes de septiembre. El periodo se define con variables del proyecto (`periodo_inicio`, `periodo_fin`).
- **Leer todo como texto y fijar los tipos en staging.** Los id de estación de Nueva York son numéricos (`5329.03`) y los de Jersey City no (`JC115`). Si se deja que DuckDB detecte los tipos, un mes podría leerse distinto que otro.
- **El calendario no sale de los viajes.** `dim_date` se genera con una serie de fechas. Si saliera de los viajes, el 23 de febrero (0 viajes por el temporal) simplemente no existiría y la media de febrero saldría inflada.
- **Comparar la lluvia con días comparables.** Llueve y nieva más en invierno, cuando ya se usa menos la bici. Cada día se compara con los días secos del **mismo mes y tipo de día**. Comparando todos los días a la vez, la nieve parecería asociarse a un 79 % menos de viajes en lugar de un 55 %.
- **Las medias por estación, sobre los días que existía.** Hudson Pl & Hoboken Terminal abrió el 31 de julio. Dividiendo entre el año entero (250 laborables en lugar de 43), su desequilibrio saldría casi 6 veces más pequeño.
- **Nombres de estación cambiantes.** JC118 aparece con dos nombres ("Pacific Ave & Communipaw Ave" y al revés). `dim_stations` usa el más reciente y guarda cuántos ha tenido.
- **El cambio de hora.** Citi Bike publica la hora local sin zona horaria. Al restar tal cual, 7 viajes de la noche del 2 de noviembre salían con duración negativa (de 01:57 a 01:03, porque esa noche la 1:00 se repite) y los de la noche del adelanto de marzo salían con 1 h de más. La macro [`duration_seconds`](macros/duration_seconds.sql) resta en UTC y corrige la hora repetida.
- **Una estación reubicada no son dos estaciones.** HB106 (River St & Newark St) desaparece el 31 de julio y ese mismo día aparece HB107 (Hudson Pl & Hoboken Terminal), a 116 m. Sumando las medias de cada estación salían ~240 bicis en la punta; contando día a día, salen ~210.
- **"Nieve" tiene que ser nieve que se note.** Open-Meteo modela trazas de 0,07 cm. Si cualquier traza contaba, salían 35 días de nieve en un invierno y un efecto del −25 %. Con 1 cm o más son 12 días y un −55 %. Además, los días secos tras una nevada fuerte no entran en la referencia de día seco: el 24 de febrero, seco, tuvo 170 viajes. Todos los umbrales son variables del proyecto.
- **Una regla que no salta también informa.** El filtro de falsos arranques (< 60 s, el criterio de Citi Bike) no descarta ningún viaje porque Citi Bike ya los quita antes de publicar. Se mantiene como salvaguarda, y la tabla de calidad lo hace visible.

## Más gráficos

![Demanda por hora](docs/img/demanda_horaria.png)

![Demanda diaria](docs/img/demanda_diaria.png)

![Efecto de la meteorología](docs/img/efecto_meteo.png)

## Cómo ejecutarlo

```bash
pip install -r requirements.txt
python descargar_datos.py     # ~35 MB: 12 meses de Citi Bike + meteorología
dbt build                     # construye los 15 modelos y ejecuta todos los tests
python graficos.py            # regenera docs/img/
dbt docs generate && dbt docs serve   # documentación y linaje en el navegador
```

La capacidad de las estaciones es un seed versionado (foto del feed GBFS del 16/11/2026): el feed no guarda histórico. `python descargar_datos.py --capacidad` la actualiza.

`profiles.yml` está en la raíz del proyecto y apunta a `data/citibike.duckdb`, así que no hace falta configurar nada más. Para otro periodo: `python descargar_datos.py 2026-01 2026-06` y `dbt build --vars '{periodo_inicio: "2026-01-01", periodo_fin: "2026-07-01"}'`.

**Por qué DuckDB:** funciona sin servidor y el SQL es estándar. Para llevar el proyecto a Snowflake, BigQuery o PostgreSQL basta con cambiar el adaptador en `profiles.yml` y las fuentes (aquí leen CSV con `read_csv`; allí serían tablas cargadas). Los modelos casi no cambian.

## Limitaciones

- El efecto de la meteorología es una asociación, no un efecto causal: se controlan el mes y el tipo de día, pero no la temperatura ni los eventos de cada día.
- El sistema ya reparte bicis con camiones, y esos movimientos no aparecen en los datos. Las llegadas y salidas miden la demanda de los usuarios, no el número real de bicis en cada estación.
- La distancia es en línea recta entre estaciones, no la ruta recorrida.
- El 0,5 % de los viajes no tiene estación de destino. El 99,5 % de ellos son en bici eléctrica, que se puede dejar fuera de un anclaje. Se excluyen, y el informe de calidad los cuenta.
- La meteorología es diaria y sale de un reanálisis (modelo ERA5 de Open-Meteo, celdas de ~10 km), no de un pluviómetro. Una tormenta a las 3 de la mañana cuenta igual que una a las 8.
- La capacidad es la de noviembre de 2026, no la de cada día del periodo. Si una estación cambió de tamaño durante el año, la relación entre la punta y los anclajes es aproximada. HB106, ya cerrada, no tiene capacidad.
- Un viaje que empieza y termina dentro de la hora repetida de noviembre (de 1:00 a 1:59, que esa noche ocurre dos veces) es ambiguo: no se puede saber si duró unos minutos o una hora más.
- Con 12 días de nieve, el intervalo de confianza es ancho (de −73 % a −37 %). Lo fiable es el orden de magnitud: la nieve reduce la demanda a la mitad.

## English summary

Analytics-engineering project built with dbt Core and DuckDB on 972k real Citi Bike trips (Jersey City & Hoboken, Oct 2025 – Sep 2026), daily weather from Open-Meteo and station capacity from GBFS. It has 15 models in four layers (staging, intermediate, core, analytics), an incremental fact table with an enforced data contract, a star schema, 85 data tests (including custom generic tests and cross-layer reconciliation tests), two unit tests (exclusion rules and durations that handle daylight saving time), seeds, exposures, documented mart columns and dbt docs auto-published to GitHub Pages by CI. CI also proves that the incremental load matches a full refresh row by row and column by column. Key findings: a handful of stations, mostly next to rail hubs, absorb about 210 bikes every weekday morning and release them in the evening, which is invisible in daily totals. Grove St PATH gains 1.5 bikes per dock during the morning peak. Heavy rain cuts demand by 35 % and snow (≥ 1 cm) by 55 % against comparable dry days, and demand stays 45 % lower on the three dry days after a heavy snowfall. 99.4 % of the source rows are valid, and every excluded row is accounted for by reason.

---

Datos: [Citi Bike System Data](https://citibikenyc.com/system-data) y [feed GBFS](https://gbfs.citibikenyc.com/gbfs/gbfs.json) (Lyft Bikes and Scooters, [Data License Agreement](https://citibikenyc.com/data-sharing-policy)) y [Open-Meteo Historical Weather API](https://open-meteo.com/) (CC BY 4.0). Los CSV no se incluyen en el repositorio; `descargar_datos.py` los descarga. El código se publica con licencia [MIT](LICENSE).
