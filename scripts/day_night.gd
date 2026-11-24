extends Node3D

const HOUR_SECONDS := 90.0
const WATER_LEVEL := -2.0
const PuddleShader = preload("res://scripts/puddle.gdshader")

var sun_light: DirectionalLight3D
var moon_light: DirectionalLight3D
var rim: DirectionalLight3D
var fill: DirectionalLight3D
var env: Environment
var sky_mat: ShaderMaterial
var rain: CPUParticles3D
var fireflies: CPUParticles3D
var dust: CPUParticles3D
var pollen: CPUParticles3D
var gusts: CPUParticles3D
var puddles: Node3D
var puddle_material: ShaderMaterial
var follow: Node3D
var terrain: Node3D
var rain_target := 0.0
var rain_strength := 0.0
var auto_weather := true
var fog_scale := 1.0
var light_scale := 1.0
var wind_scale := 1.0
var particle_scale := 1.0
var ray_scale := 1.0
var shadow_softness := 1.0
var _weather_timer := 120.0
var _t := 0.0
var _puddle_anchor := Vector3(1e9, 0.0, 1e9)
var _puddle_placed := false
var _puddle_rng := RandomNumberGenerator.new()

func _ready() -> void:
	_build()
	_build_weather()

func _build() -> void:
	var world_env := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_SKY

	sky_mat = ShaderMaterial.new()
	sky_mat.shader = load("res://scripts/sky.gdshader")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky

	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.34, 0.42)
	env.ambient_light_energy = 0.95
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.4

	env.glow_enabled = true
	env.glow_intensity = 0.24
	env.glow_strength = 0.6
	env.glow_bloom = 0.02
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN

	env.fog_enabled = true
	env.fog_light_color = Color(0.22, 0.26, 0.34)
	env.fog_light_energy = 0.45
	env.fog_density = 0.0014
	env.fog_sky_affect = 0.18
	env.fog_height = 1.5
	env.fog_height_density = 0.12

	env.adjustment_enabled = true
	env.adjustment_brightness = 1.0
	env.adjustment_contrast = 1.04
	env.adjustment_saturation = 1.02

	world_env.environment = env
	add_child(world_env)

	sun_light = DirectionalLight3D.new()
	sun_light.light_color = Color(1.0, 0.88, 0.62)
	sun_light.light_energy = 0.0
	sun_light.shadow_enabled = true
	sun_light.shadow_blur = 1.35
	sun_light.light_angular_distance = 0.45
	sun_light.directional_shadow_max_distance = 520.0
	sun_light.directional_shadow_blend_splits = true
	add_child(sun_light)

	moon_light = DirectionalLight3D.new()
	moon_light.light_color = Color(0.55, 0.65, 1.0)
	moon_light.light_energy = 0.5
	moon_light.shadow_enabled = true
	moon_light.shadow_blur = 1.9
	moon_light.light_angular_distance = 0.6
	moon_light.directional_shadow_max_distance = 520.0
	add_child(moon_light)

	rim = DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-12.0, 25.0, 0.0)
	rim.light_color = Color(0.4, 0.5, 0.75)
	rim.light_energy = 0.18
	rim.shadow_enabled = false
	add_child(rim)

	fill = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-28.0, 12.0, 0.0)
	fill.light_color = Color(0.5, 0.6, 0.9)
	fill.light_energy = 0.5
	fill.shadow_enabled = false
	add_child(fill)

	_update_sky()

func _build_weather() -> void:
	rain = CPUParticles3D.new()
	rain.name = "Rain"
	rain.amount = 420
	rain.lifetime = 1.5
	rain.preprocess = 1.0
	rain.emitting = false
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(30.0, 1.0, 30.0)
	rain.direction = Vector3(0.08, -1.0, 0.05)
	rain.spread = 3.0
	rain.gravity = Vector3(0.0, -30.0, 0.0)
	rain.initial_velocity_min = 14.0
	rain.initial_velocity_max = 22.0
	rain.scale_amount_min = 0.8
	rain.scale_amount_max = 1.4
	var drop := BoxMesh.new()
	drop.size = Vector3(0.028, 0.68, 0.028)
	rain.mesh = drop
	var rain_mat := StandardMaterial3D.new()
	rain_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rain_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rain_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	rain_mat.albedo_color = Color(0.55, 0.68, 0.95, 0.52)
	rain_mat.disable_fog = true
	rain.material_override = rain_mat
	rain.position = Vector3(0, 12, 0)
	add_child(rain)

	fireflies = CPUParticles3D.new()
	fireflies.name = "Fireflies"
	fireflies.amount = 60
	fireflies.lifetime = 8.0
	fireflies.preprocess = 2.0
	fireflies.emitting = false
	fireflies.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	fireflies.emission_box_extents = Vector3(24.0, 1.0, 24.0)
	fireflies.direction = Vector3(0.0, 1.0, 0.0)
	fireflies.spread = 70.0
	fireflies.gravity = Vector3(0.0, 0.0, 0.0)
	fireflies.initial_velocity_min = 0.1
	fireflies.initial_velocity_max = 0.5
	fireflies.scale_amount_min = 0.6
	fireflies.scale_amount_max = 1.4
	var fly := QuadMesh.new()
	fly.size = Vector2(0.06, 0.06)
	fireflies.mesh = fly
	var fly_mat := StandardMaterial3D.new()
	fly_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fly_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fly_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fly_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fly_mat.albedo_color = Color(0.8, 1.0, 0.45, 0.9)
	fly_mat.disable_fog = true
	fireflies.material_override = fly_mat
	fireflies.position = Vector3(0, 0.8, 0)
	add_child(fireflies)

	dust = CPUParticles3D.new()
	dust.name = "Dust"
	dust.amount = 90
	dust.lifetime = 12.0
	dust.preprocess = 3.0
	dust.emitting = true
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(22.0, 2.0, 22.0)
	dust.direction = Vector3(0.15, 1.0, 0.05)
	dust.spread = 40.0
	dust.gravity = Vector3(0.02, 0.04, 0.0)
	dust.initial_velocity_min = 0.05
	dust.initial_velocity_max = 0.35
	dust.scale_amount_min = 0.4
	dust.scale_amount_max = 1.0
	var mote := QuadMesh.new()
	mote.size = Vector2(0.045, 0.045)
	dust.mesh = mote
	var dust_mat := StandardMaterial3D.new()
	dust_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dust_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dust_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	dust_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dust_mat.albedo_color = Color(1.0, 0.86, 0.55, 0.30)
	dust_mat.disable_fog = true
	dust.material_override = dust_mat
	dust.position = Vector3(0, 2.0, 0)
	add_child(dust)

	pollen = CPUParticles3D.new()
	pollen.name = "Pollen"
	pollen.amount = 40
	pollen.lifetime = 9.0
	pollen.preprocess = 2.0
	pollen.emitting = true
	pollen.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	pollen.emission_box_extents = Vector3(18.0, 2.2, 18.0)
	pollen.direction = Vector3(0.4, 0.15, 0.1)
	pollen.spread = 55.0
	pollen.gravity = Vector3(0.05, -0.02, 0.0)
	pollen.initial_velocity_min = 0.15
	pollen.initial_velocity_max = 0.55
	pollen.scale_amount_min = 0.5
	pollen.scale_amount_max = 1.1
	var grain := QuadMesh.new()
	grain.size = Vector2(0.03, 0.03)
	pollen.mesh = grain
	var pollen_mat := StandardMaterial3D.new()
	pollen_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pollen_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pollen_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	pollen_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	pollen_mat.albedo_color = Color(0.95, 0.86, 0.35, 0.42)
	pollen_mat.disable_fog = true
	pollen.material_override = pollen_mat
	pollen.position = Vector3(0, 1.6, 0)
	add_child(pollen)

	gusts = CPUParticles3D.new()
	gusts.name = "Gusts"
	gusts.amount = 24
	gusts.lifetime = 1.6
	gusts.preprocess = 0.4
	gusts.emitting = true
	gusts.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	gusts.emission_box_extents = Vector3(16.0, 1.4, 16.0)
	gusts.direction = Vector3(1.0, 0.02, 0.15)
	gusts.spread = 8.0
	gusts.gravity = Vector3.ZERO
	gusts.initial_velocity_min = 7.0
	gusts.initial_velocity_max = 12.0
	gusts.scale_amount_min = 0.6
	gusts.scale_amount_max = 1.3
	var streak := BoxMesh.new()
	streak.size = Vector3(1.15, 0.012, 0.018)
	gusts.mesh = streak
	var gust_mat := StandardMaterial3D.new()
	gust_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gust_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gust_mat.albedo_color = Color(0.9, 0.92, 0.88, 0.16)
	gust_mat.disable_fog = true
	gusts.material_override = gust_mat
	gusts.position = Vector3(0, 1.3, 0)
	add_child(gusts)

	_apply_budgets()

	puddles = Node3D.new()
	puddles.name = "Puddles"
	puddles.visible = false
	add_child(puddles)
	puddle_material = ShaderMaterial.new()
	puddle_material.shader = PuddleShader
	_puddle_rng.seed = 90210
	var plane := PlaneMesh.new()
	plane.size = Vector2(1.0, 1.0)
	plane.subdivide_width = 6
	plane.subdivide_depth = 6
	for i in range(44):
		var mi := MeshInstance3D.new()
		mi.name = "Puddle%d" % i
		mi.mesh = plane
		mi.material_override = puddle_material
		mi.visible = false
		puddles.add_child(mi)

func _process(delta: float) -> void:
	_t += delta
	Game.time_of_day += delta / HOUR_SECONDS
	while Game.time_of_day >= 24.0:
		Game.time_of_day -= 24.0
		Game.day += 1
		Game.day_started.emit(Game.day)

	_update_weather(delta)
	_update_sky()

	var gust := 0.84 + 0.16 * sin(_t * 0.37)
	var wind_now := wind_scale * gust * lerpf(1.0, 1.45, rain_strength)
	RenderingServer.global_shader_parameter_set("wind_amount", wind_now)
	if gusts != null:
		var wind_dir := Vector3(cos(_t * 0.07), 0.03, sin(_t * 0.05)).normalized()
		gusts.direction = wind_dir

	if follow != null:
		rain.global_position = follow.global_position + Vector3(0, 12, 0)
		fireflies.global_position = follow.global_position + Vector3(0, 0.8, 0)
		dust.global_position = follow.global_position + Vector3(0, 2.0, 0)
		if pollen != null:
			pollen.global_position = follow.global_position + Vector3(0, 1.6, 0)
		if gusts != null:
			gusts.global_position = follow.global_position + Vector3(0, 1.3, 0)

func _update_weather(delta: float) -> void:
	if auto_weather:
		_weather_timer -= delta
		if _weather_timer <= 0.0:
			_weather_timer = randf_range(110.0, 210.0)
			if rain_target < 0.2 and randf() < 0.42:
				rain_target = 1.0
				Game.toast("Похоже, будет дождь")
			elif rain_target > 0.2:
				rain_target = 0.0
				Game.toast("Дождь стихает")

	rain_strength = move_toward(rain_strength, rain_target, delta * 0.35)
	var allow_fx := particle_scale > 0.02
	var day_amt := clampf(_day_amount(), 0.0, 1.0)
	if rain != null:
		rain.emitting = allow_fx and rain_strength > 0.02
	if dust != null:
		dust.emitting = allow_fx and rain_strength < 0.18 and day_amt > 0.2
	if pollen != null:
		pollen.emitting = allow_fx and rain_strength < 0.12 and day_amt > 0.35
	if gusts != null:
		gusts.emitting = allow_fx and wind_scale > 0.05
	if puddles != null:
		var show := rain_strength > 0.04
		puddles.visible = show
		if show:
			var center := follow.global_position if follow != null else Vector3.ZERO
			if not _puddle_placed or _puddle_anchor.distance_to(center) > 90.0:
				_place_puddles(center)
				_puddle_placed = true
		else:
			_puddle_placed = false
		if puddle_material != null:
			puddle_material.set_shader_parameter("wetness", clampf(rain_strength, 0.0, 1.0))

func _place_puddles(center: Vector3) -> void:
	if puddles == null or terrain == null:
		return
	_puddle_anchor = center
	for i in range(puddles.get_child_count()):
		var p := puddles.get_child(i) as MeshInstance3D
		if p == null:
			continue
		p.visible = false
		for attempt in range(12):
			var ang := _puddle_rng.randf_range(0.0, TAU)
			var rad := _puddle_rng.randf_range(14.0, 70.0)
			var wx := center.x + cos(ang) * rad
			var wz := center.z + sin(ang) * rad
			var h: float = terrain.get_height(wx, wz)
			if h < WATER_LEVEL + 0.6:
				continue
			var n: Vector3 = terrain.get_normal(wx, wz)
			if n.y < 0.975:
				continue
			p.visible = true
			p.global_position = Vector3(wx, h + 0.04, wz)
			p.rotation.y = _puddle_rng.randf_range(0.0, TAU)
			p.scale = Vector3(_puddle_rng.randf_range(1.7, 3.6), 1.0, _puddle_rng.randf_range(1.2, 2.5))
			break

func _day_amount() -> float:
	var a := (Game.time_of_day - 6.0) / 24.0 * TAU
	return clampf(Vector3(cos(a), sin(a), 1.0).normalized().y * 2.0, 0.0, 1.0)

func set_rain(on: bool) -> void:
	rain_target = 1.0 if on else 0.0
	Game.toast("Дождь" if on else "Проясняется")

func toggle_rain() -> void:
	set_rain(rain_target < 0.2)

func set_fog_scale(value: float) -> void:
	fog_scale = clampf(value, 0.0, 2.0)
	if env != null:
		_update_sky()

func set_light_scale(value: float) -> void:
	light_scale = clampf(value, 0.6, 1.5)
	if env != null:
		_update_sky()

func set_wind_scale(value: float) -> void:
	wind_scale = clampf(value, 0.0, 2.0)
	if env != null:
		_update_sky()

func set_particle_scale(value: float) -> void:
	particle_scale = clampf(value, 0.0, 1.5)
	_apply_budgets()
	if env != null:
		_update_sky()

func set_ray_scale(value: float) -> void:
	ray_scale = clampf(value, 0.0, 1.5)

func set_shadow_softness(value: float) -> void:
	shadow_softness = clampf(value, 0.35, 2.0)
	if env != null:
		_update_sky()

func pack_settings() -> Dictionary:
	return {
		"fog": fog_scale,
		"light": light_scale,
		"wind": wind_scale,
		"particles": particle_scale,
		"rays": ray_scale,
		"shadow": shadow_softness,
		"auto_weather": auto_weather,
	}

func unpack_settings(data: Dictionary) -> void:
	if data.has("fog"):
		set_fog_scale(float(data["fog"]))
	if data.has("light"):
		set_light_scale(float(data["light"]))
	if data.has("wind"):
		set_wind_scale(float(data["wind"]))
	if data.has("particles"):
		set_particle_scale(float(data["particles"]))
	if data.has("rays"):
		set_ray_scale(float(data["rays"]))
	if data.has("shadow"):
		set_shadow_softness(float(data["shadow"]))
	if data.has("auto_weather"):
		auto_weather = bool(data["auto_weather"])

func _apply_budgets() -> void:
	var s := clampf(particle_scale, 0.0, 1.5)
	if rain != null:
		rain.amount = maxi(1, int(420.0 * s))
	if fireflies != null:
		fireflies.amount = maxi(1, int(60.0 * s))
	if dust != null:
		dust.amount = maxi(1, int(90.0 * s))
	if pollen != null:
		pollen.amount = maxi(1, int(40.0 * s))
	if gusts != null:
		gusts.amount = maxi(1, int(24.0 * s))

func _update_sky() -> void:
	var a := (Game.time_of_day - 6.0) / 24.0 * TAU
	var sun_dir := Vector3(cos(a), sin(a), 1.0).normalized()
	var moon_dir := -sun_dir
	var sky_sun := Vector3(cos(a), sin(a), 3.0).normalized()
	var sky_moon := -sky_sun
	var elev := sun_dir.y
	var day := clampf(elev * 2.0, 0.0, 1.0)
	var dusk := clampf(1.0 - absf(elev) * 4.0, 0.0, 1.0)

	var night_top := Color(0.03, 0.06, 0.12)
	var night_hor := Color(0.12, 0.16, 0.22)
	var day_top := Color(0.34, 0.46, 0.56)
	var day_hor := Color(0.64, 0.6, 0.47)
	var top := night_top.lerp(day_top, day)
	var hor := night_hor.lerp(day_hor, day)
	hor = hor.lerp(Color(0.8, 0.5, 0.25), dusk * 0.35)

	sky_mat.set_shader_parameter("top_color", top)
	sky_mat.set_shader_parameter("horizon_color", hor)
	sky_mat.set_shader_parameter("moon_dir", sky_moon)
	sky_mat.set_shader_parameter("sun_dir", sky_sun)
	sky_mat.set_shader_parameter("day_amount", day)
	sky_mat.set_shader_parameter("star_amount", (1.0 - day) * 0.5)
	sky_mat.set_shader_parameter("sunset_amount", dusk)
	sky_mat.set_shader_parameter("cloud_amount", lerpf(0.28, 0.86, rain_strength))

	_aim(sun_light, sun_dir)
	_aim(moon_light, moon_dir)
	var sun_col := Color(1.0, 0.97, 0.9).lerp(Color(1.0, 0.42, 0.16), dusk)
	sun_light.light_color = sun_col
	sun_light.light_energy = clampf(elev, 0.0, 1.0) * lerpf(2.2, 1.6, dusk) * light_scale
	moon_light.light_energy = clampf(-elev, 0.0, 1.0) * 1.1 * light_scale
	var soft := clampf(shadow_softness, 0.35, 2.0) * lerpf(1.3, 2.2, dusk)
	sun_light.shadow_blur = soft
	sun_light.light_angular_distance = 0.25 + soft * 0.32
	moon_light.shadow_blur = 1.7 * shadow_softness
	moon_light.light_angular_distance = 0.45 * shadow_softness

	var wet := clampf(rain_strength, 0.0, 1.0)
	if terrain != null and terrain.ground_material != null:
		terrain.ground_material.set_shader_parameter("wetness", wet)
	if terrain != null and terrain.water_material != null:
		var wind_now := wind_scale * (0.84 + 0.16 * sin(_t * 0.37)) * lerpf(1.0, 1.45, wet)
		terrain.water_material.set_shader_parameter("sky_color", Vector3(hor.r, hor.g, hor.b))
		terrain.water_material.set_shader_parameter("wave_strength", 0.032 * wind_now + wet * 0.028)
		terrain.water_material.set_shader_parameter("wave_speed", lerpf(0.75, 1.25, clampf(wind_now / 2.0, 0.0, 1.0)))
		terrain.water_material.set_shader_parameter("sun_dir", sky_sun)
		terrain.water_material.set_shader_parameter("sun_color", Vector3(sun_col.r, sun_col.g, sun_col.b))
		terrain.water_material.set_shader_parameter("glint", (0.18 + dusk * 0.7 + day * 0.12) * (1.0 - wet * 0.35))
	env.ambient_light_color = Color(0.26, 0.3, 0.42).lerp(Color(0.55, 0.6, 0.55), day)
	env.ambient_light_color = env.ambient_light_color.lerp(Color(0.8, 0.44, 0.24), dusk * 0.45)
	env.ambient_light_color = env.ambient_light_color.lerp(Color(0.28, 0.32, 0.4), wet * 0.45)
	env.ambient_light_energy = lerpf(0.85, 1.0, day) + dusk * 0.1 + sin(_t * 0.7) * 0.02
	env.tonemap_exposure = lerpf(1.42, 1.32, day) + dusk * 0.05
	env.adjustment_saturation = lerpf(1.06, 1.02, day) + dusk * 0.04 - wet * 0.08
	env.fog_light_color = Color(0.16, 0.2, 0.28).lerp(Color(0.5, 0.53, 0.5), day)
	env.fog_light_color = env.fog_light_color.lerp(Color(0.86, 0.42, 0.18), dusk * 0.5)
	env.fog_light_color = env.fog_light_color.lerp(Color(0.34, 0.40, 0.46), wet * 0.5)
	env.fog_density = (lerpf(0.0028, 0.0014, day) + dusk * 0.0006) * fog_scale + wet * 0.0018
	env.glow_intensity = lerpf(0.22, 0.34, dusk) * lerpf(1.0, 0.72, wet)
	rim.light_color = Color(0.4, 0.5, 0.75).lerp(Color(1.0, 0.48, 0.2), dusk)
	rim.light_energy = (lerpf(0.16, 0.1, day) + dusk * 0.16 + sin(_t * 1.3) * 0.03) * light_scale
	fill.light_color = Color(0.5, 0.6, 0.9).lerp(Color(0.95, 0.5, 0.28), dusk * 0.75).lerp(Color(0.72, 0.78, 0.72), day * (1.0 - dusk))
	fill.light_energy = (lerpf(0.32, 0.46, day) + dusk * 0.2) * light_scale
	if dust != null and dust.material_override is StandardMaterial3D:
		var dust_mat := dust.material_override as StandardMaterial3D
		dust_mat.albedo_color = Color(1.0, 0.9, 0.7, 0.28).lerp(Color(1.0, 0.55, 0.28, 0.24), dusk)
	if fireflies != null:
		fireflies.emitting = particle_scale > 0.02 and day < 0.25 and wet < 0.35

func _aim(light: DirectionalLight3D, dir: Vector3) -> void:
	var d := dir.normalized()
	var up := Vector3.UP
	if absf(d.dot(up)) > 0.98:
		up = Vector3.FORWARD
	light.look_at(light.global_position - d, up)
