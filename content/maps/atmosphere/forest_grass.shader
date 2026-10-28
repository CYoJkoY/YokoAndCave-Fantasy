shader_type canvas_item;

uniform float elapsed = 0.0;

void vertex() {
    float phase = WORLD_MATRIX[3].x * 0.025 + WORLD_MATRIX[3].y * 0.016;
    float tip = 1.0 - UV.y;
    VERTEX.x += sin(elapsed * 1.5 + phase) * 3.0 * tip * tip;
}
