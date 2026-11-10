"""Genera los gráficos del README a partir de las tablas de analytics.

Uso: python graficos.py   (después de dbt build)
"""

from pathlib import Path

import duckdb
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import pandas as pd  # noqa: E402

RAIZ = Path(__file__).parent
DB = RAIZ / "data" / "citibike.duckdb"
IMG = RAIZ / "docs" / "img"

# Paleta categórica validada (contraste y daltonismo): azul y naranja como dos polos.
AZUL = "#2a78d6"
NARANJA = "#eb6834"
GRIS = "#9ca3af"
TINTA = "#52514e"

plt.rcParams.update({
    "figure.dpi": 120,
    "axes.spines.top": False,
    "axes.spines.right": False,
    "axes.titleweight": "bold",
    "axes.titlesize": 12,
    "axes.edgecolor": GRIS,
    "axes.labelcolor": TINTA,
    "xtick.color": TINTA,
    "ytick.color": TINTA,
    "axes.grid": True,
    "grid.color": "#e5e7eb",
    "grid.linewidth": 0.6,
    "axes.axisbelow": True,
    "font.size": 10,
})


def sql(con, q: str) -> pd.DataFrame:
    return con.sql(q).df()


def guardar(fig, nombre: str) -> None:
    fig.tight_layout()
    fig.savefig(IMG / nombre, facecolor="white")
    plt.close(fig)
    print(f"  docs/img/{nombre}")


def demanda_horaria(con) -> None:
    # Media del sistema: viajes de cada hora / días de ese tipo en el periodo.
    # No se suman las medias de mart_station_hourly_profile: cada estación se promedia
    # sobre los días en que existía, y sumarlas inflaría la demanda de los primeros
    # meses con estaciones que aún no estaban abiertas (~8 % de más).
    df = sql(con, """
        with dias as (
            select date_day,
                   case when day_type = 'laborable' then 'laborable'
                        else 'fin de semana o festivo' end as day_group
            from core.dim_date
        ),
        n_dias as (select day_group, count(*) as n from dias group by all)
        select f.start_hour as hour, d.day_group, count(*) / any_value(n.n) as viajes
        from core.fct_trips as f
        join dias as d on d.date_day = f.trip_date
        join n_dias as n using (day_group)
        group by all order by hour
    """)
    fig, ax = plt.subplots(figsize=(10, 4.2))
    for grupo, color in [("laborable", AZUL), ("fin de semana o festivo", NARANJA)]:
        d = df[df.day_group == grupo]
        ax.plot(d.hour, d.viajes, color=color, lw=2.2, label=grupo)
        pico = d.loc[d.viajes.idxmax()]
        ax.annotate(f"{pico.viajes:.0f} viajes/h", (pico.hour, pico.viajes),
                    xytext=(0, 8), textcoords="offset points", ha="center", color=TINTA)
    ax.set_xticks(range(0, 24, 2), [f"{h}:00" for h in range(0, 24, 2)])
    ax.set_ylabel("Viajes por hora (media)")
    ax.set_title("Laborables: dos picos de trabajo (8:00 y 17:00). Fines de semana: uso de ocio a mediodía")
    ax.legend(frameon=False, loc="upper left")
    ax.set_ylim(0, df.viajes.max() * 1.15)
    guardar(fig, "demanda_horaria.png")


def perfil_grove(con) -> None:
    df = sql(con, """
        select hour, avg_net_flow from analytics.mart_station_hourly_profile
        where station_id = 'JC115' and day_group = 'laborable' order by hour
    """)
    fig, ax = plt.subplots(figsize=(10, 4.2))
    colores = [AZUL if v >= 0 else NARANJA for v in df.avg_net_flow]
    ax.bar(df.hour, df.avg_net_flow, color=colores, width=0.8)
    ax.axhline(0, color=TINTA, lw=0.8)
    ax.set_xticks(range(0, 24, 2), [f"{h}:00" for h in range(0, 24, 2)])
    ax.set_ylabel("Llegadas - salidas (bicis/h)")
    am = df[df.hour.between(6, 9)].avg_net_flow.sum()
    pm = df[df.hour.between(16, 19)].avg_net_flow.sum()
    ax.text(9.8, df.avg_net_flow.max() * 0.85, f"+{am:.0f} bicis entre 6 y 10 h", ha="left",
            va="center", color=TINTA)
    ax.text(19.8, df.avg_net_flow.min() * 0.85, f"{pm:.0f} bicis entre 16 y 20 h", ha="left",
            va="center", color=TINTA)
    ax.set_title("Grove St PATH en un laborable: se llena por la mañana y se vacía por la tarde")
    guardar(fig, "grove_st_perfil.png")


def estaciones_punta(con) -> None:
    df = sql(con, """
        (select station_name, am_peak_net_flow from analytics.mart_station_rebalancing
         order by am_peak_net_flow desc limit 9)
        union all
        (select station_name, am_peak_net_flow from analytics.mart_station_rebalancing
         order by am_peak_net_flow asc limit 6)
    """).sort_values("am_peak_net_flow")
    fig, ax = plt.subplots(figsize=(10, 5.6))
    colores = [AZUL if v >= 0 else NARANJA for v in df.am_peak_net_flow]
    ax.barh(df.station_name, df.am_peak_net_flow, color=colores, height=0.7)
    ax.axvline(0, color=TINTA, lw=0.8)
    for y, v in enumerate(df.am_peak_net_flow):
        ax.text(v + (0.8 if v >= 0 else -0.8), y, f"{v:+.0f}", va="center",
                ha="left" if v >= 0 else "right", color=TINTA, fontsize=9)
    ax.set_xlabel("Bicis ganadas (+) o perdidas (-) de 6:00 a 9:59, media de un laborable")
    ax.set_xlim(df.am_peak_net_flow.min() - 6, df.am_peak_net_flow.max() + 8)
    ax.grid(axis="y", visible=False)
    fig.suptitle("Punta de mañana: unas pocas estaciones, casi todas junto al tren, "
                 "acumulan las bicis", fontweight="bold", fontsize=12)
    guardar(fig, "estaciones_punta.png")


def demanda_diaria(con) -> None:
    df = sql(con, """
        select date_day, trips, weather_category from analytics.mart_daily_demand order by 1
    """)
    df["media_7d"] = df.trips.rolling(7, center=True, min_periods=4).mean()
    fig, ax = plt.subplots(figsize=(10, 4.2))
    ax.scatter(df.date_day, df.trips, s=9, color=GRIS, label="viajes del día", zorder=2)
    nieve = df[df.weather_category == "nieve"]
    ax.scatter(nieve.date_day, nieve.trips, s=26, color=NARANJA, label="día con nieve", zorder=3)
    ax.plot(df.date_day, df.media_7d, color=AZUL, lw=2.2, label="media móvil 7 días", zorder=4)
    cero = df[df.trips == 0]
    for _, r in cero.iterrows():
        ax.annotate(f"{r.date_day:%d/%m}: temporal de nieve,\nsistema cerrado (0 viajes)",
                    (r.date_day, 0), xytext=(r.date_day + pd.Timedelta(days=35), 450),
                    color=TINTA, arrowprops={"arrowstyle": "->", "color": TINTA})
    ax.set_ylabel("Viajes por día")
    ax.set_ylim(0)
    ax.set_title("La demanda se multiplica casi por 4 entre febrero y verano")
    ax.legend(frameon=False, loc="upper left")
    guardar(fig, "demanda_diaria.png")


def efecto_meteo(con) -> None:
    orden = ["lluvia", "lluvia fuerte", "nieve"]
    df = sql(con, "select * from analytics.mart_weather_impact").set_index("weather_category")
    df = df.loc[orden]
    fig, ax = plt.subplots(figsize=(8, 3.6))
    ax.bar(df.index, df.avg_pct_vs_dry * 100, color=NARANJA, width=0.55)
    ax.axhline(0, color=TINTA, lw=0.8)
    for x, (v, n) in enumerate(zip(df.avg_pct_vs_dry, df.n_days)):
        ax.text(x, v * 100 - 1.5, f"{v:+.0%}\n({n} días)", ha="center", va="top", color=TINTA)
    ax.set_ylabel("% frente a un día seco comparable")
    ax.set_ylim(df.avg_pct_vs_dry.min() * 100 - 14, 3)
    ax.grid(axis="x", visible=False)
    ax.set_title("La lluvia ligera apenas frena la demanda; la fuerte, un tercio")
    guardar(fig, "efecto_meteo.png")


def main() -> None:
    IMG.mkdir(parents=True, exist_ok=True)
    with duckdb.connect(str(DB), read_only=True) as con:
        demanda_horaria(con)
        perfil_grove(con)
        estaciones_punta(con)
        demanda_diaria(con)
        efecto_meteo(con)


if __name__ == "__main__":
    main()
