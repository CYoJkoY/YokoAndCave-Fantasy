shader_type canvas_item;
render_mode unshaded, blend_add;

uniform float charge = 0.0;

void fragment() {
    vec2 d = TEXTURE_PIXEL_SIZE * (2.5 + charge * 2.0);
    float halo = texture(TEXTURE, UV + vec2(d.x, 0.0)).a;
    halo += texture(TEXTURE, UV - vec2(d.x, 0.0)).a;
    halo += texture(TEXTURE, UV + vec2(0.0, d.y)).a;
    halo += texture(TEXTURE, UV - vec2(0.0, d.y)).a;
    halo += texture(TEXTURE, UV + d).a;
    halo += texture(TEXTURE, UV - d).a;
    float alpha = halo / 6.0 * (0.25 + charge * 0.5);
    COLOR = vec4(0.18, 0.55, 1.0, alpha) * COLOR;
}
