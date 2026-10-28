shader_type canvas_item;
render_mode blend_add, unshaded;

void fragment() {
    float distance_to_center = length(UV - vec2(0.5, 0.2)) / length(vec2(0.5, 0.8));
    float glow = 1.0 - clamp(distance_to_center / 0.679641, 0.0, 1.0);
    COLOR = vec4(vec3(0.179756, 0.246094, 0.129776) * glow, 1.0);
}
