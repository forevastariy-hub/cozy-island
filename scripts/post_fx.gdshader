shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float vignette_strength = 0.16;
uniform float grain_strength = 0.012;
uniform float warm_shift = 0.02;
uniform float warm_mix = 1.0;
uniform float desat = 0.0;
uniform float contrast = 1.02;
uniform float aberration = 0.0004;
uniform float rain_mix = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 dir = uv - vec2(0.5);
	float d = length(dir);
	vec2 off = dir * aberration * d;

	vec3 col;
	col.r = texture(screen_texture, uv + off).r;
	col.g = texture(screen_texture, uv).g;
	col.b = texture(screen_texture, uv - off).b;

	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(lum), desat);
	col = (col - 0.5) * contrast + 0.5;

	float shadow_lift = 1.0 - smoothstep(0.0, 0.65, lum);
	col.r += warm_shift * warm_mix * shadow_lift * 0.5;
	col.g += warm_shift * warm_mix * shadow_lift * 0.3;
	col.b -= warm_shift * warm_mix * shadow_lift * 0.2;
	col = mix(col, col * vec3(1.1, 0.95, 0.82), warm_mix * 0.18);

	float night_mix = 1.0 - smoothstep(0.0, 0.22, warm_mix);
	col = mix(col, col * vec3(0.76, 0.86, 1.12), night_mix * 0.42);
	col *= mix(1.0, 0.84, night_mix * 0.45);

	col = mix(col, col * vec3(0.80, 0.89, 1.02), rain_mix * 0.42);
	col = mix(col, vec3(dot(col, vec3(0.299, 0.587, 0.114))), rain_mix * 0.10);

	float v = smoothstep(0.24, 0.95, d * 1.35);
	col *= 1.0 - v * vignette_strength;

	float g = hash(uv * vec2(1920.0, 1080.0) + TIME * 60.0) - 0.5;
	col += g * grain_strength;

	COLOR = vec4(col, 1.0);
}
