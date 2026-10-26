class_name Overlays
extends RefCounted
## Окна поверх карты: меню и сообщение о важном событии. Итог партии — ResultsScreen.


## Затемнение на весь экран с панелью по центру. Возвращает [затемнение, коробка для содержимого].
static func make_modal(width: float) -> Array:
	var shade := ColorRect.new()
	shade.color = Color(MapPalette.INK, 0.45)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(width, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	return [shade, box]


static func paragraph(text: String, width: float, size: int = GameTheme.BODY_SIZE) -> Label:
	var l := GameTheme.make_label(text, size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = width
	return l


static func button(text: String, on_press: Callable, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(200, 52)
	b.add_theme_font_size_override("font_size", 20)
	if primary:
		var sb := StyleBoxFlat.new()
		sb.bg_color = MapPalette.VERMILION
		sb.set_content_margin_all(8)
		var off := StyleBoxFlat.new()
		off.bg_color = Color(MapPalette.INK, 0.12)
		off.set_content_margin_all(8)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_stylebox_override("pressed", sb)
		b.add_theme_stylebox_override("disabled", off)
		b.add_theme_color_override("font_color", MapPalette.PAPER)
		b.add_theme_color_override("font_hover_color", MapPalette.PAPER)
		b.add_theme_color_override("font_pressed_color", MapPalette.OCHRE)
	b.pressed.connect(on_press)
	return b


## Главное меню. on_continue — null, если сохранения нет.
static func menu(on_new: Callable, on_continue: Variant, on_credits: Callable = Callable()) -> Control:
	var parts := make_modal(520.0)
	# Фон меню — иллюстрация, если её уже прислали.
	var bg := ArtLibrary.view("bg_menu", Vector2.ZERO)
	if bg != null:
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.modulate = Color(1, 1, 1, 0.85)
		parts[0].add_child(bg)
		parts[0].move_child(bg, 0)
	var box: VBoxContainer = parts[1]
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var emblem := Icons.IconView.new("emblem", MapPalette.VERMILION, 110.0)
	emblem.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(emblem)
	var title := GameTheme.make_label(TranslationServer.translate("GAME_TITLE").to_upper(), 64, GameTheme.display_font(600), MapPalette.VERMILION)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := paragraph(TranslationServer.translate("MENU_SUBTITLE"), 480.0, 20)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	if on_continue is Callable:
		buttons.add_child(button(TranslationServer.translate("MENU_CONTINUE"), on_continue, true))
	buttons.add_child(button(TranslationServer.translate("MENU_NEW"), on_new, not (on_continue is Callable)))
	var center := CenterContainer.new()
	center.add_child(buttons)
	box.add_child(center)
	var toggles := audio_toggles()
	toggles.alignment = BoxContainer.ALIGNMENT_CENTER
	if on_credits.is_valid():
		var credits := Button.new()
		credits.text = TranslationServer.translate("MENU_CREDITS")
		credits.custom_minimum_size = Vector2(120, 42)
		credits.add_theme_font_size_override("font_size", 16)
		credits.pressed.connect(on_credits)
		toggles.add_child(credits)
	box.add_child(toggles)
	return parts[0]


## Выключатели звука и музыки: надпись показывает, что сейчас.
static func audio_toggles() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var t := TranslationServer.translate
	var sfx := Button.new()
	var music := Button.new()
	for b in [sfx, music]:
		b.custom_minimum_size = Vector2(170, 42)
		b.add_theme_font_size_override("font_size", 16)
		row.add_child(b)
	var update := func() -> void:
		sfx.text = t.call("SOUND_ON" if Audio.sfx_on() else "SOUND_OFF")
		music.text = t.call("MUSIC_ON" if Audio.music_on() else "MUSIC_OFF")
	update.call()
	sfx.pressed.connect(func() -> void:
		Audio.set_sfx(not Audio.sfx_on())
		update.call())
	music.pressed.connect(func() -> void:
		Audio.set_music(not Audio.music_on())
		update.call())
	return row


## Сообщение о важном событии с кнопками «Перейти» (если есть страна) и «Понятно».
static func alert(title: String, text: String, on_goto: Variant, on_ok: Callable) -> Control:
	var parts := make_modal(560.0)
	var box: VBoxContainer = parts[1]
	box.add_child(GameTheme.make_label(title.to_upper(), 30, GameTheme.display_font(600), MapPalette.VERMILION))
	box.add_child(paragraph(text, 520.0, 20))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_END
	if on_goto is Callable:
		row.add_child(button(TranslationServer.translate("ALERT_GOTO"), on_goto, true))
	row.add_child(button(TranslationServer.translate("ALERT_OK"), on_ok))
	box.add_child(row)
	return parts[0]
