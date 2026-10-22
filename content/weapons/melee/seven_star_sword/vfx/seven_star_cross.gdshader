shader_type canvas_item;
render_mode unshaded, blend_add;

uniform float age = 0.0;
uniform float delay = 0.0;

void fragment() {
    vec4 tint = COLOR;
    float elapsed = max(0.0, age - delay);
    float retreat = smoothstep(0.10, 0.42, elapsed);
    float thickness = mix(1.0, 0.06, retreat);
    vec2 sample_uv = vec2(UV.x, (UV.y - 0.5) / thickness + 0.5);
    vec4 tex = texture(TEXTURE, clamp(sample_uv, vec2(0.001), vec2(0.999)));
    float inside = step(0.0, sample_uv.y) * step(sample_uv.y, 1.0);
    float front = mix(-0.10, 1.12, clamp(elapsed / 0.050, 0.0, 1.0));
    float reveal = (1.0 - smoothstep(front - 0.10, front + 0.02, UV.x)) * smoothstep(0.0, 0.030, elapsed);
    float tail = mix(-0.15, 1.10, smoothstep(0.18, 0.42, elapsed));
    float remain = smoothstep(tail - 0.10, tail + 0.06, UV.x);
    float fade = 1.0 - smoothstep(0.09, 0.42, elapsed);
    float edge_flash = exp(-pow((UV.x - front) / 0.08, 2.0)) * exp(-elapsed * 18.0);
    vec3 energy = tex.rgb + vec3(0.3, 0.6, 0.8) * edge_flash;
    COLOR = vec4(energy, tex.a * inside * reveal * remain * fade) * tint;
}
