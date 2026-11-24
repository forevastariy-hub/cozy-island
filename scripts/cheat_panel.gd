extends CanvasLayer

# Standalone cheat panel. Delete this file (and the _load_cheat_panel call in
# main.gd is guarded by ResourceLoader.exists) and the game keeps working.

var terrain: Node3D
var player: CharacterBody3D
var daynight: Node3D
var ui: CanvasLayer
var world: Node3D

var _panel: PanelContainer
var _zone_select: OptionButton
var _info: Label

func _ready() -> void:
	layer = 90
	visible = false
	_build()

func _build() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_panel.position = Vector2(18.0, 18.0)
	_panel.custom_minimum_size = Vector2(280.0, 0.0)
	add_child(_panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	_panel.add_child(root)

	var title := Label.new()
	title.text = "ЧИТ-ПАНЕЛЬ  ·  F3"
	title.add_theme_font_size_override("font_size", 16)
	root.add_child(title)

	_info = Label.new()
	_info.text = "F3 — скрыть/показать"
	_info.add_theme_font_size_override("font_size", 11)
	root.add_child(_info)

	root.add_child(HSeparator.new())

	root.add_child(_section("Время"))
	var time_row := HBoxContainer.new()
	time_row.add_child(_btn("-1ч", func(): _add_time(-1.0)))
	time_row.add_child(_btn("+1ч", func(): _add_time(1.0)))
	time_row.add_child(_btn("Рассвет", func(): _set_time(6.0)))
	time_row.add_child(_btn("День", func(): _set_time(12.0)))
	time_row.add_child(_btn("Ночь", func(): _set_time(0.0)))
	root.add_child(time_row)

	root.add_child(HSeparator.new())

	root.add_child(_section("Погода"))
	var weather_row := HBoxContainer.new()
	weather_row.add_child(_btn("Дождь вкл/выкл", _toggle_rain))
	weather_row.add_child(_btn("Ясно", _clear_rain))
	root.add_child(weather_row)

	root.add_child(HSeparator.new())

	root.add_child(_section("Ресурсы"))
	var res_row := HBoxContainer.new()
	res_row.add_child(_btn("+10 дерево", func(): _give("wood", 10)))
	res_row.add_child(_btn("+10 камень", func(): _give("stone", 10)))
	root.add_child(res_row)
	var res_row2 := HBoxContainer.new()
	res_row2.add_child(_btn("+10 ягоды", func(): _give("berry", 10)))
	res_row2.add_child(_btn("+5 рыба", func(): _give("fish", 5)))
	root.add_child(res_row2)
	var res_row3 := HBoxContainer.new()
	res_row3.add_child(_btn("+10 семена", func(): _give("seed", 10)))
	res_row3.add_child(_btn("+5 урожай", func(): _give("crop", 5)))
	root.add_child(res_row3)
	var comfort_row := HBoxContainer.new()
	comfort_row.add_child(_btn("+50 комфорт", _add_comfort))
	root.add_child(comfort_row)

	root.add_child(HSeparator.new())

	root.add_child(_section("Телепорт"))
	_zone_select = OptionButton.new()
	_zone_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(_zone_select)
	root.add_child(_btn("Переместиться", _teleport))

	_refresh_info()

func _section(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	return l

func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 11)
	b.pressed.connect(cb)
	return b

func _refresh_info() -> void:
	if _info == null:
		return
	_info.text = "F3 — скрыть/показать   ·   день %d, %02d:%02d" % [
		Game.day, int(Game.time_of_day), int(fmod(Game.time_of_day, 1.0) * 60.0)]

func _process(_delta: float) -> void:
	if visible:
		_refresh_info()
		if _zone_select != null and _zone_select.item_count == 0 and terrain != null:
			for key in terrain.pois:
				_zone_select.add_item(String(key))

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		visible = not visible
		if visible:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			if _zone_select != null and _zone_select.item_count == 0 and terrain != null:
				for key in terrain.pois:
					_zone_select.add_item(String(key))
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()

func _add_time(hours: float) -> void:
	Game.time_of_day = fposmod(Game.time_of_day + hours, 24.0)

func _set_time(hour: float) -> void:
	Game.time_of_day = clampf(hour, 0.0, 23.99)

func _toggle_rain() -> void:
	if daynight != null and daynight.has_method("toggle_rain"):
		daynight.toggle_rain()

func _clear_rain() -> void:
	if daynight != null and daynight.has_method("set_rain"):
		daynight.set_rain(false)

func _give(id: String, amount: int) -> void:
	Game.add_item(id, amount)
	Game.toast("+%d %s" % [amount, Game.item_name(id)])

func _add_comfort() -> void:
	Game.add_comfort(50.0)
	Game.toast("Комфорт +50")

func _teleport() -> void:
	if player == null or terrain == null or _zone_select == null:
		return
	if _zone_select.item_count == 0:
		return
	var key := _zone_select.get_item_text(_zone_select.selected)
	if not terrain.pois.has(key):
		return
	var c: Vector2 = terrain.pois[key]
	var p := _find_land_near(c)
	player.global_position = p
	player.velocity = Vector3.ZERO
	Game.toast("Телепорт: %s" % key)

func _find_land_near(c: Vector2) -> Vector3:
	var h: float = terrain.get_height(c.x, c.y)
	if h > -1.0:
		return Vector3(c.x, h + 2.0, c.y)
	for r in range(1, 24):
		for a in range(16):
			var ang := TAU * float(a) / 16.0
			var x := c.x + cos(ang) * float(r) * 4.0
			var z := c.y + sin(ang) * float(r) * 4.0
			var hh: float = terrain.get_height(x, z)
			if hh > -1.0:
				return Vector3(x, hh + 2.0, z)
	return Vector3(c.x, 20.0, c.y)
