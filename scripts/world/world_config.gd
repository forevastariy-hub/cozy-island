class_name WorldConfig
extends RefCounted

# Single source of truth for world tuning. No other class stores magic numbers.

const SIZE := 1000.0
const RES := 256
const SEA_LEVEL := -2.0
const SEABED := -9.0
const MAX_HEIGHT := 88.0

const COAST_RADIUS := 430.0
const COAST_BLEND_IN := -18.0
const COAST_BLEND_OUT := 22.0

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

const LAKE_Y := 8.0
const SWAMP_Y := -1.2

# Placement rules: structures keep their distance, towers keep their sector.
const STRUCTURES := ["camp", "mountain", "radio_tower", "stone_tower", "ruins"]
const TOWERS := ["mountain", "radio_tower", "stone_tower"]
const MAJOR_MIN := 220.0
const TOWERS_MIN := 260.0
const TOWER_ANGLE_MIN := 65.0

const POI := {
	"camp": {
		"ring": Vector2(40.0, 110.0), "size": Vector2(110.0, 100.0),
		"y": 7.5, "type": ZONE_CAMP
	},
	"lake": {
		"ring": Vector2(70.0, 160.0), "size": Vector2(170.0, 120.0),
		"y": 8.0, "depth": 4.5, "type": ZONE_LAKE,
		"min_camp": Vector2(95.0, 165.0)
	},
	"mountain": {
		"ring": Vector2(240.0, 340.0), "size": Vector2(230.0, 230.0),
		"y": 36.0, "plateau_r": 26.0, "type": ZONE_MOUNTAIN,
		"min": {"camp": 230.0, "lake": 130.0}
	},
	"radio_tower": {
		"ring": Vector2(250.0, 350.0), "size": Vector2(250.0, 250.0),
		"y": 44.0, "plateau_r": 28.0, "type": ZONE_RADIO_TOWER,
		"min": {"camp": 240.0, "mountain": 260.0}
	},
	"stone_tower": {
		"ring": Vector2(300.0, 400.0), "size": Vector2(140.0, 140.0),
		"y": 26.0, "plateau_r": 22.0, "type": ZONE_STONE_TOWER,
		"coast_max": 60.0,
		"min": {"camp": 250.0, "mountain": 260.0, "radio_tower": 260.0}
	},
	"ruins": {
		"ring": Vector2(200.0, 310.0), "size": Vector2(160.0, 150.0),
		"y": 14.0, "type": ZONE_RUINS,
		"min": {"camp": 190.0, "stone_tower": 220.0, "mountain": 220.0, "radio_tower": 220.0}
	},
	"fields": {
		"ring": Vector2(180.0, 290.0), "size": Vector2(260.0, 210.0),
		"y": 9.0, "type": ZONE_FIELDS,
		"min": {"camp": 170.0, "swamp": 250.0}
	},
	"swamp": {
		"ring": Vector2(230.0, 340.0), "size": Vector2(240.0, 200.0),
		"y": -1.2, "type": ZONE_SWAMP,
		"min": {"camp": 180.0, "mountain": 240.0, "radio_tower": 240.0, "stone_tower": 240.0}
	},
}

const RIVER := {
	"step": 14.0,
	"sample": 3.0,
	"width": 8.0,
	"depth": 1.3,
	"bank": 3.5,
	"valley": 12.0,
	"waterfall_drop": 1.1,
	"max_waterfalls": 3
}

const ROAD := {
	"width": 5.0,
	"max_slope_deg": 32.0,
	"bridge_cost": 25.0,
	"bridge_span": 12.0
}

const SCATTER := {
	"pine": 320,
	"decid": 300,
	"rock": 140,
	"bush": 120,
	"reed": 90
}
