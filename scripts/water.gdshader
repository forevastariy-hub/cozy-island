shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, diffuse_lambert;

uniform sampler2D zone_mask : filter_linear_mipmap, repeat_disable;
uniform float world_size = 160.0;
uniform vec3 deep_color : source_color = vec3(0.10, 0.32, 0.36);
uniform vec3 shallow_color : source_color = vec3(0.24, 0.55, 0.52);
uniform vec3 sky_color : source_color = vec3(0.55, 0.62, 0.63);
uniform vec3 foam_color : source_color = vec3(0.85, 0.9, 0.82);
uniform float wave_strength = 0.045;
uniform float wave_speed = 0.85;
uniform float transparency = 0.78;
uniform vec3 sun_dir = vec3(0.0, 0.6, 0.4);
uniform vec3 sun_color : source_color = vec3(1.0, 0.78, 0.42);
uniform float glint = 0.35;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float w = sin(world_pos.x * 0.34 + TIME * wave_speed)
		+ sin(world_pos.z * 0.47 + TIME * wave_speed * 1.31)
		+ sin((world_pos.x + world_pos.z) * 0.21 + TIME * 0.61);
	VERTEX.y += w * wave_strength;
	float dx = cos(world_pos.x * 0.34 + TIME * wave_speed) * 0.34
		+ cos((world_pos.x + world_pos.z) * 0.21 + TIME * 0.61) * 0.21;
	float dz = cos(world_pos.z * 0.47 + TIME * wave_speed * 1.31) * 0.47
		+ cos((world_pos.x + world_pos.z) * 0.21 + TIME * 0.61) * 0.21;
	vec3 wn = normalize(vec3(-dx * wave_strength, 1.0, -dz * wave_strength));
	world_normal = normalize((MODEL_MATRIX * vec4(wn, 0.0)).xyz);
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
}

void fragment() {
	vec2 uv = (world_pos.xz + vec2(world_size * 0.5)) / world_size;
	vec4 zone = texture(zone_mask, clamp(uv, vec2(0.001), vec2(0.999)));

	float view = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel = pow(1.0 - view, 3.0);
	float ripple = sin(world_pos.x * 2.6 + TIME * 1.8) * sin(world_pos.z * 2.2 - TIME * 1.4);
	vec3 col = mix(deep_color, shallow_color, clamp(zone.a * 0.85 + ripple * 0.08, 0.0, 1.0));
	col = mix(col, sky_color, fresnel * 0.52);

	float foam = smoothstep(0.48, 0.92, zone.a);
	foam *= 0.55 + 0.45 * sin(world_pos.x * 2.3 + world_pos.z * 1.9 + TIME * 1.6);
	foam = clamp(foam, 0.0, 1.0);

	vec3 n = normalize(world_normal);
	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - world_pos);
	vec3 refl = reflect(-view_dir, n);
	float spec = pow(clamp(dot(refl, normalize(sun_dir)), 0.0, 1.0), 42.0);
	col += sun_color * spec * glint;
	col = mix(col, sun_color, fresnel * glint * 0.08);
	ALBEDO = col;
	EMISSION = foam_color * foam * 0.22 + sun_color * spec * glint * 0.35;
	ALPHA = clamp(transparency + fresnel * 0.16 + foam * 0.15, 0.0, 0.96);
	ROUGHNESS = 0.08;
	METALLIC = 0.12;
}
