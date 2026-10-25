#!/usr/bin/env python3
"""Проверка данных игры: ссылки между записями и диапазоны значений.

Запускается в CI перед сборкой. Если что-то не так, печатает список ошибок
и завершается с кодом 1. Запуск: python3 tools/validate_data.py
"""
import csv
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "data"

# Должно совпадать с CountryState.FIELDS (src/sim/country_state.gd).
COUNTRY_FIELDS = {
    "productive_forces", "contradiction", "exploitation", "real_wage", "unemployment", "inequality",
    "hegemony", "legitimacy", "repression", "army_loyalty", "elite_split", "legality",
    "need", "consciousness", "organization", "influence", "trust", "visibility",
    "top_cant", "bottom_wont", "mass_activity", "rev_situation",
    "strikes_recent", "demos_recent", "aristocracy",
}
MODIFIERS = {"influence_growth", "consciousness_rate", "organization_rate", "organization_cap", "visibility",
             "migration_channel", "trade_channel", "media_channel", "hegemony_erosion", "underground"}
UNLOCKS = {"strikes", "industry_strikes", "consciousness_stage_1", "consciousness_stage_2", "consciousness_stage_3"}
SPECIALS = {"revolution", "defeat"}
ZONES = {"core", "semi", "periphery"}
PHASES = ["recovery", "boom", "overheat", "crisis", "depression"]
CLASSES = {"industrial_proletariat", "rural_proletariat", "peasantry", "employees",
           "petty_bourgeoisie", "big_bourgeoisie", "landowners", "lumpenproletariat"}

errors: list[str] = []


def err(msg: str) -> None:
    errors.append(msg)


def load(name: str):
    path = DATA / name
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        err(f"{name}: не читается ({exc})")
        return None


def in_range(name: str, value, lo: float, hi: float) -> None:
    if not isinstance(value, (int, float)) or not lo <= value <= hi:
        err(f"{name} = {value!r}, ожидается число от {lo} до {hi}")


def check_world(world: dict) -> set[str]:
    ids: set[str] = set()
    countries = world.get("countries", [])
    if not 150 <= len(countries) <= 220:
        err(f"world.json: стран {len(countries)}, ожидается 150–220")
    by_id = {}
    for c in countries:
        cid = c.get("id", "?")
        if cid in ids:
            err(f"world.json: повторяется id {cid}")
        ids.add(cid)
        by_id[cid] = c
        if c.get("zone") not in ZONES:
            err(f"world.json/{cid}: неизвестная зона {c.get('zone')!r}")
        if not c.get("name_ru"):
            err(f"world.json/{cid}: нет русского названия")
        ind = c.get("indicators", {})
        if ind.get("population", 0) <= 0:
            err(f"world.json/{cid}: население должно быть больше нуля")
        for key in ("emp_agriculture", "emp_industry", "emp_services", "unemployment", "gini"):
            in_range(f"world.json/{cid}.indicators.{key}", ind.get(key), 0, 100)
        classes = c.get("classes", {})
        if set(classes) != CLASSES:
            err(f"world.json/{cid}: классы {sorted(classes)} не совпадают с восемью классами из SPEC.md")
        elif abs(sum(classes.values()) - 1.0) > 0.01:
            err(f"world.json/{cid}: доли классов в сумме {sum(classes.values()):.3f}, ожидается 1")
    for c in countries:
        for n in c.get("neighbors", []):
            if n not in by_id:
                err(f"world.json/{c['id']}: сосед {n} не найден")
            elif c["id"] not in by_id[n].get("neighbors", []):
                err(f"world.json: {c['id']} и {n} — соседство только в одну сторону")
    return ids


def check_shapes(shapes: dict, ids: set[str]) -> None:
    for cid in ids:
        polys = shapes.get("countries", {}).get(cid)
        if not polys:
            err(f"world_shapes.json: нет полигонов у {cid}")
            continue
        for poly in polys:
            n = sum(len(r) // 2 for r in poly.get("rings", []))
            tris = poly.get("tris", [])
            if len(tris) % 3 != 0 or (tris and max(tris) >= n):
                err(f"world_shapes.json/{cid}: треугольники ссылаются на несуществующие вершины")


def check_links(links: dict, ids: set[str]) -> None:
    seen = set()
    for link in links.get("links", []):
        a, b = link.get("a"), link.get("b")
        if a not in ids or b not in ids:
            err(f"links.json: связь {a}–{b} ссылается на неизвестную страну")
        if (a, b) in seen:
            err(f"links.json: связь {a}–{b} повторяется")
        seen.add((a, b))
        in_range(f"links.json/{a}-{b}.trade", link.get("trade"), 0, 1)
        in_range(f"links.json/{a}-{b}.migration", link.get("migration"), 0, 1)
    linked = {x for pair in seen for x in pair}
    for cid in ids - linked:
        err(f"links.json: у страны {cid} нет ни одной связи")


def check_balance(b: dict) -> None:
    for section in ("time", "start", "zones", "cycle", "economy", "imperialism", "superstructure", "movement",
                    "spread", "revolutionary_situation", "revolution", "reaction", "solidarity", "outcome"):
        if section not in b:
            err(f"balance.json: нет раздела {section}")
    for zone in ZONES:
        z = b.get("zones", {}).get(zone, {})
        for key in ("hegemony", "legitimacy", "repression", "legality", "army_loyalty"):
            in_range(f"balance.json/zones.{zone}.{key}", z.get(key), 0, 100)
        in_range(f"balance.json/zones.{zone}.crisis_sensitivity", z.get("crisis_sensitivity"), 0.1, 5)
    cycle = b.get("cycle", {})
    phases = cycle.get("phases", [])
    if [p.get("id") for p in phases] != PHASES:
        err(f"balance.json/cycle.phases: ожидаются фазы {PHASES}")
    if abs(sum(p.get("share", 0) for p in phases) - 1.0) > 1e-6:
        err("balance.json/cycle.phases: доли фаз в сумме должны давать 1")
    weeks = b.get("time", {}).get("weeks_per_year", 52)
    lo, hi, hi_ct = cycle.get("min_weeks", 0), cycle.get("max_weeks", 0), cycle.get("max_weeks_with_countertendency", 0)
    if not 8 * weeks <= lo <= hi <= hi_ct <= 11 * weeks:
        err("balance.json/cycle: длина цикла должна укладываться в 8–11 лет (min ≤ max ≤ max с противодействием)")
    if not cycle.get("min_depth", 0) <= cycle.get("first_depth", 0) <= cycle.get("max_depth", 0):
        err("balance.json/cycle: first_depth вне [min_depth, max_depth]")
    rs = b.get("revolutionary_situation", {})
    in_range("balance.json/revolutionary_situation.threshold", rs.get("threshold"), 0, 100)
    if rs.get("window_min_weeks", 0) > rs.get("window_max_weeks", 0):
        err("balance.json/revolutionary_situation: window_min_weeks больше window_max_weeks")
    pot = b.get("movement", {}).get("potential", {})
    if set(pot) != CLASSES:
        err("balance.json/movement.potential: нужны веса всех восьми классов")


def check_actions(a: dict) -> tuple[set[str], set[str]]:
    upgrades = {}
    for u in a.get("upgrades", []):
        uid = u.get("id")
        if uid in upgrades:
            err(f"actions.json: повторяется улучшение {uid}")
        upgrades[uid] = u
        if not isinstance(u.get("cost"), (int, float)) or u["cost"] <= 0:
            err(f"actions.json/{uid}: цена должна быть больше нуля")
        for key in u.get("modifiers", {}):
            if key not in MODIFIERS:
                err(f"actions.json/{uid}: неизвестный модификатор {key}")
        for key in u.get("unlocks", []):
            if key not in UNLOCKS:
                err(f"actions.json/{uid}: неизвестная возможность {key}")
    for uid, u in upgrades.items():
        for req in u.get("requires", []):
            if req not in upgrades:
                err(f"actions.json/{uid}: требует неизвестное улучшение {req}")
    # Циклы в требованиях сделали бы улучшения некупимыми.
    def reaches(start: str, target: str, seen: set) -> bool:
        for req in upgrades.get(start, {}).get("requires", []):
            if req == target or (req not in seen and reaches(req, target, seen | {req})):
                return True
        return False
    for uid in upgrades:
        if reaches(uid, uid, set()):
            err(f"actions.json/{uid}: цикл в требованиях")

    provided = {k for u in upgrades.values() for k in u.get("unlocks", [])}
    actions = set()
    for act in a.get("country_actions", []):
        aid = act.get("id")
        if aid in actions:
            err(f"actions.json: повторяется действие {aid}")
        actions.add(aid)
        req = act.get("requires", {})
        if "unlock" in req and req["unlock"] not in provided:
            err(f"actions.json/{aid}: возможность {req['unlock']} не даёт ни одно улучшение")
        for field in req.get("min", {}):
            if field not in COUNTRY_FIELDS:
                err(f"actions.json/{aid}: неизвестный показатель в требованиях: {field}")
        chance = act.get("chance", {})
        for field in chance.get("terms", {}):
            if field not in COUNTRY_FIELDS:
                err(f"actions.json/{aid}: неизвестный показатель в шансе: {field}")
        for phase in chance.get("phase", {}):
            if phase not in PHASES:
                err(f"actions.json/{aid}: неизвестная фаза {phase}")
        for rule in chance.get("above", []):
            if rule.get("field") not in COUNTRY_FIELDS:
                err(f"actions.json/{aid}: неизвестный показатель в условии: {rule.get('field')}")
        if not 0 <= chance.get("min", 0) <= chance.get("max", 1) <= 1:
            err(f"actions.json/{aid}: шанс должен быть в пределах 0 ≤ min ≤ max ≤ 1")
        for outcome in ("success", "failure"):
            o = act.get(outcome, {})
            for field in list(o.get("add", {})) + list(o.get("mult", {})):
                if field not in COUNTRY_FIELDS:
                    err(f"actions.json/{aid}.{outcome}: неизвестный показатель {field}")
            if "special" in o and o["special"] not in SPECIALS:
                err(f"actions.json/{aid}.{outcome}: неизвестный исход {o['special']}")
    if len(upgrades) + len(actions) < 10:
        err("actions.json: на этапе 1 нужно не меньше 10 улучшений и действий")
    return set(upgrades), actions


def check_locale(upgrades: set[str], actions: set[str]) -> None:
    keys = set()
    for name in ("ui.csv", "game.csv"):
        path = ROOT / "locale" / name
        with path.open(encoding="utf-8", newline="") as f:
            rows = list(csv.reader(f))
        header = rows[0]
        for row in rows[1:]:
            if len(row) != len(header):
                err(f"locale/{name}: строка {row[0]!r} — {len(row)} столбцов вместо {len(header)}")
            keys.add(row[0])
    for uid in upgrades:
        for key in (f"UPGRADE_{uid}", f"UPGRADE_{uid}_DESC"):
            if key not in keys:
                err(f"locale: нет текста {key}")
    for aid in actions:
        for key in (f"ACTION_{aid}", f"ACTION_{aid}_DESC", f"NEWS_ACTION_{aid}_OK", f"NEWS_ACTION_{aid}_FAIL"):
            if key not in keys and not (aid == "uprising" and key.startswith("NEWS_ACTION")):
                err(f"locale: нет текста {key}")


def main() -> int:
    world = load("world.json")
    shapes = load("world_shapes.json")
    links = load("links.json")
    balance = load("balance.json")
    actions = load("actions.json")
    ids = check_world(world) if world else set()
    if shapes:
        check_shapes(shapes, ids)
    if links:
        check_links(links, ids)
    if balance:
        check_balance(balance)
    if actions:
        upgrades, acts = check_actions(actions)
        check_locale(upgrades, acts)
    if errors:
        print(f"Ошибок в данных: {len(errors)}")
        for e in errors:
            print("  - " + e)
        return 1
    print(f"Данные в порядке: стран {len(ids)}, связей {len(links.get('links', []))}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
