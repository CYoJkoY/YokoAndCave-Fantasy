shader_type canvas_item;
render_mode unshaded, blend_add;

varying vec4 ribbon_color;

void vertex() {
    ribbon_color = COLOR;
}

void fragment() {
    vec4 tint = ribbon_color;
    float wake = smoothstep(0.0, 0.85, UV.x);
    float drift = (sin(UV.x * 18.0 - TIME * 5.0) * 0.045
        + sin(UV.x * 37.0 + TIME * 3.5) * 0.018) * wake;
    vec2 uv = vec2(1.0 - UV.x, clamp(UV.y + drift, 0.0, 1.0));
    vec4 tex = texture(TEXTURE, uv);
    float vein = exp(-pow((UV.y - 0.5 + drift * 1.4) * 24.0, 2.0));
    float pulse = 0.87 + 0.13 * sin(UV.x * 27.0 - TIME * 12.0);
    float tail = pow(max(0.0, 1.0 - UV.x), 0.72);
    vec3 color = mix(tint.rgb, min(vec3(1.0), tint.rgb + vec3(0.5)), vein * 0.65);
    COLOR = vec4(color, (tex.a * pulse + vein * 0.12) * tail * tint.a);
}
