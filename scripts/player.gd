extends CharacterBody3D

const WALK_SPEED := 5.2
const SPRINT_SPEED := 8.2
const JUMP_VELOCITY := 6.0
const GRAVITY := 22.0
const MOUSE_SENS := 0.0025
const REACH := 4.5

var ui: CanvasLayer
var terrain: Node3D
var world: Node3D
var camera_pivot: Node3D
var spring_arm: SpringArm3D
var camera: Camera3D
var visual: Node3D
var interact_ray: RayCast3D
var ghost: Node3D

var left_arm: Node3D
var right_arm: Node3D
var left_leg: Node3D
var right_leg: Node3D

var _yaw := 0.0
var _pitch := -0.32
var _bob_time := 0.0
var _target: Node = null
var sitting := false
var rest_spot: Node = null
var _saved_cam_y := 1.55
var _saved_spring := 6.0
var _saved_pitch := -0.32

func _ready() -> void:
	add_to_group("player")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--yaw="):
			_yaw = deg_to_rad(float(arg.split("=")[1]))
		if arg.begins_with("--pitch="):
			_pitch = deg_to_rad(float(arg.split("=")[1]))
	_build_body()
	_build_visual()
	_build_camera()
	camera_pivot.rotation.y = _yaw
	spring_arm.rotation.x = _pitch
	_build_ray()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _build_body() -> void:
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.36
	cap.height = 1.7
	col.shape = cap
	col.position.y = 0.9
	add_child(col)

func _mat(color: Color, roughness := 0.9, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m

func _build_visual() -> void:
	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)

	var hoodie := _mat(Color(0.72, 0.52, 0.26))
	var hoodie_dark := _mat(Color(0.55, 0.38, 0.19))
	var jeans := _mat(Color(0.18, 0.24, 0.38))
	var skin := _mat(Color(0.85, 0.68, 0.55), 1.0)
	var hair := _mat(Color(0.22, 0.14, 0.08), 1.0)
	var shoe := _mat(Color(0.9, 0.88, 0.82), 0.8)
	var beanie := _mat(Color(0.2, 0.48, 0.48), 0.95)
	var pack := _mat(Color(0.4, 0.26, 0.14), 0.95)
	var strap := _mat(Color(0.3, 0.2, 0.12), 0.95)
	var dark := _mat(Color(0.12, 0.09, 0.07), 0.6)

	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.34
	cap.height = 1.15
	body.mesh = cap
	body.material_override = hoodie
	body.position.y = 0.85
	visual.add_child(body)

	var collar := MeshInstance3D.new()
	var cc := CylinderMesh.new()
	cc.top_radius = 0.29
	cc.bottom_radius = 0.37
	cc.height = 0.2
	cc.radial_segments = 8
	collar.mesh = cc
	collar.material_override = hoodie_dark
	collar.position.y = 1.38
	visual.add_child(collar)

	var head := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.26
	sph.height = 0.52
	head.mesh = sph
	head.material_override = skin
	head.position.y = 1.62
	visual.add_child(head)

	var hair_mesh := MeshInstance3D.new()
	var hs := SphereMesh.new()
	hs.radius = 0.275
	hs.height = 0.34
	hair_mesh.mesh = hs
	hair_mesh.material_override = hair
	hair_mesh.position.y = 1.73
	visual.add_child(hair_mesh)

	var hat := MeshInstance3D.new()
	var hc := CylinderMesh.new()
	hc.top_radius = 0.27
	hc.bottom_radius = 0.27
	hc.height = 0.16
	hc.radial_segments = 8
	hat.mesh = hc
	hat.material_override = beanie
	hat.position.y = 1.84
	visual.add_child(hat)

	var pom := MeshInstance3D.new()
	var ps := SphereMesh.new()
	ps.radius = 0.07
	ps.height = 0.14
	ps.radial_segments = 6
	ps.rings = 4
	pom.mesh = ps
	pom.material_override = beanie
	pom.position.y = 1.95
	visual.add_child(pom)

	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var es := SphereMesh.new()
		es.radius = 0.022
		es.height = 0.044
		es.radial_segments = 6
		es.rings = 3
		eye.mesh = es
		eye.material_override = dark
		eye.position = Vector3(side * 0.085, 1.63, -0.235)
		visual.add_child(eye)

	var nose := MeshInstance3D.new()
	var nb := BoxMesh.new()
	nb.size = Vector3(0.08, 0.08, 0.1)
	nose.mesh = nb
	nose.material_override = skin
	nose.position = Vector3(0, 1.6, -0.25)
	visual.add_child(nose)

	left_arm = _limb(Vector3(0.14, 0.52, 0.14), hoodie, Vector3(-0.42, 1.28, 0))
	right_arm = _limb(Vector3(0.14, 0.52, 0.14), hoodie, Vector3(0.42, 1.28, 0))
	left_leg = _limb(Vector3(0.16, 0.55, 0.16), jeans, Vector3(-0.16, 0.62, 0))
	right_leg = _limb(Vector3(0.16, 0.55, 0.16), jeans, Vector3(0.16, 0.62, 0))

	_add_hand(left_arm, skin)
	_add_hand(right_arm, skin)
	_add_shoe(left_leg, shoe)
	_add_shoe(right_leg, shoe)

	var backpack := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(0.44, 0.5, 0.2)
	backpack.mesh = bb
	backpack.material_override = pack
	backpack.position = Vector3(0, 1.02, 0.3)
	visual.add_child(backpack)

	var flap := MeshInstance3D.new()
	var fb := BoxMesh.new()
	fb.size = Vector3(0.4, 0.12, 0.18)
	flap.mesh = fb
	flap.material_override = strap
	flap.position = Vector3(0, 1.22, 0.32)
	visual.add_child(flap)

	for side in [-1.0, 1.0]:
		var strap_mesh := MeshInstance3D.new()
		var sb := BoxMesh.new()
		sb.size = Vector3(0.06, 0.42, 0.06)
		strap_mesh.mesh = sb
		strap_mesh.material_override = strap
		strap_mesh.position = Vector3(side * 0.22, 1.12, 0.16)
		visual.add_child(strap_mesh)

func _add_hand(pivot: Node3D, mat: Material) -> void:
	var hand := MeshInstance3D.new()
	var hb := BoxMesh.new()
	hb.size = Vector3(0.12, 0.12, 0.12)
	hand.mesh = hb
	hand.material_override = mat
	hand.position.y = -0.56
	pivot.add_child(hand)

func _add_shoe(pivot: Node3D, mat: Material) -> void:
	var shoe := MeshInstance3D.new()
	var sb := BoxMesh.new()
	sb.size = Vector3(0.2, 0.12, 0.3)
	shoe.mesh = sb
	shoe.material_override = mat
	shoe.position = Vector3(0, -0.56, -0.05)
	pivot.add_child(shoe)

func _limb(size: Vector3, mat: Material, pivot_pos: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pivot_pos
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	mi.position.y = -size.y * 0.5
	pivot.add_child(mi)
	visual.add_child(pivot)
	return pivot

func _build_camera() -> void:
	camera_pivot = Node3D.new()
	camera_pivot.position = Vector3(0, 1.55, 0)
	add_child(camera_pivot)
	spring_arm = SpringArm3D.new()
	spring_arm.spring_length = 6.0
	spring_arm.margin = 0.3
	spring_arm.collision_mask = 1
	camera_pivot.add_child(spring_arm)
	spring_arm.add_excluded_object(get_rid())
	camera = Camera3D.new()
	camera.current = true
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 60.0
	camera.near = 0.1
	camera.far = 600.0
	spring_arm.add_child(camera)

	var hero_key := SpotLight3D.new()
	hero_key.light_color = Color(0.95, 0.93, 0.88)
	hero_key.light_energy = 1.4
	hero_key.spot_range = 12.0
	hero_key.spot_angle = 40.0
	hero_key.spot_attenuation = 0.9
	hero_key.shadow_enabled = false
	camera.add_child(hero_key)

func _build_ray() -> void:
	interact_ray = RayCast3D.new()
	interact_ray.position = Vector3(0, 1.4, 0)
	interact_ray.enabled = true
	interact_ray.collide_with_areas = false
	interact_ray.add_exception(self)
	add_child(interact_ray)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * MOUSE_SENS
		_pitch -= event.relative.y * MOUSE_SENS
		_pitch = clampf(_pitch, -1.2, 0.5)
		camera_pivot.rotation.y = _yaw
		spring_arm.rotation.x = _pitch
	elif event.is_action_pressed("cancel"):
		if Game.build_mode:
			Game.set_build_mode(false)
		elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			spring_arm.spring_length = clampf(spring_arm.spring_length - 0.8, 2.5, 14.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			spring_arm.spring_length = clampf(spring_arm.spring_length + 0.8, 2.5, 14.0)
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("weather"):
		var dn := get_tree().get_first_node_in_group("daynight")
		if dn != null and dn.has_method("toggle_rain"):
			dn.toggle_rain()
	if Input.is_action_just_pressed("use_item"):
		_use_selected()

	if sitting:
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		move_and_slide()
		_animate(delta, false)
		_update_interaction()
		if Input.is_action_just_pressed("sit") or Input.is_action_just_pressed("jump"):
			stand_up()
		return

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	)
	if input.length() > 1.0:
		input = input.normalized()
	var dir := Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, _yaw)
	var speed := SPRINT_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED
	velocity.x = move_toward(velocity.x, dir.x * speed, 40.0 * delta)
	velocity.z = move_toward(velocity.z, dir.z * speed, 40.0 * delta)
	move_and_slide()

	_animate(delta, input.length() > 0.05)
	_update_interaction()

	if Input.is_action_just_pressed("build"):
		Game.set_build_mode(not Game.build_mode)
	if Input.is_action_just_pressed("sit"):
		if _target != null and _target.has_method("toggle_rest"):
			_target.toggle_rest(self)
		elif _target != null and _target.has_method("interact") and _target.is_in_group("rest_spot"):
			_target.interact(self)
		else:
			Game.toast("Сядь у костра или на скамейку")
	if Input.is_action_just_pressed("interact"):
		if Game.build_mode:
			_try_place()
		elif _target != null:
			_target.interact(self)
	_update_build_ghost()

func _animate(delta: float, moving: bool) -> void:
	if sitting:
		visual.position.y = lerpf(visual.position.y, -0.28, delta * 8.0)
		left_arm.rotation.x = lerpf(left_arm.rotation.x, -0.55, delta * 8.0)
		right_arm.rotation.x = lerpf(right_arm.rotation.x, -0.55, delta * 8.0)
		left_leg.rotation.x = lerpf(left_leg.rotation.x, -1.35, delta * 8.0)
		right_leg.rotation.x = lerpf(right_leg.rotation.x, -1.35, delta * 8.0)
		return
	if moving:
		_bob_time += delta * (11.0 if Input.is_action_pressed("sprint") else 7.0)
	var bob := sin(_bob_time) * 0.05 if moving else 0.0
	visual.position.y = lerpf(visual.position.y, bob, delta * 12.0)
	var swing := sin(_bob_time) * 0.55 if moving else 0.0
	left_arm.rotation.x = lerpf(left_arm.rotation.x, swing, delta * 12.0)
	right_arm.rotation.x = lerpf(right_arm.rotation.x, -swing, delta * 12.0)
	left_leg.rotation.x = lerpf(left_leg.rotation.x, -swing, delta * 12.0)
	right_leg.rotation.x = lerpf(right_leg.rotation.x, swing, delta * 12.0)
	if moving:
		var d := Vector3(velocity.x, 0.0, velocity.z)
		if d.length() > 0.1:
			var target_angle := atan2(-d.x, -d.z)
			visual.rotation.y = lerp_angle(visual.rotation.y, target_angle, delta * 10.0)

func toggle_rest(spot: Node = null) -> void:
	if sitting:
		stand_up()
	else:
		sit_down(spot)

func sit_down(spot: Node = null) -> void:
	sitting = true
	rest_spot = spot
	velocity = Vector3.ZERO
	_saved_cam_y = camera_pivot.position.y
	_saved_spring = spring_arm.spring_length
	_saved_pitch = spring_arm.rotation.x
	camera_pivot.position.y = 1.15
	spring_arm.spring_length = 3.2
	spring_arm.rotation.x = -0.5
	Game.add_comfort(16.0)
	Game.toast("Отдыхаешь. C или Space — встать")

func stand_up() -> void:
	if not sitting:
		return
	sitting = false
	rest_spot = null
	camera_pivot.position.y = _saved_cam_y
	spring_arm.spring_length = _saved_spring
	spring_arm.rotation.x = _saved_pitch

func _use_selected() -> void:
	var id := Game.selected_item()
	if id == "berry" or id == "fish" or id == "crop":
		if Game.remove_item(id, 1):
			var comfort_gain := 8.0
			if id == "fish":
				comfort_gain = 16.0
			elif id == "crop":
				comfort_gain = 24.0
			Game.add_comfort(comfort_gain)
			Game.toast("Съел: %s" % Game.item_name(id))
		else:
			Game.toast("Нет предмета")
	else:
		Game.toast("%s пока не используется" % Game.item_name(id))

func _update_interaction() -> void:
	var forward := -camera.global_transform.basis.z
	interact_ray.target_position = forward * REACH
	interact_ray.force_raycast_update()
	_target = null
	if interact_ray.is_colliding():
		var c := interact_ray.get_collider()
		if c != null and c.has_method("interact"):
			_target = c
	if Game.build_mode:
		return
	if ui != null:
		if _target != null and _target.has_method("get_prompt"):
			var p: String = _target.get_prompt()
			ui.set_prompt(p if p == "" else "%s   [E]" % p)
		else:
			ui.set_prompt("")

func _update_build_ghost() -> void:
	if Game.build_mode:
		if ghost == null:
			ghost = _make_ghost()
			add_child(ghost)
		ghost.visible = true
		var forward := -camera.global_transform.basis.z
		forward.y = 0.0
		if forward.length() < 0.01:
			forward = Vector3.FORWARD
		forward = forward.normalized()
		var p := global_position + forward * 3.2
		var h: float = terrain.get_height(p.x, p.z)
		ghost.global_position = Vector3(p.x, h + 0.05, p.z)
		if ui != null:
			ui.set_prompt("E — поставить костёр  (3 дерева, 2 камня)   ·   Esc — отмена")
	else:
		if ghost != null:
			ghost.visible = false

func _make_ghost() -> Node3D:
	var g := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.6, 0.2, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.disable_fog = true
	var base := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.55
	cyl.bottom_radius = 0.45
	cyl.height = 0.18
	base.mesh = cyl
	base.material_override = mat
	base.position.y = 0.09
	g.add_child(base)
	var flame := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.22
	cone.height = 0.7
	flame.mesh = cone
	flame.material_override = mat
	flame.position.y = 0.5
	g.add_child(flame)
	return g

func _try_place() -> void:
	if Game.count_item("wood") < 3 or Game.count_item("stone") < 2:
		Game.toast("Нужно 3 дерева и 2 камня")
		return
	var p := ghost.global_position
	if terrain.get_height(p.x, p.z) < -1.6:
		Game.toast("Слишком близко к воде")
		return
	Game.remove_item("wood", 3)
	Game.remove_item("stone", 2)
	if world != null and world.has_method("spawn_campfire"):
		world.spawn_campfire(Vector3(p.x, terrain.get_height(p.x, p.z), p.z))
	Game.toast("Костёр разожжён")
