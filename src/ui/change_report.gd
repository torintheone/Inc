class_name ChangeReport
extends RefCounted
## Что изменилось после действия или события: снимок показателей до и разница после.

## Показатели страны, которые попадают в итог, в порядке показа. Влияние и безработица — с десятыми.
const FIELDS: PackedStringArray = ["influence", "consciousness", "organization", "cadres", "trust", "unrest",
	"visibility", "reformism", "real_wage", "unemployment", "exploitation", "hegemony", "legitimacy",
	"repression", "army_loyalty", "elite_split", "legality"]
const DECIMALS: PackedStringArray = ["influence", "unemployment"]


static func snapshot(sim: SimWorld, cs: CountryState) -> Dictionary:
	var d := {"reaction": sim.reaction, "solidarity": sim.solidarity}
	if cs != null:
		d["revolutionary"] = cs.is_revolutionary()
		for f in FIELDS:
			d[f] = cs.get_field(f)
	return d


## Строки итога: «Зарплата +2», «Сознание +4», «Реакция +1». Мелочь меньше половины пункта не показывается.
static func lines(sim: SimWorld, before: Dictionary, cs: CountryState) -> PackedStringArray:
	var out := PackedStringArray()
	if cs != null and before.has("revolutionary"):
		if cs.is_revolutionary() and not before["revolutionary"]:
			out.append(TranslationServer.translate("REPORT_REVOLUTION"))
		else:
			for f in FIELDS:
				var delta := cs.get_field(f) - float(before[f])
				if absf(delta) >= 0.5 or (f in DECIMALS and absf(delta) >= 0.1):
					out.append("%s %s" % [TranslationServer.translate("F_" + f), _signed(delta, f in DECIMALS)])
	for key in ["reaction", "solidarity"]:
		var cur := sim.reaction if key == "reaction" else sim.solidarity
		var delta := cur - float(before[key])
		if absf(delta) >= 0.5:
			out.append("%s %s" % [TranslationServer.translate("F_" + key), _signed(delta, false)])
	return out


static func _signed(v: float, decimals: bool) -> String:
	var text := NumberFormat.decimal(v, 1 if decimals else 0)
	return ("+" + text) if v > 0.0 else text
