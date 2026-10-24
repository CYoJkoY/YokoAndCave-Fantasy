shader_type canvas_item;
render_mode unshaded, blend_add;

uniform float phase = 0.0;
uniform float progress = 0.0;
uniform float hue = 0.0;

void fragment() {
    vec4 tint = COLOR;
    float x = UV.x;
    float y = (UV.y - 0.5) * 2.0;
    float taper = mix(0.56, 0.14, x);
    float ends = smoothstep(0.0, 0.10, x) * (1.0 - smoothstep(0.82, 1.0, x));
    float drift = sin(x * 6.283185 - phase * 3.0) * sin(x * 3.141593) * 0.055;
    float veil = exp(-pow(y / taper, 2.0) * 1.6);
    float filament = exp(-pow((y - drift) / (taper * 0.13 + 0.018), 2.0));
    float edge = exp(-pow((y + drift - taper * 0.17) / (taper * 0.08 + 0.015), 2.0));
    float flow = pow(max(0.0, cos(x * 10.0 - phase * 13.0)), 4.0);
    float crest = exp(-pow((x - progress) / 0.24, 2.0));
    vec3 spectrum = 0.72 + 0.28 * cos(6.283185 * (x * 0.17 + y * 0.36 + hue - phase * 0.04 + vec3(0.0, 0.33, 0.67)));
    vec3 color = mix(vec3(0.76, 0.87, 1.0), spectrum, 0.65);
    color = mix(color, vec3(1.0, 0.98, 0.94), filament * (0.25 + crest * 0.45));
    float light = veil * (0.18 + crest * 0.12) + filament * (0.24 + flow * 0.42 + crest * 0.34) + edge * (0.12 + flow * 0.18);
    COLOR = vec4(color, light * ends) * tint;
}
