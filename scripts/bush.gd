extends "res://scripts/interactable.gd"

const LeafWindShader = preload("res://scripts/leaf_wind.gdshader")

var rng := RandomNumberGenerator.new()
var _depleted := false
var _bush: Node3D

func _ready() -> void:
	prompt_text = "Собрать ягоды"
	_build()

func _build() -> void:
	_bush = Node3D.new()
	add_child(_bush)
	var m := ShaderMaterial.new()
	m.shader = LeafWindShader
	m.set_shader_parameter("leaf_color", Color(0.28, 0.36, 0.16))
	m.set_shader_parameter("wind_strength", 0.025)
	for _i in range(3):
		var leaf := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = rng.randf_range(0.35, 0.55)
		sph.height = sph.radius * 2.0
		sph.radial_segments = 7
		sph.rings = 4
		leaf.mesh = sph
		leaf.material_override = m
		leaf.position = Vector3(rng.randf_range(-0.3, 0.3), 0.35 + rng.randf_range(0.0, 0.25), rng.randf_range(-0.3, 0.3))
		_bush.add_child(leaf)

	var berry_mat := StandardMaterial3D.new()
	berry_mat.albedo_color = Color(0.4, 0.22, 0.5)
	berry_mat.roughness = 0.6
	for _i in range(5):
		var berry := MeshInstance3D.new()
		var bs := SphereMesh.new()
		bs.radius = 0.06
		bs.height = 0.12
		bs.radial_segments = 5
		bs.rings = 3
		berry.mesh = bs
		berry.material_override = berry_mat
		var a := rng.randf_range(0.0, TAU)
		berry.position = Vector3(cos(a) * 0.4, 0.55 + rng.randf_range(-0.1, 0.2), sin(a) * 0.4)
		_bush.add_child(berry)

	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.6
	col.shape = shape
	col.position.y = 0.5
	add_child(col)

func interact(_player: Node) -> void:
	if _depleted:
		return
	Game.add_item("berry", 1)
	Game.toast("+1 ягоды")
	_deplete()

func _deplete() -> void:
	_depleted = true
	prompt_text = ""
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	var t := create_tween()
	t.tween_property(_bush, "scale", Vector3(0.3, 0.3, 0.3), 0.2)
	await get_tree().create_timer(45.0).timeout
	if not is_inside_tree():
		return
	_bush.scale = Vector3.ONE
	_depleted = false
	prompt_text = "Собрать ягоды"
	set_deferred("collision_layer", 1)
	set_deferred("collision_mask", 1)
