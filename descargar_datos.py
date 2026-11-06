"""Descarga los datos de origen del proyecto.

- Viajes de Citi Bike en Jersey City y Hoboken (12 meses), del bucket público
  https://s3.amazonaws.com/tripdata/ (licencia: Citi Bike Data License Agreement).
- Meteorología diaria de Jersey City desde la API histórica de Open-Meteo
  (CC BY 4.0, sin clave).

Los ficheros se guardan en data/raw/ y no se versionan en Git.

Uso:
    python descargar_datos.py                 # periodo por defecto
    python descargar_datos.py 2025-10 2026-09 # periodo a medida (AAAA-MM)
"""

from __future__ import annotations

import io
import sys
import time
import zipfile
from datetime import date
from pathlib import Path

import requests

RAW = Path(__file__).parent / "data" / "raw"
BUCKET = "https://s3.amazonaws.com/tripdata"
INICIO, FIN = "2025-10", "2026-09"
LAT, LON = 40.7178, -74.0431  # Jersey City


def _get(url: str, **kwargs) -> requests.Response:
    """GET con reintentos y espera creciente: un fallo puntual de red no tumba el CI."""
    for intento in range(5):
        try:
            r = requests.get(url, timeout=120, **kwargs)
            if r.status_code == 200:
                return r
            if r.status_code == 404:
                r.raise_for_status()
        except requests.HTTPError:
            raise
        except requests.RequestException as exc:
            print(f"  aviso: {exc}")
        time.sleep(2**intento)
    raise RuntimeError(f"No se pudo descargar {url}")


def meses(inicio: str, fin: str) -> list[str]:
    a, m = map(int, inicio.split("-"))
    fa, fm = map(int, fin.split("-"))
    salida = []
    while (a, m) <= (fa, fm):
        salida.append(f"{a}{m:02d}")
        a, m = (a + 1, 1) if m == 12 else (a, m + 1)
    return salida


def descargar_viajes(mes: str) -> None:
    destino = RAW / "trips" / f"JC-{mes}-citibike-tripdata.csv"
    if destino.exists():
        print(f"  {destino.name} ya existe")
        return
    # El nombre del zip no es constante: unos meses llevan ".csv.zip" y otros ".zip".
    for nombre in (f"JC-{mes}-citibike-tripdata.csv.zip", f"JC-{mes}-citibike-tripdata.zip"):
        try:
            r = _get(f"{BUCKET}/{nombre}")
            break
        except requests.HTTPError:
            continue
    else:
        raise RuntimeError(f"No hay datos de Citi Bike para {mes}")

    with zipfile.ZipFile(io.BytesIO(r.content)) as z:
        csvs = [n for n in z.namelist() if n.endswith(".csv") and not n.startswith("__MACOSX")]
        if len(csvs) != 1:
            raise RuntimeError(f"{nombre}: se esperaba 1 CSV y hay {csvs}")
        destino.parent.mkdir(parents=True, exist_ok=True)
        destino.write_bytes(z.read(csvs[0]))
    print(f"  {destino.name} ({destino.stat().st_size / 1e6:.1f} MB)")


def descargar_meteo(inicio: str, fin: str) -> None:
    a, m = map(int, fin.split("-"))
    ultimo = date(a + (m == 12), m % 12 + 1, 1).toordinal() - 1
    params = {
        "latitude": LAT,
        "longitude": LON,
        "start_date": f"{inicio}-01",
        "end_date": date.fromordinal(ultimo).isoformat(),
        "daily": "temperature_2m_max,temperature_2m_min,precipitation_sum,snowfall_sum,wind_speed_10m_max",
        "timezone": "America/New_York",
        "format": "csv",
    }
    r = _get("https://archive-api.open-meteo.com/v1/archive", params=params)
    # El CSV de Open-Meteo trae 3 líneas de metadatos y una línea en blanco antes de la tabla.
    lineas = r.text.splitlines()
    cabecera = next(i for i, linea in enumerate(lineas) if linea.startswith("time,"))
    destino = RAW / "weather" / "jersey_city_daily.csv"
    destino.parent.mkdir(parents=True, exist_ok=True)
    destino.write_text("\n".join(lineas[cabecera:]) + "\n", encoding="utf-8")
    print(f"  {destino.name} ({len(lineas) - cabecera - 1} días)")


def main() -> None:
    inicio, fin = (sys.argv[1], sys.argv[2]) if len(sys.argv) == 3 else (INICIO, FIN)
    print(f"Viajes de Citi Bike JC {inicio} -> {fin}")
    for mes in meses(inicio, fin):
        descargar_viajes(mes)
    print("Meteorología diaria (Open-Meteo)")
    descargar_meteo(inicio, fin)


if __name__ == "__main__":
    main()
