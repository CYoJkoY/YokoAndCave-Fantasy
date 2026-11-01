shader_type canvas_item;
render_mode unshaded;

uniform float phase = 0.0;
uniform float charge = 0.0;

void fragment() {
    vec4 blade = texture(TEXTURE, UV);
    float scan = pow(max(0.0, 1.0 - abs(fract(UV.x * 0.9 - phase * 0.6) - 0.5) * 8.0), 3.0);
    vec3 tint = mix(vec3(0.26, 0.65, 1.0), vec3(0.85, 0.98, 1.0), blade.r);
    COLOR = vec4(tint * (0.85 + scan * 0.65 + charge * 0.45), blade.a) * COLOR;
}
