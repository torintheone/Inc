#!/usr/bin/env python3
"""Собирает данные мира для игры «Призрак».

Результат кладётся в репозиторий, поэтому игре интернет не нужен:
  data/world.json         — страны: названия, показатели, зона мир-системы, соседи
  data/world_shapes.json  — полигоны стран для карты (уже в проекции и триангулированы)

Источники:
  * Natural Earth 1:50m, admin 0 countries (общественное достояние) — границы и названия;
  * Всемирный банк, World Development Indicators (CC BY 4.0) — показатели.

Ответы Всемирного банка сохраняются в tools/cache/worldbank.json, чтобы сборку можно
было повторить без интернета. Запуск:

  python3 tools/build_world.py            # взять кэш, недостающее докачать
  python3 tools/build_world.py --refresh  # перекачать показатели заново
  python3 tools/build_world.py --offline  # без сети: только кэш, остальное — оценки

Зависимости: pip install -r tools/requirements.txt
"""
from __future__ import annotations

import argparse
import json
import math
import statistics
import sys
import time
import urllib.request
from datetime import date
from pathlib import Path

import mapbox_earcut
import numpy as np
import topojson
import shapely
from shapely import STRtree
from shapely.geometry import MultiPolygon, Polygon, mapping, shape
from shapely.validation import make_valid

ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / "tools" / "cache"
NE_URL = ("https://raw.githubusercontent.com/nvkelso/natural-earth-vector/"
          "v5.1.2/geojson/ne_50m_admin_0_countries.geojson")
WB_URL = ("https://api.worldbank.org/v2/country/all/indicator/{code}"
          "?format=json&per_page=20000&mrnev=1")

# Показатель игры -> код Всемирного банка.
INDICATORS = {
    "population": "SP.POP.TOTL",              # население, человек
    "gdp_usd": "NY.GDP.MKTP.CD",              # ВВП, текущие доллары США
    "gdp_per_capita": "NY.GDP.PCAP.CD",       # ВВП на душу, текущие доллары США
    "industry_va": "NV.IND.TOTL.ZS",          # промышленность, % ВВП
    "emp_agriculture": "SL.AGR.EMPL.ZS",      # занятые в сельском хозяйстве, % занятых
    "emp_industry": "SL.IND.EMPL.ZS",         # занятые в промышленности, % занятых
    "emp_services": "SL.SRV.EMPL.ZS",         # занятые в услугах, % занятых
    "wage_workers": "SL.EMP.WORK.ZS",         # наёмные работники, % занятых
    "self_employed": "SL.EMP.SELF.ZS",        # самозанятые, % занятых
    "unemployment": "SL.UEM.TOTL.ZS",         # безработица, % рабочей силы
    "gini": "SI.POV.GINI",                    # коэффициент Джини, 0–100
    "trade": "NE.TRD.GNFS.ZS",                # торговля, % ВВП
    "manuf_exports": "TX.VAL.MANF.ZS.UN",     # промышленные товары, % товарного экспорта
    "fuel_exports": "TX.VAL.FUEL.ZS.UN",      # топливо, % товарного экспорта
    "internet": "IT.NET.USER.ZS",             # пользователи интернета, % населения
    "urban": "SP.URB.TOTL.IN.ZS",             # городское население, %
    "migrant_stock": "SM.POP.TOTL.ZS",        # мигранты, % населения
    "women_labor": "SL.TLF.TOTL.FE.ZS",       # женщины, % рабочей силы
    "external_debt": "DT.DOD.DECT.GN.ZS",     # внешний долг, % ВНД (только развивающиеся)
}

# Страной в партии считается территория с населением от этого порога; остальное
# рисуется на карте как нейтральная суша.
MIN_POPULATION = 200_000

# Карта: проекция Робинсона, ширина в единицах карты.
MAP_WIDTH = 4000.0
SIMPLIFY_TOLERANCE = 0.45   # в единицах карты
MIN_POLYGON_AREA = 0.6      # острова меньше этого (кв. ед.) выбрасываются, кроме самого крупного
NEIGHBOR_BUFFER_DEG = 0.02  # допуск при поиске общей сухопутной границы

# Зона мир-системы по ВВП на душу (долл.) и структуре экспорта.
CORE_GDP_PC = 28_000
SEMI_GDP_PC = 7_000
CORE_MIN_MANUF = 40         # не-ОЭСР страна с высоким ВВП входит в ядро при такой доле промышленного экспорта
ZONE_OVERRIDES = {
    "TWN": "core",          # нет во Всемирном банке; промышленное ядро Восточной Азии
    "IND": "semi",          # крупная промышленность при низком ВВП на душу
    "IDN": "semi",
    "EGY": "semi",
}

# Короткие названия вместо длинных официальных.
NAME_RU_OVERRIDES = {
    "CHN": "Китай",
    "COG": "Конго",
    "HTI": "Гаити",
    "KOR": "Южная Корея",
    "PRK": "Северная Корея",
    "CYN": "Северный Кипр",
    "COD": "ДР Конго",
    "CAF": "ЦАР",
    "BIH": "Босния и Герцеговина",
    "PSX": "Палестина",
    "SAH": "Западная Сахара",
    "SOL": "Сомалиленд",
    "KOS": "Косово",
    "TLS": "Восточный Тимор",
    "SWZ": "Эсватини",
    "MKD": "Северная Македония",
    "CIV": "Кот-д’Ивуар",
}

# Коды Natural Earth, которые у Всемирного банка записаны иначе.
WB_CODE_OVERRIDES = {"KOS": "XKX", "PSX": "PSE", "SDS": "SSD"}

ZONE_NAMES = {"core": "ядро", "semi": "полупериферия", "periphery": "периферия"}

# Коэффициенты проекции Робинсона (Snyder, 1993), шаг 5°.
ROBINSON_X = [1.0000, 0.9986, 0.9954, 0.9900, 0.9822, 0.9730, 0.9600, 0.9427, 0.9216, 0.8962,
              0.8679, 0.8350, 0.7986, 0.7597, 0.7186, 0.6732, 0.6213, 0.5722, 0.5322]
ROBINSON_Y = [0.0000, 0.0620, 0.1240, 0.1860, 0.2480, 0.3100, 0.3720, 0.4340, 0.4958, 0.5571,
              0.6176, 0.6769, 0.7346, 0.7903, 0.8435, 0.8936, 0.9394, 0.9761, 1.0000]
ROBINSON_R = MAP_WIDTH / (2 * math.pi * 0.8487)


def log(msg: str) -> None:
    print(msg, file=sys.stderr, flush=True)


def fetch(url: str, attempts: int = 4) -> bytes:
    for i in range(attempts):
        try:
            with urllib.request.urlopen(url, timeout=60) as resp:
                return resp.read()
        except Exception as exc:  # сеть ненадёжна: повторяем с паузой
            if i == attempts - 1:
                raise
            log(f"  повтор {url}: {exc}")
            time.sleep(2 ** (i + 1))
    raise AssertionError("unreachable")


def robinson(lon, lat):
    """Проекция Робинсона; y направлен вниз, как в Godot."""
    lon = np.asarray(lon, dtype=float)
    lat = np.clip(np.asarray(lat, dtype=float), -90, 90)
    a = np.abs(lat) / 5.0
    i = np.minimum(np.floor(a).astype(int), 17)
    t = a - i
    xs = np.asarray(ROBINSON_X)
    ys = np.asarray(ROBINSON_Y)
    px = xs[i] + (xs[i + 1] - xs[i]) * t
    py = ys[i] + (ys[i + 1] - ys[i]) * t
    x = 0.8487 * ROBINSON_R * px * np.radians(lon)
    y = -1.3523 * ROBINSON_R * py * np.sign(lat)
    return x, y


def load_natural_earth() -> list[dict]:
    path = CACHE / "ne_50m_admin_0_countries.geojson"
    if not path.exists():
        log("Скачиваю Natural Earth…")
        CACHE.mkdir(parents=True, exist_ok=True)
        path.write_bytes(fetch(NE_URL))
    return json.loads(path.read_text(encoding="utf-8"))["features"]


def load_worldbank(refresh: bool, offline: bool) -> dict:
    """{показатель: {код страны: [значение, год]}}"""
    path = CACHE / "worldbank.json"
    cache = json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}
    if refresh:
        cache = {}
    changed = False
    for key, code in INDICATORS.items():
        if key in cache:
            continue
        if offline:
            log(f"  нет в кэше и нет сети: {key} ({code})")
            continue
        log(f"Всемирный банк: {key} ({code})")
        payload = json.loads(fetch(WB_URL.format(code=code)))
        if not isinstance(payload, list) or len(payload) < 2 or payload[1] is None:
            raise RuntimeError(f"Неожиданный ответ Всемирного банка для {code}: {str(payload)[:300]}")
        values = {}
        for row in payload[1]:
            iso = row.get("countryiso3code") or ""
            if len(iso) == 3 and row.get("value") is not None:
                values[iso] = [row["value"], int(row["date"])]
        cache[key] = values
        changed = True
    if changed:
        CACHE.mkdir(parents=True, exist_ok=True)
        cache["_meta"] = {"source": "World Bank WDI API v2, mrnev=1", "fetched": date.today().isoformat()}
        path.write_text(json.dumps(cache, ensure_ascii=False, sort_keys=True, indent=0) + "\n", encoding="utf-8")
    return cache


def wb_code(props: dict) -> str:
    a3 = props["ADM0_A3"]
    if a3 in WB_CODE_OVERRIDES:
        return WB_CODE_OVERRIDES[a3]
    for key in ("WB_A3", "ISO_A3_EH", "ISO_A3"):
        v = props.get(key)
        if v and v != "-99":
            return v
    return a3


def build_indicators(features: list[dict], wb: dict) -> dict[str, dict]:
    """Показатели по странам; пропуски заполняются медианой группы дохода."""
    result: dict[str, dict] = {}
    for f in features:
        p = f["properties"]
        code = wb_code(p)
        values, years, estimated = {}, {}, []
        for key in INDICATORS:
            hit = wb.get(key, {}).get(code)
            if hit is not None:
                values[key] = hit[0]
                years[key] = hit[1]
        if "population" not in values:
            values["population"] = float(p["POP_EST"])
            years["population"] = int(p["POP_YEAR"])
            estimated.append("population")
        if "gdp_usd" not in values and p.get("GDP_MD", -99) > 0:
            values["gdp_usd"] = float(p["GDP_MD"]) * 1e6
            years["gdp_usd"] = int(p["GDP_YEAR"])
            estimated.append("gdp_usd")
        if "gdp_per_capita" not in values and values.get("gdp_usd"):
            values["gdp_per_capita"] = values["gdp_usd"] / max(values["population"], 1.0)
            years["gdp_per_capita"] = years.get("gdp_usd")
            estimated.append("gdp_per_capita")
        result[p["ADM0_A3"]] = {"values": values, "years": years, "estimated": estimated,
                                "group": p["INCOME_GRP"]}

    # Медианы по группам дохода Natural Earth (5 групп), затем по всему миру.
    for key in INDICATORS:
        world = [r["values"][key] for r in result.values() if key in r["values"]]
        world_median = statistics.median(world) if world else 0.0
        by_group: dict[str, list] = {}
        for r in result.values():
            if key in r["values"] and key not in r["estimated"]:
                by_group.setdefault(r["group"], []).append(r["values"][key])
        for r in result.values():
            if key in r["values"]:
                continue
            if key == "external_debt" and r["group"].startswith(("1.", "2.")):
                r["values"][key] = 0.0   # богатые страны у ВБ не отчитываются о внешнем долге
            else:
                group = by_group.get(r["group"])
                r["values"][key] = statistics.median(group) if group else world_median
            r["estimated"].append(key)
    return result


def zone_of(a3: str, props: dict, v: dict) -> str:
    if a3 in ZONE_OVERRIDES:
        return ZONE_OVERRIDES[a3]
    gdp_pc = v.get("gdp_per_capita", 0.0)
    oecd = props["INCOME_GRP"].startswith("1.")
    if gdp_pc >= CORE_GDP_PC and (oecd or v.get("manuf_exports", 0.0) >= CORE_MIN_MANUF):
        return "core"
    if gdp_pc >= SEMI_GDP_PC:
        return "semi"
    return "periphery"


def project_geometry(geom):
    return shapely.transform(geom, lambda c: np.column_stack(robinson(c[:, 0], c[:, 1])))


def polygons_of(geom) -> list[Polygon]:
    geom = make_valid(geom)
    if isinstance(geom, Polygon):
        return [geom]
    out: list[Polygon] = []
    for g in getattr(geom, "geoms", []):
        out.extend(polygons_of(g))
    return [p for p in out if isinstance(p, Polygon) and not p.is_empty]


def simplify_all(projected: dict[str, object]) -> dict[str, list[Polygon]]:
    """Совместное упрощение: общие границы соседей упрощаются одинаково, без щелей."""
    ids = list(projected)
    fc = {"type": "FeatureCollection",
          "features": [{"type": "Feature", "properties": {"id": i}, "geometry": mapping(projected[i])}
                       for i in ids]}
    topo = topojson.Topology(fc, toposimplify=SIMPLIFY_TOLERANCE, prevent_oversimplify=True)
    out: dict[str, list[Polygon]] = {}
    for feat in json.loads(topo.to_geojson())["features"]:
        out[feat["properties"]["id"]] = polygons_of(shape(feat["geometry"]))
    return out


def ring_coords(ring) -> list[tuple[float, float]]:
    pts = list(ring.coords)
    if len(pts) > 1 and pts[0] == pts[-1]:
        pts = pts[:-1]
    return [(round(x, 1), round(y, 1)) for x, y in pts]


def encode_polygons(polys: list[Polygon]) -> list[dict]:
    if not polys:
        return []
    largest = max(polys, key=lambda p: p.area)
    encoded = []
    for poly in sorted(polys, key=lambda p: -p.area):
        if poly is not largest and poly.area < MIN_POLYGON_AREA:
            continue
        rings = [ring_coords(poly.exterior)] + [ring_coords(r) for r in poly.interiors
                                                if Polygon(r).area >= MIN_POLYGON_AREA]
        rings = [r for r in rings if len(r) >= 3]
        if not rings or len(rings[0]) < 3:
            continue
        verts = np.array([pt for r in rings for pt in r], dtype=np.float64).reshape(-1, 2)
        ends = np.cumsum([len(r) for r in rings]).astype(np.uint32)
        tris = mapbox_earcut.triangulate_float64(verts, ends).tolist()
        if not tris:
            continue
        encoded.append({"rings": [[c for pt in r for c in pt] for r in rings], "tris": tris})
    return encoded


def find_neighbors(playable: list[str], geoms_lonlat: dict[str, object]) -> dict[str, list[str]]:
    geoms = [geoms_lonlat[i] for i in playable]
    tree = STRtree(geoms)
    result: dict[str, set] = {i: set() for i in playable}
    for idx, a in enumerate(playable):
        grown = geoms[idx].buffer(NEIGHBOR_BUFFER_DEG)
        for j in tree.query(grown):
            b = playable[int(j)]
            if b != a and grown.intersects(geoms[int(j)]):
                result[a].add(b)
                result[b].add(a)
    return {k: sorted(v) for k, v in result.items()}


def round_value(key: str, v: float):
    if key in ("population", "gdp_usd"):
        return int(round(v))
    return round(float(v), 2)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--refresh", action="store_true", help="перекачать показатели Всемирного банка")
    ap.add_argument("--offline", action="store_true", help="не ходить в сеть за показателями")
    args = ap.parse_args()

    features = [f for f in load_natural_earth() if f["properties"]["ADM0_A3"] != "ATA"]
    features.sort(key=lambda f: f["properties"]["ADM0_A3"])
    wb = load_worldbank(args.refresh, args.offline)
    indicators = build_indicators(features, wb)

    by_id = {f["properties"]["ADM0_A3"]: f for f in features}
    playable = [a3 for a3, f in by_id.items()
                if indicators[a3]["values"]["population"] >= MIN_POPULATION]
    geoms_lonlat = {a3: make_valid(shape(f["geometry"])) for a3, f in by_id.items()}

    log("Проекция и упрощение границ…")
    simplified = simplify_all({a3: project_geometry(g) for a3, g in geoms_lonlat.items()})
    neighbors = find_neighbors(playable, geoms_lonlat)

    countries, shapes, neutral = [], {}, []
    for a3, f in by_id.items():
        p = f["properties"]
        polys = encode_polygons(simplified.get(a3, []))
        if not polys:
            log(f"  пропущено, нет полигонов после упрощения: {a3}")
            continue
        name_ru = NAME_RU_OVERRIDES.get(a3, p["NAME_RU"])
        name_ru = name_ru[:1].upper() + name_ru[1:]
        if a3 not in playable:
            neutral.append({"id": a3, "name_ru": name_ru, "name_en": p["NAME_EN"], "polygons": polys})
            continue
        ind = indicators[a3]
        lx, ly = robinson(p["LABEL_X"], p["LABEL_Y"])
        countries.append({
            "id": a3,
            "wb_code": wb_code(p),
            "name_ru": name_ru,
            "name_en": p["NAME_EN"],
            "continent": p["CONTINENT"],
            "subregion": p["SUBREGION"],
            "zone": zone_of(a3, p, ind["values"]),
            "label": [round(float(lx), 1), round(float(ly), 1)],
            "neighbors": neighbors[a3],
            "indicators": {k: round_value(k, ind["values"][k]) for k in INDICATORS},
            "years": {k: ind["years"][k] for k in INDICATORS if k in ind["years"]},
            "estimated": sorted(ind["estimated"]),
        })
        shapes[a3] = polys

    all_x = [c for polys in list(shapes.values()) + [n["polygons"] for n in neutral]
             for poly in polys for c in poly["rings"][0][0::2]]
    all_y = [c for polys in list(shapes.values()) + [n["polygons"] for n in neutral]
             for poly in polys for c in poly["rings"][0][1::2]]
    bounds = [min(all_x), min(all_y), max(all_x), max(all_y)]
    wb_meta = wb.get("_meta", {})
    sources = {
        "borders": "Natural Earth 1:50m Admin 0 Countries v5.1.2, public domain",
        "indicators": "World Bank, World Development Indicators, CC BY 4.0",
        "indicators_fetched": wb_meta.get("fetched", "нет — только оценки"),
    }
    world = {
        "version": 1,
        "generated_by": "tools/build_world.py",
        "sources": sources,
        "map": {"projection": "robinson", "width": MAP_WIDTH, "bounds": bounds},
        "zones": ZONE_NAMES,
        "countries": countries,
    }
    shapes_doc = {"version": 1, "bounds": bounds, "countries": shapes, "neutral": neutral}

    data = ROOT / "data"
    data.mkdir(exist_ok=True)
    (data / "world.json").write_text(json.dumps(world, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    (data / "world_shapes.json").write_text(json.dumps(shapes_doc, ensure_ascii=False, separators=(",", ":")) + "\n",
                                            encoding="utf-8")

    n_vert = sum(len(r) // 2 for polys in shapes.values() for poly in polys for r in poly["rings"])
    no_wb = sum(1 for c in countries if "population" in c["estimated"])
    log(f"Готово: стран {len(countries)}, нейтральных территорий {len(neutral)}, вершин {n_vert}, "
        f"без данных Всемирного банка {no_wb}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
