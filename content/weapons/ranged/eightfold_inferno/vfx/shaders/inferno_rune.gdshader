shader_type canvas_item;
render_mode unshaded, blend_add;

uniform float strength : hint_range(0.0, 2.0) = 1.0;
uniform float energy : hint_range(0.0, 2.0) = 1.0;
uniform float spin : hint_range(-12.0, 12.0) = 0.0;
uniform float seed : hint_range(0.0, 100.0) = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float cs = cos(spin);
	float sn = sin(spin);
	vec2 rotated = vec2(centered.x * cs - centered.y * sn, centered.x * sn + centered.y * cs) + vec2(0.5);

	vec4 tex = texture(TEXTURE, rotated);
	float n = noise(vec2(rotated.x * 11.0 + TIME * 0.8 + seed, rotated.y * 11.0 - TIME * 0.6));

	vec2 spun_center = rotated - vec2(0.5);
	float angle = atan(spun_center.y, spun_center.x);
	float sweep = 0.5 + 0.5 * sin(angle * 8.0 - TIME * 1.7 + seed);
	float energy_ring = 0.82 + 0.18 * sweep;

	vec3 color = mix(vec3(1.0, 0.22, 0.015), vec3(1.0, 0.86, 0.36), clamp(tex.r * 0.9 + 0.18, 0.0, 1.0));
	float flicker = 0.76 + 0.24 * n;
	float alpha = tex.a * flicker * strength * energy_ring * (0.95 + 0.18 * energy);

	COLOR = vec4(color * (1.30 + energy * 0.45), alpha * 1.12) * COLOR;
}
