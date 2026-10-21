shader_type canvas_item;
render_mode unshaded, blend_add;

uniform float age = 0.0;
uniform float seed = 0.0;
uniform float path_length = 350.0;

void fragment() {
	float y = UV.y * 2.0 - 1.0;
	float glow = exp(-y * y * 5.5) * (1.0 - smoothstep(0.65, 1.0, abs(y)));
	float pulse = 0.88 + 0.12 * sin(UV.x * path_length * 0.055 - age * 7.0 + seed);
	float envelope = smoothstep(0.0, 0.12, UV.x) * (1.0 - smoothstep(0.88, 1.0, UV.x));
	COLOR = vec4(1.0, 0.14, 0.008, glow * pulse * envelope * 0.24) * COLOR;
}
