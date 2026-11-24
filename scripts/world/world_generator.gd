class_name WorldGenerator
extends RefCounted

# Facade that owns the generation pipeline. Order is fixed and each step only
# receives the dependencies it needs.

var world_seed := 424242
var coast := Coastline.new()
var hf := HeightField.new()
var layout := PoiLayout.new()
var zones := ZoneMap.new()
var river := RiverBuilder.new()
var roads := RoadBuilder.new()
var painter := TerrainPainter.new()
var mesh := TerrainMeshBuilder.new()
var water := WaterBuilder.new()
var scatter := WorldScatterer.new()

func generate(seed_value: int, parent: Node3D) -> void:
	world_seed = seed_value
	coast.build(WorldRng.new(seed_value, "coast"))
	hf.build_base(seed_value, coast)
	layout.place(hf, coast, WorldRng.new(seed_value, "poi"))
	hf.apply_pois(layout)
	river.build(hf, layout, coast, WorldRng.new(seed_value, "river"))
	hf.build_biomes()
	zones.build(layout, hf)
	roads.build(route_points(), hf, layout, river)
	painter.build(hf, zones, coast, roads)
	mesh.build(parent, hf, painter)
	water.build(parent, painter.mask_texture, layout, river)
	scatter.build(hf, zones, painter, layout, river, WorldRng.new(seed_value, "scatter"))

func is_water(x: float, z: float) -> bool:
	var h := hf.sample(x, z)
	if h < WorldConfig.SEA_LEVEL + 0.25:
		return true
	if layout.pois.has("lake"):
		var lp: Dictionary = layout.pois["lake"]
		var lc: Vector2 = lp["center"]
		if h < WorldConfig.LAKE_Y and ShapeUtil.ellipse_norm(x, z, lc, lp["size"], ShapeUtil.phase_for(lc)) < 1.0:
			return true
	return river.is_water_at(Vector2(x, z), h)

func route_points() -> Array:
	var out: Array = []
	var order := ["camp", "ruins", "swamp", "stone_tower", "fields", "radio_tower", "mountain", "lake", "camp"]
	for name in order:
		if not layout.pois.has(name):
			continue
		var p: Dictionary = layout.pois[name]
		var c: Vector2 = p["center"]
		if name == "swamp" or name == "lake":
			var camp_c: Vector2 = layout.pois["camp"]["center"]
			c += (camp_c - c).normalized() * ((p["size"] as Vector2).x * 0.42)
		out.append(c)
	if layout.pois.has("fields") and layout.pois.has("camp"):
		out.append(layout.pois["fields"]["center"])
	if out.size() < 2:
		out = [Vector2(0.0, 60.0), Vector2(0.0, -60.0)]
	return out

func rebuild_roads(points: Array) -> void:
	if points.size() < 2:
		return
	roads.build(points, hf, layout, river)
	painter.build(hf, zones, coast, roads)
	if mesh.material != null:
		mesh.apply_mask(painter.mask_texture)
	water.apply_mask(painter.mask_texture)

func poi_points() -> Dictionary:
	return layout.poi_points()

func heights_hash() -> int:
	var acc := 0
	for i in range(0, hf.grid.size(), 7):
		acc = int((acc * 31 + int(round(hf.grid[i] * 10.0))) % 2147483647)
	return acc
