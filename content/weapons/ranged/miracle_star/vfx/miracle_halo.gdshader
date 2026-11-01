shader_type canvas_item;
render_mode unshaded, blend_add;

uniform float phase = 0.0;
uniform float energy = 0.0;
uniform float sweep_angle = 0.0;
uniform vec3 release_angles = vec3(0.0);
uniform vec3 release_progress = vec3(1.0);
uniform float reveal = 1.0;

float flowing_tail(float distance, float tail_length) {
    float behind = mod(-distance + 6.283185, 6.283185);
    return smoothstep(0.0, 0.10, behind) * (1.0 - smoothstep(tail_length * 0.30, tail_length, behind)) * exp(-behind * 0.45);
}

vec4 flowing_release(float angle, float origin, float progress) {
    float envelope = smoothstep(0.0, 0.08, progress) * (1.0 - smoothstep(0.76, 1.0, progress));
    float distance = angle - origin;
    float head = exp((cos(distance) - 1.0) * 72.0);
    float tail = flowing_tail(distance, 1.65);
    float light = (head * 1.45 + tail * 0.95) * envelope;
    vec3 spectrum = 0.57 + 0.43 * cos(distance * 2.0 + vec3(0.0, 2.094, 4.189));
    vec3 color = mix(spectrum, vec3(1.0), head * 0.65);
    return vec4(color * light, light);
}

void fragment() {
    vec4 tint = COLOR;
    vec2 p = UV - vec2(0.5);
    float angle = atan(p.y, p.x);
    float around = fract((angle + 1.570796) / 6.283185 + 1.0);
    float reveal_mask = 1.0 - smoothstep(reveal - 0.03, reveal + 0.03, around);
    reveal_mask = mix(reveal_mask, 1.0, smoothstep(0.97, 1.0, reveal)) * smoothstep(0.0, 0.02, reveal);
    float birth_edge = exp(-pow((around - reveal) / 0.035, 2.0)) * smoothstep(0.0, 0.05, reveal) * (1.0 - smoothstep(0.92, 1.0, reveal));
    vec4 tex = texture(TEXTURE, UV);
    float weave = sin(angle * 2.0 - phase * 0.70 + sin(angle + phase * 0.28) * 0.35);
    float sweep_distance = angle - sweep_angle;
    vec3 spectrum = 0.60 + 0.40 * cos(sweep_distance + phase * 0.08 + weave * 0.20 + vec3(0.0, 2.094, 4.189));
    float orbit = pow(max(0.0, cos(angle * 2.0 - phase * 0.8)), 14.0);
    float wake = pow(max(0.0, cos(angle * 3.0 + phase * 0.45)), 5.0);
    float head = exp((cos(sweep_distance) - 1.0) * 64.0);
    float trail = flowing_tail(sweep_distance, 1.90);
    float echo = exp((cos(sweep_distance - 3.141593 + weave * 0.20) - 1.0) * 24.0);
    float arc = (head * 1.65 + trail * 1.1 + echo * 0.5) * energy;
    vec4 release_sum = flowing_release(angle, release_angles.x, release_progress.x)
        + flowing_release(angle, release_angles.y, release_progress.y)
        + flowing_release(angle, release_angles.z, release_progress.z);
    float release = 1.6 * (1.0 - exp(-release_sum.a / 1.6));
    vec3 release_color = release_sum.rgb / max(release_sum.a, 0.001);
    float radius = length(p);
    float ribbon_radius = 0.382 + weave * 0.007;
    float companion_radius = 0.382 - weave * 0.006;
    float ribbon = exp(-pow((radius - ribbon_radius) / 0.0028, 2.0));
    float companion = exp(-pow((radius - companion_radius) / 0.0022, 2.0));
    float glow = exp(-pow((radius - ribbon_radius) / 0.014, 2.0));
    float silk = ribbon * (arc * 0.52 + release * 0.65) + companion * (trail * energy * 0.40 + release * 0.28);
    vec3 color = mix(tex.rgb, spectrum, 0.72) * (1.0 + orbit * 0.55 + trail * energy * 0.95);
    color += mix(spectrum, vec3(1.0), 0.32) * (arc * 1.25 + silk * 0.55);
    color += release_color * release * 1.9;
    color += vec3(0.9, 0.95, 1.0) * birth_edge * 0.8;
    float brightness = 0.80 + orbit * 0.30 + wake * 0.14 + birth_edge * 0.8 + arc * 0.65 + release * 0.75;
    float alpha = tex.a * brightness + glow * (arc * 0.16 + release * 0.20) + silk * 0.30;
    COLOR = vec4(color, min(alpha, 1.6) * reveal_mask) * tint;
}
