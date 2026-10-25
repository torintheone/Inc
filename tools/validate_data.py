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
    "need", "consciousness", "organization", "influence", "trust", "visibility", "cadres", "unrest", "reformism",
    "top_cant", "bottom_wont", "mass_activity", "rev_situation",
    "strikes_recent", "demos_recent", "aristocracy",
}
# Должно совпадать с модификаторами, которые читает код (sim.mod("…")), и со строками MOD_<ключ> в тексте.
MODIFIERS = {"influence_growth", "consciousness_rate", "organization_rate", "organization_cap", "visibility",
             "cadre_rate", "cadre_cap", "trust_target", "auto_support", "activity", "underground",
             "hegemony_culture", "media_channel", "fragile_consciousness", "action_discount", "peasant_potential",
             "periphery_growth", "core_growth", "semi_growth", "strike_chance", "strike_loss", "upkeep",
             "demo_chance", "uprising_chance", "uprising_periphery", "repression_target", "strike_consciousness",
             "reformism", "migration_channel", "trade_channel", "neighbor_channel", "drain_cut", "core_visibility",
             "bubble_value", "army_erosion", "arrests", "legality_hold", "arrest_damage", "action_loss",
             "defeat_cushion", "repression_growth", "hegemony_erosion"}
UNLOCKS = {"strikes", "industry_strikes", "consciousness_stage_1", "consciousness_stage_2", "consciousness_stage_3",
           "elections", "army_work", "antifascist_defense", "factory_seizure", "general_strike", "solidarity_strike"}
SPECIALS = {"revolution", "defeat", "organizers", "solidarity"}
TAGS = {"strike"}
MAX_PER_TIER = 2
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
                    "unrest", "cadres", "reformism", "spread", "revolutionary_situation", "revolution", "reaction",
                    "solidarity", "bubbles", "outcome", "score"):
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
    if not 5 * weeks <= lo <= hi <= hi_ct <= 8 * weeks:
        err("balance.json/cycle: длина цикла должна укладываться в 5–8 лет (min ≤ max ≤ max с противодействием)")
    for p in phases:
        if not isinstance(p.get("unrest"), (int, float)) or p["unrest"] < 0:
            err(f"balance.json/cycle.phases.{p.get('id')}: нужен множитель стихийных протестов unrest ≥ 0")
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
    branches = a.get("branches", [])
    if len(branches) != 5:
        err("actions.json: нужно пять ветвей развития")
    upgrades = {}
    for u in a.get("upgrades", []):
        uid = u.get("id")
        if uid in upgrades:
            err(f"actions.json: повторяется улучшение {uid}")
        upgrades[uid] = u
        if u.get("branch") not in branches:
            err(f"actions.json/{uid}: неизвестная ветвь {u.get('branch')}")
        if not isinstance(u.get("tier"), int) or not 0 <= u["tier"] <= 5:
            err(f"actions.json/{uid}: ярус tier должен быть целым от 0 до 5")
        if not isinstance(u.get("cost"), (int, float)) or u["cost"] <= 0:
            err(f"actions.json/{uid}: цена должна быть больше нуля")
        for key in u.get("modifiers", {}):
            if key not in MODIFIERS:
                err(f"actions.json/{uid}: неизвестный модификатор {key}")
        for key in u.get("unlocks", []):
            if key not in UNLOCKS:
                err(f"actions.json/{uid}: неизвестная возможность {key}")
    tiers: dict[tuple, int] = {}
    for uid, u in upgrades.items():
        key = (u.get("branch"), u.get("tier"))
        tiers[key] = tiers.get(key, 0) + 1
        if tiers[key] > MAX_PER_TIER:
            err(f"actions.json/{uid}: в ветви {key[0]} на ярусе {key[1]} больше {MAX_PER_TIER} улучшений — не поместятся в дереве")
        for req in u.get("requires", []):
            if req not in upgrades:
                err(f"actions.json/{uid}: требует неизвестное улучшение {req}")
            elif upgrades[req].get("branch") == u.get("branch") and upgrades[req].get("tier", 0) >= u.get("tier", 0):
                err(f"actions.json/{uid}: требование {req} должно стоять ярусом выше")
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
    groups = a.get("action_groups", [])
    actions = set()
    for act in a.get("country_actions", []):
        aid = act.get("id")
        if aid in actions:
            err(f"actions.json: повторяется действие {aid}")
        actions.add(aid)
        if act.get("group") not in groups:
            err(f"actions.json/{aid}: неизвестная группа {act.get('group')}")
        for tag in act.get("tags", []):
            if tag not in TAGS:
                err(f"actions.json/{aid}: неизвестная метка {tag}")
        if not isinstance(act.get("cadres", 0), int) or act.get("cadres", 0) < 0:
            err(f"actions.json/{aid}: цена в кадрах — целое число не меньше нуля")
        if act.get("cadres", 0) == 0 and act.get("solidarity", 0) == 0:
            err(f"actions.json/{aid}: действие должно стоить кадров или солидарности")
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
    if len(upgrades) < 25 or len(actions) < 14:
        err("actions.json: на этапе 2 нужно не меньше 25 улучшений и 14 действий")
    return set(upgrades), actions


def check_lines(lines: dict, upgrades: set[str], actions: set[str]) -> set[str]:
    ids = set()
    for line in lines.get("lines", []):
        lid = line.get("id")
        if lid in ids:
            err(f"lines.json: повторяется линия {lid}")
        ids.add(lid)
        for key in line.get("modifiers", {}):
            if key not in MODIFIERS:
                err(f"lines.json/{lid}: неизвестный модификатор {key}")
        for aid in list(line.get("action_cost", {})) + list(line.get("action_bonus", {})) + line.get("blocked_actions", []):
            if aid not in actions:
                err(f"lines.json/{lid}: неизвестное действие {aid}")
        for uid, reqs in line.get("requires_override", {}).items():
            for x in [uid] + list(reqs):
                if x not in upgrades:
                    err(f"lines.json/{lid}: неизвестное улучшение {x}")
    if len(ids) != 5:
        err("lines.json: нужно пять стратегических линий")
    in_range("lines.json/change_organization_mult", lines.get("change_organization_mult"), 0, 1)
    return ids


EVENT_SCOPES = {"country", "world"}
EFFECT_SCOPES = {"country", "movement", "core", "periphery", "neighbors"}
EVENT_TRIGGERS = {"phase", "phase_week_min", "reaction_min", "reaction_max", "upgrade", "no_upgrade", "unlock", "line",
                  "revolutionary_count_min", "revolutionary", "min", "max", "zone", "flag", "no_flag", "timed", "no_timed",
                  "class_min", "indicator_min", "neighbor_flag_any", "any_of"}
EVENT_ON = {"crisis_start", "revolution_neighbor", "defeat", "line_change"}
TIMED_FLAGS = {"underground", "port_cells", "antifascist", "unemployed_organized", "theory", "peasant_ally", "emergency",
               "fascist_regime", "reformist_cap", "blockade"}


def check_outcome(where: str, o: dict) -> None:
    for field in list(o.get("add", {})) + list(o.get("mult", {})):
        if field not in COUNTRY_FIELDS:
            err(f"{where}: неизвестный показатель {field}")
    for flag in o.get("timed", {}):
        if flag not in TIMED_FLAGS:
            err(f"{where}: неизвестная временная отметка {flag}")
    if "special" in o and o["special"] not in {"revolution", "defeat"}:
        err(f"{where}: неизвестный исход {o['special']}")


def check_events(ev: dict, upgrades: set[str], actions: set[str]) -> list[tuple[str, list[str]]]:
    events = {}
    for e in ev.get("events", []):
        eid = e.get("id")
        if eid in events:
            err(f"events.json: повторяется событие {eid}")
        events[eid] = e
    art = (ROOT / "ART_LIST.md").read_text(encoding="utf-8")
    for eid, e in events.items():
        where = f"events.json/{eid}"
        if e.get("category") not in ev.get("categories", []):
            err(f"{where}: неизвестная категория {e.get('category')}")
        if e.get("scope") not in EVENT_SCOPES:
            err(f"{where}: scope должен быть country или world")
        if f"`{e.get('art')}.png`" not in art:
            err(f"{where}: иллюстрации {e.get('art')} нет в ART_LIST.md")
        trig = e.get("trigger", {})
        for key in trig:
            if key not in EVENT_TRIGGERS:
                err(f"{where}: неизвестное условие {key}")
        for field in list(trig.get("min", {})) + list(trig.get("max", {})):
            if field not in COUNTRY_FIELDS:
                err(f"{where}: неизвестный показатель в условии: {field}")
        for phase in trig.get("phase", []):
            if phase not in PHASES:
                err(f"{where}: неизвестная фаза {phase}")
        for key in ("upgrade", "no_upgrade"):
            if key in trig and trig[key] not in upgrades:
                err(f"{where}: неизвестное улучшение {trig[key]}")
        for on in e.get("on", []):
            kind, _, aid = on.partition(":")
            if on not in EVENT_ON and not (kind in ("action", "action_ok", "action_fail") and aid in actions):
                err(f"{where}: неизвестный повод {on}")
        options = e.get("options", [])
        if not 1 <= len(options) <= 3:
            err(f"{where}: нужно от одного до трёх вариантов")
        if len(options) > 1 and not any(o.get("default") for o in options):
            err(f"{where}: нужен вариант по умолчанию (default)")
        for o in options:
            ow = f"{where}.{o.get('id')}"
            req = o.get("requires", {})
            for key in ("upgrade",):
                if key in req and req[key] not in upgrades:
                    err(f"{ow}: неизвестное улучшение {req[key]}")
            for u in req.get("any_upgrade", []):
                if u not in upgrades:
                    err(f"{ow}: неизвестное улучшение {u}")
            if o.get("default") and req:
                err(f"{ow}: вариант по умолчанию не должен ничего требовать")
            if "chance" in o and not 0 < o["chance"] <= 1:
                err(f"{ow}: шанс должен быть в пределах 0 < шанс ≤ 1")
            for part in ("effects", "fail"):
                eff = o.get(part, {})
                for scope in EFFECT_SCOPES:
                    if scope in eff:
                        check_outcome(f"{ow}.{part}.{scope}", eff[scope])
                chain = eff.get("chain")
                if chain and chain.get("event") not in events:
                    err(f"{ow}: цепочка ведёт к неизвестному событию {chain.get('event')}")
    chained = {o.get(part, {}).get("chain", {}).get("event") for e in events.values() for o in e["options"]
               for part in ("effects", "fail")}
    for eid, e in events.items():
        if e.get("chain_only") and eid not in chained:
            err(f"events.json/{eid}: событие только из цепочки, но к нему не ведёт ни одна цепочка")
    if len(events) < 40:
        err("events.json: на этапе 3 нужно не меньше 40 событий")
    return [(eid, [o["id"] for o in e["options"]]) for eid, e in events.items()]


def check_locale(upgrades: set[str], actions: set[str], lines: set[str], branches: list[str], groups: list[str],
                 events: list) -> None:
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
    need = []
    for uid in upgrades:
        need += [f"UPGRADE_{uid}", f"UPGRADE_{uid}_DESC"]
    for aid in actions:
        need += [f"ACTION_{aid}", f"ACTION_{aid}_DESC"]
        if aid != "uprising":
            need += [f"NEWS_ACTION_{aid}_OK", f"NEWS_ACTION_{aid}_FAIL"]
    for lid in lines:
        need += [f"LINE_{lid}"] + [f"LINE_{lid}_{part}" for part in ("CURRENT", "PLUS", "MINUS", "WHERE")]
    need += [f"BRANCH_{b}" for b in branches] + [f"GROUP_{g}" for g in groups]
    need += [f"MOD_{m}" for m in MODIFIERS] + [f"UNLOCK_{u}" for u in UNLOCKS]
    for eid, options in events:
        need += [f"EVENT_{eid}", f"EVENT_{eid}_TEXT"] + [f"EVENT_{eid}_{o}" for o in options]
    need += [f"TIMED_{t}" for t in TIMED_FLAGS if t != "port_cells"]
    for key in need:
        if key not in keys:
            err(f"locale: нет текста {key}")


def main() -> int:
    world = load("world.json")
    shapes = load("world_shapes.json")
    links = load("links.json")
    balance = load("balance.json")
    actions = load("actions.json")
    lines = load("lines.json")
    events = load("events.json")
    ids = check_world(world) if world else set()
    if shapes:
        check_shapes(shapes, ids)
    if links:
        check_links(links, ids)
    if balance:
        check_balance(balance)
    if actions and lines and events:
        upgrades, acts = check_actions(actions)
        line_ids = check_lines(lines, upgrades, acts)
        event_list = check_events(events, upgrades, acts)
        check_locale(upgrades, acts, line_ids, actions.get("branches", []), actions.get("action_groups", []), event_list)
    if errors:
        print(f"Ошибок в данных: {len(errors)}")
        for e in errors:
            print("  - " + e)
        return 1
    print(f"Данные в порядке: стран {len(ids)}, связей {len(links.get('links', []))}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
