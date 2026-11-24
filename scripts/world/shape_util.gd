class_name ShapeUtil
extends RefCounted

# Deterministic lobed shapes for zones and terrain basins. One formula shared
# by zone lookup, height sculpting and the painter, so borders always match.

static func phase_for(center: Vector2) -> float:
	return fposmod(center.x * 0.013 + center.y * 0.017, TAU)

static func ellipse_norm(x: float, z: float, center: Vector2, size: Vector2, phase: float) -> float:
	var nx := (x - center.x) / maxf(1.0, size.x * 0.5)
	var nz := (z - center.y) / maxf(1.0, size.y * 0.5)
	var d := sqrt(nx * nx + nz * nz)
	var a := atan2(nz, nx)
	var wob := 1.0 \
		+ 0.13 * sin(3.0 * a + phase) \
		+ 0.08 * sin(5.0 * a + phase * 1.7 + 1.3) \
		+ 0.05 * sin(7.0 * a - phase * 0.7 + 2.2)
	return d / maxf(0.55, wob)
