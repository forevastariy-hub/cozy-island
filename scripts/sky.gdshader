shader_type sky;

uniform vec3 top_color : source_color = vec3(0.03, 0.06, 0.12);
uniform vec3 horizon_color : source_color = vec3(0.12, 0.16, 0.22);
uniform vec3 moon_color : source_color = vec3(0.95, 0.94, 0.86);
uniform vec3 sun_color : source_color = vec3(1.0, 0.82, 0.5);
uniform vec3 moon_dir = vec3(0.18, 0.3, -0.94);
uniform vec3 sun_dir = vec3(-0.18, -0.3, 0.94);
uniform float moon_size : hint_range(0.0005, 0.2) = 0.0045;
uniform float sun_size : hint_range(0.0005, 0.2) = 0.0018;
uniform float star_amount : hint_range(0.0, 1.0) = 0.5;
uniform float glow_strength : hint_range(0.0, 2.0) = 0.45;
uniform float cloud_amount : hint_range(0.0, 1.0) = 0.35;
uniform float day_amount : hint_range(0.0, 1.0) = 0.0;
uniform float sunset_amount : hint_range(0.0, 1.0) = 0.0;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 45.164))) * 43758.5453);
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = clamp(d.y * 0.5 + 0.5, 0.0, 1.0);
	vec3 col = mix(horizon_color, top_color, pow(h, 0.55));

	float horizon = pow(1.0 - clamp(abs(d.y), 0.0, 1.0), 5.0);
	vec3 horizon_glow = mix(vec3(0.08, 0.12, 0.18), vec3(0.42, 0.34, 0.22), day_amount);
	col += horizon_glow * horizon;

	vec3 sp = floor(d * 360.0);
	float rnd = hash(sp);
	float star = step(0.9982, rnd) * smoothstep(0.02, 0.35, d.y);
	col += vec3(0.8, 0.85, 1.0) * star * star_amount * (1.0 - day_amount);

	float moon_vis = smoothstep(-0.04, 0.08, moon_dir.y);
	float md = dot(d, normalize(moon_dir));
	float mdisk = smoothstep(1.0 - moon_size, 1.0 - moon_size * 0.8, md) * moon_vis;
	col = mix(col, moon_color, mdisk);
	float crater = hash(floor(d * 900.0));
	col = mix(col, moon_color * 0.78, mdisk * step(0.55, crater) * 0.5);
	col += moon_color * pow(max(md, 0.0), 80.0) * glow_strength * moon_vis;

	float sun_vis = smoothstep(-0.04, 0.08, sun_dir.y);
	float sd = dot(d, normalize(sun_dir));
	float sdisk = smoothstep(1.0 - sun_size, 1.0 - sun_size * 0.8, sd) * sun_vis;
	col = mix(col, sun_color, sdisk * 0.85);
	col += sun_color * pow(max(sd, 0.0), 40.0) * 0.45 * sun_vis;
	float low_sky = pow(1.0 - clamp(d.y + 0.02, 0.0, 1.0), 1.45);
	vec3 sunset_col = vec3(0.97, 0.40, 0.14);
	col = mix(col, sunset_col, low_sky * sunset_amount * 0.62 * sun_vis);
	col += sunset_col * pow(max(sd, 0.0), 10.0) * sunset_amount * 0.7 * sun_vis;
	col += sun_color * pow(max(sd, 0.0), 5.0) * sunset_amount * 0.22 * sun_vis;

	vec3 sdir = normalize(sun_dir);
	vec3 sup = abs(sdir.y) < 0.99 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
	vec3 sx = normalize(cross(sup, sdir));
	vec3 sy = cross(sdir, sx);
	vec2 sr = vec2(dot(d, sx), dot(d, sy));
	float srad = length(sr);
	float sang = atan(sr.y, sr.x);
	float spokes = 0.5 + 0.5 * sin(sang * 17.0 + TIME * 0.04 + sin(srad * 7.0) * 0.9);
	float ray_band = smoothstep(0.03, 0.12, srad) * (1.0 - smoothstep(0.12, 0.62, srad));
	col += sun_color * spokes * ray_band * 0.07 * sun_vis * (0.3 + 0.7 * day_amount);

	float band = smoothstep(0.0, 0.25, d.y) * smoothstep(0.7, 0.2, d.y);
	float cl = sin(d.x * 7.0 + TIME * 0.01) * sin(d.z * 6.0 - TIME * 0.008);
	vec3 cloud_col = mix(vec3(0.08, 0.09, 0.12), vec3(0.32, 0.3, 0.24), day_amount);
	col += cloud_col * smoothstep(0.55, 1.0, cl) * band * cloud_amount;

	COLOR = col;
}
