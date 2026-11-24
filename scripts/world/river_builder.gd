class_name RiverBuilder
extends RefCounted

# Traces the river as a low-cost path over the height field (weighted A*), so
# it always finds the sea, follows valleys and never loops. Falls are merged
# into single waterfalls and the ribbon skips those spans.

var polyline := PackedVector2Array()
var water_levels := PackedFloat32Array()
var waterfalls: Array = []
var waterfall_spans: Array = []
var bbox := Rect2()

func build(hf: HeightField, layout: PoiLayout, coast: Coastline, rng: WorldRng) -> void:
	polyline = PackedVector2Array()
	water_levels = PackedFloat32Array()
	waterfalls.clear()
	waterfall_spans.clear()
	if not layout.pois.has("lake") or not layout.pois.has("camp"):
		return
	var lake: Dictionary = layout.pois["lake"]
	var camp: Dictionary = layout.pois["camp"]
	var start := _lake_outlet(lake, camp)
	var goal := _coast_goal(start, coast)
	var path := _astar_path(hf, layout, coast, start, goal, rng)
	if path.size() < 2:
		path = PackedVector2Array([start, goal])
	var smooth := _chaikin(_chaikin(path))
	_resample(smooth, WorldConfig.RIVER.sample)
	_update_bbox()
	_recompute_water(hf, float(lake.get("y", WorldConfig.LAKE_Y)))
	_carve(hf)
	_detect_waterfalls(hf)

func _lake_outlet(lake: Dictionary, camp: Dictionary) -> Vector2:
	var lake_c: Vector2 = lake["center"]
	var lake_size: Vector2 = lake["size"]
	var camp_c: Vector2 = camp["center"]
	var dir := (camp_c - lake_c).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var rx := maxf(1.0, lake_size.x * 0.5)
	var rz := maxf(1.0, lake_size.y * 0.5)
	var shore_r := 1.0 / sqrt(pow(dir.x / rx, 2.0) + pow(dir.y / rz, 2.0))
	return lake_c + dir * maxf(2.0, shore_r - 2.0)

func _coast_goal(start: Vector2, coast: Coastline) -> Vector2:
	var dir := start.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	return dir * (coast.radius_at(dir.angle()) - 8.0)

func _astar_path(hf: HeightField, layout: PoiLayout, coast: Coastline, start: Vector2, goal: Vector2, rng: WorldRng) -> PackedVector2Array:
	var astar := AStarGrid2D.new()
	astar.region = Rect2i(0, 0, WorldConfig.RES, WorldConfig.RES)
	astar.cell_size = Vector2(hf.cell, hf.cell)
	astar.offset = Vector2(-WorldConfig.SIZE * 0.5, -WorldConfig.SIZE * 0.5)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	var wiggle := FastNoiseLite.new()
	wiggle.seed = rng.rng().seed + 5
	wiggle.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	wiggle.frequency = 1.0
	var lake: Dictionary = layout.pois.get("lake", {})
	var lake_c := Vector2.ZERO
	var lake_size := Vector2.ONE
	var lake_phase := 0.0
	if not lake.is_empty():
		lake_c = lake["center"]
		lake_size = lake["size"]
		lake_phase = ShapeUtil.phase_for(lake_c)
	var has_weight := astar.has_method("set_point_weight_scale")
	for zi in range(WorldConfig.RES):
		var wz := -WorldConfig.SIZE * 0.5 + (float(zi) + 0.5) * hf.cell
		for xi in range(WorldConfig.RES):
			var wx := -WorldConfig.SIZE * 0.5 + (float(xi) + 0.5) * hf.cell
			var h := hf.sample(wx, wz)
			var slope := hf.slope_deg(wx, wz)
			var solid := h < WorldConfig.SEA_LEVEL + 0.4 or slope > 38.0
			if not lake.is_empty() and ShapeUtil.ellipse_norm(wx, wz, lake_c, lake_size, lake_phase) < 1.02:
				solid = true
			var cell := Vector2i(xi, zi)
			astar.set_point_solid(cell, solid)
			if has_weight:
				var w := 1.0 + clampf(h - WorldConfig.SEA_LEVEL, 0.0, 60.0) * 0.12
				w += pow(maxf(slope - 8.0, 0.0) / 10.0, 2.0) * 2.5
				w += (wiggle.get_noise_2d(wx * 0.006, wz * 0.006) * 0.5 + 0.5) * 6.0
				astar.set_point_weight_scale(cell, w)
	var start_cell := _nearest_open(astar, start)
	var goal_cell := _nearest_open(astar, goal)
	var ids := astar.get_id_path(start_cell, goal_cell)
	var out := PackedVector2Array()
	out.append(start)
	for id in ids:
		out.append(_cell_world(id))
	out.append(goal)
	return out

func _nearest_open(astar: AStarGrid2D, pos: Vector2) -> Vector2i:
	var step := astar.cell_size.x
	var base := Vector2i(
		clampi(int(round((pos.x + WorldConfig.SIZE * 0.5) / step - 0.5)), 0, WorldConfig.RES - 1),
		clampi(int(round((pos.y + WorldConfig.SIZE * 0.5) / step - 0.5)), 0, WorldConfig.RES - 1)
	)
	if not astar.is_point_solid(base):
		return base
	for r in range(1, 14):
		for dx in range(-r, r + 1):
			for dz in range(-r, r + 1):
				var c := base + Vector2i(dx, dz)
				if c.x < 0 or c.y < 0 or c.x >= WorldConfig.RES or c.y >= WorldConfig.RES:
					continue
				if not astar.is_point_solid(c):
					return c
	return base

func _cell_world(cell: Vector2i) -> Vector2:
	var step := WorldConfig.SIZE / float(WorldConfig.RES)
	return Vector2(
		-WorldConfig.SIZE * 0.5 + (float(cell.x) + 0.5) * step,
		-WorldConfig.SIZE * 0.5 + (float(cell.y) + 0.5) * step
	)

func _chaikin(pts: PackedVector2Array) -> PackedVector2Array:
	if pts.size() < 3:
		return pts
	var out := PackedVector2Array()
	out.append(pts[0])
	for i in range(pts.size() - 1):
		var a := pts[i]
		var b := pts[i + 1]
		out.append(a.lerp(b, 0.25))
		out.append(a.lerp(b, 0.75))
	out.append(pts[pts.size() - 1])
	return out

func _resample(pts: PackedVector2Array, spacing: float) -> void:
	polyline = PackedVector2Array()
	if pts.size() < 2:
		return
	polyline.append(pts[0])
	var carry := 0.0
	for i in range(pts.size() - 1):
		var a := pts[i]
		var b := pts[i + 1]
		var seg := a.distance_to(b)
		if seg < 0.001:
			continue
		var t := spacing - carry
		while t <= seg:
			polyline.append(a.lerp(b, t / seg))
			t += spacing
		carry = seg - (t - spacing)

func _update_bbox() -> void:
	if polyline.is_empty():
		bbox = Rect2()
		return
	var mn := polyline[0]
	var mx := polyline[0]
	for p in polyline:
		mn = Vector2(minf(mn.x, p.x), minf(mn.y, p.y))
		mx = Vector2(maxf(mx.x, p.x), maxf(mx.y, p.y))
	bbox = Rect2(mn, mx - mn)

func _recompute_water(hf: HeightField, lake_y: float) -> void:
	water_levels.resize(polyline.size())
	var wl := lake_y - 0.08
	for i in range(polyline.size()):
		var p := polyline[i]
		var h := hf.sample(p.x, p.y)
		wl = minf(wl - 0.02, h - 0.18)
		water_levels[i] = maxf(wl, WorldConfig.SEA_LEVEL - 0.6)

func _carve(hf: HeightField) -> void:
	for i in range(polyline.size()):
		hf.carve_stamp(
			polyline[i],
			water_levels[i],
			WorldConfig.RIVER.width,
			WorldConfig.RIVER.depth,
			WorldConfig.RIVER.bank,
			WorldConfig.RIVER.valley
		)

func _detect_waterfalls(hf: HeightField) -> void:
	var i := 1
	while i < polyline.size():
		var drop: float = water_levels[i - 1] - water_levels[i]
		if drop <= 0.5:
			i += 1
			continue
		var start := i
		var guard := 0
		while i < polyline.size() and (water_levels[i - 1] - water_levels[i]) > 0.1 and guard < 16:
			i += 1
			guard += 1
		var end := maxi(start, i - 1)
		var total := water_levels[start - 1] - water_levels[end]
		if total >= 1.6 and water_levels[end] > WorldConfig.SEA_LEVEL + 0.8 and waterfalls.size() < WorldConfig.RIVER.max_waterfalls:
			var dir := (polyline[end] - polyline[start - 1]).normalized()
			if dir == Vector2.ZERO:
				dir = Vector2.RIGHT
			waterfalls.append({
				"top": Vector3(polyline[start - 1].x, water_levels[start - 1], polyline[start - 1].y),
				"bottom": Vector3(polyline[end].x, water_levels[end], polyline[end].y),
				"dir": dir,
				"width": WorldConfig.RIVER.width * 1.35,
				"span": Vector2i(start, end),
			})
			waterfall_spans.append(Vector2i(start, end))
			hf.lower_circle(polyline[end], 9.0, water_levels[end] - 2.0)
		i += 1

func water_level_at(p: Vector2) -> float:
	if polyline.is_empty():
		return WorldConfig.SEA_LEVEL
	var best := 0
	var best_d := 1.0e18
	for i in range(polyline.size()):
		var d := p.distance_squared_to(polyline[i])
		if d < best_d:
			best_d = d
			best = i
	return water_levels[best] if best < water_levels.size() else WorldConfig.SEA_LEVEL

func is_water_at(p: Vector2, h: float) -> bool:
	if polyline.size() < 2 or bbox.size == Vector2.ZERO:
		return false
	if not bbox.grow(4.0).has_point(p):
		return false
	var best := 1.0e18
	var best_i := 0
	for i in range(polyline.size()):
		var d := p.distance_squared_to(polyline[i])
		if d < best:
			best = d
			best_i = i
	var limit := WorldConfig.RIVER.width * 0.5 + 1.5
	if best > limit * limit:
		return false
	return h < water_levels[best_i] + 0.4
