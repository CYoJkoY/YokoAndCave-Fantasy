shader_type canvas_item;

uniform float elapsed = 0.0;
uniform float sway_strength = 2.2;
uniform float sway_speed = 0.8;
uniform float glow_strength = 0.0;
uniform float desaturation = 0.0;
uniform vec4 glow_color : hint_color = vec4(0.23, 0.78, 1.0, 1.0);
varying float spirit_phase;

void vertex() {
    spirit_phase = WORLD_MATRIX[3].x * 0.009 + WORLD_MATRIX[3].y * 0.013;
    float canopy = max(0.0, (0.9 - UV.y) / 0.9);
    float wind = sin(elapsed * sway_speed + spirit_phase);
    wind += 0.28 * sin(elapsed * sway_speed * 1.73 + spirit_phase * 1.4);
    VERTEX.x += wind * sway_strength * canopy * canopy;
}

void fragment() {
    vec4 sprite = texture(TEXTURE, UV);
    float spirit_mask = smoothstep(0.10, 0.28, sprite.b - sprite.r);
    spirit_mask *= smoothstep(0.50, 0.82, sprite.b);
    float breath = 0.55 + 0.45 * sin(elapsed * 1.1 + spirit_phase);
    float glimmer = pow(max(0.0, sin(UV.y * 16.0 - elapsed * 1.8 + spirit_phase)), 8.0);
    vec3 glow = glow_color.rgb * spirit_mask * glow_strength * (breath + glimmer * 0.35);
    float luminance = dot(sprite.rgb, vec3(0.2126, 0.7152, 0.0722));
    vec3 foliage = mix(sprite.rgb, vec3(luminance), desaturation);
    COLOR = vec4(foliage * MODULATE.rgb + glow, sprite.a * MODULATE.a);
}
