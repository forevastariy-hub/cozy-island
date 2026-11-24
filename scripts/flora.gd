extends Node3D

const FlowerColors = [
	Color(0.9, 0.9, 0.95),   # white
	Color(0.95, 0.85, 0.2),  # yellow
	Color(0.5, 0.7, 1.0),    # blue
	Color(0.8, 0.5, 0.9),    # purple
]

var terrain: Node3D

func scatter(rng: RandomNumberGenerator, count: int, min_h: float, max_h: float, avoid_radius: float = 0.0, flower_chance: float = 0.75) -> void:
	var root := Node3D.new()
	root.name = "Flora"
	add_child(root)

	var flower_mat := StandardMaterial3D.new()
	flower_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flower_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flower_mat.albedo_color = Color(1, 1, 1)
	flower_mat.render_backface_cull = false

	var mushroom_cap_mat := StandardMaterial3D.new()
	mushroom_cap_mat.albedo_color = Color(0.5, 0.2, 0.2)
	mushroom_cap_mat.roughness = 1.0
	var mushroom_stem_mat := StandardMaterial3D.new()
	mushroom_stem_mat.albedo_color = Color(0.9, 0.85, 0.8)
	mushroom_stem_mat.roughness = 1.0

	var placed := 0
	var tries := count * 4
	for _i in range(tries):
		if placed >= count:
			break
		var x := rng.randf_range(-460.0, 460.0)
		var z := rng.randf_range(-460.0, 460.0)
		if Vector2(x, z).length() < avoid_radius:
			continue
		var h: float = terrain.get_height(x, z)
		if h < min_h or h > max_h:
			continue
		if terrain.has_method("is_water") and terrain.is_water(x, z):
			continue
		if 1.0 - terrain.get_normal(x, z).y > 0.42:
			continue
		var zone: Vector4 = terrain.get_zone(x, z)
		if zone.x > 0.3 or zone.z > 0.55:
			continue

		var is_flower := rng.randf() < flower_chance
		var obj := MeshInstance3D.new()
		obj.position = Vector3(x, h, z)
		obj.rotation.y = rng.randf_range(0.0, TAU)

		if is_flower:
			_build_flower(obj, rng, flower_mat)
		else:
			_build_mushroom(obj, rng, mushroom_cap_mat, mushroom_stem_mat)

		root.add_child(obj)
		placed += 1

func _build_flower(obj: MeshInstance3D, rng: RandomNumberGenerator, mat: StandardMaterial3D) -> void:
	var col: Color = FlowerColors[rng.randi_range(0, FlowerColors.size() - 1)]
	mat.albedo_color = col
	var size := rng.randf_range(0.06, 0.13)
	# cross-shaped flower: two quads crossing
	var q1 := QuadMesh.new()
	q1.size = Vector2(size, size)
	var p1 := MeshInstance3D.new()
	p1.mesh = q1
	p1.material_override = mat.duplicate()
	obj.add_child(p1)
	var q2 := QuadMesh.new()
	q2.size = Vector2(size, size)
	var p2 := MeshInstance3D.new()
	p2.mesh = q2
	p2.material_override = mat.duplicate()
	p2.rotation.z = PI * 0.5
	obj.add_child(p2)
	# center dot
	var center := MeshInstance3D.new()
	var c := SphereMesh.new()
	c.radius = size * 0.25
	c.height = size * 0.25
	c.radial_segments = 5
	center.mesh = c
	center.material_override = mat.duplicate()
	center.material_override.albedo_color = Color(0.9, 0.8, 0.1)
	center.position.y = 0.0
	obj.add_child(center)
	obj.scale = Vector3.ONE * rng.randf_range(0.8, 1.2)

func _build_mushroom(obj: MeshInstance3D, rng: RandomNumberGenerator, cap_mat: StandardMaterial3D, stem_mat: StandardMaterial3D) -> void:
	var stem_h := rng.randf_range(0.18, 0.4)
	var cap_r := rng.randf_range(0.12, 0.25)

	var stem := MeshInstance3D.new()
	var sc := CylinderMesh.new()
	sc.top_radius = cap_r * 0.25
	sc.bottom_radius = cap_r * 0.3
	sc.height = stem_h
	sc.radial_segments = 6
	stem.mesh = sc
	stem.material_override = stem_mat.duplicate()
	stem.position.y = stem_h * 0.5
	obj.add_child(stem)

	var cap := MeshInstance3D.new()
	var cp: CylinderMesh = CylinderMesh.new()
	cp.top_radius = 0.0
	cp.bottom_radius = cap_r
	cp.height = stem_h * 0.5
	cp.radial_segments = 8
	cap.mesh = cp
	cap.material_override = cap_mat.duplicate()
	cap.position.y = stem_h + cap_r * 0.2
	obj.add_child(cap)

	var spot := rng.randf()
	if spot > 0.7:
		var smat := StandardMaterial3D.new()
		smat.albedo_color = Color(1.0, 1.0, 1.0)
		smat.roughness = 1.0
		var spot_mesh := MeshInstance3D.new()
		var ss := SphereMesh.new()
		ss.radius = cap_r * 0.18
		ss.height = cap_r * 0.18
		ss.radial_segments = 5
		spot_mesh.mesh = ss
		spot_mesh.material_override = smat
		spot_mesh.position = Vector3(rng.randf_range(-cap_r * 0.3, cap_r * 0.3), stem_h + cap_r * 0.35, rng.randf_range(-cap_r * 0.3, cap_r * 0.3))
		obj.add_child(spot_mesh)

	obj.scale = Vector3.ONE * rng.randf_range(0.85, 1.15)
	obj.rotation.x = rng.randf_range(-0.1, 0.1)
