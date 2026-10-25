class_name NumberFormat
extends RefCounted
## Числа по-русски: десятичная запятая, неразрывные пробелы между разрядами.

const NBSP := " "


## decimal(1234.56, 1) -> «1 234,6»; decimal(1234.56, 0) -> «1 235».
static func decimal(value: float, digits: int = 1) -> String:
	var scale := int(pow(10.0, digits))
	var total := int(roundf(absf(value) * scale))
	var text := _group_thousands(total / scale)
	if digits > 0:
		text += "," + str(total % scale).pad_zeros(digits)
	return ("−" if value < 0.0 and total > 0 else "") + text


static func population(value: float) -> String:
	if value >= 1.0e9:
		return tr_fmt("NUM_BILLION", decimal(value / 1.0e9, 2))
	if value >= 1.0e6:
		return tr_fmt("NUM_MILLION", decimal(value / 1.0e6, 1))
	if value >= 1.0e3:
		return tr_fmt("NUM_THOUSAND", decimal(value / 1.0e3, 0))
	return decimal(value, 0)


static func dollars(value: float) -> String:
	return "$" + decimal(value, 0)


static func percent(value: float, digits: int = 1) -> String:
	return decimal(value, digits) + NBSP + "%"


static func tr_fmt(key: String, value: String) -> String:
	return TranslationServer.translate(key) % value


static func _group_thousands(n: int) -> String:
	var s := str(n)
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = NBSP + out
	return out
