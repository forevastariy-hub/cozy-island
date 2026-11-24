extends CanvasLayer

const TEXT := Color(0.95, 0.9, 0.8)
const DIM := Color(0.72, 0.65, 0.55)
const ACCENT := Color(0.95, 0.7, 0.35)
const DARK := Color(0.12, 0.09, 0.06, 0.78)
const BORDER := Color(0.45, 0.32, 0.18, 0.95)

var prompt_label: Label
var info_label: Label
var time_slider: HSlider
var inv_box: VBoxContainer
var toast_label: Label
var comfort_bar: ProgressBar
var font: SystemFont
var hotbar_slots: Array = []
var minimap_panel: PanelContainer
var minimap_holder: Control
var minimap_rect: TextureRect
var minimap_marker: ColorRect
var pause_overlay: Control
var pause_panel: PanelContainer
var fog_slider: HSlider
var light_slider: HSlider
var auto_weather_check: CheckButton
var terrain: Node
var player: Node3D
var daynight: Node
var world: Node
var menu_open := false
var map_large := false
var _toast_tween: Tween
var _minimap_ready := false

func _ready() -> void:
	layer = 2
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Segoe UI", "Trebuchet MS", "Verdana", "sans-serif"])

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_build_time_panel(root)
	_build_minimap(root)

	prompt_label = Label.new()
	prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.offset_left = -380
	prompt_label.offset_right = 380
	prompt_label.offset_top = -170
	prompt_label.offset_bottom = -122
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_text(prompt_label, 23, ACCENT)
	prompt_label.visible = false
	root.add_child(prompt_label)

	_build_inventory(root)
	_build_hotbar(root)
	_build_controls(root)

	toast_label = Label.new()
	toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_label.offset_left = -380
	toast_label.offset_right = 380
	toast_label.offset_top = 40
	toast_label.offset_bottom = 84
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_text(toast_label, 21, ACCENT)
	toast_label.modulate.a = 0.0
	root.add_child(toast_label)

	_build_pause(root)

	Game.inventory_changed.connect(_refresh_inventory)
	Game.inventory_changed.connect(_refresh_hotbar)
	Game.hotbar_changed.connect(_refresh_hotbar)
	Game.toast_requested.connect(show_toast)
	Game.comfort_changed.connect(_on_comfort_changed)
	_refresh_inventory()
	_refresh_hotbar()
	_on_comfort_changed(Game.comfort)

func _build_time_panel(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.offset_left = 22
	panel.offset_top = 22
	panel.offset_right = 340
	panel.offset_bottom = 176
	panel.add_theme_stylebox_override("panel", _panel_style())
	root.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	panel.add_child(v)

	info_label = Label.new()
	_style_text(info_label, 18, TEXT)
	v.add_child(info_label)

	time_slider = HSlider.new()
	time_slider.min_value = 0.0
	time_slider.max_value = 24.0
	time_slider.step = 0.05
	time_slider.value = Game.time_of_day
	time_slider.custom_minimum_size = Vector2(286, 18)
	time_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time_slider.focus_mode = Control.FOCUS_NONE

	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.16, 0.11, 0.07, 0.95)
	track.border_width_left = 1
	track.border_width_top = 1
	track.border_width_right = 1
	track.border_width_bottom = 1
	track.border_color = Color(0.36, 0.25, 0.14, 0.9)
	track.content_margin_top = 4
	track.content_margin_bottom = 4

	var fill := StyleBoxFlat.new()
	fill.bg_color = ACCENT
	fill.content_margin_top = 4
	fill.content_margin_bottom = 4

	var fill_hi := StyleBoxFlat.new()
	fill_hi.bg_color = Color(1.0, 0.82, 0.5)
	fill_hi.content_margin_top = 4
	fill_hi.content_margin_bottom = 4

	time_slider.add_theme_stylebox_override("slider", track)
	time_slider.add_theme_stylebox_override("grabber_area", fill)
	time_slider.add_theme_stylebox_override("grabber_area_highlight", fill_hi)
	time_slider.value_changed.connect(_on_time_changed)
	v.add_child(time_slider)

	var hint := Label.new()
	hint.text = "Esc → курсор → тяни   ·   P — пауза"
	_style_text(hint, 11, DIM)
	v.add_child(hint)

	var comfort_label := Label.new()
	comfort_label.text = "КОМФОРТ"
	_style_text(comfort_label, 12, DIM)
	v.add_child(comfort_label)

	comfort_bar = ProgressBar.new()
	comfort_bar.min_value = 0.0
	comfort_bar.max_value = 100.0
	comfort_bar.value = Game.comfort
	comfort_bar.show_percentage = false
	comfort_bar.custom_minimum_size = Vector2(286, 11)
	comfort_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.15, 0.1, 0.06, 0.9)
	bg.corner_radius_top_left = 3
	bg.corner_radius_top_right = 3
	bg.corner_radius_bottom_left = 3
	bg.corner_radius_bottom_right = 3
	var fg := StyleBoxFlat.new()
	fg.bg_color = Color(0.56, 0.72, 0.36)
	fg.corner_radius_top_left = 3
	fg.corner_radius_top_right = 3
	fg.corner_radius_bottom_left = 3
	fg.corner_radius_bottom_right = 3
	comfort_bar.add_theme_stylebox_override("background", bg)
	comfort_bar.add_theme_stylebox_override("fill", fg)
	v.add_child(comfort_bar)

func _build_minimap(root: Control) -> void:
	minimap_panel = PanelContainer.new()
	minimap_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	minimap_panel.offset_left = -238
	minimap_panel.offset_top = 22
	minimap_panel.offset_right = -22
	minimap_panel.offset_bottom = 252
	minimap_panel.add_theme_stylebox_override("panel", _panel_style())
	root.add_child(minimap_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	minimap_panel.add_child(v)

	var title := Label.new()
	title.text = "КАРТА"
	_style_text(title, 13, ACCENT)
	v.add_child(title)

	minimap_holder = Control.new()
	minimap_holder.custom_minimum_size = Vector2(190, 190)
	minimap_holder.clip_contents = true
	minimap_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(minimap_holder)

	minimap_rect = TextureRect.new()
	minimap_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	minimap_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	minimap_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	minimap_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap_holder.add_child(minimap_rect)

	minimap_marker = ColorRect.new()
	minimap_marker.color = ACCENT
	minimap_marker.size = Vector2(9, 9)
	minimap_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap_holder.add_child(minimap_marker)

	var hint := Label.new()
	hint.text = "M — развернуть"
	_style_text(hint, 10, DIM)
	v.add_child(hint)

func _build_inventory(root: Control) -> void:
	var inv_panel := PanelContainer.new()
	inv_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	inv_panel.offset_left = 22
	inv_panel.offset_top = -224
	inv_panel.offset_right = 262
	inv_panel.offset_bottom = -122
	inv_panel.add_theme_stylebox_override("panel", _panel_style())
	root.add_child(inv_panel)

	inv_box = VBoxContainer.new()
	inv_box.add_theme_constant_override("separation", 2)
	inv_panel.add_child(inv_box)

func _build_hotbar(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_left = -300
	panel.offset_top = -96
	panel.offset_right = 300
	panel.offset_bottom = -18
	panel.add_theme_stylebox_override("panel", _panel_style())
	root.add_child(panel)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(h)

	for i in range(Game.HOTBAR.size()):
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(88, 62)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 1)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		slot.add_child(v)
		var name := Label.new()
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_style_text(name, 11, TEXT)
		v.add_child(name)
		var count := Label.new()
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_style_text(count, 15, ACCENT)
		v.add_child(count)
		h.add_child(slot)
		hotbar_slots.append({"panel": slot, "name": name, "count": count})

func _build_controls(root: Control) -> void:
	var controls := Label.new()
	controls.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	controls.offset_left = -360
	controls.offset_top = -238
	controls.offset_right = -24
	controls.offset_bottom = -122
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	controls.text = "WASD — движение   Shift — бег\nSpace — прыжок   E — действие\nC — сесть / встать   F — использовать\nB — костёр   R — дождь   M — карта\nF5 / F9 — сохранить / загрузить\nEsc — курсор / отмена   P — пауза"
	_style_text(controls, 14, DIM)
	root.add_child(controls)

func _build_pause(root: Control) -> void:
	pause_overlay = Control.new()
	pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_overlay.visible = false
	root.add_child(pause_overlay)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.03, 0.04, 0.64)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_overlay.add_child(center)

	pause_panel = PanelContainer.new()
	pause_panel.custom_minimum_size = Vector2(380, 520)
	pause_panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(pause_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	pause_panel.add_child(v)

	var title := Label.new()
	title.text = "ПАУЗА"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_text(title, 26, ACCENT)
	v.add_child(title)

	_add_button(v, "Продолжить", _close_menu)
	_add_button(v, "Сохранить", _on_save_pressed)
	_add_button(v, "Загрузить", _on_load_pressed)

	var settings_title := Label.new()
	settings_title.text = "НАСТРОЙКИ"
	settings_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_text(settings_title, 14, DIM)
	v.add_child(settings_title)

	var fog_label := Label.new()
	fog_label.text = "Туман"
	_style_text(fog_label, 13, TEXT)
	v.add_child(fog_label)
	fog_slider = HSlider.new()
	fog_slider.min_value = 0.0
	fog_slider.max_value = 2.0
	fog_slider.step = 0.05
	fog_slider.value = 1.0
	fog_slider.custom_minimum_size = Vector2(320, 18)
	fog_slider.value_changed.connect(_on_fog_changed)
	v.add_child(fog_slider)

	var light_label := Label.new()
	light_label.text = "Свет"
	_style_text(light_label, 13, TEXT)
	v.add_child(light_label)
	light_slider = HSlider.new()
	light_slider.min_value = 0.6
	light_slider.max_value = 1.5
	light_slider.step = 0.05
	light_slider.value = 1.0
	light_slider.custom_minimum_size = Vector2(320, 18)
	light_slider.value_changed.connect(_on_light_changed)
	v.add_child(light_slider)

	auto_weather_check = CheckButton.new()
	auto_weather_check.text = "Авто-погода"
	auto_weather_check.button_pressed = true
	auto_weather_check.add_theme_font_override("font", font)
	auto_weather_check.add_theme_font_size_override("font_size", 13)
	auto_weather_check.add_theme_color_override("font_color", TEXT)
	auto_weather_check.toggled.connect(_on_auto_weather_toggled)
	v.add_child(auto_weather_check)

	_add_button(v, "Выход", _on_quit_pressed)

	var close_hint := Label.new()
	close_hint.text = "P или Esc — закрыть"
	close_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_text(close_hint, 12, DIM)
	v.add_child(close_hint)

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = DARK
	style.border_width_left = 3
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = BORDER
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _add_button(parent: VBoxContainer, text: String, callback: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 38)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", ACCENT)
	b.add_theme_stylebox_override("normal", _button_style(Color(0.18, 0.13, 0.08, 0.95), BORDER))
	b.add_theme_stylebox_override("hover", _button_style(Color(0.26, 0.18, 0.1, 0.98), ACCENT))
	b.add_theme_stylebox_override("pressed", _button_style(Color(0.12, 0.09, 0.06, 1.0), ACCENT))
	b.pressed.connect(callback)
	parent.add_child(b)

func _button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_width_left = 1
	s.border_width_top = 1
	s.border_width_right = 1
	s.border_width_bottom = 1
	s.border_color = border
	s.corner_radius_top_left = 4
	s.corner_radius_top_right = 4
	s.corner_radius_bottom_left = 4
	s.corner_radius_bottom_right = 4
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 5
	s.content_margin_bottom = 5
	return s

func setup_minimap() -> void:
	if terrain == null or minimap_rect == null:
		return
	minimap_rect.texture = terrain.get_minimap_texture(160)
	_minimap_ready = true
	_update_minimap_marker()

func _on_time_changed(value: float) -> void:
	Game.time_of_day = 0.0 if value >= 23.995 else value

func _style_text(l: Label, size: int, color := TEXT) -> void:
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.02, 0.9))
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)

func _process(_delta: float) -> void:
	var h := int(Game.time_of_day)
	var m := int((Game.time_of_day - h) * 60.0)
	info_label.text = "ДЕНЬ %02d    %02d:%02d" % [Game.day, h, m]
	time_slider.set_value_no_signal(Game.time_of_day)
	comfort_bar.value = Game.comfort
	_update_minimap_marker()

	if not menu_open:
		for i in range(Game.HOTBAR.size()):
			if Input.is_action_just_pressed("hotbar_%d" % (i + 1)):
				Game.set_hotbar(i)
		if Input.is_action_just_pressed("map"):
			_toggle_map()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if menu_open:
			_close_menu()
		else:
			_open_menu()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cancel") and menu_open:
		_close_menu()
		get_viewport().set_input_as_handled()

func _open_menu() -> void:
	if menu_open:
		return
	menu_open = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	pause_overlay.visible = true
	pause_overlay.modulate.a = 0.0
	pause_panel.scale = Vector2(0.94, 0.94)
	pause_panel.pivot_offset = pause_panel.size * 0.5
	var t := create_tween().set_parallel(true)
	t.tween_property(pause_overlay, "modulate:a", 1.0, 0.18)
	t.tween_property(pause_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _close_menu() -> void:
	if not menu_open:
		return
	menu_open = false
	get_tree().paused = false
	pause_overlay.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_save_pressed() -> void:
	if world != null and world.has_method("_save_game"):
		world._save_game()

func _on_load_pressed() -> void:
	if world != null and world.has_method("_load_game"):
		world._load_game()

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_fog_changed(value: float) -> void:
	if daynight != null:
		daynight.set_fog_scale(value)

func _on_light_changed(value: float) -> void:
	if daynight != null:
		daynight.set_light_scale(value)

func _on_auto_weather_toggled(on: bool) -> void:
	if daynight != null:
		daynight.auto_weather = on

func _on_comfort_changed(value: float) -> void:
	if comfort_bar != null:
		comfort_bar.value = value

func _toggle_map() -> void:
	map_large = not map_large
	var size := 390.0 if map_large else 190.0
	minimap_holder.custom_minimum_size = Vector2(size, size)
	minimap_panel.offset_left = -238.0 - (size - 190.0)
	minimap_panel.offset_bottom = 252.0 + (size - 190.0)
	var t := create_tween()
	t.tween_property(minimap_panel, "modulate", Color.WHITE, 0.12)

func _update_minimap_marker() -> void:
	if not _minimap_ready or terrain == null or player == null or minimap_holder == null:
		return
	if minimap_holder.size.x <= 1.0 or minimap_holder.size.y <= 1.0:
		return
	var u := player.global_position.x / float(terrain.SIZE) + 0.5
	var v := player.global_position.z / float(terrain.SIZE) + 0.5
	u = clampf(u, 0.0, 1.0)
	v = clampf(v, 0.0, 1.0)
	var sz := minimap_holder.size
	minimap_marker.position = Vector2(u * sz.x, v * sz.y) - minimap_marker.size * 0.5

func set_prompt(text: String) -> void:
	prompt_label.text = text
	prompt_label.visible = text != ""

func show_toast(text: String) -> void:
	toast_label.text = text
	if _toast_tween != null and _toast_tween.is_running():
		_toast_tween.kill()
	toast_label.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.4)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.8)

func _refresh_inventory() -> void:
	for c in inv_box.get_children():
		inv_box.remove_child(c)
		c.queue_free()
	var title := Label.new()
	title.text = "ИНВЕНТАРЬ"
	_style_text(title, 16, ACCENT)
	inv_box.add_child(title)
	var any := false
	for id in Game.inventory:
		var count: int = int(Game.inventory[id])
		if count <= 0:
			continue
		any = true
		var l := Label.new()
		l.text = "%s  × %d" % [Game.item_name(id), count]
		_style_text(l, 15, TEXT)
		inv_box.add_child(l)
	if not any:
		var empty := Label.new()
		empty.text = "(пусто)"
		_style_text(empty, 14, DIM)
		inv_box.add_child(empty)

func _refresh_hotbar(_index: int = 0) -> void:
	for i in range(hotbar_slots.size()):
		var slot: PanelContainer = hotbar_slots[i]["panel"]
		var name_label: Label = hotbar_slots[i]["name"]
		var count_label: Label = hotbar_slots[i]["count"]
		var id: String = Game.HOTBAR[i]
		name_label.text = Game.item_name(id)
		count_label.text = "×%d" % Game.count_item(id)
		var selected := i == Game.selected_hotbar
		var style := _button_style(
			Color(0.22, 0.16, 0.09, 0.94) if selected else Color(0.12, 0.09, 0.06, 0.78),
			ACCENT if selected else BORDER)
		style.border_width_left = 2 if selected else 1
		style.border_width_right = 2 if selected else 1
		style.border_width_top = 2 if selected else 1
		style.border_width_bottom = 2 if selected else 1
		slot.add_theme_stylebox_override("panel", style)
