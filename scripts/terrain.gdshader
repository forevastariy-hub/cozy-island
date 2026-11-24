shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

uniform sampler2D zone_mask : filter_linear, repeat_disable;
uniform float world_size = 1000.0;
uniform vec3 grass_dark : source_color = vec3(0.22, 0.40, 0.13);
uniform vec3 grass_light : source_color = vec3(0.42, 0.58, 0.20);
uniform vec3 dirt_color : source_color = vec3(0.42, 0.32, 0.18);
uniform vec3 path_color : source_color = vec3(0.56, 0.46, 0.30);
uniform vec3 swamp_color : source_color = vec3(0.19, 0.28, 0.14);
uniform vec3 rock_color : source_color = vec3(0.48, 0.45, 0.38);
uniform vec3 sand_color : source_color = vec3(0.70, 0.62, 0.44);
uniform vec3 field_color : source_color = vec3(0.55, 0.50, 0.26);
uniform float wetness = 0.0;

varying vec3 world_pos;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += value_noise(p) * a;
		p = p * 2.03 + vec2(13.7, 7.1);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = (world_pos.xz + vec2(world_size * 0.5)) / world_size;
	vec4 zone = texture(zone_mask, clamp(uv, vec2(0.001), vec2(0.999)));

	float broad = fbm(world_pos.xz * 0.07);
	float fine = fbm(world_pos.xz * 0.45);
	float grain = mix(broad, fine, 0.35);
	// extra micro detail so ground is not plastic
	float micro = fbm(world_pos.xz * 1.6 + vec2(17.0, -23.0)) * 0.5 + 0.5;
	grain = mix(grain, micro, 0.25);

	vec3 base = mix(grass_dark, grass_light, smoothstep(0.15, 0.85, grain));
	base = mix(base, dirt_color, smoothstep(0.55, 0.9, broad) * 0.22);

	// dry grass patches driven by noise, scattered naturally
	float dry = fbm(world_pos.xz * 0.9 + vec2(50.0, -80.0));
	float dry_patch = smoothstep(0.6, 0.95, dry) * smoothstep(0.2, 0.8, fine);
	base = mix(base, vec3(0.62, 0.54, 0.28), dry_patch * 0.22);

	vec3 path = path_color * (0.90 + grain * 0.22);
	base = mix(base, path, smoothstep(0.0, 0.72, zone.r) * 0.8);
	base = mix(base, swamp_color * (0.80 + fine * 0.30), zone.g * 0.92);
	base = mix(base, rock_color * (0.78 + fine * 0.35), zone.b);
	base = mix(base, sand_color * (0.88 + grain * 0.18), zone.a * 0.85);

	float wet = clamp(wetness, 0.0, 1.0);
	vec3 albedo = mix(COLOR.rgb, base, 0.5) * mix(1.0, 0.72, wet);
	ALBEDO = albedo;
	ROUGHNESS = mix(1.0, 0.18, wet);
	SPECULAR = mix(0.04, 0.55, wet);
}
