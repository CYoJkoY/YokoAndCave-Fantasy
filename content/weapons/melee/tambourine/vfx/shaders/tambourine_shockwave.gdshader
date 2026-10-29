shader_type canvas_item;

uniform float clock_time = 0.0;
uniform float visual_lifetime;
uniform float clock_period;
uniform vec4 tint_color : hint_color = vec4(1.0, 0.77, 0.24, 1.0);

varying vec4 ring_params;
varying vec4 layer_tint;

void vertex() {
	float layer = floor(COLOR.r * 3.0 + 0.5);
	float elapsed = mod(clock_time - COLOR.g * clock_period + clock_period, clock_period);
	float visual_rotation = (COLOR.b * 2.0 - 1.0) * 3.14159265359;
	float progress = clamp(elapsed / visual_lifetime, 0.0, 1.0);
	float travel = 0.64 * (1.0 - exp(-6.0 * progress)) + 0.46 * progress;
	vec2 size;
	float angle = 0.0;
	float alpha;
	ring_params = vec4(0.0);
	layer_tint = vec4(1.0);
	if (layer < 0.5) {
		size = vec2((147.34 / 82.0) * (0.22 + 0.95 * travel));
		alpha = 0.50 * pow(1.0 - progress, 3.0);
	} else if (layer < 1.5) {
		float echo_time = max(0.0, elapsed - 0.035);
		float echo_progress = clamp(echo_time / (visual_lifetime - 0.035), 0.0, 1.0);
		float echo_travel = 0.5 * (1.0 - exp(-5.0 * echo_progress)) + 0.4 * echo_progress;
		size = vec2((147.34 / 106.0) * (0.18 + echo_travel));
		angle = visual_rotation + 0.65 - 0.06 * echo_progress;
		alpha = 0.52 * smoothstep(0.0, 0.018, echo_time) * pow(1.0 - echo_progress, 1.1);
		ring_params = vec4(echo_progress, visual_rotation + 2.1, 0.65, 1.0);
		layer_tint = vec4(1.0, 0.93, 0.65, 1.0);
	} else if (layer < 2.5) {
		size = vec2((147.34 / 106.0) * (0.22 + travel));
		angle = visual_rotation + 0.08 * progress;
		alpha = pow(1.0 - progress, 0.6);
		ring_params = vec4(progress, visual_rotation, 1.0, 1.0);
		layer_tint = tint_color;
	} else {
		float strike = clamp(elapsed / 0.16, 0.0, 1.0);
		float flash_travel = 1.5 * (1.0 - exp(-4.0 * strike)) + 0.45 * strike;
		size = vec2(1.06, 0.94) * (0.7 + flash_travel);
		angle = visual_rotation * 0.1 + 0.08 * strike;
		alpha = 1.0 - smoothstep(0.015, 0.16, elapsed);
	}
	vec2 position = VERTEX * 0.25 * size;
	float c = cos(angle);
	float s = sin(angle);
	VERTEX = vec2(c * position.x - s * position.y, s * position.x + c * position.y);
	COLOR = vec4(1.0, 1.0, 1.0, alpha);
}

void fragment() {
	if (ring_params.w > 0.5) {
		float progress = ring_params.x;
		float arc_phase = ring_params.y;
		vec2 offset = UV - vec2(0.5);
		float radius = max(length(offset), 0.0001);
		float angle = atan(offset.y, offset.x);
		float width = 1.18 * ring_params.z * mix(1.0, 0.22, smoothstep(0.06, 0.95, progress));
		float sample_radius = max(0.0, 106.0 / 256.0 + (radius - 106.0 / 256.0) / width);
		vec2 sample_uv = vec2(0.5) + offset / radius * sample_radius;
		vec4 tex = texture(TEXTURE, sample_uv);
		float arcs = 0.54 + 0.26 * sin(angle * 3.0 + arc_phase)
			+ 0.15 * sin(angle * 7.0 - arc_phase * 0.7)
			+ 0.05 * sin(angle * 13.0 + arc_phase);
		float erosion = smoothstep(0.16, 0.94, progress);
		float arc_mask = smoothstep(erosion - 0.16, erosion + 0.08, arcs);
		float edge = smoothstep(0.0, 0.12, tex.a);
		vec3 color = mix(tex.rgb, layer_tint.rgb, 0.2);
		color = mix(color, vec3(1.0, 0.97, 0.82), 0.12 + (1.0 - smoothstep(0.0, 0.28, progress)) * 0.44);
		COLOR *= vec4(color, tex.a * layer_tint.a * arc_mask * edge);
	} else {
		COLOR *= texture(TEXTURE, UV);
	}
}
