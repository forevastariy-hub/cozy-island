extends Node3D

const TerrainScript = preload("res://scripts/terrain.gd")
const PlayerScript = preload("res://scripts/player.gd")
const UIScript = preload("res://scripts/ui.gd")
const DayNightScript = preload("res://scripts/day_night.gd")
const TreeScript = preload("res://scripts/tree.gd")
const RockScript = preload("res://scripts/rock.gd")
const BushScript = preload("res://scripts/bush.gd")
const FarmScript = preload("res://scripts/farm_plot.gd")
const FishingScript = preload("res://scripts/fishing_spot.gd")
const CampfireScript = preload("res://scripts/campfire.gd")
const PostFXScript = preload("res://scripts/post_fx.gd")
const RuinsScript = preload("res://scripts/ruins.gd")
const FloraScript = preload("res://scripts/flora.gd")
const StructuresScript = preload("res://scripts/structures.gd")
const ReedScript = preload("res://scripts/reed.gd")

var terrain: Node3D
var player: CharacterBody3D
var ui: CanvasLayer
var daynight: Node3D
var post_fx: CanvasLayer
var ruins: Node3D
var flora: Node3D
var structures: Node3D

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--time="):
			Game.time_of_day = clampf(float(arg.split("=")[1]), 0.0, 23.99)

	terrain = TerrainScript.new()
	terrain.name = "Terrain"
	add_child(terrain)

	daynight = DayNightScript.new()
	daynight.name = "DayNight"
	daynight.terrain = terrain
	daynight.add_to_group("daynight")
	add_child(daynight)

	post_fx = PostFXScript.new()
	post_fx.name = "PostFX"
	post_fx.daynight = daynight
	add_child(post_fx)
	if "--nopost" in OS.get_cmdline_user_args():
		post_fx.visible = false
	if "--nofog" in OS.get_cmdline_user_args():
		daynight.env.fog_enabled = false

	ui = UIScript.new()
	ui.name = "UI"
	ui.terrain = terrain
	ui.daynight = daynight
	ui.world = self
	add_child(ui)

	_spawn_player()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--at="):
			var parts := arg.split("=")[1].split(",")
			if parts.size() == 2:
				var ax := float(parts[0])
				var az := float(parts[1])
				var ah: float = terrain.get_height(ax, az)
				player.position = Vector3(ax, ah + 2.0, az)
		elif arg.begins_with("--yaw="):
			player.camera_pivot.rotation.y = deg_to_rad(float(arg.split("=")[1]))
			player._yaw = player.camera_pivot.rotation.y
	ui.player = player
	daynight.follow = player
	_scatter_world()
	_spawn_ruins()
	_spawn_garden()
	_spawn_fishing_spots()
	_place_structures()
	_build_paths()
	_place_bridges()
	terrain.build_grass()
	ui.setup_minimap()
	_load_cheat_panel()

	await get_tree().process_frame
	Game.toast("Тёплый день. WASD — идти, E — действие")

	if "--mapshot" in OS.get_cmdline_user_args():
		daynight.env.fog_enabled = false
		post_fx.visible = false
		var cam := Camera3D.new()
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = 1000.0
		cam.position = Vector3(0.0, 700.0, 0.0)
		cam.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		cam.current = true
		add_child(cam)
		await get_tree().create_timer(1.0).timeout
		get_viewport().get_texture().get_image().save_png("res://mapshot.png")
		get_tree().quit()
		return

	if "--rain" in OS.get_cmdline_user_args():
		daynight.set_rain(true)
	if "--menu" in OS.get_cmdline_user_args():
		ui._open_menu()

	if "--shot" in OS.get_cmdline_user_args():
		await get_tree().create_timer(2.0).timeout
		var img := get_viewport().get_texture().get_image()
		img.save_png("res://shot.png")
		get_tree().quit()

	if "--selftest" in OS.get_cmdline_user_args():
		await get_tree().create_timer(1.0).timeout
		print("SELFTEST pos=", player.global_position, " floor=", player.is_on_floor())
		var list: Array = []
		_collect_interactables(self, list)
		print("SELFTEST interactables=", list.size())
		for n in list:
			if n.get_prompt() == "Собрать хворост":
				for _i in range(3):
					n.interact(player)
				break
		print("SELFTEST inventory=", Game.inventory)
		print("SELFTEST ruins=", ruins.get_child_count())
		var plot = null
		for n in list:
			if n.get_prompt() == "Посадить семена":
				n.interact(player)
				print("SELFTEST planted_stage=", n.stage)
				plot = n
				break
		spawn_campfire(player.global_position + Vector3(2, 0, 0))
		var cam: Camera3D = player.camera
		var sp: Vector2 = cam.unproject_position(player.global_position + Vector3.UP * 1.6)
		print("SELFTEST screen_player=", sp, " frustum=", cam.is_position_in_frustum(player.global_position + Vector3.UP * 1.6))
		Engine.time_scale = 30.0
		await get_tree().create_timer(3.0, true, false, true).timeout
		Engine.time_scale = 1.0
		if plot != null:
			print("SELFTEST crop_stage_after=", plot.stage)
		print("SELFTEST day=", Game.day, " time=", Game.time_of_day)
		ui.time_slider.value = 6.0
		await get_tree().process_frame
		print("SELFTEST slider_time=", Game.time_of_day, " slider=", ui.time_slider.value)
		print("SELFTEST paths=", terrain._path_segments.size(), " grass=", terrain.grass.multimesh.instance_count if terrain.grass != null else 0)
		player.sit_down(null)
		await get_tree().process_frame
		print("SELFTEST sitting=", player.sitting)
		player.stand_up()
		daynight.set_rain(true)
		await get_tree().create_timer(1.5).timeout
		var puddle_shown := 0
		var puddle_sample := Vector3.ZERO
		for p in daynight.puddles.get_children():
			if p.visible:
				puddle_shown += 1
				if puddle_sample == Vector3.ZERO:
					puddle_sample = p.global_position
		print("SELFTEST rain=", daynight.rain_strength, " puddles=", daynight.puddles.visible, " shown=", puddle_shown, " sample=", puddle_sample)
		var save_path := "user://selftest_save.json"
		var wood_before := Game.count_item("wood")
		_save_game(save_path)
		Game.remove_item("wood", 2)
		_load_game(save_path)
		print("SELFTEST load_wood=", Game.count_item("wood"), " expected=", wood_before)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
		var w = terrain.world
		print("SELFTEST seed=", w.world_seed, " poi_min=", w.layout.min_structure_distance())
		print("SELFTEST river_pts=", w.river.polyline.size(), " waterfalls=", w.river.waterfalls.size(), " bridges=", w.roads.bridges.size())
		var trees_on_cliffs := 0
		for pl in w.scatter.placements:
			var pk: String = pl["kind"]
			if pk == "pine" or pk == "decid":
				var pp: Vector3 = pl["pos"]
				if w.hf.slope_deg(pp.x, pp.z) > 28.0:
					trees_on_cliffs += 1
		print("SELFTEST trees_on_cliffs=", trees_on_cliffs, " hash=", w.heights_hash())
		for key in w.layout.pois:
			var pc: Vector2 = w.layout.pois[key]["center"]
			print("SELFTEST poi ", key, " x=", int(pc.x), " z=", int(pc.y), " h=", int(w.hf.sample(pc.x, pc.y)))
		if not w.river.polyline.is_empty():
			print("SELFTEST river_start=", w.river.polyline[0], " end=", w.river.polyline[w.river.polyline.size() - 1])
			for i in [0, 20, 40, 60, 80, 100]:
				if i < w.river.polyline.size():
					var rp: Vector2 = w.river.polyline[i]
					print("SELFTEST river[", i, "] x=", int(rp.x), " z=", int(rp.y), " wl=", snappedf(w.river.water_levels[i], 0.01), " ground=", snappedf(w.hf.sample(rp.x, rp.y), 0.01))
		for br in w.roads.bridges:
			var bp: Vector3 = br["pos"]
			print("SELFTEST bridge x=", int(bp.x), " z=", int(bp.z), " y=", snappedf(bp.y, 0.01), " ground=", snappedf(w.hf.sample(bp.x, bp.z), 0.01))
		print("SELFTEST done children=", get_child_count())
		get_tree().quit()

func _collect_interactables(node: Node, out: Array) -> void:
	for c in node.get_children():
		if c.has_method("interact") and c.has_method("get_prompt"):
			out.append(c)
		_collect_interactables(c, out)

func _spawn_player() -> void:
	player = PlayerScript.new()
	player.name = "Player"
	player.terrain = terrain
	player.ui = ui
	player.world = self
	player.position = _find_spawn()
	add_child(player)

func _find_spawn() -> Vector3:
	var camp: Vector2 = terrain.CAMP_C + Vector2(0.0, 8.0)
	var camp_h: float = terrain.get_height(camp.x, camp.y)
	if camp_h > 1.0:
		return Vector3(camp.x, camp_h + 2.0, camp.y)
	for r in range(0, 200):
		for a in range(12):
			var ang := TAU * float(a) / 12.0
			var rad := float(r) * 4.0
			var x := camp.x + cos(ang) * rad
			var z := camp.y + sin(ang) * rad
			var h: float = terrain.get_height(x, z)
			if h > 1.5:
				return Vector3(x, h + 2.0, z)
	return Vector3(camp.x, terrain.get_height(camp.x, camp.y) + 2.0, camp.y)

func _find_spot(rng: RandomNumberGenerator, min_h: float, max_h: float, min_radius: float, max_radius: float = 460.0) -> Variant:
	for _a in range(40):
		var ang := rng.randf_range(0.0, TAU)
		var rad := rng.randf_range(min_radius, max_radius)
		var x := cos(ang) * rad
		var z := sin(ang) * rad
		var h: float = terrain.get_height(x, z)
		if h < min_h or h > max_h:
			continue
		if 1.0 - terrain.get_normal(x, z).y > 0.4:
			continue
		return Vector3(x, h, z)
	return null

func _scatter_world() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20241108
	for item in terrain.world.scatter.placements:
		var kind: String = item["kind"]
		var pos: Vector3 = item["pos"]
		var rot: float = item["rot"]
		var scl: float = item["scale"]
		match kind:
			"pine":
				var t = TreeScript.new()
				t.rng.seed = rng.randi()
				t.kind = 1 if rng.randf() < 0.7 else 0
				t.position = pos
				t.rotation.y = rot
				t.scale = Vector3(scl, scl * rng.randf_range(0.9, 1.2), scl)
				add_child(t)
			"decid":
				var t2 = TreeScript.new()
				t2.rng.seed = rng.randi()
				t2.kind = 2
				t2.position = pos
				t2.rotation.y = rot
				t2.scale = Vector3(scl, scl * rng.randf_range(0.9, 1.15), scl)
				add_child(t2)
			"rock":
				var r = RockScript.new()
				r.rng.seed = rng.randi()
				r.position = pos
				r.rotation.y = rot
				r.scale = Vector3(scl, scl * rng.randf_range(0.7, 1.0), scl)
				add_child(r)
			"bush":
				var b = BushScript.new()
				b.rng.seed = rng.randi()
				b.position = pos
				add_child(b)
			"reed":
				var reed = ReedScript.new()
				reed.position = pos
				add_child(reed)

	flora = FloraScript.new()
	flora.name = "Flora"
	flora.terrain = terrain
	add_child(flora)
	flora.scatter(rng, 320, 0.2, 18.0, 8.0, 0.7)

func p_on_land(x: float, z: float) -> Vector3:
	var h: float = terrain.get_height(x, z)
	return Vector3(x, h, z)

func _spawn_ruins() -> void:
	ruins = RuinsScript.new()
	ruins.name = "Ruins"
	add_child(ruins)
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	# ruins are located on the west side of the island
	var rp: Vector2 = terrain.pois["ruins"]
	var rh: float = terrain.get_height(rp.x, rp.y)
	ruins.build(terrain, rng, Vector3(rp.x, rh, rp.y))

func _place_structures() -> void:
	structures = StructuresScript.new()
	structures.name = "Structures"
	add_child(structures)
	seed(998877)

	var t := terrain
	# Lookout tower on mountain (north)
	var mp: Vector2 = t.pois["mountain"]
	var mh: float = t.get_height(mp.x, mp.y)
	structures.build_lookout_tower(structures, Vector3(mp.x, mh, mp.y))

	# Stone tower on east coast
	var sp: Vector2 = t.pois["stone_tower"]
	var sh: float = t.get_height(sp.x, sp.y)
	structures.build_stone_tower(structures, Vector3(sp.x, sh, sp.y))

	# Radio tower (south)
	var rp: Vector2 = t.pois["radio_tower"]
	var rh: float = t.get_height(rp.x, rp.y)
	structures.build_radio_tower(structures, Vector3(rp.x, rh, rp.y))

	# Camp (center)
	var cp: Vector2 = t.pois["camp"]
	var ch: float = t.get_height(cp.x, cp.y)
	structures.build_camp(structures, Vector3(cp.x, ch, cp.y))

	# Windmill + farmhouse on the fields (east)
	var fc: Vector2 = t.FIELDS_C
	var fx := fc.x - 34.0
	var fz := fc.y + 8.0
	var fh: float = t.get_height(fx, fz)
	structures.build_windmill(structures, Vector3(fx, fh, fz))
	var hx := fc.x + 26.0
	var hz := fc.y - 18.0
	var hh: float = t.get_height(hx, hz)
	structures.build_farmhouse(structures, Vector3(hx, hh, hz))

func _spawn_garden() -> void:
	var base := player.position + Vector3(6.0, 0.0, 4.0)
	for ix in range(3):
		for iz in range(2):
			var x := base.x + (float(ix) - 1.0) * 1.7
			var z := base.z + (float(iz) - 0.5) * 1.7
			var h: float = terrain.get_height(x, z)
			if h < 0.5:
				continue
			var plot = FarmScript.new()
			plot.position = Vector3(x, h, z)
			add_child(plot)

func _spawn_fishing_spots() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var placed := 0
	for _i in range(80):
		if placed >= 6:
			break
		var p = _find_spot(rng, -1.95, -0.9, 14.0, 420.0)
		if p == null:
			continue
		var f = FishingScript.new()
		f.position = p
		f.rotation.y = atan2(-p.x, -p.z)
		add_child(f)
		placed += 1

func _load_cheat_panel() -> void:
	var path := "res://scripts/cheat_panel.gd"
	if not ResourceLoader.exists(path):
		return
	var res = load(path)
	var panel = res.new()
	panel.name = "CheatPanel"
	panel.terrain = terrain
	panel.player = player
	panel.daynight = daynight
	panel.ui = ui
	panel.world = self
	add_child(panel)

func spawn_campfire(pos: Vector3) -> void:
	var c = CampfireScript.new()
	c.position = pos
	add_child(c)

func _place_bridges() -> void:
	if structures == null:
		return
	for br in terrain.world.roads.bridges:
		structures.build_bridge(structures, br["pos"], br["dir"], br["width"])

func _build_paths() -> void:
	var points: Array = [player.global_position]
	for n in get_tree().get_nodes_in_group("path_poi"):
		if n is Node3D:
			points.append(n.global_position)
	# Order POIs for a sensible route: camp -> lake -> ruins -> mountain -> stone tower -> radio tower -> fields
	var ordered: Array = []
	var poi_names := ["camp", "lake", "ruins", "mountain", "stone_tower", "radio_tower", "fields"]
	var added := {}
	for name in poi_names:
		if terrain.pois.has(name):
			var p: Vector2 = terrain.pois[name]
			var h: float = terrain.get_height(p.x, p.y)
			ordered.append(Vector3(p.x, h, p.y))
			added[name] = true
	# add any remaining path_poi not in ordered list
	for n in get_tree().get_nodes_in_group("path_poi"):
		if n is Node3D:
			var found := false
			for o in ordered:
				if o.distance_to(n.global_position) < 1.0:
					found = true
					break
			if not found:
				ordered.append(n.global_position)
	if player.global_position.distance_to(ordered[0] if ordered.size() > 0 else Vector3(9999, 9999, 9999)) > 2.0:
		ordered.push_front(player.global_position)
	if ordered.size() > 1:
		terrain.build_paths(ordered)

func toggle_rain() -> void:
	if daynight != null and daynight.has_method("toggle_rain"):
		daynight.toggle_rain()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("save"):
		_save_game()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("load"):
		_load_game()
		get_viewport().set_input_as_handled()

func _save_game(path: String = "user://save.json") -> void:
	var data := {
		"player": [player.global_position.x, player.global_position.y, player.global_position.z],
		"state": Game.save_state(),
		"rain": daynight.rain_target if daynight != null else 0.0,
	}
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		Game.toast("Не удалось сохранить")
		return
	f.store_string(JSON.stringify(data))
	f.close()
	Game.toast("Игра сохранена")

func _load_game(path: String = "user://save.json") -> void:
	if not FileAccess.file_exists(path):
		Game.toast("Сохранения нет")
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		Game.toast("Не удалось загрузить")
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		Game.toast("Сохранение повреждено")
		return
	if parsed.has("state"):
		Game.load_state(parsed["state"])
	if parsed.has("player"):
		var p: Array = parsed["player"]
		if p.size() >= 3:
			player.global_position = Vector3(float(p[0]), float(p[1]), float(p[2]))
			player.velocity = Vector3.ZERO
	if parsed.has("rain") and daynight != null:
		daynight.set_rain(float(parsed["rain"]) > 0.2)
	Game.toast("Игра загружена")
