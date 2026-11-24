extends Node3D

# Decorative reeds for the swamp and lake shallows. No interaction.

var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.seed = int(absf(global_position.x * 13.0 + global_position.z * 7.0)) + 17
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.34, 0.42, 0.19)
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var stalks := rng.randi_range(5, 9)
	for _i in range(stalks):
		var h := rng.randf_range(0.7, 1.5)
		var mi := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.012
		cyl.bottom_radius = 0.028
		cyl.height = h
		cyl.radial_segments = 4
		mi.mesh = cyl
		mi.material_override = mat
		mi.position = Vector3(rng.randf_range(-0.35, 0.35), h * 0.5, rng.randf_range(-0.35, 0.35))
		mi.rotation = Vector3(rng.randf_range(-0.15, 0.15), rng.randf_range(0.0, TAU), rng.randf_range(-0.15, 0.15))
		add_child(mi)
