shader_type canvas_item;
render_mode unshaded, blend_add;

void fragment() {
    vec2 p = UV * 2.0 - 1.0;
    float radius_squared = dot(p, p);
    float radius = sqrt(radius_squared);
    float falloff = exp(-radius_squared * 6.8) * 0.48 * smoothstep(0.14, 0.42, radius);
    float edge = 1.0 - smoothstep(0.72, 0.98, radius);
    float alpha = falloff * COLOR.a;
    float grain = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
    alpha += grain / 255.0 * smoothstep(0.0, 0.008, alpha);
    COLOR = vec4(COLOR.rgb * vec3(1.0, 0.88, 0.57), max(0.0, alpha) * edge);
}
