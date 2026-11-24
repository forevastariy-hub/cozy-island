shader_type spatial;
render_mode cull_disabled, diffuse_lambert, depth_draw_opaque;

uniform vec3 root_color : source_color = vec3(0.20, 0.23, 0.10);
uniform vec3 tip_color : source_color = vec3(0.47, 0.48, 0.22);
uniform float wind_strength = 0.16;
uniform float wind_speed = 1.15;
global uniform float wind_amount;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float phase = world_pos.x * 0.3 + world_pos.z * 0.22 + world_pos.y * 0.5;
	float bend = sin(TIME * wind_speed + phase) * wind_strength
		+ sin(TIME * wind_speed * 2.4 + phase * 1.6) * wind_strength * 0.22
		+ sin(TIME * wind_speed * 0.6 + phase * 2.4) * wind_strength * 0.12;
	bend *= wind_amount;
	float h = clamp(VERTEX.y, 0.0, 1.0);
	// base stays fixed, tip moves most, with a slight curve
	float curve = h * h * (1.0 - h * 0.3);
	VERTEX.x += bend * curve;
	VERTEX.z += bend * 0.45 * curve;
	VERTEX.y += bend * 0.03 * h;
}

void fragment() {
	float h = clamp(UV.y, 0.0, 1.0);
	float variation = 0.85 + 0.15 * sin(world_pos.x * 2.4 + world_pos.z * 1.8 + world_pos.y * 1.2);
	vec3 base = mix(root_color, tip_color, h);
	ALBEDO = base * variation * COLOR.rgb;
	ALBEDO *= COLOR.a;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
