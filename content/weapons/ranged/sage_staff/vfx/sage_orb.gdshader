shader_type canvas_item;
render_mode unshaded, blend_add;

const int ELEMENT_FIRE = 1;
const int ELEMENT_EARTH = 2;
const int ELEMENT_WIND = 3;
const int ELEMENT_THUNDER = 4;
const int ELEMENT_LIGHT = 5;

uniform vec4 tint : hint_color = vec4(0.345, 0.792, 1.0, 1.0);
uniform int element = 0;
uniform float age = 0.0;
uniform float charge = 0.0;
uniform float flight = 0.0;
uniform float seed = 0.0;
uniform float launch = 0.0;

void fragment() {
    vec4 modulation = COLOR;
    vec2 p = UV * 2.0 - 1.0;
    float birth = smoothstep(0.0, 0.10, age);
    p /= max(0.04, 0.55 + birth * 0.45);
    p *= vec2(1.0 + flight * 0.16 + launch * 0.15, 1.0 - flight * 0.12 - launch * 0.12);
    float t = age + seed;
    float flutter = element == ELEMENT_FIRE ? 0.065 : 0.042;
    p += vec2(sin(p.y * 5.0 + t * 5.2), cos(p.x * 4.0 - t * 4.3)) * flutter;
    float r = length(p);
    float angle = atan(p.y, p.x);
    float pulse = 0.96 + sin(t * 6.2) * 0.06;
    float flow = angle * 2.0 + r * 10.0 - t * (element == ELEMENT_WIND ? 5.0 : 3.2);
    float field = exp(-r * r * 7.0);
    float veil = exp(-r * r * 4.8) * (0.15 + 0.09 * sin(flow));
    float curl = exp(-pow((r - 0.37 - sin(flow) * 0.045) * 15.0, 2.0));
    float broken = smoothstep(-0.45, 0.85, sin(angle * 2.0 + t * 2.1));
    vec2 center = p + vec2(sin(t * 2.3), cos(t * 1.7)) * 0.045;
    float core = exp(-dot(center, center) * (36.0 - charge * 4.0));
    float inner = exp(-r * r * 15.0);
    vec3 hot = mix(tint.rgb, vec3(1.0), 0.86);
    vec3 companion = mix(tint.rgb, vec3(tint.b, tint.r, tint.g), 0.16);
    if (element == ELEMENT_FIRE) { hot = vec3(1.0, 0.96, 0.73); companion = vec3(1.0, 0.52, 0.10); }
    if (element == ELEMENT_EARTH) { hot = vec3(1.0, 0.97, 0.84); }
    float eddy = exp(-pow((r - 0.52 - sin(angle * 3.0 - t * 3.0) * 0.055) * 16.0, 2.0));
    float wisps = eddy * pow(max(0.0, sin(angle * 2.0 - t * 2.5)), 3.0);
    vec3 light = tint.rgb * (field * 0.60 + veil + curl * broken * 0.30 + wisps * 0.16);
    light += companion * inner * (0.10 + 0.08 * sin(flow + 2.0));
    light += hot * (core * 1.28 + inner * 0.18 + launch * inner * 0.42);
    if (element == ELEMENT_THUNDER) {
        float flicker = pow(max(0.0, sin(t * 16.0)), 10.0);
        light += hot * inner * flicker * 0.12;
    }
    if (element == ELEMENT_LIGHT) {
        float glint = exp(-p.x * p.x * 600.0 - p.y * p.y * 13.0)
            + exp(-p.y * p.y * 600.0 - p.x * p.x * 13.0);
        light += hot * glint * (0.09 + charge * 0.08);
    }
    float edge = 1.0 - smoothstep(0.78, 0.98, r);
    COLOR = vec4(light * pulse * birth * edge, edge) * modulation;
}
