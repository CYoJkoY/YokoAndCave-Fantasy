shader_type canvas_item;
render_mode unshaded, blend_add;

varying vec4 head_color;

void vertex() {
    head_color = COLOR;
}

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    tex.a *= smoothstep(0.78, 0.88, UV.x);
    COLOR = tex * head_color;
}
