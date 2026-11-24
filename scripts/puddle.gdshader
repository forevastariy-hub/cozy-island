shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, diffuse_lambert;

uniform vec3 water_color : source_color = vec3(0.12, 0.23, 0.28);
uniform vec3 sky_color : source_color = vec3(0.62, 0.72, 0.80);
uniform vec3 rim_color : source_color = vec3(0.76, 0.83, 0.86);
uniform float wetness = 1.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(world_pos.x * 5.0 + TIME * 1.3) * sin(world_pos.z * 4.3 - TIME * 1.1) * 0.004;
}

void fragment() {
	vec2 c = (UV - vec2(0.5)) * vec2(1.0, 1.35);
	float d = length(c);
	float edge = 1.0 - smoothstep(0.34, 0.5, d);
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	float rings = sin(d * 38.0 - TIME * 2.4
		+ sin(UV.x * 11.0 + TIME * 0.7) * 1.2
		+ sin(UV.y * 9.0 - TIME * 0.6) * 1.2);
	vec3 col = mix(water_color, sky_color, 0.22 + fresnel * 0.65);
	col *= mix(0.80, 1.0, smoothstep(0.0, 0.22, d));
	col += rings * 0.012;
	col = mix(col, rim_color, smoothstep(0.36, 0.5, d) * 0.30);
	ALBEDO = col;
	ALPHA = edge * wetness * (0.88 + fresnel * 0.12);
	ROUGHNESS = 0.05;
	METALLIC = 0.2;
}
