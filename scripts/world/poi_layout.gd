class_name PoiLayout
extends RefCounted

# Places structures with rejection sampling against one shared constraint
# table, so no two rules can drift apart. Forests are not placed here: they
# are derived from height, moisture and temperature by HeightField.

var pois := {}

const ORDER := ["camp", "lake", "mountain", "radio_tower", "stone_tower", "ruins", "fields", "swamp"]

func place(hf: HeightField, coast: Coastline, rng: WorldRng) -> void:
	pois.clear()
	for name in ORDER:
		_place_one(String(name), hf, coast, rng)

func _place_one(name: String, hf: HeightField, coast: Coastline, rng: WorldRng) -> void:
	var cfg: Dictionary = WorldConfig.POI[name]
	var center := Vector2.ZERO
	var found := false
	for relax in range(3):
		for _attempt in range(300):
			var cand := _candidate(name, cfg, coast, rng)
			if _violates(name, cand, hf, coast, relax):
				continue
			center = cand
			found = true
			break
		if found:
			break
	if not found:
		push_warning("PoiLayout: fallback placement for " + name)
		center = _candidate(name, cfg, coast, rng)
	pois[name] = {
		"name": name,
		"center": center,
		"size": cfg["size"],
		"radius": cfg["size"].x * 0.5,
		"type": cfg["type"],
		"y": cfg.get("y", 0.0),
		"plateau_r": cfg.get("plateau_r", 0.0),
	}

func _candidate(name: String, cfg: Dictionary, coast: Coastline, rng: WorldRng) -> Vector2:
	if name == "stone_tower":
		var a := rng.randf_range(0.0, TAU)
		var r := coast.radius_at(a) - rng.randf_range(18.0, 52.0)
		return Vector2(cos(a), sin(a)) * r
	var ring: Vector2 = cfg["ring"]
	var ang := rng.randf_range(0.0, TAU)
	var rad := rng.randf_range(ring.x, ring.y)
	return Vector2(cos(ang), sin(ang)) * rad

func _violates(name: String, cand: Vector2, hf: HeightField, coast: Coastline, relax: int) -> bool:
	var cfg: Dictionary = WorldConfig.POI[name]
	var mul := pow(0.9, float(relax))
	var d0 := cand.length()
	var ring: Vector2 = cfg["ring"]
	if name != "stone_tower" and (d0 < ring.x or d0 > ring.y * 1.02):
		return true

	if hf.sample(cand.x, cand.y) < WorldConfig.SEA_LEVEL + 1.0:
		return true
	if hf.slope_deg(cand.x, cand.y) > 32.0:
		return true

	if cfg.has("coast_max"):
		if absf(coast.signed_distance(cand.x, cand.y)) > float(cfg["coast_max"]):
			return true

	for other in pois:
		var other_name := String(other)
		var oc: Vector2 = pois[other]["center"]
		var dist := cand.distance_to(oc)
		var need := 0.0
		var ocfg: Dictionary = WorldConfig.POI.get(other_name, {})
		if WorldConfig.STRUCTURES.has(name) and WorldConfig.STRUCTURES.has(other_name):
			need = maxf(need, WorldConfig.MAJOR_MIN)
		if WorldConfig.TOWERS.has(name) and WorldConfig.TOWERS.has(other_name):
			need = maxf(need, WorldConfig.TOWERS_MIN)
			if _angle_gap_deg(cand, oc) < WorldConfig.TOWER_ANGLE_MIN:
				return true
		if cfg.has("min") and cfg["min"].has(other_name):
			need = maxf(need, float(cfg["min"][other_name]))
		if ocfg.has("min") and ocfg["min"].has(name):
			need = maxf(need, float(ocfg["min"][name]))
		if name == "lake" and other_name == "camp":
			need = 0.0
		if dist < need * mul:
			return true

	if name == "lake" and pois.has("camp"):
		var dc := cand.distance_to(pois["camp"]["center"])
		var band: Vector2 = WorldConfig.POI["lake"]["min_camp"]
		if dc < band.x or dc > band.y:
			return true
	return false

func _angle_gap_deg(a: Vector2, b: Vector2) -> float:
	return absf(rad_to_deg(angle_difference(a.angle(), b.angle())))

func poi_points() -> Dictionary:
	var out := {}
	for name in pois:
		out[name] = pois[name]["center"]
	return out

func min_structure_distance() -> float:
	var best := 1.0e9
	var names: Array = WorldConfig.STRUCTURES
	for i in range(names.size()):
		for j in range(i + 1, names.size()):
			var a: String = names[i]
			var b: String = names[j]
			if not pois.has(a) or not pois.has(b):
				continue
			best = minf(best, (pois[a]["center"] as Vector2).distance_to(pois[b]["center"]))
	return best
