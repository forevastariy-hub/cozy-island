extends Node3D

# Thin facade. The public API stays the same as before the refactor, so player,
# UI, flora, grass and day/night keep working unchanged.

const GrassFieldScript = preload("res://scripts/grass_field.gd")
const WorldGen = preload("res://scripts/world/world_generator.gd")

const SIZE := 1000.0
const RES := 256
const WATER_LEVEL := -2.0
const MAX_HEIGHT := 88.0

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

var world := WorldGen.new()
var grass: MultiMeshInstance3D
var ground_material: ShaderMaterial
var water_material: ShaderMaterial
var pois: Dictionary = {}
var CAMP_C := Vector2.ZERO
var FIELDS_C := Vector2.ZERO
var LAKE_C := Vector2.ZERO
var _zones: Array = []
var _path_segments: Array = []

func _ready() -> void:
	build()

func build() -> void:
	var seed_value := 424242
	if Game != null:
		seed_value = Game.world_seed
	world.generate(seed_value, self)
	pois = world.poi_points()
	CAMP_C = pois.get("camp", Vector2.ZERO)
	FIELDS_C = pois.get("fields", Vector2.ZERO)
	LAKE_C = pois.get("lake", Vector2.ZERO)
	_zones = world.zones.as_legacy()
	ground_material = world.mesh.material
	water_material = world.water.material
	_path_segments = world.roads.flat_segments()

func get_height(x: float, z: float) -> float:
	return world.hf.sample(x, z)

func get_normal(x: float, z: float) -> Vector3:
	return world.hf.sample_normal(x, z)

func get_zone(x: float, z: float) -> Vector4:
	return world.painter.get_zone(x, z)

func get_zone_type(x: float, z: float) -> int:
	if world.hf.sample(x, z) < WATER_LEVEL + 0.25:
		return ZONE_LAKE
	return world.zones.type_at(x, z)

func get_minimap_texture(map_size: int = 320) -> ImageTexture:
	return world.painter.minimap_texture(map_size)

func is_water(x: float, z: float) -> bool:
	return world.is_water(x, z)

func build_paths(points: Array) -> void:
	var pts: Array = []
	for p in points:
		if p is Vector3:
			pts.append(Vector2(p.x, p.z))
		elif p is Vector2:
			pts.append(p)
	world.rebuild_roads(pts)
	_path_segments = world.roads.flat_segments()

func build_grass() -> void:
	if grass != null:
		grass.queue_free()
		grass = null
	grass = GrassFieldScript.new()
	grass.name = "Grass"
	add_child(grass)
	grass.build(self)
