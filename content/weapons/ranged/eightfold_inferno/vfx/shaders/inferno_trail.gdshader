shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform float age = 0.0;
uniform float seed = 0.0;
uniform float path_length = 350.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}

void fragment() {
	float x = UV.x * path_length;
	float y = UV.y * 2.0 - 1.0;
	float flow = x * 0.065 - age * 7.5 + seed;
	float coarse = noise(vec2(flow, y * 2.4 + seed));
	float fine = noise(vec2(flow * 2.7 - age * 2.0, y * 6.0));
	float curl = sin(x * 0.09 - age * 11.0 + seed) * 0.11;
	float ridge = abs(y + curl + (coarse - 0.5) * 0.34);
	float edge = 0.40 + coarse * 0.42 + fine * 0.10;
	float body = 1.0 - smoothstep(edge - 0.14, edge, ridge);
	float heat = 1.0 - smoothstep(0.04, 0.53, ridge);
	float tongues = smoothstep(0.34, 0.74, fine + coarse * 0.22);
	float gold = heat * (0.30 + tongues * 0.65);
	vec3 color = mix(vec3(0.48, 0.025, 0.008), vec3(1.0, 0.18, 0.012), body);
	color = mix(color, vec3(1.0, 0.60, 0.075), gold);
	color = mix(color, vec3(1.0, 0.91, 0.48), heat * tongues * 0.55);
	float start = smoothstep(0.0, 0.07, UV.x);
	float end = 1.0 - smoothstep(0.965, 1.0, UV.x);
	COLOR = vec4(color, body * start * end * 0.92) * COLOR;
}
