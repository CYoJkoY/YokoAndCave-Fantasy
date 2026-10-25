shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec4 core_color : hint_color = vec4(1.0, 0.99, 0.91, 1.0);
uniform vec4 edge_color : hint_color = vec4(1.0, 0.55, 0.05, 1.0);
uniform float flow_speed : hint_range(0.0, 20.0) = 3.2;
uniform float pulse_speed : hint_range(0.0, 30.0) = 8.0;
uniform float noise_scale : hint_range(0.1, 20.0) = 5.0;
uniform float core_strength : hint_range(1.0, 80.0) = 22.0;
uniform float soft_strength : hint_range(0.1, 20.0) = 2.4;
uniform float intensity : hint_range(0.0, 4.0) = 1.0;
uniform float seed : hint_range(0.0, 100.0) = 0.0;
uniform float tail_fade_length : hint_range(0.0, 1.0) = 0.0;

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
	float across = uv.y - 0.5;

	float core = exp(-across * across * core_strength);
	float soft = exp(-across * across * soft_strength);

	float n1 = noise(vec2(uv.x * noise_scale + seed, TIME * flow_speed));
	float n2 = noise(vec2(uv.x * noise_scale * 2.35 - TIME * flow_speed * 1.7, across * 4.0 + seed));
	float filaments = smoothstep(0.28, 0.82, n1) * (0.50 + 0.50 * n2);

	float pulse = 0.76 + 0.24 * sin(uv.x * 25.0 - TIME * pulse_speed + seed * 3.0);
	vec3 color = mix(edge_color.rgb, core_color.rgb, clamp(core * 1.55 + n1 * 0.18, 0.0, 1.0));
	color = mix(color, core_color.rgb, filaments * core * 0.58);

	float alpha = (core * 0.86 + soft * 0.13 + filaments * core * 0.72) * pulse * intensity;
	float edge_fade = 1.0 - smoothstep(0.33, 0.5, abs(across));
	float tail_fade = 1.0;
	if (tail_fade_length > 0.0) {
		tail_fade = smoothstep(0.0, tail_fade_length, uv.x);
	}
	alpha *= edge_fade * tail_fade;

	COLOR = vec4(color * (1.0 + core * 1.05), alpha) * COLOR;
}
