class_name RoadBuilder
extends RefCounted

# Weighted A* over the height field. Slopes cost extra, water is impassable,
# and every river crossing becomes a bridge instead of a ford.

var segments: Array = []
var bridges: Array = []

func build(points: Array, hf: HeightField, layout: PoiLayout, river: RiverBuilder) -> void:
	segments.clear()
	bridges.clear()
	if points.size() < 2:
		return
	var astar := _make_astar(hf, layout)
	var prev_cell := _nearest_cell(astar, points[0])
	for i in range(1, points.size()):
		var cell := _nearest_cell(astar, points[i])
		if cell == prev_cell:
			continue
		var id_path := astar.get_id_path(prev_cell, cell)
		if id_path.size() < 2:
			prev_cell = cell
			continue
		var raw := PackedVector2Array()
		for id in id_path:
			raw.append(_cell_world(id))
		segments.append(_chaikin(_chaikin(raw)))
		prev_cell = cell
	_find_bridges(river, hf)
	_ensure_crossings(river, hf)

func _make_astar(hf: HeightField, layout: PoiLayout) -> AStarGrid2D:
	var astar := AStarGrid2D.new()
	astar.region = Rect2i(0, 0, WorldConfig.RES, WorldConfig.RES)
	astar.cell_size = Vector2(hf.cell, hf.cell)
	astar.offset = Vector2(-WorldConfig.SIZE * 0.5, -WorldConfig.SIZE * 0.5)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	var lake: Dictionary = layout.pois.get("lake", {})
	var has_weight := astar.has_method("set_point_weight_scale")
	for zi in range(WorldConfig.RES):
		var wz := -WorldConfig.SIZE * 0.5 + (float(zi) + 0.5) * hf.cell
		for xi in range(WorldConfig.RES):
			var wx := -WorldConfig.SIZE * 0.5 + (float(xi) + 0.5) * hf.cell
			var h := hf.sample(wx, wz)
			var slope := hf.slope_deg(wx, wz)
			var solid := h < WorldConfig.SEA_LEVEL + 0.6 or slope > WorldConfig.ROAD.max_slope_deg
			if not lake.is_empty():
				var c: Vector2 = lake["center"]
				var sz: Vector2 = lake["size"]
				var nx := (wx - c.x) / maxf(1.0, sz.x * 0.45)
				var nz := (wz - c.y) / maxf(1.0, sz.y * 0.45)
				if nx * nx + nz * nz < 1.0:
					solid = true
			var cell := Vector2i(xi, zi)
			astar.set_point_solid(cell, solid)
			if has_weight:
				var w := 1.0 + pow(maxf(slope - 8.0, 0.0) / 10.0, 2.0) * 2.5
				astar.set_point_weight_scale(cell, w)
	return astar

func _nearest_cell(astar: AStarGrid2D, pos: Vector2) -> Vector2i:
	var step := astar.cell_size.x
	var base := Vector2i(
		clampi(int(round((pos.x + WorldConfig.SIZE * 0.5) / step - 0.5)), 0, WorldConfig.RES - 1),
		clampi(int(round((pos.y + WorldConfig.SIZE * 0.5) / step - 0.5)), 0, WorldConfig.RES - 1)
	)
	if not astar.is_point_solid(base):
		return base
	for r in range(1, 10):
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

func _find_bridges(river: RiverBuilder, hf: HeightField) -> void:
	if river.polyline.size() < 2:
		return
	for seg in segments:
		var pts: PackedVector2Array = seg
		for i in range(0, pts.size() - 1, 2):
			var a := pts[i]
			var b := pts[mini(i + 2, pts.size() - 1)]
			if a.distance_to(b) < 2.0:
				continue
			for k in range(0, river.polyline.size() - 1):
				var c := river.polyline[k]
				var d := river.polyline[k + 1]
				if absf(a.x - c.x) > 90.0 or absf(a.y - c.y) > 90.0:
					continue
				var hit = Geometry2D.segment_intersects_segment(a, b, c, d)
				if hit == null:
					continue
				var hp: Vector2 = hit
				var rdir := (d - c).normalized()
				var br := _bridge_at(hp, rdir, river, hf)
				if br.is_empty():
					continue
				bridges.append(br)
				if bridges.size() >= 3:
					return

func _has_bridge_near(p: Vector2) -> bool:
	for br in bridges:
		var pos: Vector3 = br["pos"]
		if Vector2(pos.x, pos.z).distance_to(p) < 42.0:
			return true
	return false

func _ensure_crossings(river: RiverBuilder, hf: HeightField) -> void:
	if river.polyline.size() < 10:
		return
	for f in [0.24, 0.52, 0.76]:
		if bridges.size() >= 3:
			break
		var idx := clampi(int(float(river.polyline.size()) * float(f)), 2, river.polyline.size() - 3)
		var p := river.polyline[idx]
		var dir := (river.polyline[idx + 1] - river.polyline[idx - 1]).normalized()
		if dir == Vector2.ZERO:
			continue
		var br := _bridge_at(p, dir, river, hf)
		if br.is_empty():
			continue
		segments.append(PackedVector2Array([br["a"], p, br["b"]]))
		bridges.append(br)

func _bridge_at(p: Vector2, rdir: Vector2, river: RiverBuilder, hf: HeightField) -> Dictionary:
	var wl := river.water_level_at(p)
	if wl < WorldConfig.SEA_LEVEL + 1.0:
		return {}
	if _has_bridge_near(p):
		return {}
	var perp := Vector2(-rdir.y, rdir.x)
	var half := 3.0
	var ha := 0.0
	var hb := 0.0
	while half < 34.0:
		var ta := p + perp * half
		var tb := p - perp * half
		ha = hf.sample(ta.x, ta.y)
		hb = hf.sample(tb.x, tb.y)
		if ha > wl + 0.6 and hb > wl + 0.6:
			break
		half += 1.5
	if half >= 34.0:
		return {}
	var span := half * 2.0 + 2.0
	var deck := maxf(ha, hb) + 0.25
	return {
		"pos": Vector3(p.x, deck, p.y),
		"dir": Vector3(rdir.x, 0.0, rdir.y),
		"width": span,
		"water_y": wl,
		"a": p + perp * half,
		"b": p - perp * half,
	}

func flat_segments() -> Array:
	var out := []
	for seg in segments:
		var pts: PackedVector2Array = seg
		for i in range(pts.size() - 1):
			out.append([pts[i], pts[i + 1]])
	return out
