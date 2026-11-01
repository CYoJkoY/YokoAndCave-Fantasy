shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec4 tint : hint_color = vec4(0.345, 0.792, 1.0, 1.0);
uniform float age = 0.0;
uniform float seed = 0.0;

void fragment() {
    float u = clamp(UV.x, 0.0, 1.0);
    float y = UV.y * 2.0 - 1.0;
    float t = age + seed;
    float spine = sin(u * 11.0 - t * 14.0) * (1.0 - u) * 0.065;
    float width = 0.08 + pow(u, 0.85) * 0.46;
    float fluid = exp(-pow((y - spine) / width, 2.0));
    float filament_width = 0.045 + u * 0.025;
    float thread_a = exp(-pow((y - spine - sin(u * 12.0 - t * 12.0) * width * 0.42) / filament_width, 2.0));
    float thread_b = exp(-pow((y - spine + sin(u * 8.0 + t * 10.0) * width * 0.48) / filament_width, 2.0));
    float glow = exp(-pow((y - spine) / (width * 1.8), 2.0));
    float taper = smoothstep(0.0, 0.24, u) * (1.0 - smoothstep(0.72, 1.0, u) * 0.80);
    vec3 companion = mix(tint.rgb, vec3(tint.b, tint.r, tint.g), 0.12);
    float weave = 1.0 - smoothstep(0.65, 1.0, u);
    vec3 light = tint.rgb * (fluid * 0.42 + thread_a * weave * 0.13 + glow * 0.12);
    light += companion * thread_b * weave * 0.12;
    light += mix(tint.rgb, vec3(1.0), 0.85) * fluid * 0.18 * u * u;
    float edge = 1.0 - smoothstep(0.72, 0.99, abs(y));
    COLOR = vec4(light * taper * edge, edge) * COLOR;
}
