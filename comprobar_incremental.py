"""Comprueba que la carga incremental de fct_trips da el mismo resultado que una completa.

El CI construye fct_trips hasta agosto (--full-refresh), añade septiembre en modo
incremental y ejecuta este script, que compara el resultado, columna a columna, con la
versión completa reconstruida desde int_trips__classified. Si difieren en un solo valor
de una sola fila, falla.

Uso: python comprobar_incremental.py   (después de los dos dbt run del CI)
"""

import sys
from pathlib import Path

import duckdb

DB = Path(__file__).parent / "data" / "citibike.duckdb"

# Mismas columnas y transformaciones que models/marts/core/fct_trips.sql.
FULL = """
    select ride_id, cast(started_at as date) as trip_date,
           extract(hour from started_at)::integer as start_hour, started_at, ended_at,
           duration_s, round(duration_s / 60.0, 2) as duration_min, rideable_type,
           rider_type, start_station_id, end_station_id, start_area_code, end_area_code,
           distance_km, is_round_trip, is_cross_area
    from intermediate.int_trips__classified
    where is_valid
"""
INCREMENTAL = "select * from core.fct_trips"


def main() -> int:
    with duckdb.connect(str(DB), read_only=True) as con:
        # Si alguien añade una columna a fct_trips y no aquí, la comparación no valdría.
        cols_fct = [c[0] for c in con.sql(INCREMENTAL).description]
        cols_full = [c[0] for c in con.sql(FULL).description]
        if cols_fct != cols_full:
            print(f"Las columnas no coinciden:\n  fct_trips: {cols_fct}\n  completa:  {cols_full}")
            return 1
        n_inc = con.sql(f"select count(*) from ({INCREMENTAL})").fetchall()[0][0]
        n_full = con.sql(f"select count(*) from ({FULL})").fetchall()[0][0]
        diff = con.sql(
            f"select count(*) from (({INCREMENTAL} except all {FULL}) "
            f"union all ({FULL} except all {INCREMENTAL}))"
        ).fetchall()[0][0]
        meses = con.sql("select count(distinct strftime(trip_date, '%Y-%m')) from core.fct_trips").fetchall()[0][0]
    print(f"incremental: {n_inc:,} filas | completa: {n_full:,} filas | "
          f"meses: {meses} | diferencias: {diff}")
    # Si la carga incremental no hubiera añadido el último mes, las dos versiones
    # coincidirían igualmente: por eso también se exige que estén los 12 meses.
    return 0 if diff == 0 and n_inc == n_full and meses == 12 else 1


if __name__ == "__main__":
    sys.exit(main())
