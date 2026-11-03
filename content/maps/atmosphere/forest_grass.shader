shader_type canvas_item;

uniform float elapsed = 0.0;
uniform float desaturation = 0.0;

void vertex() {
    float phase = WORLD_MATRIX[3].x * 0.025 + WORLD_MATRIX[3].y * 0.016;
    float tip = 1.0 - UV.y;
    VERTEX.x += sin(elapsed * 1.5 + phase) * 3.0 * tip * tip;
}

void fragment() {
    vec4 sprite = texture(TEXTURE, UV);
    float luminance = dot(sprite.rgb, vec3(0.2126, 0.7152, 0.0722));
    COLOR = vec4(mix(sprite.rgb, vec3(luminance), desaturation), sprite.a) * MODULATE;
}
