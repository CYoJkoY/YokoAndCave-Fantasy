shader_type canvas_item;
render_mode unshaded;

uniform float charge : hint_range(0.0, 1.0) = 1.0;
uniform float pulse : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec4 mask = texture(TEXTURE, UV);
    float flow = 0.5 + 0.5 * sin(UV.x * 32.0 - TIME * 6.0 + sin(UV.y * 23.0));
    float crest = smoothstep(0.72, 1.0, flow);
    float filled = 1.0 - smoothstep(charge - 0.05, charge + 0.03, UV.x);
    vec3 deep = vec3(0.14, 0.20, 0.34);
    vec3 water = mix(vec3(0.13, 0.48, 0.59), vec3(0.53, 0.91, 0.92), crest);
    vec3 color = mix(deep, water, filled * 0.9);
    color = mix(color, vec3(0.85, 1.0, 0.98), pulse * 0.65);
    COLOR = vec4(color, mask.a) * COLOR;
}
