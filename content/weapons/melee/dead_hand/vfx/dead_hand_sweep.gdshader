shader_type canvas_item;
render_mode blend_add, unshaded;

uniform float progress = 0.0;
uniform float side = 1.0;
uniform float half_angle = 1.75;
uniform float release = 0.0;

void fragment() {
    vec4 tint = COLOR;
    vec2 p = (UV - vec2(0.5)) * 2.0;
    float angle = atan(p.y * side, p.x);
    float along = (angle + half_angle) / (half_angle * 2.0);
    float front = progress * 1.04 + release * 0.12;
    float reveal = 1.0 - smoothstep(front - 0.025, front + 0.025, along);
    float tail_width = mix(0.72, 0.28, release);
    float tail = smoothstep(front - tail_width, front - tail_width * 0.30, along);
    float fan = smoothstep(-0.025, 0.015, along) * (1.0 - smoothstep(0.99, 1.025, along));
    float radius = length(p);
    float sample_radius = 0.78 + (radius - 0.78) / (1.0 - release * 0.30);
    vec2 sample_uv = p * max(0.0, sample_radius) / max(radius, 0.001) * 0.5 + vec2(0.5);
    vec4 art = texture(TEXTURE, clamp(sample_uv, vec2(0.001), vec2(0.999)));
    float edge = exp(-pow((along - front + 0.045) / 0.085, 2.0));
    vec3 col = mix(art.rgb, vec3(0.89, 0.78, 1.0), edge * 0.36 * (1.0 - release));
    col = mix(col, col * vec3(0.72, 0.46, 0.90), release * 0.6);
    COLOR = vec4(col, art.a * reveal * tail * fan) * tint;
}
