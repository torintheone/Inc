#!/usr/bin/env python3
"""Карты стран для местных сражений: регионы, города и ключевые объекты.

Берёт административное деление первого уровня Natural Earth 1:10m (области, штаты, провинции),
объединяет соседние регионы, если их больше 20, и делит крупные, если их меньше 8. Для каждого
региона считает население (по городам Natural Earth и площади), находит столицу, промышленные
районы, железнодорожный узел, порт, узел связи, арсенал и аграрные районы. Пишет
data/battle_maps.json. Запуск: python3 tools/build_regions.py (нужен интернет при первом запуске;
скачанное кладётся в tools/cache/).
"""
from __future__ import annotations

import json
import math
import sys
from pathlib import Path

import numpy as np
import shapely
import topojson
from shapely.geometry import LineString, MultiPolygon, Point, Polygon, mapping, shape
from shapely.ops import split, unary_union
from shapely.validation import make_valid

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_world as bw  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / "tools" / "cache"
NE_BASE = "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/v5.1.2/geojson/"
ADMIN1 = "ne_10m_admin_1_states_provinces.geojson"
PLACES = "ne_10m_populated_places.geojson"
PORTS = "ne_10m_ports.geojson"

MAX_REGIONS = 20
MIN_REGIONS = 8
# Карта страны вписывается в такой прямоугольник (единицы карты сражения).
BOX_W, BOX_H = 1000.0, 640.0
SIMPLIFY = 1.2           # упрощение границ в единицах карты сражения
MIN_PART_AREA = 6.0      # острова мельче (кв. ед.) отбрасываются, кроме самого крупного в регионе
# Регионы, отделённые от основной территории морем или чужой землёй шире этого (градусы), не берутся:
# заморские территории, Аляска, Гавайи.
CLUSTER_GAP = 4.0
RURAL_DENSITY = 25.0     # человек на кв. км вне городов из Natural Earth — для оценки населения


def load(name: str) -> dict:
    path = CACHE / name
    if not path.exists():
        bw.log(f"скачиваю {name}")
        path.write_bytes(bw.fetch(NE_BASE + name))
    return json.loads(path.read_text(encoding="utf-8"))


def lon_fix(geom, shift: bool):
    """Страны через линию перемены дат (Россия, Фиджи): западные долготы сдвигаются на +360."""
    if not shift:
        return geom
    return shapely.transform(geom, lambda c: np.column_stack((np.where(c[:, 0] < 0, c[:, 0] + 360, c[:, 0]), c[:, 1])))


def main_part(geoms: list) -> Polygon:
    """Самая большая сплошная часть страны (по объединению всех областей)."""
    union = make_valid(unary_union([g.buffer(0.01) for g in geoms]))
    return max(bw.polygons_of(union), key=lambda p: p.area)


def keep_near(regions: list[dict]) -> list[dict]:
    """Оставить основную территорию: регионы, связанные цепочкой промежутков не шире CLUSTER_GAP градусов,
    вокруг самой большой части. Так архипелаги (Индонезия, Филиппины) остаются целиком, а заморские
    территории, Аляска и Гавайи — отбрасываются."""
    n = len(regions)
    parent = list(range(n))

    def find(a: int) -> int:
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    tree = shapely.STRtree([r["geom"] for r in regions])
    for a in range(n):
        for b in tree.query(regions[a]["geom"].buffer(CLUSTER_GAP)):
            b = int(b)
            if b > a and regions[a]["geom"].distance(regions[b]["geom"]) <= CLUSTER_GAP:
                parent[find(a)] = find(b)
    main = main_part([r["geom"] for r in regions])
    root = None
    for a in range(n):
        if regions[a]["geom"].intersects(main):
            root = find(a)
            break
    if root is None:
        return regions
    return [regions[a] for a in range(n) if find(a) == root]


def merge_small(regions: list[dict]) -> list[dict]:
    """Пока регионов больше MAX_REGIONS, самый маленький сливается с самым маленьким соседом."""
    while len(regions) > MAX_REGIONS:
        regions.sort(key=lambda r: r["weight"])
        small = regions[0]
        buf = small["geom"].buffer(0.05)
        neighbors = [r for r in regions[1:] if buf.intersects(r["geom"])]
        target = min(neighbors, key=lambda r: r["weight"]) if neighbors else \
            min(regions[1:], key=lambda r: r["geom"].distance(small["geom"]))
        big, little = (target, small) if target["weight"] >= small["weight"] else (small, target)
        merged = {"name_ru": big["name_ru"], "geom": make_valid(unary_union([small["geom"], target["geom"]])),
                  "weight": small["weight"] + target["weight"], "members": big["members"] + little["members"]}
        regions = [r for r in regions if r is not small and r is not target] + [merged]
    return regions


def absorb_tiny(regions: list[dict]) -> list[dict]:
    """Крошечные отдельные острова (Парасельские у Китая) присоединяются к ближайшему региону."""
    total_area = sum(r["geom"].area for r in regions) or 1.0
    total_weight = sum(r["weight"] for r in regions) or 1.0
    changed = True
    while changed and len(regions) > 2:
        changed = False
        for small in regions:
            if small["geom"].area / total_area < 0.003 and small["weight"] / total_weight < 0.005:
                others = [r for r in regions if r is not small]
                target = min(others, key=lambda r: r["geom"].distance(small["geom"]))
                target["geom"] = make_valid(unary_union([target["geom"], small["geom"]]))
                target["weight"] += small["weight"]
                regions = others
                changed = True
                break
    return regions


SIDES = {0: ("запад", "восток"), 1: ("юг", "север")}
COMPASS = ["восток", "северо-восток", "север", "северо-запад", "запад", "юго-запад", "юг", "юго-восток"]


def group_by_region(regions: list[dict], feats: list[dict]) -> list[dict]:
    """Если областей слишком много, сначала объединить их по крупным регионам Natural Earth (поле region)."""
    groups: dict[str, list[dict]] = {}
    for r in regions:
        groups.setdefault(r.get("group") or r["name_ru"], []).append(r)
    if not MIN_REGIONS <= len(groups) <= MAX_REGIONS * 2 or len(groups) == len(regions):
        return regions
    out = []
    for members in groups.values():
        main = max(members, key=lambda r: r["weight"])
        out.append({"name_ru": main["name_ru"], "geom": make_valid(unary_union([m["geom"] for m in members])),
                    "weight": sum(m["weight"] for m in members), "members": [n for m in members for n in m["members"]]})
    return out


def rename_split(regions: list[dict]) -> list[dict]:
    """Части одного разрезанного региона называются по сторонам света: «Аляска — северо-запад»."""
    by_base: dict[str, list[dict]] = {}
    for r in regions:
        by_base.setdefault(r.get("base", r["name_ru"]), []).append(r)
    for base, parts in by_base.items():
        if len(parts) < 2:
            continue
        center = unary_union([p["geom"] for p in parts]).centroid
        used: dict[str, int] = {}
        for p in parts:
            c = p["geom"].centroid
            dx, dy = c.x - center.x, c.y - center.y
            if math.hypot(dx, dy) < 1e-6:
                word = "центр"
            else:
                word = COMPASS[int(round(math.atan2(dy, dx) / (math.pi / 4))) % 8]
            used[word] = used.get(word, 0) + 1
            p["name_ru"] = f"{base} — {word}" + (f" {used[word]}" if used[word] > 1 else "")
    return regions


def split_large(regions: list[dict]) -> list[dict]:
    """Пока регионов меньше MIN_REGIONS, самый большой режется пополам поперёк длинной стороны."""
    guard = 0
    while len(regions) < MIN_REGIONS and guard < 40:
        guard += 1
        regions.sort(key=lambda r: -r["geom"].area)
        big = regions[0]
        minx, miny, maxx, maxy = big["geom"].bounds
        axis = 0 if (maxx - minx) >= (maxy - miny) else 1
        c = big["geom"].centroid
        if axis == 0:
            line = LineString([(c.x, miny - 1), (c.x, maxy + 1)])
        else:
            line = LineString([(minx - 1, c.y), (maxx + 1, c.y)])
        pieces = list(split(big["geom"], line).geoms) if big["geom"].is_valid else []
        if len(pieces) < 2:
            break
        low = unary_union([p for p in pieces if (p.centroid.x if axis == 0 else p.centroid.y) < (c.x if axis == 0 else c.y)])
        high = unary_union([p for p in pieces if (p.centroid.x if axis == 0 else p.centroid.y) >= (c.x if axis == 0 else c.y)])
        if low.is_empty or high.is_empty:
            break
        parts = []
        base = big.get("base", big["name_ru"])
        for geom in (low, high):
            share = geom.area / big["geom"].area
            parts.append({"name_ru": base, "base": base, "geom": geom, "weight": big["weight"] * share,
                          "members": big["members"]})
        regions = regions[1:] + parts
    return rename_split(regions)


def project_for_country(regions: list[dict]):
    """Равнопромежуточная проекция с центром в стране, вписанная в BOX_W × BOX_H."""
    allg = unary_union([r["geom"] for r in regions])
    minx, miny, maxx, maxy = allg.bounds
    lat0 = math.radians((miny + maxy) / 2)
    kx = math.cos(lat0)
    w = max((maxx - minx) * kx, 1e-6)
    h = max(maxy - miny, 1e-6)
    scale = min(BOX_W / w, BOX_H / h)
    ox = (BOX_W - w * scale) / 2
    oy = (BOX_H - h * scale) / 2

    def fn(c):
        x = (c[:, 0] - minx) * kx * scale + ox
        y = (maxy - c[:, 1]) * scale + oy
        return np.column_stack((x, y))

    return fn, scale


def simplify_regions(projected: list) -> list[list[Polygon]]:
    fc = {"type": "FeatureCollection", "features": [
        {"type": "Feature", "properties": {"i": i}, "geometry": mapping(g)} for i, g in enumerate(projected)]}
    topo = topojson.Topology(fc, toposimplify=SIMPLIFY, prevent_oversimplify=True)
    out: list[list[Polygon]] = [[] for _ in projected]
    for feat in json.loads(topo.to_geojson())["features"]:
        out[feat["properties"]["i"]] = bw.polygons_of(shape(feat["geometry"]))
    return out


def encode(polys: list[Polygon]) -> list[dict]:
    saved = bw.MIN_POLYGON_AREA
    bw.MIN_POLYGON_AREA = MIN_PART_AREA
    try:
        return bw.encode_polygons(polys)
    finally:
        bw.MIN_POLYGON_AREA = saved


def build_country(cid: str, feats: list[dict], places: list[dict], ports: list[Point], population: float) -> dict | None:
    geoms = [make_valid(shape(f["geometry"])) for f in feats]
    span = max(g.bounds[2] for g in geoms) - min(g.bounds[0] for g in geoms)
    shift = span > 180
    regions = []
    for f, g in zip(feats, geoms):
        p = f["properties"]
        regions.append({"name_ru": p.get("name_ru") or p.get("name") or "?", "geom": lon_fix(g, shift),
                        "members": [p.get("name_ru") or p.get("name")], "weight": 0.0, "group": p.get("region") or ""})
    regions = [r for r in regions if not r["geom"].is_empty]
    regions = keep_near(regions)
    # Вес региона для слияния: площадь и городское население.
    city_pts = [(lon_fix(Point(c["lon"], c["lat"]), shift), c) for c in places]
    for r in regions:
        r["weight"] = r["geom"].area * 1.0 + sum(c["pop"] for pt, c in city_pts if r["geom"].contains(pt)) / 1e6
    if len(regions) > MAX_REGIONS:
        regions = group_by_region(regions, feats)
    regions = merge_small(regions)
    regions = absorb_tiny(regions)
    regions = split_large(regions)

    fn, scale = project_for_country(regions)
    projected = [shapely.transform(r["geom"], fn) for r in regions]
    simple = simplify_regions(projected)

    # Города, население, столица.
    # Каждый город — ровно в одном регионе: в том, где он стоит, или в ближайшем (город на берегу).
    city_region: list[list[dict]] = [[] for _ in regions]
    for pt, c in city_pts:
        xy = shapely.transform(pt, fn)
        best, best_d = -1, 8.0
        for i, g in enumerate(projected):
            dist = g.distance(xy)
            if dist < best_d:
                best, best_d = i, dist
                if dist == 0.0:
                    break
        if best >= 0:
            city_region[best].append(c)
    out_regions = []
    urban_total = 0.0
    for i, r in enumerate(regions):
        geom = projected[i]
        inside = city_region[i]
        urban = sum(c["pop"] for c in inside)
        area_km2 = r["geom"].area * 111.0 * 111.0 * math.cos(math.radians(r["geom"].centroid.y))
        out_regions.append({"name_ru": r["name_ru"], "geom": geom, "polys": simple[i], "urban": urban,
                            "area_km2": area_km2, "cities": sorted(inside, key=lambda c: -c["pop"]),
                            "capital": any(c["capital"] for c in inside)})
        urban_total += urban
    # Население: городское из Natural Earth (не больше 70% населения страны) плюс сельское по площади.
    urban_cap = 0.7 * population
    k_urban = min(1.0, urban_cap / urban_total) if urban_total > 0 else 0.0
    rural_total = max(population - urban_total * k_urban, 0.3 * population)
    area_sum = sum(r["area_km2"] for r in out_regions) or 1.0
    for r in out_regions:
        r["urban"] *= k_urban
        r["pop"] = r["urban"] + rural_total * r["area_km2"] / area_sum

    # Соседство регионов.
    n = len(out_regions)
    for r in out_regions:
        r["neighbors"] = []
    for a in range(n):
        ga = out_regions[a]["geom"].buffer(1.5)
        for b in range(a + 1, n):
            if ga.intersects(out_regions[b]["geom"]):
                out_regions[a]["neighbors"].append(b)
                out_regions[b]["neighbors"].append(a)
    # Регион без соседей (остров) связываем с ближайшим: туда можно перебросить войска морем.
    for a in range(n):
        if not out_regions[a]["neighbors"] and n > 1:
            b = min((x for x in range(n) if x != a), key=lambda x: out_regions[a]["geom"].distance(out_regions[x]["geom"]))
            out_regions[a]["neighbors"].append(b)
            out_regions[b]["neighbors"].append(a)

    # Ключевые объекты.
    if not any(r["capital"] for r in out_regions):
        best = max(out_regions, key=lambda r: r["urban"])
        best["capital"] = True
    cap_index = next(i for i, r in enumerate(out_regions) if r["capital"])
    for i, r in enumerate(out_regions):
        r["objects"] = []
        if i == cap_index:
            r["objects"].append("capital")
    by_urban = sorted(range(n), key=lambda i: -out_regions[i]["urban"])
    covered = 0.0
    factories = []
    urban_sum = sum(r["urban"] for r in out_regions) or 1.0
    for i in by_urban:
        if len(factories) >= max(2, int(0.45 * n)) or (covered >= 0.55 * urban_sum and len(factories) >= 2):
            break
        factories.append(i)
        covered += out_regions[i]["urban"]
    for i in factories:
        out_regions[i]["objects"].append("factories")
    # Узел связи — столица и второй по величине город.
    out_regions[cap_index]["objects"].append("comms")
    second = next((i for i in by_urban if i != cap_index), None)
    if second is not None and n >= 6:
        out_regions[second]["objects"].append("comms")
    # Железнодорожный узел — самый связанный регион с городами, кроме столицы.
    rail = sorted([i for i in range(n) if i != cap_index],
                  key=lambda i: -(len(out_regions[i]["neighbors"]) * 1.0 + out_regions[i]["urban"] / urban_sum * 6.0))
    for i in rail[:2 if n >= 12 else 1]:
        out_regions[i]["objects"].append("railway")
    # Порт — регион с портом Natural Earth.
    port_count = [0] * n
    lonlat = unary_union([r["geom"] for r in regions]).buffer(0.3)
    zones = [r["geom"].buffer(6.0) for r in out_regions]
    for p in ports:
        p = lon_fix(p, shift)
        if not lonlat.contains(p):
            continue
        pt = shapely.transform(p, fn)
        for i in range(n):
            if zones[i].contains(pt):
                port_count[i] += 1
                break
    port_regions = sorted([i for i in range(n) if port_count[i] > 0], key=lambda i: -port_count[i])[:2]
    for i in port_regions:
        out_regions[i]["objects"].append("port")
    # Арсенал — у столицы, в самом населённом соседнем регионе.
    near_cap = sorted(out_regions[cap_index]["neighbors"], key=lambda i: -out_regions[i]["urban"])
    arsenal = near_cap[0] if near_cap else cap_index
    out_regions[arsenal]["objects"].append("arsenal")
    # Аграрные районы — самые сельские.
    for i, r in enumerate(out_regions):
        share = r["urban"] / max(r["pop"], 1.0)
        if share < 0.2 and "capital" not in r["objects"]:
            r["objects"].append("agrarian")

    result = []
    for i, r in enumerate(out_regions):
        label = r["geom"].representative_point()
        city = r["cities"][0]["name"] if r["cities"] else ""
        # Объединённый регион называется по главному городу: «Лилль» понятнее, чем «Нор».
        name = r["name_ru"]
        if len(regions[i]["members"]) > 1 and city and regions[i].get("base") is None:
            name = city
        result.append({
            "name_ru": name,
            "city": city,
            "label": [round(label.x, 1), round(label.y, 1)],
            "population": int(round(r["pop"], -3)),
            "urban": round(r["urban"] / max(r["pop"], 1.0), 3),
            "objects": r["objects"],
            "neighbors": sorted(r["neighbors"]),
            "polygons": encode(r["polys"]),
        })
    return {"size": [BOX_W, BOX_H], "regions": result}


def main() -> int:
    world = json.loads((ROOT / "data" / "world.json").read_text(encoding="utf-8"))
    countries = {c["id"]: c for c in world["countries"]}
    admin1 = load(ADMIN1)["features"]
    by_country: dict[str, list[dict]] = {}
    for f in admin1:
        by_country.setdefault(f["properties"].get("adm0_a3"), []).append(f)
    places_all = []
    for f in load(PLACES)["features"]:
        p = f["properties"]
        places_all.append({"a3": p.get("ADM0_A3"), "name": p.get("NAME_RU") or p.get("NAME"),
                           "lon": float(p["LONGITUDE"]), "lat": float(p["LATITUDE"]), "pop": float(p.get("POP_MAX") or 0),
                           "capital": int(p.get("ADM0CAP") or 0) == 1})
    ports = [shape(f["geometry"]) for f in load(PORTS)["features"]]
    # Запасной вариант — контур страны целиком (если у Natural Earth нет её областей).
    admin0 = {f["properties"]["ADM0_A3"]: f for f in json.loads((CACHE / "ne_50m_admin_0_countries.geojson").read_text(
        encoding="utf-8"))["features"]} if (CACHE / "ne_50m_admin_0_countries.geojson").exists() else {}
    out = {}
    for cid, c in sorted(countries.items()):
        feats = by_country.get(cid) or []
        if not feats and cid in admin0:
            f = dict(admin0[cid])
            f["properties"] = {"name_ru": c["name_ru"], "name": c["name_en"]}
            feats = [f]
        if not feats:
            bw.log(f"  {cid}: нет областей — пропуск")
            continue
        places = [p for p in places_all if p["a3"] == cid]
        try:
            out[cid] = build_country(cid, feats, places, ports, float(c["indicators"].get("population") or 1e6))
        except Exception as exc:  # noqa: BLE001
            bw.log(f"  {cid}: ошибка {exc}")
            continue
        bw.log(f"  {cid}: регионов {len(out[cid]['regions'])}")
    doc = {"version": 1,
           "source": "Natural Earth 1:10m Admin 1 States and Provinces, Populated Places, Ports v5.1.2 (public domain)",
           "countries": out}
    path = ROOT / "data" / "battle_maps.json"
    path.write_text(json.dumps(doc, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    bw.log(f"{path.relative_to(ROOT)}: стран {len(out)}, {path.stat().st_size // 1024} КБ")
    return 0


if __name__ == "__main__":
    sys.exit(main())
