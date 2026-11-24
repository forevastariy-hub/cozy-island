class_name WorldScatterer
extends RefCounted

# One placement loop for every species. Species follow the biome grid (height,
# moisture, temperature), so forests grow where the climate allows.

var placements: Array = []
var tree_points: Array[Vector3] = []

func build(hf: HeightField, zones: ZoneMap, painter: TerrainPainter, layout: PoiLayout, river: RiverBuilder, rng: WorldRng) -> void:
	placements.clear()
	tree_points.clear()
	_scatter_species(hf, zones, painter, layout, river, rng, "pine", int(WorldConfig.SCATTER["pine"]), WorldConfig.ZONE_PINE_FOREST)
	_scatter_species(hf, zones, painter, layout, river, rng, "decid", int(WorldConfig.SCATTER["decid"]), WorldConfig.ZONE_DECIDUOUS_FOREST)
	_scatter_lone_trees(hf, zones, painter, layout, river, rng, 45)
	_scatter_rocks(hf, zones, painter, layout, river, rng, int(WorldConfig.SCATTER["rock"]))
	_scatter_bushes(hf, zones, painter, layout, river, rng, int(WorldConfig.SCATTER["bush"]))
	_scatter_reeds(hf, zones, painter, layout, river, rng, int(WorldConfig.SCATTER["reed"]))

func _spacing_ok(hf: HeightField, p: Vector2, min_dist: float) -> bool:
	var pos := Vector3(p.x, 0.0, p.y)
	for q in tree_points:
		if (Vector3(q.x, 0.0, q.z)).distance_to(pos) < min_dist:
			return false
	return true

func _forest_spacing(hf: HeightField, p: Vector2) -> float:
	var moist := hf.moisture_at(p.x, p.y)
	var dense := clampf((moist - 0.5) / 0.35, 0.0, 1.0)
	return lerpf(10.0, 3.2, dense)

func _ctx(hf: HeightField, zones: ZoneMap, painter: TerrainPainter, layout: PoiLayout, river: RiverBuilder, x: float, z: float) -> Dictionary:
	var h := hf.sample(x, z)
	var zdef := zones.zone_at(x, z)
	var zt := int(zdef.get("type", WorldConfig.ZONE_GENERAL))
	var water_y := WorldConfig.SEA_LEVEL
	if zt == WorldConfig.ZONE_LAKE and layout.pois.has("lake"):
		water_y = float(layout.pois["lake"].get("y", WorldConfig.LAKE_Y))
	var water := false
	if h < WorldConfig.SEA_LEVEL + 0.25:
		water = true
	if not water and layout.pois.has("lake"):
		var lp: Dictionary = layout.pois["lake"]
		var lc: Vector2 = lp["center"]
		if h < WorldConfig.LAKE_Y and ShapeUtil.ellipse_norm(x, z, lc, lp["size"], ShapeUtil.phase_for(lc)) < 1.0:
			water = true
	if not water and river.is_water_at(Vector2(x, z), h):
		water = true
	var dpoi := 9999.0
	for name in layout.pois:
		dpoi = minf(dpoi, Vector2(x, z).distance_to(layout.pois[name]["center"]))
	return {
		"height": h,
		"slope_deg": hf.slope_deg(x, z),
		"zone_type": zt,
		"road": painter.path_at(x, z),
		"dist_poi": dpoi,
		"water_y": water_y,
		"water": water,
	}

func _random_land_point(rng: WorldRng) -> Vector2:
	var a := rng.randf_range(0.0, TAU)
	var r := rng.randf_range(18.0, 445.0)
	return Vector2(cos(a), sin(a)) * r

func _scatter_species(hf: HeightField, zones: ZoneMap, painter: TerrainPainter, layout: PoiLayout, river: RiverBuilder, rng: WorldRng, kind: String, count: int, target_type: int) -> void:
	var placed := 0
	for _i in range(count * 30):
		if placed >= count:
			break
		var p := _random_land_point(rng)
		if zones.type_at(p.x, p.y) != target_type:
			continue
		var ctx := _ctx(hf, zones, painter, layout, river, p.x, p.y)
		if not BiomeRules.tree_allowed(ctx):
			continue
		if not _spacing_ok(hf, p, _forest_spacing(hf, p)):
			continue
		var pos := Vector3(p.x, float(ctx["height"]), p.y)
		tree_points.append(pos)
		placements.append({
			"kind": kind,
			"pos": pos,
			"rot": rng.randf_range(0.0, TAU),
			"scale": rng.randf_range(0.85, 1.35),
		})
		placed += 1

func _scatter_lone_trees(hf: HeightField, zones: ZoneMap, painter: TerrainPainter, layout: PoiLayout, river: RiverBuilder, rng: WorldRng, count: int) -> void:
	var placed := 0
	for _i in range(count * 40):
		if placed >= count:
			break
		var p := _random_land_point(rng)
		var ctx := _ctx(hf, zones, painter, layout, river, p.x, p.y)
		if not BiomeRules.tree_allowed(ctx):
			continue
		if int(ctx["zone_type"]) == WorldConfig.ZONE_PINE_FOREST or int(ctx["zone_type"]) == WorldConfig.ZONE_DECIDUOUS_FOREST:
			continue
		if not _spacing_ok(hf, p, 16.0):
			continue
		var kind := "pine" if rng.randf() < 0.5 else "decid"
		var pos := Vector3(p.x, float(ctx["height"]), p.y)
		tree_points.append(pos)
		placements.append({
			"kind": kind,
			"pos": pos,
			"rot": rng.randf_range(0.0, TAU),
			"scale": rng.randf_range(0.95, 1.25),
		})
		placed += 1

func _scatter_rocks(hf: HeightField, zones: ZoneMap, painter: TerrainPainter, layout: PoiLayout, river: RiverBuilder, rng: WorldRng, count: int) -> void:
	var placed := 0
	for _i in range(count * 16):
		if placed >= count:
			break
		var p := _random_land_point(rng)
		var ctx := _ctx(hf, zones, painter, layout, river, p.x, p.y)
		if not BiomeRules.rock_allowed(ctx):
			continue
		placements.append({
			"kind": "rock",
			"pos": Vector3(p.x, float(ctx["height"]), p.y),
			"rot": rng.randf_range(0.0, TAU),
			"scale": rng.randf_range(0.7, 1.5),
		})
		placed += 1

func _scatter_bushes(hf: HeightField, zones: ZoneMap, painter: TerrainPainter, layout: PoiLayout, river: RiverBuilder, rng: WorldRng, count: int) -> void:
	var placed := 0
	for _i in range(count * 16):
		if placed >= count:
			break
		var p := _random_land_point(rng)
		var ctx := _ctx(hf, zones, painter, layout, river, p.x, p.y)
		if not BiomeRules.bush_allowed(ctx):
			continue
		placements.append({
			"kind": "bush",
			"pos": Vector3(p.x, float(ctx["height"]), p.y),
			"rot": rng.randf_range(0.0, TAU),
			"scale": 1.0,
		})
		placed += 1

func _scatter_reeds(hf: HeightField, zones: ZoneMap, painter: TerrainPainter, layout: PoiLayout, river: RiverBuilder, rng: WorldRng, count: int) -> void:
	var placed := 0
	for _i in range(count * 26):
		if placed >= count:
			break
		var p := _random_land_point(rng)
		var ctx := _ctx(hf, zones, painter, layout, river, p.x, p.y)
		if not BiomeRules.reed_allowed(ctx):
			continue
		placements.append({
			"kind": "reed",
			"pos": Vector3(p.x, float(ctx["height"]), p.y),
			"rot": rng.randf_range(0.0, TAU),
			"scale": rng.randf_range(0.8, 1.2),
		})
		placed += 1
