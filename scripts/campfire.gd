extends "res://scripts/interactable.gd"

var light: OmniLight3D
var flame: MeshInstance3D
var inner: MeshInstance3D
var sparks: CPUParticles3D
var lit := true
var _t := 0.0
var _wet_time := 0.0
var _comfort_tick := 0.0

func _ready() -> void:
	prompt_text = "Отдохнуть у костра" if lit else "Разжечь костёр"
	add_to_group("rest_spot")
	add_to_group("path_poi")
	add_to_group("campfire")
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.8
	shape.height = 0.6
	col.shape = shape
	col.position.y = 0.3
	add_child(col)

	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.55, 0.52, 0.46)
	stone.roughness = 1.0

	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.38, 0.24, 0.13)
	wood.roughness = 1.0

	var charcoal := StandardMaterial3D.new()
	charcoal.albedo_color = Color(0.16, 0.12, 0.09)
	charcoal.roughness = 1.0

	for i in range(9):
		var a := TAU * float(i) / 9.0
		var rock := MeshInstance3D.new()
		var rs := SphereMesh.new()
		rs.radius = 0.15
		rs.height = 0.24
		rs.radial_segments = 5
		rs.rings = 3
		rock.mesh = rs
		rock.material_override = stone
		rock.position = Vector3(cos(a) * 0.62, 0.1, sin(a) * 0.62)
		rock.rotation = Vector3(0.0, a, 0.0)
		add_child(rock)

	for i in range(4):
		var a := TAU * float(i) / 4.0 + 0.35
		var log := MeshInstance3D.new()
		var lc := CylinderMesh.new()
		lc.top_radius = 0.07
		lc.bottom_radius = 0.09
		lc.height = 0.9
		lc.radial_segments = 6
		log.mesh = lc
		log.material_override = wood
		log.position = Vector3(cos(a) * 0.12, 0.18, sin(a) * 0.12)
		log.rotation = Vector3(PI * 0.5, a, 0.0)
		add_child(log)

	for i in range(6):
		var a := TAU * float(i) / 6.0
		var coal := MeshInstance3D.new()
		var cs := SphereMesh.new()
		cs.radius = 0.08
		cs.height = 0.14
		cs.radial_segments = 5
		cs.rings = 3
		coal.mesh = cs
		coal.material_override = charcoal
		coal.position = Vector3(cos(a) * 0.24, 0.2, sin(a) * 0.24)
		add_child(coal)

	flame = MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.3
	cone.height = 0.75
	cone.radial_segments = 8
	flame.mesh = cone
	var fmat := StandardMaterial3D.new()
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmat.albedo_color = Color(0.35, 0.15, 0.04)
	fmat.emission_enabled = true
	fmat.emission = Color(1.0, 0.55, 0.12)
	fmat.emission_energy_multiplier = 4.0
	fmat.disable_fog = true
	flame.material_override = fmat
	flame.position.y = 0.55
	add_child(flame)

	inner = MeshInstance3D.new()
	var ic := CylinderMesh.new()
	ic.top_radius = 0.0
	ic.bottom_radius = 0.16
	ic.height = 0.45
	ic.radial_segments = 7
	inner.mesh = ic
	var imat := StandardMaterial3D.new()
	imat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	imat.albedo_color = Color(0.5, 0.35, 0.1)
	imat.emission_enabled = true
	imat.emission = Color(1.0, 0.85, 0.4)
	imat.emission_energy_multiplier = 5.0
	imat.disable_fog = true
	inner.material_override = imat
	inner.position.y = 0.42
	add_child(inner)

	light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.25)
	light.light_energy = 2.2
	light.omni_range = 8.0
	light.position.y = 0.9
	add_child(light)

func _process(delta: float) -> void:
	_t += delta
	light.light_energy = 2.2 + sin(_t * 11.0) * 0.25 + sin(_t * 23.0) * 0.12
	flame.scale = Vector3.ONE * (0.92 + sin(_t * 9.0) * 0.08)

func interact(player: Node) -> void:
	if player != null and player.has_method("toggle_rest"):
		player.toggle_rest(self)

func toggle_rest(player: Node) -> void:
	interact(player)
