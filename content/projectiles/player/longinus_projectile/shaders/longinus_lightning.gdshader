shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec4 core_color : hint_color = vec4(1.0, 0.97, 0.76, 1.0);
uniform vec4 glow_color : hint_color = vec4(1.0, 0.50, 0.03, 0.62);
uniform float flicker_speed : hint_range(0.0, 60.0) = 22.0;
uniform float flicker_amount : hint_range(0.0, 1.0) = 0.30;
uniform float core_width : hint_range(0.02, 0.49) = 0.20;
uniform float glow_softness : hint_range(0.05, 1.0) = 0.55;
uniform float intensity : hint_range(0.0, 4.0) = 1.0;
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
	float across = abs(uv.y - 0.5) * 2.0;

	float core = 1.0 - smoothstep(0.0, max(0.02, core_width), across);
	core = pow(core, 1.35);
	float glow = exp(-across * across / max(0.04, glow_softness * glow_softness));

	float n1 = noise(vec2(uv.x * 17.0 + seed, TIME * flicker_speed));
	float n2 = noise(vec2(uv.x * 37.0 - TIME * flicker_speed * 1.63, seed + 9.0));
	float flicker = 1.0 - flicker_amount * 0.5 + flicker_amount * (n1 * 0.65 + n2 * 0.35);

	vec3 color = mix(glow_color.rgb, core_color.rgb, clamp(core * 1.6, 0.0, 1.0));
	float alpha = (core * 0.95 + glow * 0.46) * flicker * intensity;
	COLOR = vec4(color, alpha) * COLOR;
}
