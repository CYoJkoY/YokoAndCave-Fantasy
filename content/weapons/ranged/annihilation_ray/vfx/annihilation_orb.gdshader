shader_type canvas_item;
render_mode unshaded;

uniform float phase = 0.0;
uniform float charge = 0.0;
uniform float flash = 0.0;

void fragment() {
    vec2 p = UV * 2.0 - 1.0;
    float radius = length(p);
    float angle = atan(p.y, p.x);
    float noise = texture(TEXTURE, fract(UV * 1.35 + vec2(phase * 0.12, -phase * 0.17))).r;
    float sphere = 1.0 - smoothstep(0.65, 0.72, radius);
    float interior = 1.0 - smoothstep(0.12, 0.67, radius);
    float outer_shell = exp(-pow((radius - 0.65) * 35.0, 2.0));
    float shell_light = 0.55 + 0.45 * sin(angle * 3.0 - phase * 4.5 + noise);
    float inner_glow = exp(-radius * radius * 7.0);
    float inner_light = 0.85 + 0.15 * sin(angle * 2.0 + phase * 3.0);
    float core_glow = exp(-radius * radius * 27.0);
    float core = 1.0 - smoothstep(0.13, 0.21 + charge * 0.02 + flash * 0.09, radius);
    float highlight = exp(-dot(p - vec2(-0.18, -0.24), p - vec2(-0.18, -0.24)) * 48.0);
    float ready_glow = smoothstep(0.78, 1.0, charge);
    float drift = phase * 0.95;
    vec2 glow_a = p - vec2(cos(drift), sin(drift)) * 0.62;
    vec2 glow_b = p - vec2(cos(-drift * 0.73 + 2.3), sin(-drift * 0.73 + 2.3)) * 0.60;
    vec2 glow_c = p - vec2(cos(drift * 0.57 + 4.4), sin(drift * 0.57 + 4.4)) * 0.64;
    float edge_glow = exp(-dot(glow_a, glow_a) * 38.0) * (0.62 + 0.22 * sin(phase * 2.1));
    edge_glow += exp(-dot(glow_b, glow_b) * 30.0) * (0.46 + 0.20 * sin(phase * 1.7 + 2.0));
    edge_glow += exp(-dot(glow_c, glow_c) * 52.0) * (0.28 + 0.14 * sin(phase * 2.5 + 4.0));
    edge_glow *= 0.55 + charge * 0.45;
    vec3 color = mix(vec3(0.12, 0.015, 0.29), vec3(0.49, 0.13, 0.78), interior);
    color += vec3(0.22, 0.1, 0.3) * noise * interior;
    color += vec3(0.56, 0.36, 0.7) * outer_shell * shell_light;
    color += vec3(0.26, 0.13, 0.40) * inner_glow * inner_light;
    color += vec3(0.50, 0.35, 0.57) * core_glow + vec3(0.35, 0.27, 0.38) * highlight;
    color += vec3(0.63, 0.47, 0.76) * edge_glow;
    color += vec3(0.18, 0.16, 0.22) * inner_glow * ready_glow;
    color = mix(color, vec3(1.0, 0.97, 1.0), core);
    color = mix(color, vec3(1.0, 0.93, 1.0), flash * 0.55 * interior);
    float corona = exp(-pow((radius - 0.65) * 12.0, 2.0)) * 0.38;
    float alpha = max(sphere * 0.95, corona + edge_glow * 0.40) * (1.0 - smoothstep(0.8, 0.98, radius));
    COLOR = vec4(color, alpha) * COLOR;
}
