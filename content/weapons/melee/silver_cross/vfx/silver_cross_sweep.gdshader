shader_type canvas_item;
render_mode blend_add, unshaded;

uniform float progress = 0.0;
uniform float side = 1.0;

void fragment() {
    vec4 tint = COLOR;
    vec2 p = UV * 2.0 - 1.0;
    float along = (atan(p.y * side, p.x) + 1.5707963) / 3.1415926;
    float head = 1.0 - smoothstep(progress - 0.09, progress + 0.005, along);
    float tail = smoothstep(progress - 0.72, progress - 0.12, along);
    vec4 art = texture(TEXTURE, UV);
    COLOR = vec4(art.rgb, art.a * head * tail) * tint;
}
