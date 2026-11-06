"""Comprueba que la carga incremental de fct_trips da el mismo resultado que una completa.

El CI construye fct_trips hasta agosto (--full-refresh), añade septiembre en modo
incremental y ejecuta este script, que compara el resultado con la versión completa
reconstruida desde int_trips__classified. Si difieren en una sola fila, falla.

Uso: python comprobar_incremental.py   (después de los dos dbt run del CI)
"""

import sys
from pathlib import Path

import duckdb

DB = Path(__file__).parent / "data" / "citibike.duckdb"

FULL = """
    select ride_id, cast(started_at as date) as trip_date, duration_s, rider_type,
           start_station_id, end_station_id
    from intermediate.int_trips__classified
    where is_valid
"""
INCREMENTAL = """
    select ride_id, trip_date, duration_s, rider_type, start_station_id, end_station_id
    from core.fct_trips
"""


def main() -> int:
    with duckdb.connect(str(DB), read_only=True) as con:
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
