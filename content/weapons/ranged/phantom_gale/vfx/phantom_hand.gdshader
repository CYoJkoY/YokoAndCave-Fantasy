shader_type canvas_item;
render_mode unshaded, blend_add;

uniform float release_flash : hint_range(0.0, 1.0) = 0.0;
uniform float draw_strength : hint_range(0.0, 1.0) = 0.0;

varying vec4 hand_color;

void vertex() {
    hand_color = COLOR;
}

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    vec3 jade = vec3(0.47, 0.87, 0.77);
    vec3 violet = vec3(0.59, 0.51, 0.77);
    vec3 gold = vec3(0.92, 0.83, 0.61);
    float sweep = pow(0.5 + 0.5 * sin(UV.y * 18.0 - TIME * (3.0 + draw_strength * 4.0)), 4.0);
    vec3 tint = mix(jade, violet, smoothstep(0.3, 0.85, UV.y));
    tint = mix(tint, gold, sweep * (0.4 + draw_strength * 0.45));
    COLOR = vec4(mix(tint, vec3(0.96, 0.95, 0.84), release_flash * 0.7),
        tex.a * (0.38 + sweep * 0.4 + draw_strength * 0.18 + release_flash)) * hand_color;
}
