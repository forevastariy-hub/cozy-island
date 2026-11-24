class_name Coastline
extends RefCounted

# Noise-driven island outline: bays, peninsulas and a ragged shore instead of
# a perfect circle. Distances are signed and in metres.

var _noise: FastNoiseLite

func build(rng: WorldRng) -> void:
	_noise = FastNoiseLite.new()
	_noise.seed = rng.rng().seed
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0
	_noise.fractal_octaves = 5
	_noise.fractal_gain = 0.5

func effective_radius(x: float, z: float) -> float:
	var n1 := _noise.get_noise_2d(x * 0.0015, z * 0.0015)
	var n2 := _noise.get_noise_2d(x * 0.0055, z * 0.0055)
	var n3 := _noise.get_noise_2d(x * 0.016, z * 0.016)
	var base := 350.0 + n1 * 150.0 + n2 * 58.0 + n3 * 16.0
	var p := Vector2(x, z)
	if p.length() > 0.01:
		var north := maxf(-p.normalized().y, 0.0)
		base *= 1.0 - 0.06 * north
	return base

func signed_distance(x: float, z: float) -> float:
	return effective_radius(x, z) - Vector2(x, z).length()

func radius_at(a: float) -> float:
	var dir := Vector2(cos(a), sin(a))
	var lo := 80.0
	var hi := 560.0
	for _i in range(24):
		var mid := (lo + hi) * 0.5
		if signed_distance(dir.x * mid, dir.y * mid) > 0.0:
			lo = mid
		else:
			hi = mid
	return lo

func polygon(steps: int = 180) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in steps:
		var a := TAU * float(i) / float(steps)
		out.append(Vector2(cos(a), sin(a)) * radius_at(a))
	return out
