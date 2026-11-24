class_name WorldScatterer
extends RefCounted

# One placement loop for every species. Rules live in BiomeRules, quotas in
# WorldConfig, so a new plant or rock is a data change, not new code.

var placements: Array = []

func build(hf: HeightField, zones: ZoneMap, painter: TerrainPainter, layout: PoiLayout, rng: WorldRng) -> void:
	placements.clear()
	_scatter_trees(hf, zones, painter, layout, rng, "pine", int(WorldConfig.SCATTER["pine"]), WorldConfig.ZONE_PINE_FOREST)
	_scatter_trees(hf, zones, painter, layout, rng, "decid", int(WorldConfig.SCATTER["decid"]), WorldConfig.ZONE_DECIDUOUS_FOREST)
	_scatter_rocks(hf, zones, painter, layout, rng, int(WorldConfig.SCATTER["rock"]))
	_scatter_bushes(hf, zones, painter, layout, rng, int(WorldConfig.SCATTER["bush"]))
	_scatter_reeds(hf, zones, painter, layout, rng, int(WorldConfig.SCATTER["reed"]))

func _ctx(hf: HeightField, zones: ZoneMap, painter: TerrainPainter, layout: PoiLayout, x: float, z: float) -> Dictionary:
	var h := hf.sample(x, z)
	var zdef := zones.zone_at(x, z)
	var zt := int(zdef.get("type", WorldConfig.ZONE_GENERAL))
	var water_y := WorldConfig.SEA_LEVEL
	if zt == WorldConfig.ZONE_LAKE:
		water_y = WorldConfig.LAKE_Y
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
	}

func _scatter_trees(hf: HeightField, zones: ZoneMap, painter: TerrainPainter, layout: PoiLayout, rng: WorldRng, kind: String, count: int, zone_type: int) -> void:
	var def := zones.def_by_type(zone_type)
	if def.is_empty():
		return
	var center: Vector2 = def["center"]
	var radii: Vector2 = (def["size"] as Vector2) * 0.5
	var placed := 0
	var attempts := count * 10
	for _i in range(attempts):
		if placed >= count:
			break
		var p := rng.random_in_ellipse(center, radii, 0.92)
		if zones.type_at(p.x, p.y) != zone_type:
			continue
		var ctx := _ctx(hf, zones, painter, layout, p.x, p.y)
		if not BiomeRules.tree_allowed(ctx):
			continue
		placements.append({
			"kind": kind,
			"pos": Vector3(p.x, float(ctx["height"]), p.y),
			"rot": rng.randf_range(0.0, TAU),
			"scale": rng.randf_range(0.85, 1.35),
		})
		placed += 1

func _scatter_rocks(hf: HeightField, zones: ZoneMap, painter: TerrainPainter, layout: PoiLayout, rng: WorldRng, count: int) -> void:
	var placed := 0
	for _i in range(count * 12):
		if placed >= count:
			break
		var a := rng.randf_range(0.0, TAU)
		var r := rng.randf_range(12.0, 470.0)
		var p := Vector2(cos(a), sin(a)) * r
		var ctx := _ctx(hf, zones, painter, layout, p.x, p.y)
		if not BiomeRules.rock_allowed(ctx):
			continue
		placements.append({
			"kind": "rock",
			"pos": Vector3(p.x, float(ctx["height"]), p.y),
			"rot": rng.randf_range(0.0, TAU),
			"scale": rng.randf_range(0.7, 1.5),
		})
		placed += 1

func _scatter_bushes(hf: HeightField, zones: ZoneMap, painter: TerrainPainter, layout: PoiLayout, rng: WorldRng, count: int) -> void:
	var placed := 0
	for _i in range(count * 12):
		if placed >= count:
			break
		var a := rng.randf_range(0.0, TAU)
		var r := rng.randf_range(30.0, 450.0)
		var p := Vector2(cos(a), sin(a)) * r
		var ctx := _ctx(hf, zones, painter, layout, p.x, p.y)
		if not BiomeRules.bush_allowed(ctx):
			continue
		placements.append({
			"kind": "bush",
			"pos": Vector3(p.x, float(ctx["height"]), p.y),
			"rot": rng.randf_range(0.0, TAU),
			"scale": 1.0,
		})
		placed += 1

func _scatter_reeds(hf: HeightField, zones: ZoneMap, painter: TerrainPainter, layout: PoiLayout, rng: WorldRng, count: int) -> void:
	var spots: Array = []
	for zt in [WorldConfig.ZONE_SWAMP, WorldConfig.ZONE_LAKE]:
		var def := zones.def_by_type(zt)
		if not def.is_empty():
			spots.append(def)
	if spots.is_empty():
		return
	var placed := 0
	for _i in range(count * 14):
		if placed >= count:
			break
		var def: Dictionary = spots[rng.randi_range(0, spots.size() - 1)]
		var p := rng.random_in_ellipse(def["center"], (def["size"] as Vector2) * 0.5, 1.05)
		var ctx := _ctx(hf, zones, painter, layout, p.x, p.y)
		if not BiomeRules.reed_allowed(ctx):
			continue
		placements.append({
			"kind": "reed",
			"pos": Vector3(p.x, float(ctx["height"]), p.y),
			"rot": rng.randf_range(0.0, TAU),
			"scale": rng.randf_range(0.8, 1.2),
		})
		placed += 1
