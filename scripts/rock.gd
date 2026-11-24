extends "res://scripts/interactable.gd"

var rng := RandomNumberGenerator.new()
var hits := 3
var max_hits := 3
var _depleted := false
var _tween: Tween
var _kind := 0

func _ready() -> void:
	prompt_text = "Собрать камни"
	_build()

func _build() -> void:
	_kind = rng.randi_range(0, 3)

	var root := Node3D.new()
	add_child(root)

	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.5, 0.48, 0.44)
	base_mat.roughness = 1.0

	if _kind == 0:
		# Small rounded pebble
		var rock := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 0.45
		sph.height = 0.7
		sph.radial_segments = 6
		sph.rings = 3
		rock.mesh = sph
		rock.material_override = base_mat
		rock.position.y = 0.3
		rock.rotation = Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(0.0, TAU), rng.randf_range(-0.4, 0.4))
		root.add_child(rock)
		var s := rng.randf_range(0.7, 1.0)
		root.scale = Vector3(s, rng.randf_range(0.55, 0.85), s)

		var col := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = 0.4
		col.shape = shape
		col.position.y = 0.3
		add_child(col)

	elif _kind == 1:
		# Large boulder (deformed sphere)
		var rock := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 1.1
		sph.height = 1.5
		sph.radial_segments = 8
		sph.rings = 4
		rock.mesh = sph
		rock.material_override = base_mat
		rock.position.y = 0.75
		rock.rotation = Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(0.0, TAU), rng.randf_range(-0.5, 0.5))
		root.add_child(rock)
		var sx := rng.randf_range(0.9, 1.4)
		var sy := rng.randf_range(0.7, 1.1)
		var sz := rng.randf_range(0.9, 1.4)
		root.scale = Vector3(sx, sy, sz)

		# smaller stones around it
		var pebble_mat := StandardMaterial3D.new()
		pebble_mat.albedo_color = Color(0.62, 0.59, 0.54)
		pebble_mat.roughness = 1.0
		for _i in range(rng.randi_range(2, 5)):
			var c := MeshInstance3D.new()
			var cs := SphereMesh.new()
			cs.radius = rng.randf_range(0.1, 0.22)
			cs.height = cs.radius * 1.3
			cs.radial_segments = 5
			cs.rings = 3
			c.mesh = cs
			c.material_override = pebble_mat
			var a := rng.randf_range(0.0, TAU)
			c.position = Vector3(cos(a) * rng.randf_range(0.5, 1.1), rng.randf_range(0.7, 1.3), sin(a) * rng.randf_range(0.5, 1.1))
			c.rotation = Vector3(rng.randf_range(-0.5, 0.5), a, rng.randf_range(-0.5, 0.5))
			root.add_child(c)

		var col := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = 0.95
		col.shape = shape
		col.position.y = 0.75
		add_child(col)

	elif _kind == 2:
		# Flat stone slab
		var rock := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(rng.randf_range(1.2, 2.2), 0.18, rng.randf_range(0.9, 1.7))
		rock.mesh = box
		rock.material_override = base_mat
		rock.position.y = 0.1
		rock.rotation = Vector3(rng.randf_range(-0.2, 0.2), rng.randf_range(0.0, TAU), rng.randf_range(-0.2, 0.2))
		root.add_child(rock)

		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = box.size
		col.shape = shape
		col.position.y = 0.1
		add_child(col)

	else:
		# Irregular rock cluster
		var mats: Array = []
		var m1 := StandardMaterial3D.new()
		m1.albedo_color = Color(0.5, 0.48, 0.44)
		m1.roughness = 1.0
		var m2 := StandardMaterial3D.new()
		m2.albedo_color = Color(0.58, 0.55, 0.5)
		m2.roughness = 1.0
		mats = [m1, m2]
		var cluster := Node3D.new()
		for _i in range(rng.randi_range(3, 6)):
			var piece := MeshInstance3D.new()
			var ps := SphereMesh.new()
			var pr := rng.randf_range(0.25, 0.55)
			ps.radius = pr
			ps.height = pr * rng.randf_range(0.8, 1.4)
			ps.radial_segments = 5
			ps.rings = 3
			piece.mesh = ps
			piece.material_override = mats[rng.randi_range(0, 1)]
			piece.position = Vector3(
				rng.randf_range(-0.6, 0.6),
				rng.randf_range(0.1, 0.5),
				rng.randf_range(-0.6, 0.6))
			piece.rotation = Vector3(
				rng.randf_range(-0.6, 0.6),
				rng.randf_range(0.0, TAU),
				rng.randf_range(-0.6, 0.6))
			cluster.add_child(piece)
		root.add_child(cluster)

		var col := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = 1.0
		col.shape = shape
		col.position.y = 0.45
		add_child(col)

	root.rotation.y = rng.randf_range(0.0, TAU)
	scale = Vector3.ONE

	# Moss on some rocks
	if rng.randf() < 0.4:
		var moss_mat := StandardMaterial3D.new()
		moss_mat.albedo_color = Color(0.32, 0.44, 0.23)
		moss_mat.roughness = 1.0
		for _i in range(rng.randi_range(1, 3)):
			var moss := MeshInstance3D.new()
			var ms := SphereMesh.new()
			ms.radius = rng.randf_range(0.08, 0.18)
			ms.height = ms.radius * 1.2
			ms.radial_segments = 5
			ms.rings = 3
			moss.mesh = ms
			moss.material_override = moss_mat
			moss.position = Vector3(rng.randf_range(-0.6, 0.6), 0.6 + rng.randf_range(0.0, 0.4), rng.randf_range(-0.6, 0.6))
			moss.rotation = Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(0.0, TAU), rng.randf_range(-0.4, 0.4))
			add_child(moss)

func interact(_player: Node) -> void:
	if _depleted:
		return
	Game.add_item("stone", 1)
	Game.toast("+1 камень")
	hits -= 1
	if _tween != null and _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "rotation:z", 0.05, 0.05)
	_tween.tween_property(self, "rotation:z", -0.05, 0.08)
	_tween.tween_property(self, "rotation:z", 0.0, 0.08)
	if hits <= 0:
		_deplete()

func _deplete() -> void:
	_depleted = true
	prompt_text = ""
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	var t := create_tween()
	t.tween_property(self, "scale", Vector3(0.02, 0.02, 0.02), 0.35)
	await get_tree().create_timer(90.0).timeout
	if not is_inside_tree():
		return
	scale = Vector3.ONE
	hits = max_hits
	_depleted = false
	prompt_text = "Собрать камни"
	set_deferred("collision_layer", 1)
	set_deferred("collision_mask", 1)
