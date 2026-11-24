class_name TerrainPainter
extends RefCounted

# Turns geometry into the shader mask and vertex colours. One palette, one
# formula per channel, so the minimap can never disagree with the ground.

const N := 257

var path_grid := PackedFloat32Array()
var swamp_grid := PackedFloat32Array()
var rock_grid := PackedFloat32Array()
var shore_grid := PackedFloat32Array()
var colors := PackedColorArray()
var heights := PackedFloat32Array()
var mask_texture: ImageTexture
var _minimap: ImageTexture
var _minimap_size := 0
var _noise: FastNoiseLite
var _zones: ZoneMap

func build(hf: HeightField, zones: ZoneMap, coast: Coastline, roads: RoadBuilder) -> void:
	_zones = zones
	heights = hf.grid.duplicate()
	_noise = FastNoiseLite.new()
	_noise.seed = 424242
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.03
	_build_path_grid(hf, roads)
	_build_zone_grids(hf, zones)
	colors.resize(N * N)
	for zi in range(N):
		var z := -WorldConfig.SIZE * 0.5 + float(zi) * hf.cell
		for xi in range(N):
			var x := -WorldConfig.SIZE * 0.5 + float(xi) * hf.cell
			var idx := zi * N + xi
			var h := hf.grid[idx]
			var slope := 0.0
			if xi > 0 and zi > 0 and xi < N - 1 and zi < N - 1:
				slope = _slope_from_grid(hf, x, z)
			var zdef := zones.zone_at(x, z)
			var zt := int(zdef.get("type", WorldConfig.ZONE_GENERAL))
			var c := _color_for(x, z, h, slope, zt, hf.mud[idx], path_grid[idx])
			colors[idx] = c.srgb_to_linear()
	_build_mask()

func _slope_from_grid(hf: HeightField, x: float, z: float) -> float:
	var n := hf.sample_normal(x, z)
	return rad_to_deg(acos(clampf(n.y, -1.0, 1.0)))

func _build_path_grid(hf: HeightField, roads: RoadBuilder) -> void:
	path_grid.resize(N * N)
	path_grid.fill(0.0)
	for seg in roads.segments:
		var pts: PackedVector2Array = seg
		for i in range(0, pts.size() - 1, 2):
			_stamp_path(pts[i].lerp(pts[mini(i + 2, pts.size() - 1)], 0.5), 5.5)

func _stamp_path(p: Vector2, radius: float) -> void:
	var j0 := clampi(int(floor((p.y - radius + WorldConfig.SIZE * 0.5) / (WorldConfig.SIZE / float(WorldConfig.RES)))), 0, N - 1)
	var j1 := clampi(int(ceil((p.y + radius + WorldConfig.SIZE * 0.5) / (WorldConfig.SIZE / float(WorldConfig.RES)))), 0, N - 1)
	var i0 := clampi(int(floor((p.x - radius + WorldConfig.SIZE * 0.5) / (WorldConfig.SIZE / float(WorldConfig.RES)))), 0, N - 1)
	var i1 := clampi(int(ceil((p.x + radius + WorldConfig.SIZE * 0.5) / (WorldConfig.SIZE / float(WorldConfig.RES)))), 0, N - 1)
	var cell := WorldConfig.SIZE / float(WorldConfig.RES)
	for zi in range(j0, j1 + 1):
		var wz := -WorldConfig.SIZE * 0.5 + float(zi) * cell
		for xi in range(i0, i1 + 1):
			var wx := -WorldConfig.SIZE * 0.5 + float(xi) * cell
			var d := Vector2(wx, wz).distance_to(p)
			if d > radius:
				continue
			var v := 1.0 - d / radius
			var idx := zi * N + xi
			path_grid[idx] = maxf(path_grid[idx], v)

func _build_zone_grids(hf: HeightField, zones: ZoneMap) -> void:
	swamp_grid.resize(N * N)
	rock_grid.resize(N * N)
	shore_grid.resize(N * N)
	var swamp_def := zones.def_by_type(WorldConfig.ZONE_SWAMP)
	for zi in range(N):
		var z := -WorldConfig.SIZE * 0.5 + float(zi) * hf.cell
		for xi in range(N):
			var x := -WorldConfig.SIZE * 0.5 + float(xi) * hf.cell
			var idx := zi * N + xi
			var h := hf.grid[idx]
			var slope := _slope_from_grid(hf, x, z)
			var swamp := 0.0
			if not swamp_def.is_empty():
				var c: Vector2 = swamp_def["center"]
				var sz: Vector2 = swamp_def["size"]
				var nx := (x - c.x) / maxf(1.0, sz.x * 0.5)
				var nz := (z - c.y) / maxf(1.0, sz.y * 0.5)
				swamp = 1.0 - smoothstep(0.70, 1.15, sqrt(nx * nx + nz * nz))
			var rock := smoothstep(26.0, 40.0, slope)
			rock = maxf(rock, smoothstep(22.0, 34.0, h))
			var shore := 1.0 - smoothstep(0.0, 1.8, absf(h - (WorldConfig.SEA_LEVEL + 0.5)))
			shore *= 1.0 - rock * 0.6
			swamp_grid[idx] = swamp
			rock_grid[idx] = rock
			shore_grid[idx] = shore

func _build_mask() -> void:
	var mask_size := WorldConfig.RES
	var img := Image.create(mask_size, mask_size, false, Image.FORMAT_RGBA8)
	var cell := WorldConfig.SIZE / float(WorldConfig.RES)
	for y in range(mask_size):
		var wz := -WorldConfig.SIZE * 0.5 + (float(y) + 0.5) * cell
		for x in range(mask_size):
			var wx := -WorldConfig.SIZE * 0.5 + (float(x) + 0.5) * cell
			var idx := _node_at(wx, wz)
			img.set_pixel(x, y, Color(path_grid[idx], swamp_grid[idx], rock_grid[idx], shore_grid[idx]))
	mask_texture = ImageTexture.create_from_image(img)
	_minimap = null
	_minimap_size = 0

func _node_at(x: float, z: float) -> int:
	var cell := WorldConfig.SIZE / float(WorldConfig.RES)
	var xi := clampi(int(round((x + WorldConfig.SIZE * 0.5) / cell)), 0, N - 1)
	var zi := clampi(int(round((z + WorldConfig.SIZE * 0.5) / cell)), 0, N - 1)
	return zi * N + xi

func get_zone(x: float, z: float) -> Vector4:
	var idx := _node_at(x, z)
	return Vector4(path_grid[idx], swamp_grid[idx], rock_grid[idx], shore_grid[idx])

func path_at(x: float, z: float) -> float:
	return path_grid[_node_at(x, z)]

func _color_for(x: float, z: float, h: float, slope: float, zone_type: int, mudv: float, pathv: float) -> Color:
	var n := _noise.get_noise_2d(x * 2.5, z * 2.5) * 0.5 + 0.5
	if h < WorldConfig.SEA_LEVEL + 1.2:
		return Color(0.62, 0.55, 0.38).lerp(Color(0.74, 0.66, 0.47), n)
	var c := Color(0.24, 0.38, 0.14).lerp(Color(0.40, 0.50, 0.19), n)
	match zone_type:
		WorldConfig.ZONE_SWAMP:
			c = c.lerp(Color(0.22, 0.28, 0.15), 0.7)
		WorldConfig.ZONE_PINE_FOREST:
			c = c.lerp(Color(0.23, 0.34, 0.16), 0.25)
		WorldConfig.ZONE_DECIDUOUS_FOREST:
			c = c.lerp(Color(0.30, 0.40, 0.18), 0.2)
		WorldConfig.ZONE_FIELDS:
			c = c.lerp(Color(0.58, 0.53, 0.29), 0.55)
		WorldConfig.ZONE_CAMP:
			c = c.lerp(Color(0.40, 0.36, 0.24), 0.4)
		WorldConfig.ZONE_RUINS:
			c = c.lerp(Color(0.46, 0.43, 0.37), 0.45)
		WorldConfig.ZONE_MOUNTAIN:
			c = c.lerp(Color(0.46, 0.43, 0.37), 0.55)
		WorldConfig.ZONE_STONE_TOWER:
			c = c.lerp(Color(0.46, 0.44, 0.39), 0.5)
		WorldConfig.ZONE_RADIO_TOWER:
			c = c.lerp(Color(0.45, 0.44, 0.41), 0.55)
		WorldConfig.ZONE_LAKE:
			c = Color(0.20, 0.30, 0.28).lerp(Color(0.26, 0.36, 0.30), n)
	if mudv > 0.05:
		c = c.lerp(Color(0.35, 0.27, 0.17), clampf(mudv, 0.0, 1.0) * 0.7)
	var rock_amt := smoothstep(26.0, 40.0, slope)
	rock_amt = maxf(rock_amt, smoothstep(22.0, 34.0, h) * 0.92)
	if rock_amt > 0.01:
		var rock_col := Color(0.47, 0.44, 0.39).lerp(Color(0.60, 0.55, 0.47), n)
		c = c.lerp(rock_col, rock_amt)
	if pathv > 0.05:
		c = c.lerp(Color(0.56, 0.46, 0.30), clampf(pathv, 0.0, 1.0) * 0.85)
	return c

func minimap_texture(size: int = 160) -> ImageTexture:
	if _minimap != null and _minimap_size == size:
		return _minimap
	_minimap = null
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		var wz := -WorldConfig.SIZE * 0.5 + (float(y) + 0.5) * WorldConfig.SIZE / float(size)
		for x in range(size):
			var wx := -WorldConfig.SIZE * 0.5 + (float(x) + 0.5) * WorldConfig.SIZE / float(size)
			var idx := _node_at(wx, wz)
			var h := heights[idx]
			var zt := WorldConfig.ZONE_GENERAL
			if h < WorldConfig.SEA_LEVEL + 0.2:
				zt = WorldConfig.ZONE_LAKE
			elif _zones != null:
				zt = _zones.type_at(wx, wz)
			img.set_pixel(x, y, _color_for(wx, wz, h, 0.0, zt, 0.0, path_grid[idx]))
	_minimap = ImageTexture.create_from_image(img)
	_minimap_size = size
	return _minimap
