shader_type canvas_item;
render_mode unshaded, blend_add;

uniform sampler2D palette;
uniform vec4 tint : hint_color = vec4(0.345, 0.792, 1.0, 1.0);
uniform float flow = 0.0;
uniform float orbit_spin = 0.0;
uniform float energy = 0.0;
uniform float pulse = 0.0;

void fragment() {
    vec4 modulation = COLOR;
    vec4 art = texture(TEXTURE, UV);
    float luminance = dot(art.rgb, vec3(0.30, 0.59, 0.11));
    float painted = smoothstep(0.22, 0.62, luminance) * art.a;
    float wood = smoothstep(0.07, 0.20, luminance) * art.a;
    vec2 gem = (UV - vec2(0.742, 0.755)) * vec2(180.0, 96.0);
    float crystal = exp(-dot(gem, gem) / 58.0);
    float rim = exp(-pow((length(gem) - 8.0) / 1.8, 2.0));
    float angle = atan(gem.y, gem.x);
    float glint = pow(max(0.0, cos(angle - flow)), 6.0);
    float shaft = exp(-pow((UV.y - 0.69) * 65.0, 2.0));
    shaft *= smoothstep(0.12, 0.20, UV.x) * (1.0 - smoothstep(0.62, 0.74, UV.x));
    float stream = pow(max(0.0, sin(UV.x * 15.0 - flow * 3.0)), 8.0);
    vec3 spectrum = texture(palette, vec2(fract((angle - orbit_spin) / 6.283185 + 1.0), 0.5)).rgb;
    float travel = fract(flow * 0.24);
    float crest_wave = exp(-pow((length(gem) - 12.0 - travel * 40.0) / 5.0, 2.0));
    crest_wave *= sin(travel * 3.141593) * smoothstep(0.56, 0.68, UV.x);
    vec3 light = mix(tint.rgb, vec3(1.0), 0.32) * crystal * (0.05 + energy * 0.16 + pulse * 0.16);
    light += mix(spectrum, vec3(1.0), 0.24) * rim * glint * (0.14 + energy * 0.30 + pulse * 0.16);
    light += spectrum * crest_wave * energy * 0.23;
    light *= painted;
    light += tint.rgb * shaft * stream * energy * wood * 0.62;
    COLOR = vec4(light, 1.0) * modulation;
}
