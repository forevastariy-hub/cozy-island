extends MultiMeshInstance3D

const GrassShader = preload("res://scripts/grass.gdshader")
const WATER_LEVEL := -2.0

var terrain: Node3D

func build(t: Node3D) -> void:
	terrain = t
	var rng := RandomNumberGenerator.new()
	rng.seed = 1357911

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _make_blade()

	var xforms: Array[Transform3D] = []
	var colors: Array[Color] = []

	# Grass shades for tuft base colors
	var palettes: Array[Color] = [
		Color(0.16, 0.22, 0.09),  # dark green
		Color(0.22, 0.30, 0.12),  # natural green
		Color(0.32, 0.40, 0.16),  # light green
		Color(0.26, 0.28, 0.14),  # olive
		Color(0.34, 0.32, 0.16),  # yellow-green
	]

	var attempt_count := 2200
	for _i in range(attempt_count):
		var ang := rng.randf_range(0.0, TAU)
		var rad := 5.0 + sqrt(rng.randf()) * 470.0
		var x := cos(ang) * rad
		var z := sin(ang) * rad
		var h: float = terrain.get_height(x, z)
		if h < WATER_LEVEL + 0.45:
			continue
		if terrain.has_method("is_water") and terrain.is_water(x, z):
			continue
		if 1.0 - terrain.get_normal(x, z).y > 0.42:
			continue
		var zone: Vector4 = terrain.get_zone(x, z)
		if zone.x > 0.28 or zone.z > 0.55:
			continue
		# Density: thinner on hills, thicker in flats
		var slope: float = 1.0 - terrain.get_normal(x, z).y
		if rng.randf() < slope * 0.6:
			continue

		# Tuft of 3-7 blades
		var blade_count := rng.randi_range(3, 7)
		var tuft_spread := rng.randf_range(0.12, 0.45)
		var palette := palettes[rng.randi_range(0, palettes.size() - 1)]
		var hue_shift := rng.randf_range(-0.15, 0.15)

		for b in range(blade_count):
			var bx := x + rng.randf_range(-tuft_spread, tuft_spread)
			var bz := z + rng.randf_range(-tuft_spread, tuft_spread)
			var bh: float = terrain.get_height(bx, bz)
			if bh < WATER_LEVEL + 0.45:
				continue
			if terrain.has_method("is_water") and terrain.is_water(bx, bz):
				continue
			if 1.0 - terrain.get_normal(bx, bz).y > 0.48:
				continue

			# Height categories
			var height_cat := rng.randf()
			var blade_h: float
			if height_cat < 0.30:
				blade_h = rng.randf_range(0.05, 0.12)   # low
			elif height_cat < 0.72:
				blade_h = rng.randf_range(0.15, 0.30)   # normal
			else:
				blade_h = rng.randf_range(0.35, 0.60)   # high

			# Near water -> taller vegetation
			var dist_to_water := absf(bh - WATER_LEVEL)
			if dist_to_water < 1.5:
				blade_h = lerpf(blade_h, rng.randf_range(0.45, 0.75), 0.6)

			var s := rng.randf_range(0.5, 1.05)
			var lean := rng.randf_range(0.0, TAU)
			var lean_amt := rng.randf_range(0.0, 0.18)
			var basis := Basis(Vector3.UP, lean).scaled(Vector3(s, 1.0, s))
			var pos := Vector3(bx, bh, bz)
			pos += Vector3(cos(lean) * lean_amt, 0.0, sin(lean) * lean_amt)
			xforms.append(Transform3D(basis, pos))

			# Per-blade color variation around tuft base
			var c := Color(
				clampf(palette.r + rng.randf_range(-0.12, 0.12) + hue_shift, 0.0, 1.0),
				clampf(palette.g + rng.randf_range(-0.12, 0.12) + hue_shift, 0.0, 1.0),
				clampf(palette.b + rng.randf_range(-0.10, 0.10), 0.0, 1.0),
				1.0)
			colors.append(c)

	mm.instance_count = xforms.size()
	for i in range(xforms.size()):
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, colors[i])
	multimesh = mm

	var mat := ShaderMaterial.new()
	mat.shader = GrassShader
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _make_blade() -> ArrayMesh:
	var verts := PackedVector3Array([
		# front face (pointed blade)
		Vector3(-0.10, 0.0, 0.0),
		Vector3(0.10, 0.0, 0.0),
		Vector3(0.0, 1.0, 0.04),
		# back face
		Vector3(0.10, 0.0, 0.0),
		Vector3(-0.10, 0.0, 0.0),
		Vector3(0.0, 1.0, -0.04),
	])
	var norms := PackedVector3Array([
		Vector3(0.0, 0.2, 1.0),
		Vector3(0.0, 0.2, 1.0),
		Vector3(0.0, 0.2, 1.0),
		Vector3(0.0, 0.2, -1.0),
		Vector3(0.0, 0.2, -1.0),
		Vector3(0.0, 0.2, -1.0),
	])
	var indices := PackedInt32Array([0, 1, 2, 3, 4, 5])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
