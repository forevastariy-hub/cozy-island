class_name HeightField
extends RefCounted

# Owns the height grid and exposes only primitives (sample / lower / sculpt).
# Terrain is built from layered noise: plains, ridged mountain ranges, a wide
# beach band, a real bathymetry profile and noise-shaped sea islets.

const N := 321

var cell := WorldConfig.SIZE / float(WorldConfig.RES)
var grid := PackedFloat32Array()
var mud := PackedFloat32Array()
var moisture := PackedFloat32Array()
var temperature := PackedFloat32Array()
var biome := PackedInt32Array()

var _noise: FastNoiseLite
var _islet: FastNoiseLite
var _rugged: FastNoiseLite

func build_base(world_seed: int, coast: Coastline) -> void:
	_noise = FastNoiseLite.new()
	_noise.seed = world_seed
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0
	_noise.fractal_octaves = 5
	_noise.fractal_gain = 0.5
	_islet = FastNoiseLite.new()
	_islet.seed = world_seed + 91
	_islet.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_islet.frequency = 1.0
	_islet.fractal_octaves = 4
	_islet.fractal_gain = 0.55
	_rugged = FastNoiseLite.new()
	_rugged.seed = world_seed + 77
	_rugged.noise_type = FastNoiseLite.TYPE_CELLULAR
	_rugged.frequency = 0.03

	grid.resize(N * N)
	mud.resize(N * N)
	mud.fill(0.0)
	for zi in range(N):
		var z := -WorldConfig.SIZE * 0.5 + float(zi) * cell
		for xi in range(N):
			var x := -WorldConfig.SIZE * 0.5 + float(xi) * cell
			grid[zi * N + xi] = _base_at(x, z, coast)
	_smooth_all(1)

func _base_at(x: float, z: float, coast: Coastline) -> float:
	var signed := coast.signed_distance(x, z)
	var inland := _inland_height(x, z, signed)
	var beach_w := _beach_width(x, z)
	var shore_t := smoothstep(0.0, 1.0, clampf(signed / beach_w, 0.0, 1.0))
	var land_h := lerpf(WorldConfig.SEA_LEVEL + 0.7, inland, shore_t)
	var bathy := _bathy(x, z, signed)
	var h := lerpf(bathy, land_h, smoothstep(-5.0, 5.0, signed))
	var isl := _sea_islet(x, z, signed)
	if isl > -100.0:
		h = maxf(h, isl)
	return h

func _inland_height(x: float, z: float, signed: float) -> float:
	var n1 := _noise.get_noise_2d(x * 0.0032, z * 0.0032) * 0.5 + 0.5
	var n2 := _noise.get_noise_2d(x * 0.0075 + 120.0, z * 0.0075 - 40.0) * 0.5 + 0.5
	var n3 := _noise.get_noise_2d(x * 0.02 - 30.0, z * 0.02 + 80.0) * 0.5 + 0.5
	var coast_fade := smoothstep(55.0, 165.0, signed)
	return 2.5 + n3 * 1.2 + (n1 * 12.0 + n2 * 5.0) * coast_fade

func _beach_width(_x: float, _z: float) -> float:
	return 85.0

func _bathy(x: float, z: float, signed: float) -> float:
	var d := maxf(0.0, -signed)
	var depth := 0.8
	depth += smoothstep(0.0, 45.0, d) * 4.5
	depth += smoothstep(45.0, 110.0, d) * 10.0
	depth += smoothstep(110.0, 240.0, d) * 12.0
	depth += (_islet.get_noise_2d(x * 0.02, z * 0.02) * 0.5 + 0.5) * 1.3
	return WorldConfig.SEA_LEVEL - depth

func _sea_islet(x: float, z: float, signed: float) -> float:
	if signed >= 0.0 or signed < -250.0:
		return -999.0
	var isl := _islet.get_noise_2d(x * 0.012 + 311.0, z * 0.012 - 177.0)
	if isl < 0.52:
		return -999.0
	var d := -signed
	var fade := 1.0 - smoothstep(70.0, 250.0, d)
	var rise := (isl - 0.52) / 0.48
	return WorldConfig.SEA_LEVEL - 1.3 + rise * 8.0 * fade

func _smooth_all(passes: int) -> void:
	for _p in range(passes):
		var src := grid.duplicate()
		for zi in range(1, N - 1):
			for xi in range(1, N - 1):
				var s := 0.0
				for dz in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						s += src[(zi + dz) * N + (xi + dx)]
				grid[zi * N + xi] = s / 9.0

func _smooth_rect(center: Vector2, radius: float, passes: int) -> void:
	var j0 := clampi(int(floor((center.y - radius + WorldConfig.SIZE * 0.5) / cell)), 1, N - 2)
	var j1 := clampi(int(ceil((center.y + radius + WorldConfig.SIZE * 0.5) / cell)), 1, N - 2)
	var i0 := clampi(int(floor((center.x - radius + WorldConfig.SIZE * 0.5) / cell)), 1, N - 2)
	var i1 := clampi(int(ceil((center.x + radius + WorldConfig.SIZE * 0.5) / cell)), 1, N - 2)
	for _p in range(passes):
		var src := grid.duplicate()
		for zi in range(j0, j1 + 1):
			for xi in range(i0, i1 + 1):
				var s := 0.0
				for dz in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						s += src[(zi + dz) * N + (xi + dx)]
				grid[zi * N + xi] = s / 9.0

func _rim_min(center: Vector2, radii: Vector2) -> float:
	var size := radii * 2.0
	var phase := ShapeUtil.phase_for(center)
	var best := 1.0e9
	for i in range(48):
		var a := TAU * float(i) / 48.0
		var w := ShapeUtil.wobble(a, phase)
		var p := center + Vector2(cos(a) * radii.x * w, sin(a) * radii.y * w)
		best = minf(best, sample(p.x, p.y))
	return best

func sample(x: float, z: float) -> float:
	var fx := (x + WorldConfig.SIZE * 0.5) / cell
	var fz := (z + WorldConfig.SIZE * 0.5) / cell
	fx = clampf(fx, 0.0, float(N - 1) - 0.0001)
	fz = clampf(fz, 0.0, float(N - 1) - 0.0001)
	var x0 := int(fx)
	var z0 := int(fz)
	var tx := fx - float(x0)
	var tz := fz - float(z0)
	var x1 := mini(x0 + 1, N - 1)
	var z1 := mini(z0 + 1, N - 1)
	var h00 := grid[z0 * N + x0]
	var h10 := grid[z0 * N + x1]
	var h01 := grid[z1 * N + x0]
	var h11 := grid[z1 * N + x1]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)

func sample_normal(x: float, z: float) -> Vector3:
	var e := 2.5
	var hl := sample(x - e, z)
	var hr := sample(x + e, z)
	var hd := sample(x, z - e)
	var hu := sample(x, z + e)
	return Vector3(-(hr - hl), 2.0 * e, -(hu - hd)).normalized()

func slope_deg(x: float, z: float) -> float:
	var n := sample_normal(x, z)
	return rad_to_deg(acos(clampf(n.y, -1.0, 1.0)))

func node_index(x: float, z: float) -> int:
	var xi := clampi(int(round((x + WorldConfig.SIZE * 0.5) / cell)), 0, N - 1)
	var zi := clampi(int(round((z + WorldConfig.SIZE * 0.5) / cell)), 0, N - 1)
	return zi * N + xi

func mud_at(x: float, z: float) -> float:
	return mud[node_index(x, z)]

func biome_at(x: float, z: float) -> int:
	if biome.is_empty():
		return WorldConfig.ZONE_GENERAL
	return biome[node_index(x, z)]

func moisture_at(x: float, z: float) -> float:
	if moisture.is_empty():
		return 0.5
	return moisture[node_index(x, z)]

func raise_inland_lowlands(coast: Coastline, layout: PoiLayout) -> void:
	var lake: Dictionary = layout.pois.get("lake", {})
	var lake_c := Vector2.ZERO
	var lake_size := Vector2.ONE
	var lake_phase := 0.0
	if not lake.is_empty():
		lake_c = lake["center"]
		lake_size = lake["size"]
		lake_phase = ShapeUtil.phase_for(lake_c)
	for zi in range(N):
		var z := -WorldConfig.SIZE * 0.5 + float(zi) * cell
		for xi in range(N):
			var x := -WorldConfig.SIZE * 0.5 + float(xi) * cell
			var idx := zi * N + xi
			if grid[idx] >= WorldConfig.SEA_LEVEL + 0.05:
				continue
			if coast.signed_distance(x, z) < 25.0:
				continue
			if not lake.is_empty() and ShapeUtil.ellipse_norm(x, z, lake_c, lake_size, lake_phase) < 1.25:
				continue
			grid[idx] = WorldConfig.SEA_LEVEL + 0.05

func lower_to(x: float, z: float, target: float) -> void:
	var idx := node_index(x, z)
	if grid[idx] > target:
		grid[idx] = target

func lower_circle(center: Vector2, radius: float, target: float) -> void:
	var j0 := clampi(int(floor((center.y - radius + WorldConfig.SIZE * 0.5) / cell)), 0, N - 1)
	var j1 := clampi(int(ceil((center.y + radius + WorldConfig.SIZE * 0.5) / cell)), 0, N - 1)
	var i0 := clampi(int(floor((center.x - radius + WorldConfig.SIZE * 0.5) / cell)), 0, N - 1)
	var i1 := clampi(int(ceil((center.x + radius + WorldConfig.SIZE * 0.5) / cell)), 0, N - 1)
	for zi in range(j0, j1 + 1):
		var wz := -WorldConfig.SIZE * 0.5 + float(zi) * cell
		for xi in range(i0, i1 + 1):
			var wx := -WorldConfig.SIZE * 0.5 + float(xi) * cell
			var d := Vector2(wx - center.x, wz - center.y).length()
			if d > radius:
				continue
			var f := 1.0 - smoothstep(radius * 0.45, radius, d)
			var goal := lerpf(grid[zi * N + xi], target, f)
			if goal < grid[zi * N + xi]:
				grid[zi * N + xi] = goal

func carve_stamp(center: Vector2, water: float, width: float, depth: float, bank: float, valley: float) -> void:
	var r_in := maxf(0.8, width * 0.5)
	var r_bank := r_in + bank
	var r_out := r_bank + valley
	var j0 := clampi(int(floor((center.y - r_out + WorldConfig.SIZE * 0.5) / cell)), 0, N - 1)
	var j1 := clampi(int(ceil((center.y + r_out + WorldConfig.SIZE * 0.5) / cell)), 0, N - 1)
	var i0 := clampi(int(floor((center.x - r_out + WorldConfig.SIZE * 0.5) / cell)), 0, N - 1)
	var i1 := clampi(int(ceil((center.x + r_out + WorldConfig.SIZE * 0.5) / cell)), 0, N - 1)
	for zi in range(j0, j1 + 1):
		var wz := -WorldConfig.SIZE * 0.5 + float(zi) * cell
		for xi in range(i0, i1 + 1):
			var wx := -WorldConfig.SIZE * 0.5 + float(xi) * cell
			var d := Vector2(wx - center.x, wz - center.y).length()
			if d > r_out:
				continue
			var idx := zi * N + xi
			if d <= r_in:
				var t := 1.0 - d / r_in
				var target := water - depth * (0.35 + 0.65 * t)
				if target < grid[idx]:
					grid[idx] = target
				mud[idx] = maxf(mud[idx], 1.0)
			elif d <= r_bank:
				var b := (d - r_in) / maxf(0.001, bank)
				var target := lerpf(water - 0.15, water + 0.8, b)
				if target < grid[idx]:
					grid[idx] = target
				mud[idx] = maxf(mud[idx], (1.0 - b) * 0.8)
			else:
				var f := 1.0 - smoothstep(r_bank, r_out, d)
				var goal := water + 0.8 + (d - r_bank) * 0.16
				if goal < grid[idx]:
					grid[idx] = lerpf(grid[idx], goal, f * 0.9)

# --- POI sculpting --------------------------------------------------------

func apply_pois(layout: PoiLayout) -> void:
	for name in layout.pois:
		var p: Dictionary = layout.pois[name]
		var c: Vector2 = p["center"]
		var sz: Vector2 = p["size"]
		match String(name):
			"camp":
				_flatten(c, sz * 0.42, 7.5, 0.95, 1.5)
			"fields":
				_flatten(c, sz * 0.45, 9.0, 0.9, 1.1)
			"ruins":
				_flatten(c, Vector2(40.0, 36.0), 10.0, 0.92, 2.0)
			"mountain":
				_plateau(c, 70.0, 26.0, 16.0)
			"radio_tower":
				_plateau(c, 74.0, 28.0, 20.0)
			"stone_tower":
				_plateau(c, 46.0, 20.0, 12.0)
			"lake":
				var rim := _rim_min(c, sz * 0.5)
				var lake_y := clampf(rim - 0.8, WorldConfig.SEA_LEVEL + 2.0, 9.0)
				p["y"] = lake_y
				_lake_basin(c, sz * 0.5, lake_y, 3.0)
				_smooth_rect(c, maxf(sz.x, sz.y) * 0.62, 2)
			"swamp":
				_swamp_basin(c, sz * 0.5)

func build_biomes() -> void:
	moisture.resize(N * N)
	temperature.resize(N * N)
	biome.resize(N * N)
	for zi in range(N):
		var z := -WorldConfig.SIZE * 0.5 + float(zi) * cell
		for xi in range(N):
			var x := -WorldConfig.SIZE * 0.5 + float(xi) * cell
			var idx := zi * N + xi
			var h := grid[idx]
			var slope := 0.0
			if xi > 0 and zi > 0 and xi < N - 1 and zi < N - 1:
				var n := sample_normal(x, z)
				slope = rad_to_deg(acos(clampf(n.y, -1.0, 1.0)))
			var temp := clampf(0.60 - (h - WorldConfig.SEA_LEVEL) * 0.006 + (z / 500.0) * 0.10, 0.0, 1.0)
			var moist := (_noise.get_noise_2d(x * 0.0035 + 90.0, z * 0.0035 - 40.0) * 0.5 + 0.5) * 0.82
			moist += (1.0 - clampf(slope / 30.0, 0.0, 1.0)) * 0.14
			if h < WorldConfig.SEA_LEVEL + 5.0:
				moist += 0.05
			moist = clampf(moist, 0.0, 1.0)
			temperature[idx] = temp
			moisture[idx] = moist
			var t := WorldConfig.ZONE_GENERAL
			if h < WorldConfig.SEA_LEVEL + 0.3:
				t = WorldConfig.ZONE_LAKE
			elif slope > 32.0 or h > 24.0:
				t = WorldConfig.ZONE_MOUNTAIN
			elif moist > 0.68 and h < WorldConfig.SEA_LEVEL + 4.2:
				t = WorldConfig.ZONE_SWAMP
			elif moist > 0.55:
				t = WorldConfig.ZONE_PINE_FOREST if temp < 0.50 else WorldConfig.ZONE_DECIDUOUS_FOREST
			biome[idx] = t

func _flatten(center: Vector2, radii: Vector2, target: float, strength: float, power: float) -> void:
	var rmax := maxf(radii.x, radii.y) * 1.5
	var size := radii * 2.0
	var phase := ShapeUtil.phase_for(center)
	var j0 := clampi(int(floor((center.y - rmax + WorldConfig.SIZE * 0.5) / cell)), 0, N - 1)
	var j1 := clampi(int(ceil((center.y + rmax + WorldConfig.SIZE * 0.5) / cell)), 0, N - 1)
	var i0 := clampi(int(floor((center.x - rmax + WorldConfig.SIZE * 0.5) / cell)), 0, N - 1)
	var i1 := clampi(int(ceil((center.x + rmax + WorldConfig.SIZE * 0.5) / cell)), 0, N - 1)
	for zi in range(j0, j1 + 1):
		var wz := -WorldConfig.SIZE * 0.5 + float(zi) * cell
		for xi in range(i0, i1 + 1):
			var wx := -WorldConfig.SIZE * 0.5 + float(xi) * cell
			var d := ShapeUtil.ellipse_norm(wx, wz, center, size, phase)
			if d > 1.45:
				continue
			var f := 1.0 - smoothstep(0.45, 1.35, d)
			f = pow(f, power) * strength
			if f <= 0.0:
				continue
			var idx := zi * N + xi
			if grid[idx] > target + 3.5:
				continue
			grid[idx] = lerpf(grid[idx], target, f)

func _plateau(center: Vector2, base_r: float, plateau_r: float, target: float) -> void:
	var rmax := base_r * 1.02
	var j0 := clampi(int(floor((center.y - rmax + WorldConfig.SIZE * 0.5) / cell)), 0, N - 1)
	var j1 := clampi(int(ceil((center.y + rmax + WorldConfig.SIZE * 0.5) / cell)), 0, N - 1)
	var i0 := clampi(int(floor((center.x - rmax + WorldConfig.SIZE * 0.5) / cell)), 0, N - 1)
	var i1 := clampi(int(ceil((center.x + rmax + WorldConfig.SIZE * 0.5) / cell)), 0, N - 1)
	for zi in range(j0, j1 + 1):
		var wz := -WorldConfig.SIZE * 0.5 + float(zi) * cell
		for xi in range(i0, i1 + 1):
			var wx := -WorldConfig.SIZE * 0.5 + float(xi) * cell
			var d := Vector2(wx - center.x, wz - center.y).length()
			d += _rugged.get_noise_2d(wx, wz) * 9.0
			var f := 0.0
			if d <= plateau_r:
				f = 1.0
			elif d < base_r:
				var t := 1.0 - (d - plateau_r) / (base_r - plateau_r)
				f = smoothstep(0.0, 1.0, t)
			if f <= 0.0:
				continue
			var idx := zi * N + xi
			grid[idx] = lerpf(grid[idx], target, pow(f, 1.2))

func smooth_global(passes: int) -> void:
	_smooth_all(passes)

func _lake_basin(center: Vector2, radii: Vector2, water_y: float, depth: float) -> void:
	var rmax := maxf(radii.x, radii.y) * 1.3
	var size := radii * 2.0
	var phase := ShapeUtil.phase_for(center)
	var j0 := clampi(int(floor((center.y - rmax + WorldConfig.SIZE * 0.5) / cell)), 0, N - 1)
	var j1 := clampi(int(ceil((center.y + rmax + WorldConfig.SIZE * 0.5) / cell)), 0, N - 1)
	var i0 := clampi(int(floor((center.x - rmax + WorldConfig.SIZE * 0.5) / cell)), 0, N - 1)
	var i1 := clampi(int(ceil((center.x + rmax + WorldConfig.SIZE * 0.5) / cell)), 0, N - 1)
	for zi in range(j0, j1 + 1):
		var wz := -WorldConfig.SIZE * 0.5 + float(zi) * cell
		for xi in range(i0, i1 + 1):
			var wx := -WorldConfig.SIZE * 0.5 + float(xi) * cell
			var rn := ShapeUtil.ellipse_norm(wx, wz, center, size, phase)
			var infl := 1.0 - smoothstep(0.86, 1.24, rn)
			if infl <= 0.0:
				continue
			var target := water_y - depth * (1.0 - 0.45 * clampf(rn, 0.0, 1.0))
			var idx := zi * N + xi
			grid[idx] = lerpf(grid[idx], target, infl * 0.96)

func _swamp_basin(center: Vector2, radii: Vector2) -> void:
	var rmax := maxf(radii.x, radii.y) * 1.25
	var size := radii * 2.0
	var phase := ShapeUtil.phase_for(center)
	var j0 := clampi(int(floor((center.y - rmax + WorldConfig.SIZE * 0.5) / cell)), 0, N - 1)
	var j1 := clampi(int(ceil((center.y + rmax + WorldConfig.SIZE * 0.5) / cell)), 0, N - 1)
	var i0 := clampi(int(floor((center.x - rmax + WorldConfig.SIZE * 0.5) / cell)), 0, N - 1)
	var i1 := clampi(int(ceil((center.x + rmax + WorldConfig.SIZE * 0.5) / cell)), 0, N - 1)
	for zi in range(j0, j1 + 1):
		var wz := -WorldConfig.SIZE * 0.5 + float(zi) * cell
		for xi in range(i0, i1 + 1):
			var wx := -WorldConfig.SIZE * 0.5 + float(xi) * cell
			var rn := ShapeUtil.ellipse_norm(wx, wz, center, size, phase)
			var infl := 1.0 - smoothstep(0.72, 1.2, rn)
			if infl <= 0.0:
				continue
			var wet := _noise.get_noise_2d(wx * 0.02 + 400.0, wz * 0.02 - 300.0) * 0.5 + 0.5
			var target := -1.3 + wet * 0.8 - pow(wet, 4.0) * 1.8
			var idx := zi * N + xi
			grid[idx] = lerpf(grid[idx], target, infl * 0.9)
