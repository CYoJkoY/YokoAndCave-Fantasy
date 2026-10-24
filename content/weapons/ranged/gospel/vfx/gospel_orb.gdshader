shader_type canvas_item;
render_mode unshaded, blend_add;

uniform float age = 0.0;
uniform float energy = 0.0;
uniform float readiness = 1.0;
uniform float motion = 0.0;
uniform float cursed = 0.0;

void fragment() {
    float breathing = 0.97 + sin(age * 2.1) * 0.025 + sin(age * 4.2 + 0.5) * 0.01;
    float pulse = 1.0 + sin(age * 2.1) * 0.015 - motion * 0.018;
    vec4 light = texture(TEXTURE, (UV - vec2(0.5)) / pulse + vec2(0.5));
    light.rgb *= mix(vec3(1.0), vec3(1.0, 0.90, 0.98), cursed * 0.35);
    light.a *= breathing * (0.86 + readiness * 0.14) + energy * 0.16 + motion * 0.045;
    COLOR *= light;
}
