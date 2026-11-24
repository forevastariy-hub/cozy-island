extends Node

signal inventory_changed
signal toast_requested(text: String)
signal day_started(day: int)
signal build_mode_changed(active: bool)
signal comfort_changed(value: float)
signal hotbar_changed(index: int)
signal pickup_requested(id: String, amount: int)

const ITEMS := {
	"wood": {"name": "Дерево", "color": Color(0.55, 0.36, 0.18)},
	"stone": {"name": "Камень", "color": Color(0.62, 0.62, 0.66)},
	"berry": {"name": "Ягоды", "color": Color(0.45, 0.25, 0.55)},
	"fish": {"name": "Рыба", "color": Color(0.35, 0.58, 0.85)},
	"seed": {"name": "Семена", "color": Color(0.52, 0.72, 0.32)},
	"crop": {"name": "Урожай", "color": Color(0.92, 0.72, 0.25)},
}
const HOTBAR := ["wood", "stone", "berry", "fish", "seed", "crop"]

var inventory: Dictionary = {}
var day: int = 1
var time_of_day: float = 16.0
var build_mode: bool = false
var comfort: float = 100.0
var selected_hotbar: int = 0
var world_seed: int = 424242
var _comfort_emit_timer := 0.0

func _ready() -> void:
	_setup_input()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			world_seed = int(arg.split("=")[1])
	inventory["seed"] = 6
	inventory["wood"] = 4

func _setup_input() -> void:
	var actions := {
		"move_forward": [KEY_W, KEY_UP],
		"move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE],
		"sprint": [KEY_SHIFT],
		"interact": [KEY_E],
		"build": [KEY_B],
		"cancel": [KEY_ESCAPE],
		"sit": [KEY_C],
		"weather": [KEY_R],
		"map": [KEY_M],
		"pause": [KEY_P],
		"use_item": [KEY_F],
		"save": [KEY_F5],
		"load": [KEY_F9],
		"hotbar_1": [KEY_1],
		"hotbar_2": [KEY_2],
		"hotbar_3": [KEY_3],
		"hotbar_4": [KEY_4],
		"hotbar_5": [KEY_5],
		"hotbar_6": [KEY_6],
	}
	for action in actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in actions[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)

func add_item(id: String, amount: int = 1) -> void:
	inventory[id] = int(inventory.get(id, 0)) + amount
	inventory_changed.emit()

func remove_item(id: String, amount: int = 1) -> bool:
	var have := int(inventory.get(id, 0))
	if have < amount:
		return false
	if have - amount <= 0:
		inventory.erase(id)
	else:
		inventory[id] = have - amount
	inventory_changed.emit()
	return true

func count_item(id: String) -> int:
	return int(inventory.get(id, 0))

func item_name(id: String) -> String:
	return ITEMS.get(id, {}).get("name", id)

func toast(text: String) -> void:
	toast_requested.emit(text)

func pickup(id: String, amount: int = 1) -> void:
	add_item(id, amount)
	pickup_requested.emit(id, amount)

func set_build_mode(active: bool) -> void:
	build_mode = active
	build_mode_changed.emit(active)

func _process(delta: float) -> void:
	comfort = clampf(comfort - delta * 0.06, 0.0, 100.0)
	_comfort_emit_timer += delta
	if _comfort_emit_timer >= 0.5:
		_comfort_emit_timer = 0.0
		comfort_changed.emit(comfort)

func add_comfort(amount: float) -> void:
	comfort = clampf(comfort + amount, 0.0, 100.0)
	comfort_changed.emit(comfort)

func set_hotbar(index: int) -> void:
	selected_hotbar = clampi(index, 0, HOTBAR.size() - 1)
	hotbar_changed.emit(selected_hotbar)

func selected_item() -> String:
	return HOTBAR[selected_hotbar]

func save_state() -> Dictionary:
	return {
		"inventory": inventory.duplicate(true),
		"day": day,
		"time_of_day": time_of_day,
		"comfort": comfort,
		"selected_hotbar": selected_hotbar,
	}

func load_state(data: Dictionary) -> void:
	if data.has("inventory"):
		inventory = data["inventory"].duplicate(true)
	if data.has("day"):
		day = int(data["day"])
	if data.has("time_of_day"):
		time_of_day = float(data["time_of_day"])
	if data.has("comfort"):
		comfort = float(data["comfort"])
	if data.has("selected_hotbar"):
		selected_hotbar = clampi(int(data["selected_hotbar"]), 0, HOTBAR.size() - 1)
	inventory_changed.emit()
	hotbar_changed.emit(selected_hotbar)
	comfort_changed.emit(comfort)
