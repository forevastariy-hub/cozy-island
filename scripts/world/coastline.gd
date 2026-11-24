class_name Coastline
extends RefCounted

# Analytic island contour: radius is a function of the angle, so the land mask
# costs O(1) per sample. The polygon is only a derived view of the same curve.

var phase := 0.0
var islets: Array = []

func build(rng: WorldRng) -> void:
	phase = rng.randf_range(0.0, TAU)
	islets.clear()
	var angles := [-2.45, -2.05, 2.95, 2.55, 0.55, 1.05]
	for i in angles.size():
		var a: float = float(angles[i]) + rng.randf_range(-0.08, 0.08)
		var dist := radius_at(a) + rng.randf_range(38.0, 78.0)
		islets.append({
			"center": Vector2(cos(a), sin(a)) * dist,
			"radius": rng.randf_range(18.0, 32.0),
			"height": rng.randf_range(4.0, 6.5),
		})

func radius_at(a: float) -> float:
	var wob := 1.0 \
		+ 0.075 * sin(3.0 * a + phase) \
		+ 0.045 * sin(5.0 * a + phase * 1.7 + 2.1) \
		+ 0.030 * sin(7.0 * a - phase * 0.6 + 4.3)
	var base := WorldConfig.COAST_RADIUS
	var north := maxf(-sin(a), 0.0)
	var south := maxf(sin(a), 0.0)
	base *= 1.0 - 0.07 * north + 0.04 * south
	return base * wob

func signed_distance(x: float, z: float) -> float:
	var p := Vector2(x, z)
	return radius_at(p.angle()) - p.length()

func land_mask(x: float, z: float) -> float:
	return smoothstep(WorldConfig.COAST_BLEND_IN, WorldConfig.COAST_BLEND_OUT, signed_distance(x, z))

func polygon(steps: int = 160) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in steps:
		var a := TAU * float(i) / float(steps)
		out.append(Vector2(cos(a), sin(a)) * radius_at(a))
	return out
