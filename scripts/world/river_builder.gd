class_name RiverBuilder
extends RefCounted

# Traces a river downhill from the lake to the sea, carves it and finds
# waterfalls where the channel drops faster than the threshold.

var polyline := PackedVector2Array()
var water_levels := PackedFloat32Array()
var waterfalls: Array = []
var bbox := Rect2()
var _travel := 0.0

func build(hf: HeightField, layout: PoiLayout, coast: Coastline, rng: WorldRng) -> void:
	polyline = PackedVector2Array()
	water_levels = PackedFloat32Array()
	waterfalls.clear()
	_travel = 0.0
	if not layout.pois.has("lake") or not layout.pois.has("camp"):
		return
	var lake: Dictionary = layout.pois["lake"]
	var camp: Dictionary = layout.pois["camp"]
	var lake_c: Vector2 = lake["center"]
	var lake_size: Vector2 = lake["size"]
	var camp_c: Vector2 = camp["center"]
	var start_dir := (camp_c - lake_c).normalized()
	if start_dir == Vector2.ZERO:
		start_dir = Vector2.RIGHT
	var rx := maxf(1.0, lake_size.x * 0.5)
	var rz := maxf(1.0, lake_size.y * 0.5)
	var shore_r := 1.0 / sqrt(pow(start_dir.x / rx, 2.0) + pow(start_dir.y / rz, 2.0))
	var p := lake_c + start_dir * maxf(2.0, shore_r - 3.0)
	var dir := start_dir
	var raw := PackedVector2Array()
	raw.append(p)
	for _i in range(150):
		dir = _choose_dir(p, dir, hf, layout, coast, rng)
		p += dir * WorldConfig.RIVER.step
		_travel += WorldConfig.RIVER.step
		raw.append(p)
		var h := hf.sample(p.x, p.y)
		if h < WorldConfig.SEA_LEVEL + 0.3:
			break
		if coast.signed_distance(p.x, p.y) < -8.0:
			break
	if raw.size() > 1:
		var tail_dir := (raw[raw.size() - 1] - raw[raw.size() - 2]).normalized()
		for _k in range(3):
			raw.append(raw[raw.size() - 1] + tail_dir * 12.0)
	var smooth := _chaikin(raw)
	_resample(smooth, WorldConfig.RIVER.sample)
	_update_bbox()
	_recompute_water(hf)
	_carve(hf)
	_detect_waterfalls(hf)

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

func _choose_dir(p: Vector2, prev_dir: Vector2, hf: HeightField, layout: PoiLayout, coast: Coastline, rng: WorldRng) -> Vector2:
	var best := prev_dir
	var best_score := 1.0e18
	var avoid := ["camp", "fields", "ruins", "stone_tower", "mountain", "radio_tower"]
	var lake: Dictionary = layout.pois.get("lake", {})
	for i in range(16):
		var a := TAU * float(i) / 16.0 + rng.randf_range(-0.05, 0.05)
		var cand := Vector2(cos(a), sin(a))
		var np := p + cand * WorldConfig.RIVER.step
		var score := hf.sample(np.x, np.y)
		var desired := prev_dir.angle() + sin(_travel * 0.03) * 0.28
		score += absf(angle_difference(cand.angle(), desired)) * 5.0
		if not lake.is_empty():
			var lc: Vector2 = lake["center"]
			if ShapeUtil.ellipse_norm(np.x, np.y, lc, lake["size"], ShapeUtil.phase_for(lc)) < 1.08:
				score += 800.0
		for key in avoid:
			if not layout.pois.has(key):
				continue
			var c: Vector2 = layout.pois[key]["center"]
			var size: Vector2 = layout.pois[key]["size"]
			var r := minf(size.x, size.y) * 0.45
			if np.distance_to(c) < r:
				score += 400.0
		if coast.signed_distance(np.x, np.y) < -14.0:
			score += 300.0
		if score < best_score:
			best_score = score
			best = cand
	return best

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

func _recompute_water(hf: HeightField) -> void:
	water_levels.resize(polyline.size())
	var wl := WorldConfig.LAKE_Y
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
	for i in range(1, polyline.size()):
		var drop: float = water_levels[i - 1] - water_levels[i]
		if drop <= WorldConfig.RIVER.waterfall_drop:
			continue
		if waterfalls.size() >= WorldConfig.RIVER.max_waterfalls:
			break
		var top := Vector3(polyline[i - 1].x, water_levels[i - 1], polyline[i - 1].y)
		var bottom := Vector3(polyline[i].x, water_levels[i], polyline[i].y)
		var dir := (polyline[i] - polyline[i - 1]).normalized()
		waterfalls.append({
			"top": top,
			"bottom": bottom,
			"dir": dir,
			"width": WorldConfig.RIVER.width * 1.3,
		})
		hf.lower_circle(polyline[i], 9.0, water_levels[i] - 2.0)

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
