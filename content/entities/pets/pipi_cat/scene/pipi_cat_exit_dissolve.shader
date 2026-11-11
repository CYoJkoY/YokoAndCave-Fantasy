shader_type canvas_item;

// Four-point star iris used when the pipi cat leaves the wave. The visible
// area starts as the whole sprite; the four corners are clipped first and the
// remaining diamond star shrinks into the center.

uniform float progress = 0.0; // 0.0 = fully visible, 1.0 = fully dissolved
uniform float star_sharpness = 0.62; // 1.0 = diamond, lower = thinner star points
uniform float edge_softness = 0.012;
uniform float edge_width = 0.06;
uniform vec4 edge_color : hint_color = vec4(1.0, 1.0, 1.0, 0.85);


void fragment() {
    vec4 base = texture(TEXTURE, UV) * COLOR;
    vec2 point = UV * 2.0 - 1.0;

    // L-p norm inside the sprite rect. Corners have the largest distance, so
    // they are erased first; the level sets become the four-point star.
    float sharpness = max(star_sharpness, 0.05);
    float star_distance = pow(
        pow(abs(point.x), sharpness) + pow(abs(point.y), sharpness),
        1.0 / sharpness
    );
    float start_distance = pow(2.0, 1.0 / sharpness);
    float threshold = mix(start_distance + edge_softness, -edge_softness, progress);

    float coverage = 1.0 - smoothstep(
        threshold - edge_softness,
        threshold + edge_softness,
        star_distance
    );
    float edge = (1.0 - smoothstep(0.0, max(edge_width, 0.001), abs(star_distance - threshold)))
        * coverage * progress;
    vec3 color = mix(base.rgb, edge_color.rgb, edge * edge_color.a);

    COLOR = vec4(color, base.a * coverage);
}
