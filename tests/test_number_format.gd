extends GutTest
## Числа в интерфейсе по-русски.

const NB := NumberFormat.NBSP


func before_all() -> void:
	TranslationServer.set_locale("ru")


func test_decimal_uses_comma_and_groups() -> void:
	assert_eq(NumberFormat.decimal(1234.56, 1), "1" + NB + "234,6")
	assert_eq(NumberFormat.decimal(1234.56, 0), "1" + NB + "235")
	assert_eq(NumberFormat.decimal(0.05, 1), "0,1")
	assert_eq(NumberFormat.decimal(1.999, 2), "2,00")
	assert_eq(NumberFormat.decimal(-3.25, 1), "−3,3")


func test_population_units() -> void:
	assert_eq(NumberFormat.population(1_406_585_000.0), "1,41 млрд")
	assert_eq(NumberFormat.population(68_720_337.0), "68,7 млн")
	assert_eq(NumberFormat.population(512_400.0), "512 тыс.")


func test_money_and_percent() -> void:
	assert_eq(NumberFormat.dollars(48985.73), "$48" + NB + "986")
	assert_eq(NumberFormat.percent(7.54), "7,5" + NB + "%")
