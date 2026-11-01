shader_type canvas_item;
render_mode unshaded;

uniform sampler2D mist_texture;
uniform float age = 0.0;
uniform float energy = 0.0;
uniform float cursed = 0.0;
uniform vec4 waves = vec4(-1.0);

vec4 sample_mist(vec2 uv) {
    vec2 mirrored_uv = 1.0 - abs(mod(uv, 2.0) - 1.0);
    return texture(mist_texture, mirrored_uv);
}

float wave(float r, float t, float n) {
    float front = t * 1.35;
    return exp(-pow((r - front + (n - 0.5) * 0.045) * 25.0, 2.0)) * step(0.0, t) * (1.0 - smoothstep(0.52, 0.8, t));
}

void fragment() {
    vec2 p = UV * 2.0 - 1.0;
    float r = length(p);
    vec2 drift = vec2(age * 0.013, -age * 0.021);
    float n = clamp((sample_mist(UV * 1.6 + drift).r - 0.18) * 2.0, 0.0, 1.0);
    float smoke = clamp((sample_mist(UV * 2.3 - drift * 0.7 + vec2(n * 0.13)).g - 0.18) * 2.0, 0.0, 1.0);
    vec4 mask = texture(TEXTURE, UV + vec2(sin(age * 0.7 + p.y * 10.0), cos(age * 0.6 + p.x * 9.0)) * 0.004);
    float boundary = 1.0 - smoothstep(0.91, 1.0, r);
    float flow = 0.5 + 0.5 * sin(r * 23.0 - age * 2.8 + n * 6.0);
    float pulses = min(1.3, wave(r, waves.x, n) + wave(r, waves.y, n) + wave(r, waves.z, n));
    float veins = mask.r * (0.22 + flow * 0.52 + energy * 0.2 + pulses * 1.2);
    float glyphs = mask.g * (0.8 + 0.35 * sin(age * 1.8 + r * 14.0) + pulses * 1.5);
    float mist = mask.b * smoothstep(0.12, 0.7, smoke) * (0.22 + energy * 0.10);
    float edge = exp(-pow((r - 0.91 + (smoke - 0.5) * 0.045) * 30.0, 2.0));
    vec3 violet = mix(vec3(0.37, 0.10, 0.62), vec3(0.63, 0.10, 0.55), cursed);
    vec3 green = vec3(0.10, 0.63, 0.37);
    vec3 pigment = mix(violet, green, smoothstep(0.15, 0.85, n * 0.65 + r * 0.35 + sin(age * 0.45 + r * 8.0) * 0.12));
    float light = veins + glyphs * 0.65 + pulses * (0.06 + mask.b * smoke * 0.23) + edge * (0.10 + smoke * 0.16);
    vec3 rgb = mix(vec3(0.055, 0.018, 0.09), pigment, clamp(0.24 + smoke * 0.16 + light * 2.0, 0.0, 1.0));
    rgb += pigment * light * 0.45;
    COLOR = vec4(rgb, boundary * clamp(mist + light * 0.65, 0.0, 0.65)) * COLOR;
}
