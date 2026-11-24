shader_type spatial;
render_mode diffuse_lambert, cull_disabled;

uniform vec3 leaf_color : source_color = vec3(0.29, 0.35, 0.16);
uniform float wind_strength = 0.045;
uniform float wind_speed = 0.85;
global uniform float wind_amount;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float phase = world_pos.x * 0.18 + world_pos.z * 0.14;
	float sway = sin(TIME * wind_speed + phase) * wind_strength
		+ sin(TIME * wind_speed * 2.7 + phase * 1.9) * wind_strength * 0.22;
	sway *= wind_amount;
	float h = max(VERTEX.y, 0.0);
	VERTEX.x += sway * h;
	VERTEX.z += sway * 0.55 * h;
}

void fragment() {
	float variation = 0.88 + 0.12 * sin(world_pos.x * 2.1 + world_pos.z * 1.6);
	ALBEDO = leaf_color * variation;
	ROUGHNESS = 0.96;
	SPECULAR = 0.03;
}
