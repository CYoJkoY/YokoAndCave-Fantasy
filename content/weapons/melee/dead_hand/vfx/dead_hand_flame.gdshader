shader_type canvas_item;
render_mode unshaded;

uniform float phase = 0.0;
uniform float charge = 0.0;
uniform float release = 0.0;
uniform float spectral = 0.0;

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    vec4 h = fract(sin(vec4(dot(i, vec2(127.1, 311.7)), dot(i + vec2(1.0, 0.0), vec2(127.1, 311.7)), dot(i + vec2(0.0, 1.0), vec2(127.1, 311.7)), dot(i + vec2(1.0), vec2(127.1, 311.7)))) * 43758.5453);
    return mix(mix(h.x, h.y, f.x), mix(h.z, h.w, f.x), f.y);
}

void fragment() {
    vec4 tint = COLOR;
    if (spectral > 0.5) {
        vec4 art = texture(TEXTURE, UV);
        float light = dot(art.rgb, vec3(0.25, 0.55, 0.20));
        vec3 bone = mix(vec3(0.25, 0.10, 0.46), vec3(0.84, 0.75, 1.0), smoothstep(0.12, 0.85, light));
        COLOR = vec4(bone, art.a) * tint;
    } else {
        float flow = noise(UV * vec2(4.0, 5.0) + vec2(-phase * 0.32, phase * 1.1));
        float detail = noise(UV * vec2(9.0, 7.0) + vec2(phase * 0.45, phase * 1.7));
        float tip = 0.4 + 0.6 * (1.0 - UV.y);
        vec2 drift = vec2(flow - 0.5, detail - 0.5) * vec2(0.065, 0.035) * tip;
        drift += vec2(sin(UV.y * 11.0 - phase * 3.0) * 0.012, release * release * 0.13);
        vec4 art = texture(TEXTURE, clamp(UV + drift, vec2(0.002), vec2(0.998)));
        float heat = dot(art.rgb, vec3(0.25, 0.55, 0.20)) * 0.90 + flow * 0.18 + charge * 0.09 - release * 0.25;
        vec3 flame = mix(vec3(0.29, 0.055, 0.60), vec3(0.72, 0.31, 1.0), smoothstep(0.15, 0.65, heat));
        flame = mix(flame, vec3(0.90, 0.72, 1.0), smoothstep(0.55, 0.95, heat));
        float fuel = art.a * (0.76 + flow * 0.24);
        fuel *= 1.0 - release * smoothstep(0.22, 0.92, UV.y);
        COLOR = vec4(flame, fuel) * tint;
    }
}
