shader_type canvas_item;
render_mode unshaded, blend_add;

uniform float strength : hint_range(0.0, 2.0) = 1.0;
uniform float age : hint_range(0.0, 100.0) = 0.0;
uniform float energy : hint_range(0.0, 2.0) = 0.0;
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
	vec2 uv = UV;
	float n = noise(vec2(uv.x * 6.5 + age * 0.45 + seed, uv.y * 6.5 - age * 0.62));
	vec2 distort = vec2(
		sin(uv.y * 9.0 + age * 2.2) * 0.010,
		cos(uv.x * 8.0 - age * 2.6) * 0.010
	) * (0.55 + energy * 0.8);

	vec4 tex = texture(TEXTURE, uv + distort);
	float flicker = 0.72 + 0.28 * n;
	vec3 color = mix(vec3(1.0, 0.16, 0.012), vec3(1.0, 0.70, 0.16), clamp(tex.r * 0.75 + 0.28, 0.0, 1.0));

	// A quick rising lick of flame at the top of the texture.
	float lick = (1.0 - smoothstep(0.0, 0.10, uv.y)) * noise(vec2(uv.x * 9.0 + age * 2.0, age * 1.5));
	color += vec3(1.0, 0.44, 0.04) * lick * 0.35;

	float alpha = tex.a * flicker * strength * (0.78 + 0.22 * energy);
	COLOR = vec4(color * (1.0 + energy * 0.55), alpha) * COLOR;
}
