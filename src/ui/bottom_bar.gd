class_name BottomBar
extends PanelContainer
## Нижняя панель: вкладки «Развитие», «Действия», «События», «Статистика» и лента новостей.

signal tab_selected(tab: String)

const TABS: PackedStringArray = ["upgrades", "actions", "news", "stats"]

## Скорость «телеграфа»: знаков в секунду; стук раз в столько знаков.
const TYPE_SPEED := 70.0
const TICK_EVERY := 7

var _buttons: Dictionary[String, Button] = {}
var _ticker: Label
var _typed := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", GameTheme.bar_panel())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	add_child(row)
	for tab in TABS:
		var b := Button.new()
		b.text = tr("TAB_" + tab)
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(118, 44)
		b.pressed.connect(func() -> void: tab_selected.emit(tab))
		row.add_child(b)
		_buttons[tab] = b
	_ticker = GameTheme.make_label("", 16, null, MapPalette.INK)
	_ticker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ticker.clip_text = true
	_ticker.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_ticker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var ticker_box := PanelContainer.new()
	ticker_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(MapPalette.INK, 0.06)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	ticker_box.add_theme_stylebox_override("panel", sb)
	ticker_box.add_child(_ticker)
	row.add_child(ticker_box)


## Середина кнопки вкладки на экране — для стрелки обучения.
func button_center(tab: String) -> Vector2:
	var b: Button = _buttons.get(tab)
	return b.get_global_rect().get_center() if b != null else Vector2.ZERO


func show_tab(tab: String) -> void:
	for t: String in _buttons:
		_buttons[t].set_pressed_no_signal(t == tab)


## Последняя новость «телеграфом»: буквы появляются одна за другой под стук аппарата.
func show_news(text: String) -> void:
	if text == _ticker.text:
		return
	_ticker.text = text
	_ticker.visible_characters = 0
	_typed = 0.0
	set_process(true)


func _process(delta: float) -> void:
	var total := _ticker.get_total_character_count()
	if _ticker.visible_characters < 0 or _ticker.visible_characters >= total:
		_ticker.visible_characters = -1
		set_process(false)
		return
	var before := int(_typed)
	_typed += delta * TYPE_SPEED
	var now := int(_typed)
	if now / TICK_EVERY != before / TICK_EVERY:
		Audio.play("telegraph", -2.0, randf_range(0.9, 1.15))
	_ticker.visible_characters = mini(now, total)
