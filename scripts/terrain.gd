extends Node3D

const SIZE := 1000.0
const RES := 256
const WATER_LEVEL := -2.0
const MAX_HEIGHT := 88.0
const MASK_RES := 256
const TerrainShader = preload("res://scripts/terrain.gdshader")
const WaterShader = preload("res://scripts/water.gdshader")
const GrassFieldScript = preload("res://scripts/grass_field.gd")

# Zone type constants
const ZONE_GENERAL := 0
const ZONE_PINE_FOREST := 1
const ZONE_DECIDUOUS_FOREST := 2
const ZONE_FIELDS := 3
const ZONE_LAKE := 4
const ZONE_SWAMP := 5
const ZONE_MOUNTAIN := 6
const ZONE_STONE_TOWER := 7
const ZONE_RUINS := 8
const ZONE_CAMP := 9
const ZONE_RADIO_TOWER := 10

# Zone definitions: name, center, radius, type
var _zones: Array = []

# Core locations (world XZ). North is -Z, south is +Z, east is +X, west is -X.
const CAMP_C := Vector2(0.0, 70.0)
const LAKE_C := Vector2(10.0, -150.0)
const LAKE_R := Vector2(82.0, 60.0)
const SWAMP_C := Vector2(-250.0, 250.0)
const SWAMP_R := Vector2(115.0, 90.0)
const FIELDS_C := Vector2(290.0, 55.0)
const FIELDS_R := Vector2(135.0, 110.0)

# Main river: from the south edge of the lake down to the south coast.
const RIVER_POINTS := [
	Vector2(15.0, -92.0),
	Vector2(40.0, -45.0),
	Vector2(66.0, 5.0),
	Vector2(78.0, 60.0),
	Vector2(70.0, 120.0),
	Vector2(88.0, 180.0),
	Vector2(84.0, 240.0),
	Vector2(104.0, 300.0),
	Vector2(122.0, 360.0),
	Vector2(138.0, 420.0),
]
const RIVER_BOUNDS := Rect2(-20.0, -120.0, 200.0, 560.0)

# Small streams in the swamp (south-west) and the deciduous forest (south-east).
const SWAMP_STREAM := [
	Vector2(-235.0, 235.0),
	Vector2(-278.0, 268.0),
	Vector2(-318.0, 305.0),
	Vector2(-342.0, 338.0),
]
const SWAMP_STREAM_BOUNDS := Rect2(-370.0, 210.0, 170.0, 160.0)

const DECID_STREAM := [
	Vector2(150.0, 290.0),
	Vector2(175.0, 332.0),
	Vector2(168.0, 382.0),
	Vector2(188.0, 424.0),
]
const DECID_STREAM_BOUNDS := Rect2(120.0, 260.0, 100.0, 190.0)

var noise: FastNoiseLite
var _n := RES + 1
var _step := SIZE / float(RES)
var _mask_step := SIZE / float(MASK_RES)
var _path_segments: Array = []
var _mask_image: Image
var _mask_texture: ImageTexture
var _minimap_cache: ImageTexture
var _hgrid: PackedFloat32Array = PackedFloat32Array()
var _hgrid_n := RES + 1
var ground_material: ShaderMaterial
var water_material: ShaderMaterial
var grass: MultiMeshInstance3D

# Points of interest for road network (name -> position)
var pois: Dictionary = {}

func _ready() -> void:
	build()

func build() -> void:
	noise = FastNoiseLite.new()
	noise.seed = 424242
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.0085
	noise.fractal_octaves = 5
	noise.fractal_gain = 0.52
	_mask_image = Image.create(MASK_RES, MASK_RES, false, Image.FORMAT_RGBA8)
	_setup_zones()
	_build_height_grid()
	_rebuild_mask()
	_build_mesh()
	_build_water()

func _setup_zones() -> void:
	# Priority order: small point-of-interest zones first, big biomes last.
	_zones = [
		{"name": "camp", "center": CAMP_C, "radius": 34.0, "type": ZONE_CAMP},
		{"name": "ruins", "center": Vector2(-235.0, 20.0), "radius": 95.0, "type": ZONE_RUINS},
		{"name": "stone_tower", "center": Vector2(255.0, 15.0), "radius": 58.0, "type": ZONE_STONE_TOWER},
		{"name": "radio_tower", "center": Vector2(160.0, -215.0), "radius": 78.0, "type": ZONE_RADIO_TOWER},
		{"name": "mountain", "center": Vector2(0.0, -330.0), "radius": 150.0, "type": ZONE_MOUNTAIN},
		{"name": "lake", "center": LAKE_C, "radius": 105.0, "type": ZONE_LAKE},
		{"name": "swamp", "center": SWAMP_C, "radius": 125.0, "type": ZONE_SWAMP},
		{"name": "fields", "center": FIELDS_C, "radius": 135.0, "type": ZONE_FIELDS},
		{"name": "pine_forest", "center": Vector2(-160.0, -170.0), "radius": 195.0, "type": ZONE_PINE_FOREST},
		{"name": "deciduous_forest", "center": Vector2(120.0, 250.0), "radius": 195.0, "type": ZONE_DECIDUOUS_FOREST},
	]
	for z in _zones:
		pois[String(z["name"])] = z["center"]

# --- Height field -----------------------------------------------------------

func _island_dist(x: float, z: float) -> float:
	var half := SIZE * 0.5
	var nz := z / half
	var northness := clampf(-nz, 0.0, 1.0)
	var southness := clampf(nz, 0.0, 1.0)
	# Narrow north, wide centre, broad round south.
	var ax := 0.68 - 0.16 * northness + 0.12 * southness
	var az := 0.80 + 0.05 * southness
	var nx := x / (ax * half)
	var nzz := z / (az * half)
	var d := sqrt(nx * nx + nzz * nzz)
	var ang := atan2(nzz, nx)
	var wob := 1.0 + 0.08 * sin(ang * 3.0 + 0.7) + 0.05 * sin(ang * 5.0 + 2.1) + 0.035 * sin(ang * 7.0 + 4.3)
	return d / wob

func _build_height_grid() -> void:
	_hgrid.resize(_hgrid_n * _hgrid_n)
	for zi in range(_hgrid_n):
		var z := -SIZE * 0.5 + zi * _step
		for xi in range(_hgrid_n):
			var x := -SIZE * 0.5 + xi * _step
			_hgrid[zi * _hgrid_n + xi] = _height_raw(x, z)

func _height_raw(x: float, z: float) -> float:
	var d := _island_dist(x, z)
	var land := 1.0 - smoothstep(0.80, 1.02, d)

	var n1 := noise.get_noise_2d(x, z) * 0.5 + 0.5
	var n2 := noise.get_noise_2d(x * 2.3 + 100.0, z * 2.3 - 55.0) * 0.5 + 0.5
	var base := 4.5 + n1 * 10.0 + n2 * 3.0
	base += _gaussian(x, z, 0.0, 30.0, 250.0) * 2.5

	# A handful of broad, smooth hills (no jagged mountains).
	var hills := 0.0
	hills += _hill(x, z, 0.0, -330.0, 125.0, 60.0)     # north massif / lookout
	hills += _hill(x, z, 160.0, -220.0, 100.0, 30.0)   # north-east hills
	hills += _hill(x, z, 255.0, -10.0, 105.0, 38.0)    # east hills / stone tower
	hills += _hill(x, z, -235.0, 30.0, 105.0, 24.0)    # west rocky coast ridge
	hills += _hill(x, z, 120.0, 250.0, 130.0, 14.0)    # gentle south rise
	hills += _hill(x, z, -120.0, -40.0, 85.0, 8.0)     # central bump

	var h := base + hills

	# Flat clearings for the camp, the fields and the ruins plateau.
	var camp := _gaussian(x, z, CAMP_C.x, CAMP_C.y, 20.0)
	h = lerpf(h, 7.0, camp * 0.75)
	var fields := _ellipse_factor(x, z, FIELDS_C, FIELDS_R)
	h = lerpf(h, 8.0, fields * 0.85)
	var ruins := _gaussian(x, z, -235.0, 20.0, 45.0)
	h = lerpf(h, 20.0, ruins * 0.8)

	# Lake basin.
	var ld := _ellipse_norm(x, z, LAKE_C, LAKE_R)
	var lake := 1.0 - smoothstep(0.35, 1.0, ld)
	h = lerpf(h, -5.5, lake)

	# Main river carved into the terrain.
	if RIVER_BOUNDS.has_point(Vector2(x, z)):
		var rd := _polyline_distance(Vector2(x, z), RIVER_POINTS)
		var rw := 8.5 + 2.0 * sin(z * 0.02 + 1.0)
		var river := 1.0 - smoothstep(rw * 0.3, rw, rd)
		h = lerpf(h, -4.5, river)

	# Swamp stream.
	if SWAMP_STREAM_BOUNDS.has_point(Vector2(x, z)):
		var sd := _polyline_distance(Vector2(x, z), SWAMP_STREAM)
		var s := 1.0 - smoothstep(2.0, 5.5, sd)
		h = lerpf(h, -3.5, s * 0.8)

	# Deciduous forest stream.
	if DECID_STREAM_BOUNDS.has_point(Vector2(x, z)):
		var dd := _polyline_distance(Vector2(x, z), DECID_STREAM)
		var s2 := 1.0 - smoothstep(1.5, 4.5, dd)
		h = lerpf(h, -3.2, s2 * 0.75)

	# Low, marshy swamp.
	var swamp := _ellipse_factor(x, z, SWAMP_C, SWAMP_R)
	h = lerpf(h, minf(h, 1.4), swamp * 0.75)

	# Coast falloff goes last so the island melts into the ocean.
	return lerpf(-6.0, h, land)

func get_height(x: float, z: float) -> float:
	if _hgrid.is_empty():
		return _height_raw(x, z)
	var fx := (x + SIZE * 0.5) / _step
	var fz := (z + SIZE * 0.5) / _step
	fx = clampf(fx, 0.0, float(_hgrid_n - 1) - 0.0001)
	fz = clampf(fz, 0.0, float(_hgrid_n - 1) - 0.0001)
	var x0 := int(fx)
	var z0 := int(fz)
	var tx := fx - float(x0)
	var tz := fz - float(z0)
	var x1 := mini(x0 + 1, _hgrid_n - 1)
	var z1 := mini(z0 + 1, _hgrid_n - 1)
	var h00 := _hgrid[z0 * _hgrid_n + x0]
	var h10 := _hgrid[z0 * _hgrid_n + x1]
	var h01 := _hgrid[z1 * _hgrid_n + x0]
	var h11 := _hgrid[z1 * _hgrid_n + x1]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)

func get_normal(x: float, z: float) -> Vector3:
	var e := 2.5
	var hx := get_height(x + e, z) - get_height(x - e, z)
	var hz := get_height(x, z + e) - get_height(x, z - e)
	return Vector3(-hx, 2.0 * e, -hz).normalized()

func get_zone_type(x: float, z: float) -> int:
	var h := get_height(x, z)
	if h < WATER_LEVEL + 0.25:
		return ZONE_LAKE
	var swamp := _ellipse_factor(x, z, SWAMP_C, SWAMP_R)
	if swamp > 0.5 and h < 3.0:
		return ZONE_SWAMP
	for zdef in _zones:
		var d := Vector2(x, z).distance_to(zdef["center"])
		if d < zdef["radius"]:
			return zdef["type"]
	return ZONE_GENERAL

func get_zone(x: float, z: float) -> Vector4:
	var h := get_height(x, z)
	var slope := 1.0 - get_normal(x, z).y
	var path := _path_factor(x, z)

	var swamp := _ellipse_factor(x, z, SWAMP_C, SWAMP_R)
	swamp *= 1.0 - smoothstep(2.0, 8.0, h)

	var rock := smoothstep(52.0, 80.0, h)
	rock = maxf(rock, smoothstep(0.55, 0.85, slope))
	rock = maxf(rock, _gaussian(x, z, 255.0, -10.0, 40.0) * 0.85)
	rock = maxf(rock, _gaussian(x, z, -235.0, 30.0, 45.0) * 0.8)
	rock = maxf(rock, _gaussian(x, z, 0.0, -330.0, 60.0) * 0.30)
	rock = clampf(rock, 0.0, 1.0)

	var shore := 1.0 - smoothstep(0.0, 1.6, absf(h - (WATER_LEVEL + 0.4)))
	shore *= 1.0 - rock * 0.6
	shore *= 1.0 - swamp * 0.4
	# Broad sandy south coast.
	shore = maxf(shore, _gaussian(x, z, 80.0, 360.0, 160.0) * 0.45)

	return Vector4(clampf(path, 0.0, 1.0), clampf(swamp, 0.0, 1.0), rock, clampf(shore, 0.0, 1.0))

# --- Roads ------------------------------------------------------------------

func build_paths(points: Array) -> void:
	_path_segments.clear()
	if points.is_empty():
		return

	var astar := AStarGrid2D.new()
	astar.region = Rect2i(0, 0, RES, RES)
	astar.cell_size = Vector2(_step, _step)
	astar.offset = Vector2(-SIZE * 0.5, -SIZE * 0.5)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()

	for zi in range(RES):
		for xi in range(RES):
			var wx := -SIZE * 0.5 + (float(xi) + 0.5) * _step
			var wz := -SIZE * 0.5 + (float(zi) + 0.5) * _step
			var h := get_height(wx, wz)
			var slope := 1.0 - get_normal(wx, wz).y
			astar.set_point_solid(Vector2i(xi, zi), h < WATER_LEVEL + 0.5 or slope > 0.62)

	var start: Vector3 = points[0]
	var start_cell := _nearest_cell(astar, start)
	for i in range(1, points.size()):
		var p: Vector3 = points[i]
		var end_cell := _nearest_cell(astar, p)
		var id_path: Array = astar.get_id_path(start_cell, end_cell)
		if id_path.size() < 2:
			continue
		var prev := _cell_world(id_path[0])
		for j in range(1, id_path.size()):
			var cur := _cell_world(id_path[j])
			_path_segments.append([Vector2(prev.x, prev.z), Vector2(cur.x, cur.z)])
			prev = cur

	_rebuild_mask()
	_minimap_cache = null
	if grass != null:
		build_grass()

func build_grass() -> void:
	if grass != null:
		grass.queue_free()
		grass = null
	grass = GrassFieldScript.new()
	grass.name = "Grass"
	add_child(grass)
	grass.build(self)

# --- Minimap ----------------------------------------------------------------

func get_minimap_texture(map_size: int = 320) -> ImageTexture:
	if _minimap_cache != null:
		return _minimap_cache
	var img := Image.create(map_size, map_size, false, Image.FORMAT_RGBA8)
	for y in range(map_size):
		for x in range(map_size):
			var wx := -SIZE * 0.5 + (float(x) + 0.5) * SIZE / float(map_size)
			var wz := -SIZE * 0.5 + (float(y) + 0.5) * SIZE / float(map_size)
			img.set_pixel(x, y, _minimap_color(wx, wz))
	_minimap_cache = ImageTexture.create_from_image(img)
	return _minimap_cache

func _minimap_color(x: float, z: float) -> Color:
	var h := get_height(x, z)
	if h < WATER_LEVEL + 0.2:
		return Color(0.10, 0.26, 0.34)
	var zt := get_zone_type(x, z)
	var c := Color(0.30, 0.35, 0.17).lerp(Color(0.45, 0.44, 0.23), clampf(h / 22.0, 0.0, 1.0))
	match zt:
		ZONE_FIELDS:
			c = Color(0.62, 0.55, 0.28)
		ZONE_SWAMP:
			c = Color(0.24, 0.30, 0.17)
		ZONE_PINE_FOREST:
			c = Color(0.20, 0.30, 0.15)
		ZONE_DECIDUOUS_FOREST:
			c = Color(0.34, 0.40, 0.19)
		ZONE_CAMP:
			c = Color(0.55, 0.45, 0.30)
		ZONE_RUINS:
			c = Color(0.48, 0.46, 0.40)
		ZONE_STONE_TOWER:
			c = Color(0.55, 0.53, 0.47)
		ZONE_RADIO_TOWER:
			c = Color(0.5, 0.5, 0.5)
		ZONE_MOUNTAIN:
			c = c.lerp(Color(0.48, 0.46, 0.41), 0.4)
	var shore := 1.0 - smoothstep(0.0, 1.6, absf(h - (WATER_LEVEL + 0.4)))
	c = c.lerp(Color(0.70, 0.62, 0.44), shore * 0.6)
	return c

# --- Mesh / mask / water ----------------------------------------------------

func _rebuild_mask() -> void:
	if _mask_image == null:
		_mask_image = Image.create(MASK_RES, MASK_RES, false, Image.FORMAT_RGBA8)
	for zi in range(MASK_RES):
		var wz := -SIZE * 0.5 + (float(zi) + 0.5) * _mask_step
		for xi in range(MASK_RES):
			var wx := -SIZE * 0.5 + (float(xi) + 0.5) * _mask_step
			var z := get_zone(wx, wz)
			_mask_image.set_pixel(xi, zi, Color(z.x, z.y, z.z, z.w))
	_mask_texture = ImageTexture.create_from_image(_mask_image)
	if ground_material != null:
		ground_material.set_shader_parameter("zone_mask", _mask_texture)
	if water_material != null:
		water_material.set_shader_parameter("zone_mask", _mask_texture)

func _build_mesh() -> void:
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var norms := PackedVector3Array()
	for zi in range(_n):
		var z := -SIZE * 0.5 + zi * _step
		for xi in range(_n):
			var x := -SIZE * 0.5 + xi * _step
			var h := get_height(x, z)
			verts.append(Vector3(x, h, z))
			cols.append(_color_for(x, z, h).srgb_to_linear())
			norms.append(get_normal(x, z))
	var indices := PackedInt32Array()
	var faces := PackedVector3Array()
	for zi in range(RES):
		for xi in range(RES):
			var i0 := zi * _n + xi
			var i1 := i0 + 1
			var i2 := i0 + _n
			var i3 := i2 + 1
			indices.append_array([i0, i1, i2])
			faces.append_array([verts[i0], verts[i1], verts[i2]])
			indices.append_array([i1, i3, i2])
			faces.append_array([verts[i1], verts[i3], verts[i2]])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	ground_material = ShaderMaterial.new()
	ground_material.shader = TerrainShader
	ground_material.set_shader_parameter("zone_mask", _mask_texture)
	ground_material.set_shader_parameter("world_size", SIZE)

	var mi := MeshInstance3D.new()
	mi.name = "Ground"
	mi.mesh = mesh
	mi.material_override = ground_material
	add_child(mi)
	var body := StaticBody3D.new()
	body.name = "GroundBody"
	var col := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	col.shape = shape
	body.add_child(col)
	add_child(body)

func _build_water() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(SIZE * 2.2, SIZE * 2.2)
	plane.subdivide_width = 64
	plane.subdivide_depth = 64
	water_material = ShaderMaterial.new()
	water_material.shader = WaterShader
	water_material.set_shader_parameter("zone_mask", _mask_texture)
	water_material.set_shader_parameter("world_size", SIZE)
	var mi := MeshInstance3D.new()
	mi.name = "Water"
	mi.mesh = plane
	mi.material_override = water_material
	mi.position = Vector3(0, WATER_LEVEL, 0)
	add_child(mi)

func _color_for(x: float, z: float, h: float) -> Color:
	var slope := 1.0 - get_normal(x, z).y
	var n := noise.get_noise_2d(x * 2.5, z * 2.5) * 0.5 + 0.5
	if h < WATER_LEVEL + 1.2:
		return Color(0.62, 0.55, 0.38).lerp(Color(0.74, 0.66, 0.47), n)
	var zt := get_zone_type(x, z)
	var ground := Color(0.22, 0.38, 0.12).lerp(Color(0.38, 0.50, 0.18), n)
	var dirt := noise.get_noise_2d(x * 3.5 + 70.0, z * 3.5 - 30.0) * 0.5 + 0.5
	if dirt > 0.72:
		ground = ground.lerp(Color(0.47, 0.36, 0.21), (dirt - 0.72) * 1.5)
	match zt:
		ZONE_SWAMP:
			ground = ground.lerp(Color(0.20, 0.27, 0.14), 0.7)
		ZONE_PINE_FOREST:
			ground = ground.lerp(Color(0.18, 0.30, 0.11), 0.45)
		ZONE_DECIDUOUS_FOREST:
			ground = ground.lerp(Color(0.26, 0.36, 0.14), 0.35)
		ZONE_FIELDS:
			ground = ground.lerp(Color(0.56, 0.52, 0.28), 0.55)
		ZONE_CAMP:
			ground = ground.lerp(Color(0.36, 0.36, 0.22), 0.35)
		ZONE_RUINS:
			ground = ground.lerp(Color(0.46, 0.43, 0.37), 0.35)
	var rock_amt := smoothstep(52.0, 80.0, h)
	rock_amt = maxf(rock_amt, smoothstep(0.55, 0.85, slope) * 0.7)
	if rock_amt > 0.01:
		var rock_col := Color(0.46, 0.43, 0.38).lerp(Color(0.58, 0.53, 0.45), n)
		ground = ground.lerp(rock_col, rock_amt)
	return ground

# --- Helpers ----------------------------------------------------------------

func _path_factor(x: float, z: float) -> float:
	if _path_segments.is_empty():
		return 0.0
	var p := Vector2(x, z)
	var best := 9999.0
	for seg in _path_segments:
		var d := _segment_distance(p, seg[0], seg[1])
		if d < best:
			best = d
	return clampf(1.0 - (best - 1.0) / 3.0, 0.0, 1.0)

func _polyline_distance(p: Vector2, pts: Array) -> float:
	var best := 1e9
	for i in range(pts.size() - 1):
		var d := _segment_distance(p, pts[i], pts[i + 1])
		if d < best:
			best = d
	return best

func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len2 := ab.length_squared()
	if len2 < 0.0001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / len2, 0.0, 1.0)
	return p.distance_to(a + ab * t)

func _nearest_cell(astar: AStarGrid2D, pos: Vector3) -> Vector2i:
	var base := Vector2i(
		clampi(int(round((pos.x + SIZE * 0.5) / _step - 0.5)), 0, RES - 1),
		clampi(int(round((pos.z + SIZE * 0.5) / _step - 0.5)), 0, RES - 1))
	if not astar.is_point_solid(base):
		return base
	for r in range(1, 9):
		for dx in range(-r, r + 1):
			for dz in range(-r, r + 1):
				var c := base + Vector2i(dx, dz)
				if c.x < 0 or c.y < 0 or c.x >= RES or c.y >= RES:
					continue
				if not astar.is_point_solid(c):
					return c
	return base

func _cell_world(cell: Vector2i) -> Vector3:
	return Vector3(
		-SIZE * 0.5 + (float(cell.x) + 0.5) * _step,
		0.0,
		-SIZE * 0.5 + (float(cell.y) + 0.5) * _step)

func _hill(x: float, z: float, cx: float, cz: float, radius: float, height: float) -> float:
	var d2 := (x - cx) * (x - cx) + (z - cz) * (z - cz)
	return height * exp(-d2 / (2.0 * radius * radius))

func _gaussian(x: float, z: float, cx: float, cz: float, radius: float) -> float:
	var d2 := (x - cx) * (x - cx) + (z - cz) * (z - cz)
	return exp(-d2 / (2.0 * radius * radius))

func _ellipse_norm(x: float, z: float, center: Vector2, radius: Vector2) -> float:
	var nx := (x - center.x) / radius.x
	var nz := (z - center.y) / radius.y
	return sqrt(nx * nx + nz * nz)

func _ellipse_factor(x: float, z: float, center: Vector2, radius: Vector2) -> float:
	return 1.0 - smoothstep(0.1, 1.0, _ellipse_norm(x, z, center, radius))
