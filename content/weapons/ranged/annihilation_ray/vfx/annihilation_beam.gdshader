shader_type canvas_item;
render_mode unshaded, blend_add;

uniform float phase = 0.0;
uniform float beam_length = 800.0;
uniform float beam_padding = 64.0;

void fragment() {
    float x = UV.x * (beam_length + beam_padding * 2.0) - beam_padding;
    float y = (UV.y - 0.5) / TEXTURE_PIXEL_SIZE.y;
    float tail_length = min(140.0, beam_length * 0.3);
    float tip = smoothstep(beam_length - tail_length, beam_length + 12.0, x);
    float root_width = mix(0.55, 1.0, smoothstep(0.0, 55.0, x));
    float width = root_width * mix(1.0, 0.14, tip);
    float wave = sin(x * 0.047 - phase * 75.0) * sin(x * 0.019 + phase * 43.0);
    float center = (y / 48.0 + wave * 0.035 * width) / width;
    float flow = 0.5 + 0.5 * sin(x * 0.11 - phase * 180.0 + sin(x * 0.029));
    float pulse = 0.91 + 0.09 * sin(phase * 137.0);
    float halo_width = mix(1.0, 0.45, tip);
    float halo = exp(-pow(y / (23.0 * halo_width), 2.0)) * 0.5;
    float sheath = exp(-center * center * 25.0) * (0.65 + flow * 0.35);
    float core = exp(-center * center * 210.0) * pulse;
    float thread_a = exp(-pow((center - 0.22 * sin(x * 0.023 - phase * 38.0)) * 55.0, 2.0));
    float thread_b = exp(-pow((center + 0.28 * sin(x * 0.018 - phase * 29.0 + 2.0)) * 65.0, 2.0));
    float before_muzzle = min(x, 0.0);
    float beyond_tip = max(x - beam_length + 8.0, 0.0);
    float ends = exp(-pow(before_muzzle / 16.0, 2.0) - pow(beyond_tip / 22.0, 2.0));
    float thread_ends = smoothstep(0.0, 38.0, x) * (1.0 - tip);
    thread_a *= thread_ends;
    thread_b *= thread_ends;
    vec3 color = vec3(0.42, 0.08, 1.0) * halo + vec3(0.73, 0.34, 1.0) * sheath;
    color += vec3(0.86, 0.7, 1.0) * (thread_a + thread_b) * 0.45;
    color = mix(color, vec3(1.0, 0.98, 1.0), core);
    float alpha = (halo + sheath * 0.65 + core + (thread_a + thread_b) * 0.24) * ends;
    alpha *= 1.0 - smoothstep(0.75, 1.0, abs(UV.y * 2.0 - 1.0));
    alpha *= smoothstep(-beam_padding, -beam_padding * 0.65, x);
    alpha *= 1.0 - smoothstep(beam_length + beam_padding * 0.65, beam_length + beam_padding, x);
    COLOR = vec4(color, min(1.0, alpha)) * COLOR;
}
