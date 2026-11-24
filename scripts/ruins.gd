extends Node3D

const RestSpotScript = preload("res://scripts/rest_spot.gd")

var terrain: Node3D
var rng: RandomNumberGenerator
var _lights: Array[OmniLight3D] = []
var _swings: Array[Node3D] = []
var _t := 0.0

var stone: StandardMaterial3D
var dark_stone: StandardMaterial3D
var moss: StandardMaterial3D
var wood: StandardMaterial3D
var wood_light: StandardMaterial3D
var cloth: StandardMaterial3D
var pillow: StandardMaterial3D
var rope: StandardMaterial3D
var lantern_glass: StandardMaterial3D

func build(t: Node3D, r: RandomNumberGenerator, center: Vector3) -> void:
	terrain = t
	rng = r
	_make_materials()

	for _i in range(12):
		var p = _place_on_land(6.0, 52.0, center)
		if p != null:
			_pillar(p)
	for _i in range(6):
		var p = _place_on_land(8.0, 46.0, center)
		if p != null:
			_wall(p)
	for _i in range(10):
		var p = _place_on_land(5.0, 40.0, center)
		if p != null:
			_rubble(p)

	var hp = _place_on_land(12.0, 40.0, center)
	if hp != null:
		_hammock(hp)
	var pp = _place_shore(center)
	if pp != null:
		_pier(pp)
	var vp = _place_high(center)
	if vp != null:
		_viewpoint(vp)

func _process(delta: float) -> void:
	_t += delta
	for i in range(_lights.size()):
		var l := _lights[i]
		if is_instance_valid(l):
			var base: float = float(l.get_meta("base", 1.2))
			l.light_energy = base * (0.92 + sin(_t * 11.0 + float(i)) * 0.06)
	for i in range(_swings.size()):
		var s := _swings[i]
		if is_instance_valid(s):
			s.rotation.z = sin(_t * 0.8 + float(i) * 1.7) * 0.025

func _make_materials() -> void:
	stone = StandardMaterial3D.new()
	stone.albedo_color = Color(0.55, 0.52, 0.46)
	stone.roughness = 0.95

	dark_stone = StandardMaterial3D.new()
	dark_stone.albedo_color = Color(0.4, 0.38, 0.34)
	dark_stone.roughness = 1.0

	moss = StandardMaterial3D.new()
	moss.albedo_color = Color(0.33, 0.45, 0.24)
	moss.roughness = 1.0

	wood = StandardMaterial3D.new()
	wood.albedo_color = Color(0.42, 0.28, 0.16)
	wood.roughness = 0.95

	wood_light = StandardMaterial3D.new()
	wood_light.albedo_color = Color(0.55, 0.38, 0.22)
	wood_light.roughness = 0.9

	cloth = StandardMaterial3D.new()
	cloth.albedo_color = Color(0.78, 0.66, 0.45)
	cloth.roughness = 1.0

	pillow = StandardMaterial3D.new()
	pillow.albedo_color = Color(0.9, 0.85, 0.75)
	pillow.roughness = 1.0

	rope = StandardMaterial3D.new()
	rope.albedo_color = Color(0.62, 0.52, 0.34)
	rope.roughness = 1.0

	lantern_glass = StandardMaterial3D.new()
	lantern_glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lantern_glass.albedo_color = Color(0.35, 0.25, 0.1)
	lantern_glass.emission_enabled = true
	lantern_glass.emission = Color(1.0, 0.72, 0.32)
	lantern_glass.emission_energy_multiplier = 2.2
	lantern_glass.disable_fog = true

func _place_on_land(min_radius: float, max_radius: float, center: Vector3) -> Variant:
	for _i in range(50):
		var ang := rng.randf_range(0.0, TAU)
		var rad := rng.randf_range(min_radius, max_radius)
		var x := center.x + cos(ang) * rad
		var z := center.z + sin(ang) * rad
		if absf(x) > 450.0 or absf(z) > 450.0:
			continue
		var h: float = terrain.get_height(x, z)
		if h < -0.9 or h > 32.0:
			continue
		if 1.0 - terrain.get_normal(x, z).y > 0.36:
			continue
		return Vector3(x, h, z)
	return null

func _place_shore(center: Vector3) -> Variant:
	for _i in range(400):
		var ang := rng.randf_range(0.0, TAU)
		var rad := rng.randf_range(16.0, 56.0)
		var x := center.x + cos(ang) * rad
		var z := center.z + sin(ang) * rad
		if absf(x) > 440.0 or absf(z) > 440.0:
			continue
		var h: float = terrain.get_height(x, z)
		if h < -1.5 or h > -0.15:
			continue
		var out := Vector3(x, 0.0, z)
		if out.length() < 0.1:
			continue
		out = out.normalized()
		var h2: float = terrain.get_height(x + out.x * 8.0, z + out.z * 8.0)
		if h2 > -1.9:
			continue
		if 1.0 - terrain.get_normal(x, z).y > 0.4:
			continue
		return Vector3(x, h, z)
	return null

func _place_high(center: Vector3) -> Variant:
	for _i in range(300):
		var ang := rng.randf_range(0.0, TAU)
		var rad := rng.randf_range(16.0, 52.0)
		var x := center.x + cos(ang) * rad
		var z := center.z + sin(ang) * rad
		if absf(x) > 440.0 or absf(z) > 440.0:
			continue
		var h: float = terrain.get_height(x, z)
		if h < 18.0 or h > 32.0:
			continue
		if 1.0 - terrain.get_normal(x, z).y > 0.25:
			continue
		return Vector3(x, h, z)
	return null

func _mi(mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	return m

func _box(size: Vector3, mat: Material, pos: Vector3) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _mi(b, mat, pos)

func _cyl(top: float, bottom: float, height: float, segments: int) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = height
	c.radial_segments = segments
	return c

func _rod(a: Vector3, b: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var dir := b - a
	var length := dir.length()
	if length < 0.001:
		return _mi(_cyl(radius, radius, 0.01, 5), mat, a)
	var mid := (a + b) * 0.5
	var up := Vector3.UP
	if absf(dir.normalized().dot(up)) > 0.99:
		up = Vector3.RIGHT
	var x_axis := up.cross(dir).normalized()
	var z_axis := x_axis.cross(dir).normalized()
	var basis := Basis(x_axis, dir.normalized(), z_axis)
	var mi := _mi(_cyl(radius, radius, length, 5), mat, Vector3.ZERO)
	mi.transform = Transform3D(basis, mid)
	return mi

func _collide(root: Node3D, shape: Shape3D, y: float) -> void:
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = y
	body.add_child(col)
	root.add_child(body)

func _pillar(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = rng.randf_range(0.0, TAU)
	var h := rng.randf_range(2.4, 5.6)
	var broken := rng.randf() < 0.45

	root.add_child(_box(Vector3(1.0, 0.34, 1.0), dark_stone, Vector3(0, 0.17, 0)))
	root.add_child(_mi(_cyl(0.34, 0.43, h, 8), stone, Vector3(0, 0.34 + h * 0.5, 0)))
	if not broken:
		root.add_child(_box(Vector3(0.92, 0.28, 0.92), stone, Vector3(0, 0.34 + h + 0.14, 0)))
	if rng.randf() < 0.75:
		root.add_child(_box(Vector3(0.58, 0.05, 0.58), moss, Vector3(0, 0.36, 0)))
	root.rotation.z = rng.randf_range(-0.07, 0.07)

	var shape := CylinderShape3D.new()
	shape.radius = 0.46
	shape.height = h
	_collide(root, shape, 0.34 + h * 0.5)
	add_child(root)

func _wall(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = rng.randf_range(0.0, TAU)
	var length := rng.randf_range(2.2, 3.4)
	var max_h := rng.randf_range(0.9, 1.9)

	root.add_child(_box(Vector3(length, 0.25, 0.7), dark_stone, Vector3(0, 0.12, 0)))
	var n := int(length / 0.55)
	for i in range(n):
		var h := rng.randf_range(0.4, max_h)
		var x := -length * 0.5 + 0.3 + float(i) * 0.55
		var block := _box(Vector3(0.5, h, 0.55), stone, Vector3(x, 0.25 + h * 0.5, 0))
		block.rotation.y = rng.randf_range(-0.08, 0.08)
		root.add_child(block)
		if rng.randf() < 0.3:
			root.add_child(_box(Vector3(0.4, 0.04, 0.45), moss, Vector3(x, 0.27 + h, 0)))

	var shape := BoxShape3D.new()
	shape.size = Vector3(length, 1.8, 0.75)
	_collide(root, shape, 0.9)
	add_child(root)

func _rubble(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = rng.randf_range(0.0, TAU)
	for _i in range(rng.randi_range(5, 9)):
		var s := rng.randf_range(0.2, 0.55)
		var mat: Material = moss if rng.randf() < 0.22 else stone
		var block := _box(Vector3(s, s * 0.6, s * 0.8), mat, Vector3(
			rng.randf_range(-0.9, 0.9), s * 0.3, rng.randf_range(-0.9, 0.9)))
		block.rotation = Vector3(
			rng.randf_range(-0.2, 0.2), rng.randf_range(0.0, TAU), rng.randf_range(-0.2, 0.2))
		root.add_child(block)
	if rng.randf() < 0.6:
		var fallen := _mi(_cyl(0.24, 0.27, 1.2, 7), stone, Vector3(
			rng.randf_range(-0.4, 0.4), 0.27, rng.randf_range(-0.4, 0.4)))
		fallen.rotation.z = PI * 0.5
		fallen.rotation.y = rng.randf_range(0.0, TAU)
		root.add_child(fallen)
	add_child(root)

func _hammock(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = rng.randf_range(0.0, TAU)
	root.add_to_group("path_poi")

	for side in [-1.0, 1.0]:
		var sx := float(side) * 1.5
		root.add_child(_box(Vector3(0.35, 0.1, 0.35), dark_stone, Vector3(sx, 0.05, 0)))
		root.add_child(_mi(_cyl(0.07, 0.09, 1.9, 6), wood, Vector3(sx, 0.95, 0)))
		var shape := CylinderShape3D.new()
		shape.radius = 0.12
		shape.height = 1.9
		_collide(root, shape, 0.95)

	var cloth_root := Node3D.new()
	cloth_root.position = Vector3(0, 0.9, 0)
	root.add_child(cloth_root)
	var segs := 5
	for i in range(segs):
		var t := float(i) / float(segs - 1)
		var x := lerpf(-1.1, 1.1, t)
		var y := -sin(t * PI) * 0.28
		var seg := _box(Vector3(0.55, 0.06, 0.9), cloth, Vector3(x, y, 0))
		seg.rotation.z = -cos(t * PI) * 0.12
		cloth_root.add_child(seg)
	cloth_root.add_child(_box(Vector3(0.45, 0.12, 0.55), pillow, Vector3(-0.85, 0.02, 0)))

	root.add_child(_rod(Vector3(-1.5, 1.85, 0), Vector3(-1.1, 0.9, 0), 0.018, rope))
	root.add_child(_rod(Vector3(1.5, 1.85, 0), Vector3(1.1, 0.9, 0), 0.018, rope))
	_swings.append(cloth_root)
	add_child(root)

func _pier(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	root.add_to_group("path_poi")
	var out := Vector3(pos.x, 0.0, pos.z)
	if out.length() < 0.1:
		out = Vector3.FORWARD
	out = out.normalized()
	root.rotation.y = atan2(out.x, out.z)

	for i in range(8):
		var z := 0.4 + float(i) * 0.8
		var mat: Material = wood if i % 2 == 0 else wood_light
		root.add_child(_box(Vector3(2.4, 0.14, 0.72), mat, Vector3(0, -0.07, z)))

	for side in [-1.0, 1.0]:
		var sx := float(side) * 1.1
		for z in [0.5, 2.5, 4.5, 6.3]:
			var zz := float(z)
			root.add_child(_mi(_cyl(0.08, 0.1, 2.6, 6), wood, Vector3(sx, -1.3, zz)))
		root.add_child(_box(Vector3(0.08, 0.08, 6.0), wood, Vector3(sx, 0.88, 3.2)))
		for z in [0.6, 2.2, 3.8, 5.4]:
			var zz := float(z)
			root.add_child(_box(Vector3(0.08, 0.9, 0.08), wood, Vector3(sx, 0.45, zz)))

	root.add_child(_mi(_cyl(0.06, 0.08, 1.6, 6), wood, Vector3(1.0, 0.8, 5.8)))
	root.add_child(_box(Vector3(0.22, 0.28, 0.22), lantern_glass, Vector3(1.0, 1.7, 5.8)))
	root.add_child(_box(Vector3(0.3, 0.08, 0.3), dark_stone, Vector3(1.0, 1.86, 5.8)))
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.75, 0.4)
	lamp.light_energy = 1.1
	lamp.omni_range = 5.0
	lamp.position = Vector3(1.0, 1.7, 5.8)
	lamp.set_meta("base", 1.1)
	root.add_child(lamp)
	_lights.append(lamp)

	var shape := BoxShape3D.new()
	shape.size = Vector3(2.5, 0.14, 6.4)
	_collide(root, shape, -0.07)
	add_child(root)

func _viewpoint(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	root.add_to_group("path_poi")
	var out := Vector3(pos.x, 0.0, pos.z)
	if out.length() < 0.1:
		out = Vector3.FORWARD
	out = out.normalized()
	root.rotation.y = atan2(-out.x, -out.z)

	for ix in range(3):
		for iz in range(3):
			var mat: Material = stone if (ix + iz) % 2 == 0 else dark_stone
			var tile := _box(Vector3(1.0, 0.1, 1.0), mat, Vector3(
				(float(ix) - 1.0) * 1.05, 0.05, (float(iz) - 1.0) * 1.05))
			tile.rotation.y = rng.randf_range(-0.03, 0.03)
			root.add_child(tile)

	var bench := Node3D.new()
	bench.position = Vector3(0, 0.1, -0.6)
	root.add_child(bench)
	bench.add_child(_box(Vector3(2.2, 0.12, 0.55), wood, Vector3(0, 0.5, 0)))
	bench.add_child(_box(Vector3(2.2, 0.5, 0.1), wood, Vector3(0, 0.8, 0.25)))
	for side in [-1.0, 1.0]:
		for z in [-0.18, 0.18]:
			bench.add_child(_box(Vector3(0.12, 0.5, 0.12), wood, Vector3(
				float(side) * 0.9, 0.25, float(z))))
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.2, 0.6, 0.7)
	_collide(bench, shape, 0.35)

	var rest := RestSpotScript.new()
	rest.name = "BenchRest"
	rest.position = Vector3(0.0, 0.3, 0.0)
	bench.add_child(rest)

	root.add_child(_mi(_cyl(0.06, 0.08, 1.6, 6), wood, Vector3(-1.2, 0.8, 1.2)))
	root.add_child(_box(Vector3(0.22, 0.28, 0.22), lantern_glass, Vector3(-1.2, 1.7, 1.2)))
	root.add_child(_box(Vector3(0.3, 0.08, 0.3), dark_stone, Vector3(-1.2, 1.86, 1.2)))
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.75, 0.4)
	lamp.light_energy = 1.1
	lamp.omni_range = 5.0
	lamp.position = Vector3(-1.2, 1.7, 1.2)
	lamp.set_meta("base", 1.1)
	root.add_child(lamp)
	_lights.append(lamp)

	add_child(root)
