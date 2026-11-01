shader_type canvas_item;
render_mode unshaded;

uniform float progress = 0.0;

void fragment() {
    vec2 p = UV * 2.0 - 1.0;
    float r = length(p);
    float angle = atan(p.y, p.x);
    float burst = 1.0 - pow(1.0 - min(1.0, progress * 3.0), 3.0);
    float noise = texture(TEXTURE, fract(UV * 1.8 + vec2(progress * 0.4))).r;
    float radius = 0.12 + burst * 0.57;
    float edge = r + sin(angle * 9.0 + noise * 6.0 + progress * 11.0) * 0.025;
    float rim = exp(-pow((edge - radius) * 37.0, 2.0));
    float core = (1.0 - smoothstep(0.0, 0.45, r)) * max(0.0, 1.0 - progress * 5.0);
    float void_mask = (1.0 - smoothstep(radius * 0.5, radius, r)) * min(1.0, progress * 12.0);
    float rays = pow(max(0.0, sin(angle * 13.0 + noise * 3.0)), 14.0);
    rays *= exp(-pow((r - radius * 1.1) * 9.0, 2.0)) * (1.0 - progress);
    vec3 color = mix(vec3(0.055, 0.008, 0.11), vec3(0.78, 0.45, 1.0), rim);
    color += vec3(0.7, 0.37, 1.0) * rays;
    color = mix(color, vec3(1.0, 0.97, 1.0), core);
    float fade = pow(1.0 - progress, 1.4);
    float alpha = max(core, max(rim, max(void_mask * 0.65, rays * 0.7))) * fade;
    COLOR = vec4(color, alpha) * COLOR;
}
