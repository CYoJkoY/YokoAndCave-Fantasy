shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform float age = 0.0;
uniform float seed = 0.0;

void fragment() {
	float x = UV.x;
	float y = UV.y * 2.0 - 1.0;
	float tail = 1.0 - smoothstep(0.25, 0.82, x);
	float sway = sin(x * 9.0 + age * 10.0 + seed);
	float curl = sin(x * 17.0 + age * 14.0 + seed * 1.7);
	float center = sway * tail * 0.20;
	float front = 1.0 - smoothstep(0.70, 0.96, x);
	float radius = (0.12 + 0.50 * smoothstep(0.04, 0.68, x)) * front;
	float edge = abs(y - center) / max(radius, 0.008);
	float body = 1.0 - smoothstep(0.72, 1.02, edge);
	float split = abs(y - center - curl * 0.13 * tail);
	float notch = (1.0 - smoothstep(0.025, 0.095, split)) * tail;
	body *= 1.0 - notch * 0.95;
	float tongue_center = center + (0.18 + curl * 0.09) * tail;
	float tongue = 1.0 - smoothstep(0.035, 0.11, abs(y - tongue_center));
	tongue *= smoothstep(0.02, 0.24, x) * (1.0 - smoothstep(0.45, 0.75, x));
	float core = (1.0 - smoothstep(0.12, 0.66, edge)) * smoothstep(0.26, 0.62, x);
	float rim = 1.0 - smoothstep(0.25, 0.95, edge);
	vec3 color = mix(vec3(0.98, 0.12, 0.012), vec3(1.0, 0.58, 0.045), rim);
	color = mix(color, vec3(1.0, 0.96, 0.70), core);
	float alpha = max(body, tongue * 0.8) * smoothstep(0.015, 0.16, x);
	COLOR = vec4(color, alpha) * COLOR;
}
