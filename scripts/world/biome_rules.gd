class_name BiomeRules
extends RefCounted

# Pure predicates. Easy to test without a scene and shared by every spawner.

static func is_cliff(slope_deg: float) -> bool:
	return slope_deg > 42.0

static func tree_allowed(ctx: Dictionary) -> bool:
	if float(ctx["height"]) < WorldConfig.SEA_LEVEL + 2.5:
		return false
	if float(ctx["slope_deg"]) > 28.0:
		return false
	if float(ctx["road"]) > 0.18:
		return false
	if float(ctx["dist_poi"]) < 12.0:
		return false
	var t := int(ctx["zone_type"])
	if t == WorldConfig.ZONE_LAKE or t == WorldConfig.ZONE_SWAMP:
		return false
	if t == WorldConfig.ZONE_FIELDS or t == WorldConfig.ZONE_CAMP:
		return false
	if t == WorldConfig.ZONE_RUINS or t == WorldConfig.ZONE_STONE_TOWER:
		return false
	return true

static func bush_allowed(ctx: Dictionary) -> bool:
	if float(ctx["height"]) < WorldConfig.SEA_LEVEL + 1.5:
		return false
	if float(ctx["slope_deg"]) > 30.0:
		return false
	if float(ctx["road"]) > 0.20:
		return false
	if float(ctx["dist_poi"]) < 10.0:
		return false
	var t := int(ctx["zone_type"])
	return t != WorldConfig.ZONE_LAKE and t != WorldConfig.ZONE_SWAMP

static func rock_allowed(ctx: Dictionary) -> bool:
	if float(ctx["height"]) < WorldConfig.SEA_LEVEL - 0.5:
		return false
	if float(ctx["slope_deg"]) > 48.0:
		return false
	if float(ctx["road"]) > 0.20:
		return false
	if float(ctx["dist_poi"]) < 10.0:
		return false
	return true

static func reed_allowed(ctx: Dictionary) -> bool:
	if absf(float(ctx["height"]) - float(ctx["water_y"])) > 0.9:
		return false
	if float(ctx["slope_deg"]) > 30.0:
		return false
	var t := int(ctx["zone_type"])
	return t == WorldConfig.ZONE_SWAMP or t == WorldConfig.ZONE_LAKE
