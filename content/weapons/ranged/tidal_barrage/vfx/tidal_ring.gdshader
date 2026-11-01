shader_type canvas_item;
render_mode unshaded;

uniform float progress : hint_range(0.0, 1.0) = 1.0;

void fragment() {
    vec2 center = UV - vec2(0.5);
    float angle = atan(center.y, center.x);
    float wave = sin(angle * 5.0 - progress * 9.0) * 0.035;
    wave += sin(angle * 9.0 + progress * 6.0) * 0.015;
    vec2 water_uv = UV + center * wave;
    COLOR = texture(TEXTURE, water_uv) * COLOR;
}
