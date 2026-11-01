shader_type canvas_item;
render_mode unshaded, blend_add;

uniform sampler2D palette;
uniform float flow = 0.0;
uniform float energy = 0.0;
uniform float pulse = 0.0;
uniform float release_progress = 1.0;
uniform vec3 pulses_a = vec3(0.0);
uniform vec3 pulses_b = vec3(0.0);

float star_light(float angle, float origin, float strength) {
    return exp((cos(angle - origin) - 1.0) * 14.0) * strength;
}

void vertex() {
    VERTEX *= 1.12;
}

void fragment() {
    vec4 modulation = COLOR;
    vec2 p = (UV * 2.0 - 1.0) * 1.12;
    float radius = length(p);
    float angle = atan(p.y, p.x);
    float around = fract(angle / 6.283185 + 1.0);
    vec3 spectrum = texture(palette, vec2(around, 0.5)).rgb;
    spectrum = clamp(spectrum * 1.18 - vec3(0.09), vec3(0.0), vec3(1.0));
    float stars = star_light(angle, 0.0, pulses_a.x)
        + star_light(angle, 1.047198, pulses_a.y)
        + star_light(angle, 2.094395, pulses_a.z)
        + star_light(angle, 3.141593, pulses_b.x)
        + star_light(angle, 4.188790, pulses_b.y)
        + star_light(angle, 5.235988, pulses_b.z);
    float sector = around * 6.0 + 0.5;
    float sector_id = mod(floor(sector), 6.0);
    float local = fract(sector);
    float window = smoothstep(0.02, 0.20, local) * (1.0 - smoothstep(0.80, 0.98, local));
    float travel = fract(flow * 0.24 + sector_id * 0.19);
    float envelope = sin(travel * 3.141593);
    float weave = sin(angle * 3.0 + flow * 0.60) * 0.024;
    float base_radius = 0.56;
    float ribbon = exp(-pow((radius - base_radius) / 0.010, 2.0));
    float haze = exp(-pow((radius - base_radius) / 0.058, 2.0));
    float sweep = pow(max(0.0, cos(angle * 2.0 - flow)), 3.0);
    vec2 seal_uv = clamp(p / 0.69 * 0.5 + vec2(0.5), vec2(0.0), vec2(1.0));
    float seal = texture(TEXTURE, seal_uv).a;
    float glyph_reveal = smoothstep(-0.30, 0.65, sin(angle * 3.0 + radius * 8.0 + flow * 0.75));
    float ink = seal * glyph_reveal * (0.10 + energy * 0.14 + stars * 0.10);
    float broken_arc = window * (0.30 + sweep * 0.70);
    float alpha = ink + (ribbon * (0.23 + energy * 0.26) + haze * 0.12) * broken_arc;
    float drift_radius = 0.54 + travel * 0.47 + weave * 0.25;
    float drift = exp(-pow((radius - drift_radius) / 0.014, 2.0));
    float drift_glow = exp(-pow((radius - drift_radius) / 0.050, 2.0));
    vec2 fragment_uv = clamp(p / (0.64 + travel * 0.53) * 0.5 + vec2(0.5), vec2(0.0), vec2(1.0));
    float fragments = texture(TEXTURE, fragment_uv).a;
    fragments *= smoothstep(0.43, 0.61, radius) * (1.0 - smoothstep(1.00, 1.09, radius));
    alpha += (drift * 0.45 + drift_glow * 0.10 + fragments * 0.28) * envelope * window * (0.25 + energy * 0.75 + stars * 0.20);
    float inner = exp(-pow((radius - 0.30) / 0.010, 2.0));
    float inner_arc = pow(max(0.0, cos(angle * 2.0 + flow * 0.85)), 4.0);
    alpha += inner * inner_arc * (0.10 + energy * 0.16 + pulse * 0.08);
    float wave_radius = mix(0.32, 1.07, smoothstep(0.0, 1.0, release_progress));
    float wave = exp(-pow((radius - wave_radius) / 0.030, 2.0));
    wave *= sin(release_progress * 3.141593) * (1.0 - release_progress) * window * 0.30;
    alpha += wave;
    vec3 light = mix(spectrum, vec3(1.0), ribbon * sweep * 0.08 + stars * 0.06);
    float edge = 1.0 - smoothstep(1.06, 1.12, radius);
    COLOR = vec4(light, alpha * edge) * modulation;
}
