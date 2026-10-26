class_name CreditsScreen
extends Control
## Титры: кто и что сделал, источники данных, шрифтов, звука и музыки и их лицензии
## (тот же список — в LICENSES-ASSETS.md).

signal closed

const W := 980.0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_meta("paper", true)
	var bg := ColorRect.new()
	bg.color = MapPalette.PAPER
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)
	var bar := PanelContainer.new()
	bar.custom_minimum_size = Vector2(0, 64)
	bar.add_theme_stylebox_override("panel", Screens.band(MapPalette.INK))
	var row := HBoxContainer.new()
	bar.add_child(row)
	var title := GameTheme.make_label(tr("CREDITS_TITLE").to_upper(), 30, GameTheme.display_font(600), MapPalette.PAPER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	row.add_child(Screens.close_button(func() -> void: closed.emit(), true))
	root.add_child(bar)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(W, 0)
	box.add_theme_constant_override("separation", 6)
	center.add_child(box)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	box.add_child(spacer)
	box.add_child(_label("%s %s" % [tr("GAME_TITLE"), ProjectSettings.get_setting("application/config/version", "")], 34,
		GameTheme.display_font(700), MapPalette.VERMILION))
	box.add_child(_label(tr("CREDITS_ABOUT"), 17))
	for section in sections():
		box.add_child(HSeparator.new())
		box.add_child(_label(tr(section[0]).to_upper(), 16, GameTheme.BODY_BOLD_FONT, MapPalette.VERMILION))
		for line: String in section[1]:
			box.add_child(_label(tr(line), 16))
	var end := Control.new()
	end.custom_minimum_size = Vector2(0, 24)
	box.add_child(end)


## Разделы титров: [заголовок, [строки]]. Строка про Grok появляется, когда прислали иллюстрации.
static func sections() -> Array:
	var art: Array = ["CREDITS_ART_STUBS"]
	if ArtLibrary.any():
		art = ["CREDITS_ART_GROK"]
	return [
		["CREDITS_CODE", ["CREDITS_GODOT", "CREDITS_CLAUDE"]],
		["CREDITS_DATA", ["CREDITS_NATURAL_EARTH", "CREDITS_WORLD_BANK"]],
		["CREDITS_FONTS", ["CREDITS_PT_SANS", "CREDITS_OSWALD"]],
		["CREDITS_SOUND", ["CREDITS_MUSIC_SONGS", "CREDITS_MUSIC_OWN", "CREDITS_SOUNDFONT", "CREDITS_SFX"]],
		["CREDITS_ART", art],
	]


func _label(text: String, size: int, font: Font = null, color: Color = MapPalette.INK) -> Label:
	var l := GameTheme.make_label(text, size, font, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = W
	return l
