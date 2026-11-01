shader_type canvas_item;
render_mode unshaded, blend_add;

uniform float phase = 0.0;
uniform float fade = 1.0;
uniform float beam_length = 400.0;
uniform float travel_time = 0.05;

void fragment() {
    vec4 tint = COLOR;
    vec4 tex = texture(TEXTURE, UV);
    float y = abs(UV.y - 0.5) * 2.0;
    float core = exp(-y * y * 260.0);
    float flow = UV.x * beam_length * 0.035 - phase * 52.0;
    float ribbon = 0.80 + 0.20 * sin(flow + UV.y * 22.0);
    vec3 spectrum = 0.57 + 0.43 * cos(6.283185 * (UV.y * 2.8 + UV.x * 0.16 - phase * 0.35 + vec3(0.0, 0.33, 0.67)));
    float caustic = exp(-pow((y - 0.24 - sin(flow * 0.7) * 0.035) * 48.0, 2.0));
    float reach = 1.0 - smoothstep(phase / travel_time - 0.035, phase / travel_time + 0.035, UV.x);
    float leading_light = exp(-pow((UV.x - phase / travel_time) / 0.07, 2.0));
    vec3 color = mix(spectrum * ribbon, vec3(1.0, 0.98, 0.94), core);
    COLOR = vec4(color * (0.85 + core * 0.35 + leading_light * 0.55), (tex.a + caustic * tex.a * 0.7) * reach * pow(fade, 1.15)) * tint;
}
