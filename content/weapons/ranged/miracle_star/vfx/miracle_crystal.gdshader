shader_type canvas_item;
render_mode unshaded;

uniform float phase = 0.0;
uniform float energy = 0.0;
uniform float cast_phase = 1.25;
uniform vec4 region = vec4(0.0, 0.0, 1.0, 1.0);

void fragment() {
    vec4 tint = COLOR;
    vec4 base = texture(TEXTURE, UV);
    vec2 facet_uv = (UV - region.xy) / region.zw;
    float band = pow(max(0.0, sin((facet_uv.x * 0.70 + facet_uv.y * 0.42) * 16.0 - phase * 1.2)), 18.0);
    vec3 spectrum = 0.65 + 0.35 * cos(6.283185 * (facet_uv.x * 0.6 + facet_uv.y * 0.4 + phase * 0.035 + vec3(0.0, 0.33, 0.67)));
    float sweep = exp(-pow((facet_uv.x * 0.65 + facet_uv.y * 0.35 - cast_phase) / 0.095, 2.0));
    vec3 glass = base.rgb + spectrum * band * (0.14 + energy * 0.14);
    glass += mix(spectrum, vec3(1.0), 0.6) * sweep * energy * 0.8;
    COLOR = vec4(glass, base.a) * tint;
}
