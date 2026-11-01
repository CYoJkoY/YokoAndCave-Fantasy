shader_type canvas_item;
render_mode unshaded, blend_add;

uniform float age = 0.0;
uniform float seed = 0.0;
uniform float path_length = 350.0;

void fragment() {
	float x = UV.x * path_length;
	float y = UV.y * 2.0 - 1.0;
	float flow = x * 0.11 - age * 13.0 + seed;
	float braid = sin(x * 0.075 - age * 8.0 + seed) * 0.32;
	float first_distance = (y - braid) * 4.0;
	float second_distance = (y + braid * 0.8) * 5.0;
	float strand = exp(-first_distance * first_distance);
	float second = exp(-second_distance * second_distance);
	float gaps = smoothstep(-0.65, 0.55, sin(flow) + sin(flow * 1.73 + seed) * 0.45);
	float envelope = smoothstep(0.0, 0.10, UV.x) * (1.0 - smoothstep(0.92, 1.0, UV.x));
	float alpha = (strand * gaps * 0.68 + second * (1.0 - gaps) * 0.34) * envelope;
	COLOR = vec4(1.0, 0.84, 0.36, alpha) * COLOR;
}
