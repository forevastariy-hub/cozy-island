class_name HeightField
extends RefCounted

# Owns the height grid and exposes only primitives (sample / lower / sculpt).
# It knows nothing about rivers, roads, colours or meshes.

const N := 257

var cell := WorldConfig.SIZE / float(WorldConfig.RES)
var grid := PackedFloat32Array()
var mud := PackedFloat32Array()
var _noise: FastNoiseLite
var _rugged: FastNoiseLite

func build_base(world_seed: int, coast: Coastline) -> void:
	_noise = FastNoiseLite.new()
	_noise.seed = world_seed
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.0085
	_noise.fractal_octaves = 5
	_noise.fractal_gain = 0.52
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

func _base_at(x: float, z: float, coast: Coastline) -> float:
	var land := coast.land_mask(x, z)
	var n1 := _noise.get_noise_2d(x, z) * 0.5 + 0.5
	var n2 := _noise.get_noise_2d(x * 2.3 + 100.0, z * 2.3 - 55.0) * 0.5 + 0.5
	var h := 4.5 + n1 * 10.0 + n2 * 3.0
	h += _hill(x, z, -120.0, -40.0, 90.0, 5.0)
	h += _hill(x, z, 140.0, 240.0, 130.0, 6.0)
	h += _hill(x, z, -300.0, 250.0, 110.0, 3.0)
	var sea := lerpf(WorldConfig.SEABED, h, land)
	return _islet_height(x, z, coast, sea)

func _hill(x: float, z: float, cx: float, cz: float, radius: float, height: float) -> float:
	var dx := x - cx
	var dz := z - cz
	return height * exp(-(dx * dx + dz * dz) / (2.0 * radius * radius))

func _islet_height(x: float, z: float, coast: Coastline, base_h: float) -> float:
	var out := base_h
	for it in coast.islets:
		var c: Vector2 = it["center"]
		var r: float = it["radius"]
		var d := Vector2(x, z).distance_to(c)
		if d > r * 2.4:
			continue
		var f := exp(-(d * d) / (2.0 * r * r))
		out = maxf(out, WorldConfig.SEA_LEVEL - 1.6 + float(it["height"]) * f * 1.9)
	return out

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
				_flatten(c, Vector2(40.0, 36.0), 14.0, 0.92, 2.0)
			"mountain":
				_plateau(c, 78.0, 30.0, 36.0)
			"radio_tower":
				_plateau(c, 88.0, 32.0, 44.0)
			"stone_tower":
				_plateau(c, 58.0, 24.0, 26.0)
			"lake":
				_lake_basin(c, sz * 0.5, 8.0, 4.5)
			"swamp":
				_swamp_basin(c, sz * 0.5)

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
				f = _terrace(t, 4)
			if f <= 0.0:
				continue
			var idx := zi * N + xi
			grid[idx] = lerpf(grid[idx], target, pow(f, 1.35))

func _terrace(t: float, steps: float) -> float:
	var x := clampf(t, 0.0, 1.0) * steps
	return (floor(x) + smoothstep(0.72, 0.98, fmod(x, 1.0))) / steps

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
