shader_type canvas_item;
render_mode blend_mul, unshaded;

uniform vec4 center_color : hint_color = vec4(1.0);
uniform vec4 edge_color : hint_color = vec4(0.555771, 0.832031, 0.754333, 1.0);

void fragment() {
    float distance_to_center = length(UV - vec2(0.5)) / length(vec2(0.5));
    float edge = clamp((distance_to_center - 0.326347) / (0.994012 - 0.326347), 0.0, 1.0);
    COLOR = vec4(mix(center_color.rgb, edge_color.rgb, edge), 1.0);
}
