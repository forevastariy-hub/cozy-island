extends "res://scripts/interactable.gd"

const GROW_TIME := 20.0

var stage := 0
var timer := 0.0
var _crop: Node3D

func _ready() -> void:
	prompt_text = "Посадить семена"
	add_to_group("path_poi")
	_build()

func _build() -> void:
	var soil := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.3, 0.16, 1.3)
	soil.mesh = box
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.3, 0.2, 0.12)
	m.roughness = 1.0
	soil.material_override = m
	soil.position.y = 0.08
	add_child(soil)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.3, 0.4, 1.3)
	col.shape = shape
	col.position.y = 0.2
	add_child(col)

	_crop = Node3D.new()
	add_child(_crop)
	_update_crop()

func _process(delta: float) -> void:
	if stage >= 1 and stage < 4:
		timer += delta
		if timer >= GROW_TIME:
			timer = 0.0
			stage += 1
			_update_crop()
			if stage == 4:
				prompt_text = "Собрать урожай"

func _update_crop() -> void:
	for c in _crop.get_children():
		_crop.remove_child(c)
		c.queue_free()
	if stage <= 0:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.28, 0.48, 0.22)
	var height := 0.15 + stage * 0.18
	var stem := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.04
	cyl.bottom_radius = 0.06
	cyl.height = height
	cyl.radial_segments = 5
	stem.mesh = cyl
	stem.material_override = mat
	stem.position.y = height * 0.5
	_crop.add_child(stem)
	if stage >= 4:
		var fruit_mat := StandardMaterial3D.new()
		fruit_mat.albedo_color = Color(0.92, 0.62, 0.22)
		fruit_mat.roughness = 0.7
		var fruit := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.14
		s.height = 0.28
		s.radial_segments = 7
		s.rings = 4
		fruit.mesh = s
		fruit.material_override = fruit_mat
		fruit.position.y = height
		_crop.add_child(fruit)

func interact(_player: Node) -> void:
	if stage == 0:
		if Game.count_item("seed") > 0:
			Game.remove_item("seed", 1)
			stage = 1
			timer = 0.0
			_update_crop()
			prompt_text = "Растёт..."
			Game.toast("Посажено")
		else:
			Game.toast("Нужны семена")
	elif stage == 4:
		Game.add_item("crop", 1)
		Game.add_item("seed", 1)
		stage = 0
		timer = 0.0
		_update_crop()
		prompt_text = "Посадить семена"
		Game.toast("+1 урожай")
