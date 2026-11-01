shader_type canvas_item;
render_mode unshaded, blend_add;

uniform float age = 1.0;

void fragment() {
    vec2 p = (UV - 0.5) * vec2(192.0, 128.0);
    vec2 center = vec2(-29.0, 0.0);
    vec2 q = (p - center) / vec2(0.80, 1.0);
    float r = length(q);
    float angle = atan(q.y, q.x);
    float flash = exp(-age * 30.0);
    vec2 glint_offset = vec2((p.x + 29.0) / 17.0, p.y / 2.0);
    float glint = exp(-dot(glint_offset, glint_offset));
    float body = exp(-dot(q, q) / 440.0) * flash;
    vec3 light = vec3(0.61, 0.24, 1.0) * body * 0.56;
    light += vec3(1.0, 0.87, 1.0) * glint * flash * 1.2;
    for (int i = 0; i < 3; i++) {
        float t = age - float(i) * 0.036;
        float alive = step(0.0, t) * max(0.0, 1.0 - t / 0.40);
        float radius = 22.0 + max(t, 0.0) * 122.0;
        float ring_offset = (r - radius) / 1.1;
        float ring = exp(-ring_offset * ring_offset);
        float arc = pow(max(0.0, cos(angle + float(i - 1) * 0.55)), 3.0);
        light += mix(vec3(0.65, 0.28, 1.0), vec3(0.40, 0.78, 1.0), float(i) * 0.4) * ring * arc * alive * alive;
    }
    float sweep_y = -15.0 + age * 220.0;
    vec2 sweep_offset = vec2((p.x + 29.0) / 18.0, (p.y - sweep_y) / 1.4);
    float sweep_x_squared = sweep_offset.x * sweep_offset.x;
    float sweep = exp(-sweep_offset.y * sweep_offset.y - sweep_x_squared * sweep_x_squared);
    light += vec3(0.94, 0.82, 1.0) * sweep * exp(-age * 17.0);
    for (int i = 0; i < 5; i++) {
        float a = float(i) * 1.2566 + 0.35;
        vec2 mote = center + vec2(cos(a), sin(a)) * (17.0 + age * 75.0);
        vec2 d = p - mote;
        float spark = exp(-dot(d, d) * 0.55);
        light += vec3(0.74, 0.64, 1.0) * spark * exp(-age * 9.0);
    }
    float edge = 1.0 - smoothstep(0.85, 0.99, max(abs(UV.x - 0.5), abs(UV.y - 0.5)) * 2.0);
    COLOR = vec4(light * edge, edge) * COLOR;
}
