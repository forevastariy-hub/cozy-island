extends "res://scripts/interactable.gd"

var busy := false

func _ready() -> void:
	prompt_text = "Рыбачить"
	add_to_group("path_poi")
	_build()

func _build() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.4, 0.26, 0.14)
	wood.roughness = 1.0

	var post := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.07
	cyl.bottom_radius = 0.1
	cyl.height = 1.3
	cyl.radial_segments = 6
	post.mesh = cyl
	post.material_override = wood
	post.position.y = 0.65
	add_child(post)

	var board := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.6, 0.34, 0.06)
	board.mesh = box
	board.material_override = wood
	board.position = Vector3(0, 1.15, 0.06)
	add_child(board)

	var arm := MeshInstance3D.new()
	var ab := BoxMesh.new()
	ab.size = Vector3(0.06, 0.06, 0.42)
	arm.mesh = ab
	arm.material_override = wood
	arm.position = Vector3(0, 1.36, 0.18)
	add_child(arm)

	var lamp_mat := StandardMaterial3D.new()
	lamp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lamp_mat.albedo_color = Color(0.3, 0.22, 0.1)
	lamp_mat.emission_enabled = true
	lamp_mat.emission = Color(1.0, 0.7, 0.3)
	lamp_mat.emission_energy_multiplier = 2.2
	var lamp := MeshInstance3D.new()
	var ls := SphereMesh.new()
	ls.radius = 0.09
	ls.height = 0.18
	ls.radial_segments = 6
	ls.rings = 4
	lamp.mesh = ls
	lamp.material_override = lamp_mat
	lamp.position = Vector3(0, 1.3, 0.38)
	add_child(lamp)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.72, 0.38)
	light.light_energy = 1.0
	light.omni_range = 4.0
	light.position = Vector3(0, 1.3, 0.38)
	add_child(light)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.6, 1.3, 0.6)
	col.shape = shape
	col.position.y = 0.65
	add_child(col)

func interact(_player: Node) -> void:
	if busy:
		return
	busy = true
	prompt_text = "Ждём поклёвки..."
	Game.toast("Забросил удочку...")
	await get_tree().create_timer(randf_range(2.5, 5.0)).timeout
	if not is_inside_tree():
		return
	prompt_text = "КЛЮЁТ!  [E]"
	Game.toast("Клюёт! Жми E")
	var start := Time.get_ticks_msec()
	var caught := false
	while Time.get_ticks_msec() - start < 1800:
		if Input.is_action_just_pressed("interact"):
			caught = true
			break
		await get_tree().process_frame
	if caught:
		Game.add_item("fish", 1)
		Game.toast("+1 рыба")
	else:
		Game.toast("Сорвалась...")
	busy = false
	prompt_text = "Рыбачить"
