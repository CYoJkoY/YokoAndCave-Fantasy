shader_type canvas_item;
render_mode blend_add, unshaded;

uniform float charge = 0.0;
uniform float phase = 0.0;

void fragment() {
    vec4 tint = COLOR;
    vec4 art = texture(TEXTURE, UV);
    float shimmer = pow(max(0.0, cos(UV.y * 10.0 - phase * 2.8)), 10.0);
    vec3 hue = mix(vec3(0.65, 0.88, 1.0), vec3(1.0, 0.98, 0.78), charge);
    COLOR = vec4(art.rgb * hue * (1.0 + charge * 0.4), art.a * (0.32 + charge * 0.68 + shimmer * 0.12)) * tint;
}
