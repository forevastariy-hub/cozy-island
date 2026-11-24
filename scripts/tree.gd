extends "res://scripts/interactable.gd"

const LeafWindShader = preload("res://scripts/leaf_wind.gdshader")

var rng := RandomNumberGenerator.new()
var hits := 3
var max_hits := 3
var kind := 0
var _depleted := false
var _foliage: Node3D
var _shake: Tween

func _ready() -> void:
	prompt_text = "Собрать хворост"
	_build()

func _build() -> void:
	var h := rng.randf_range(2.6, 5.0)
	var trunk := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.11
	cyl.bottom_radius = 0.28
	cyl.height = h
	cyl.radial_segments = 7
	trunk.mesh = cyl
	var tm := StandardMaterial3D.new()
	tm.albedo_color = Color(0.32, 0.2, 0.12)
	tm.roughness = 1.0
	trunk.material_override = tm
	trunk.position.y = h * 0.5
	trunk.rotation.z = rng.randf_range(-0.1, 0.1)
	add_child(trunk)

	for _i in range(2):
		var bl := rng.randf_range(0.8, 1.5)
		var branch := MeshInstance3D.new()
		var bc := CylinderMesh.new()
		bc.top_radius = 0.025
		bc.bottom_radius = 0.08
		bc.height = bl
		bc.radial_segments = 5
		branch.mesh = bc
		branch.material_override = tm
		var a := rng.randf_range(0.0, TAU)
		branch.position = Vector3(cos(a) * 0.14, h * 0.68 + rng.randf_range(-0.2, 0.5), sin(a) * 0.14)
		branch.rotation = Vector3(rng.randf_range(0.6, 1.1), a, 0.0)
		add_child(branch)

	_foliage = Node3D.new()
	_foliage.position.y = h
	add_child(_foliage)

	if rng.randf() > 0.25:
		var leaf_mat := ShaderMaterial.new()
		leaf_mat.shader = LeafWindShader
		var green := rng.randf_range(0.15, 0.3)
		if kind == 1:
			# Pine: conical crowns
			leaf_mat.set_shader_parameter("leaf_color", Color(
				0.30 + green * 0.3, 0.34 + green * 0.4, 0.16))
			leaf_mat.set_shader_parameter("wind_strength", 0.055)
			var r := rng.randf_range(1.0, 1.6)
			for i in range(3):
				var cone := MeshInstance3D.new()
				var cm := CylinderMesh.new()
				cm.top_radius = 0.0
				cm.bottom_radius = r * (1.0 - i * 0.22)
				cm.height = r * 1.5
				cm.radial_segments = 7
				cone.mesh = cm
				cone.material_override = leaf_mat
				cone.position.y = i * r * 0.5
				cone.rotation.z = rng.randf_range(-0.12, 0.12)
				cone.rotation.x = rng.randf_range(-0.08, 0.08)
				_foliage.add_child(cone)
		elif kind == 2:
			# Deciduous: rounded canopy of spheres
			leaf_mat.set_shader_parameter("leaf_color", Color(
				0.34 + green * 0.4, 0.42 + green * 0.42, 0.2))
			leaf_mat.set_shader_parameter("wind_strength", 0.04)
			var r := rng.randf_range(1.4, 2.2)
			var sphere_count := rng.randi_range(5, 9)
			for i in range(sphere_count):
				var crown := MeshInstance3D.new()
				var sm := SphereMesh.new()
				var sr := r * rng.randf_range(0.45, 0.9)
				sm.radius = sr
				sm.height = sr * 1.3
				sm.radial_segments = 7
				sm.rings = 4
				crown.mesh = sm
				crown.material_override = leaf_mat
				var a := rng.randf_range(0.0, TAU)
				var phi := rng.randf_range(-0.6, 0.6)
				var off := Vector3(
					cos(a) * cos(phi) * rng.randf_range(0.3, 0.9),
					rng.randf_range(-0.4, 1.0),
					sin(a) * cos(phi) * rng.randf_range(0.3, 0.9))
				crown.position = off
				crown.scale = Vector3(1.0, rng.randf_range(0.85, 1.15), 1.0)
				_foliage.add_child(crown)
		else:
			# Default pine (original)
			leaf_mat.set_shader_parameter("leaf_color", Color(
				0.30 + green * 0.3, 0.34 + green * 0.4, 0.16))
			leaf_mat.set_shader_parameter("wind_strength", 0.055)
			var r := rng.randf_range(1.0, 1.5)
			for i in range(3):
				var cone := MeshInstance3D.new()
				var cm := CylinderMesh.new()
				cm.top_radius = 0.0
				cm.bottom_radius = r * (1.0 - i * 0.24)
				cm.height = r * 1.5
				cm.radial_segments = 7
				cone.mesh = cm
				cone.material_override = leaf_mat
				cone.position.y = i * r * 0.55
				cone.rotation.z = rng.randf_range(-0.15, 0.15)
				_foliage.add_child(cone)

	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.5
	shape.height = h
	col.shape = shape
	col.position.y = h * 0.5
	add_child(col)

func interact(_player: Node) -> void:
	if _depleted:
		return
	Game.add_item("wood", 1)
	Game.toast("+1 дерево")
	hits -= 1
	_shake_it()
	if hits <= 0:
		_deplete()

func _shake_it() -> void:
	if _shake != null and _shake.is_running():
		_shake.kill()
	_shake = create_tween()
	_shake.tween_property(_foliage, "rotation:z", 0.08, 0.05)
	_shake.tween_property(_foliage, "rotation:z", -0.08, 0.09)
	_shake.tween_property(_foliage, "rotation:z", 0.0, 0.09)

func _deplete() -> void:
	_depleted = true
	prompt_text = ""
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	var t := create_tween()
	t.tween_property(self, "scale", Vector3(0.02, 0.02, 0.02), 0.35)
	await get_tree().create_timer(75.0).timeout
	if not is_inside_tree():
		return
	scale = Vector3.ONE
	hits = max_hits
	_depleted = false
	prompt_text = "Собрать хворост"
	set_deferred("collision_layer", 1)
	set_deferred("collision_mask", 1)
