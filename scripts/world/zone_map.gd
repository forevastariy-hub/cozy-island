class_name ZoneMap
extends RefCounted

# Zone lookup with priorities. One authority for "which biome is here".

var zones: Array = []
var _priority := {
	WorldConfig.ZONE_GENERAL: 0,
	WorldConfig.ZONE_FIELDS: 6,
	WorldConfig.ZONE_LAKE: 9,
	WorldConfig.ZONE_SWAMP: 8,
	WorldConfig.ZONE_CAMP: 7,
	WorldConfig.ZONE_RUINS: 7,
	WorldConfig.ZONE_MOUNTAIN: 6,
	WorldConfig.ZONE_STONE_TOWER: 6,
	WorldConfig.ZONE_RADIO_TOWER: 6,
	WorldConfig.ZONE_PINE_FOREST: 5,
	WorldConfig.ZONE_DECIDUOUS_FOREST: 5,
}

func build(layout: PoiLayout) -> void:
	zones.clear()
	for name in layout.pois:
		var p: Dictionary = layout.pois[name]
		zones.append({
			"name": String(name),
			"center": p["center"],
			"size": p["size"],
			"type": int(p["type"]),
			"priority": int(_priority.get(int(p["type"]), 0)),
		})

func zone_at(x: float, z: float) -> Dictionary:
	var best := {}
	var best_priority := -1
	for zdef in zones:
		var sz: Vector2 = zdef["size"]
		var c: Vector2 = zdef["center"]
		var nx := (x - c.x) / maxf(1.0, sz.x * 0.5)
		var nz := (z - c.y) / maxf(1.0, sz.y * 0.5)
		if nx * nx + nz * nz > 1.0:
			continue
		if int(zdef["priority"]) > best_priority:
			best_priority = int(zdef["priority"])
			best = zdef
	return best

func type_at(x: float, z: float) -> int:
	var zdef := zone_at(x, z)
	if zdef.is_empty():
		return WorldConfig.ZONE_GENERAL
	return int(zdef["type"])

func def_by_type(zone_type: int) -> Dictionary:
	for zdef in zones:
		if int(zdef["type"]) == zone_type:
			return zdef
	return {}

func as_legacy() -> Array:
	var out := []
	for zdef in zones:
		var sz: Vector2 = zdef["size"]
		out.append({
			"name": zdef["name"],
			"center": zdef["center"],
			"radius": sz.x * 0.5,
			"type": zdef["type"],
		})
	return out
