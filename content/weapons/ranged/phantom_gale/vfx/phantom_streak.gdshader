shader_type canvas_item;
render_mode unshaded, blend_add;

varying vec4 streak_color;

void vertex() {
    streak_color = COLOR;
}

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    float tail = pow(max(0.0, 1.0 - UV.x), 0.85);
    COLOR = vec4(tex.rgb * streak_color.rgb, tex.a * tail * streak_color.a);
}
