shader_type canvas_item;
render_mode unshaded;

uniform vec2 control_size = vec2(1.0);
uniform bool soft_background = false;
varying vec2 local_position;

void vertex() {
    local_position = VERTEX;
}

void fragment() {
    vec4 source = texture(TEXTURE, UV) * COLOR;
    vec2 position = local_position / max(control_size, vec2(1.0));
    float blend = clamp(position.x, 0.0, 1.0);
    vec3 purple = vec3(173.0, 90.0, 255.0) / 255.0;
    vec3 red = vec3(255.0, 59.0, 59.0) / 255.0;
    if (soft_background) {
        float distance_to_glow = length(position - vec2(0.88, 0.12));
        blend = 1.0 - smoothstep(0.0, 1.05, distance_to_glow);
    }
    vec3 tint = mix(purple, red, blend);
    float brightness = max(source.r, max(source.g, source.b));
    COLOR = vec4(tint * brightness, source.a);
}
