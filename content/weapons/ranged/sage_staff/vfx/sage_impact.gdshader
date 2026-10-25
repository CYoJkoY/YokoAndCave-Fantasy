shader_type canvas_item;
render_mode unshaded, blend_add;

const int ELEMENT_WATER = 0;
const int ELEMENT_FIRE = 1;
const int ELEMENT_EARTH = 2;
const int ELEMENT_WIND = 3;
const int ELEMENT_THUNDER = 4;

uniform vec4 tint : hint_color = vec4(0.345, 0.792, 1.0, 1.0);
uniform int element = 0;
uniform float age = 0.0;
uniform float seed = 0.0;
uniform float duration = 0.56;

float band(float distance, float sharpness) {
    return exp(-distance * distance * sharpness);
}

void fragment() {
    vec2 p = UV * 2.0 - 1.0;
    float r = length(p);
    float angle = atan(p.y, p.x);
    float progress = clamp(age / duration, 0.0, 1.0);
    float fade = pow(1.0 - progress, 1.6);
    float open = 1.0 - pow(1.0 - progress, 3.0);
    float flash = exp(-age * 24.0);
    vec3 hot = mix(tint.rgb, vec3(1.0), 0.86);
    vec3 energy = vec3(0.0);

    if (element == ELEMENT_WATER) {
        vec2 pool = p * vec2(1.0, 1.30);
        float radius = length(pool);
        float theta = atan(pool.y, pool.x);
        float front = 0.15 + open * 0.65;
        float ripple = sin(theta * 5.0 + seed + progress * 6.0) * 0.016;
        float outer = band(radius - front - ripple, 1900.0);
        float inner = band(radius - front * 0.70 + ripple, 2300.0);
        float lip = 0.45 + 0.55 * pow(sin(theta + seed), 2.0);
        energy = tint.rgb * (outer * 0.90 + inner * 0.48) * lip * fade;
        energy += hot * outer * lip * fade * 0.32;
        energy += tint.rgb * exp(-radius * radius * 7.0) * fade * 0.20;
        float spray = exp(-pow(sin(theta * 4.0 + seed + radius * 2.0), 2.0) * 130.0) * band(radius - front * 0.85, 160.0);
        energy += hot * spray * fade * 0.65;
        energy += hot * exp(-r * r * 46.0) * flash * 1.2;
    } else if (element == ELEMENT_FIRE) {
        vec2 flame = p + vec2(0.0, open * 0.25);
        flame.x += sin(flame.y * 8.0 - age * 9.0 + seed) * 0.035;
        float theta = atan(flame.y, flame.x);
        float radius = length(flame * vec2(1.0, 0.85));
        float lobe = 0.14 + open * (0.28 + pow(max(0.0, -sin(theta)), 3.0) * 0.13 + sin(theta * 3.0 + seed) * 0.035);
        float shell = band(radius - lobe, 220.0);
        float body = exp(-pow(radius / max(0.04, lobe), 4.0) * 1.6);
        float flicker = 0.65 + 0.35 * sin(theta * 4.0 + radius * 18.0 - age * 18.0);
        energy = vec3(1.0, 0.22, 0.035) * (shell * 0.24 + body * 1.15) * fade;
        energy += vec3(1.0, 0.76, 0.24) * body * flicker * fade * 0.85;
        energy += vec3(1.0, 0.98, 0.76) * exp(-radius * radius * 48.0) * exp(-age * 10.0) * 1.8;
    } else if (element == ELEMENT_EARTH) {
        vec2 ground = p * vec2(1.0, 1.6);
        float radius = length(ground);
        float theta = atan(ground.y, ground.x);
        float front = 0.12 + open * 0.72;
        float ripple = sin(theta * 9.0 + seed) * 0.015;
        float ring = band(radius - front + ripple, 1300.0) * (0.25 + 0.75 * pow(sin(theta * 3.0 + seed), 2.0));
        float facets = exp(-pow(sin(theta * 4.0 + seed + sin(radius * 32.0) * 0.12), 2.0) * 240.0);
        float fracture = facets * smoothstep(0.08, 0.25, radius) * (1.0 - smoothstep(front * 0.45, front * 0.90, radius));
        energy = tint.rgb * (ring * 0.55 + fracture * 0.65) * fade;
        energy += tint.rgb * band(radius - front, 90.0) * fade * 0.30;
        energy += hot * exp(-dot(ground, ground) * 20.0) * flash * 1.8;
        energy += tint.rgb * exp(-dot(ground, ground) * 9.0) * pow(1.0 - progress, 3.0) * 0.65;
    } else if (element == ELEMENT_WIND) {
        float spiral = angle - progress * 8.0 + seed;
        float front = 0.14 + open * 0.56;
        float sweep = pow(max(0.0, sin(spiral * 2.0 + r * 5.0)), 3.0);
        float outer = band(r - front - sin(spiral * 2.0) * 0.05, 1100.0) * sweep;
        float inner = band(r - front * 0.68, 1500.0) * pow(max(0.0, cos(spiral * 2.0 + 1.4)), 3.0);
        energy = tint.rgb * (outer * 1.6 + inner * 0.9) * fade;
        energy += hot * (outer * 0.65 + inner * 0.35) * fade;
        energy += tint.rgb * band(r - front, 140.0) * sweep * fade * 0.25;
        energy += tint.rgb * exp(-r * r * 8.0) * fade * 0.20;
        energy += hot * exp(-r * r * 36.0) * flash;
    } else if (element == ELEMENT_THUNDER) {
        float bolt_angle = angle + seed;
        float jitter = sin(r * 31.0 + seed) * 0.18 + sin(r * 61.0 - seed) * 0.08;
        float forks = abs(sin(bolt_angle * 3.0 + jitter));
        float bolts = exp(-forks * forks * 650.0 * max(r, 0.08));
        float gate = smoothstep(0.04, 0.13, r) * (1.0 - smoothstep(0.35 + open * 0.32, 0.55 + open * 0.32, r));
        float strike = exp(-age * 20.0) + exp(-pow((age - 0.085) * 55.0, 2.0)) * 0.55;
        energy = hot * bolts * gate * strike * 1.9;
        energy += tint.rgb * exp(-forks * forks * 45.0) * gate * strike * 0.45;
        energy += tint.rgb * exp(-r * r * 9.0) * strike * 0.65;
        energy += hot * exp(-r * r * 48.0) * flash * 2.1;
    } else {
        vec2 q = vec2(p.x * 0.924 - p.y * 0.383, p.x * 0.383 + p.y * 0.924);
        float cross = exp(-p.x * p.x * 2100.0 - p.y * p.y * 4.0)
            + exp(-p.y * p.y * 2100.0 - p.x * p.x * 7.0);
        float rays = exp(-q.x * q.x * 1600.0 - q.y * q.y * 8.0)
            + exp(-q.y * q.y * 1600.0 - q.x * q.x * 8.0);
        float bloom = (1.0 - exp(-age * 65.0)) * exp(-age * 7.0);
        float crown = band(r - (0.15 + open * 0.52), 1900.0) * pow(max(0.0, cos(angle * 4.0 + seed)), 6.0);
        energy = hot * (cross * 1.8 + rays * 0.65) * bloom;
        energy += tint.rgb * crown * fade * 0.70;
        energy += hot * exp(-r * r * 36.0) * exp(-age * 13.0) * 1.7;
        energy += tint.rgb * exp(-r * r * 6.0) * bloom * 0.40;
    }
    float edge = 1.0 - smoothstep(0.88, 1.0, r);
    COLOR = vec4(energy * edge, edge * smoothstep(0.0, 0.012, age)) * COLOR;
}
