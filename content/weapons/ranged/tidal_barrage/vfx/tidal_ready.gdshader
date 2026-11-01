shader_type canvas_item;
render_mode unshaded, blend_add;

uniform float progress : hint_range(0.0, 1.0) = 1.0;

void fragment() {
    vec4 body = texture(TEXTURE, UV);
    float sweep = 1.0 - smoothstep(0.025, 0.14, abs(UV.x + UV.y * 0.15 - mix(-0.15, 1.3, progress)));
    float fade = 1.0 - smoothstep(0.55, 1.0, progress);
    float metal = smoothstep(0.10, 0.50, max(body.r, max(body.g, body.b)));
    vec3 light = mix(vec3(0.22, 0.73, 0.83), vec3(0.88, 1.0, 0.97), sweep);
    COLOR = vec4(light, body.a * metal * (sweep * 0.85 + fade * 0.08) * fade) * COLOR;
}
