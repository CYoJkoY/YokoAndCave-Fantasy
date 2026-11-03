shader_type canvas_item;
render_mode unshaded;

uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform float elapsed = 0.0;

void fragment() {
    vec2 p = UV * 2.0 - 1.0;
    float radius = length(p);
    float envelope = 1.0 - smoothstep(0.6, 1.0, radius);
    float pulse = sin(radius * 17.0 - elapsed * 2.6);
    float shear = sin(p.y * 6.0 + elapsed * 1.4);
    vec2 tangent = vec2(-p.y, p.x);
    vec2 warp = vec2(shear * 13.5, sin(p.x * 4.0 - elapsed) * 6.0);
    warp += p * pulse * 6.75 + tangent * sin(elapsed * 0.8) * 6.0;
    warp *= envelope * strength * SCREEN_PIXEL_SIZE;

    vec2 sample_uv = clamp(SCREEN_UV + warp, SCREEN_PIXEL_SIZE, vec2(1.0) - SCREEN_PIXEL_SIZE);
    vec3 refracted = texture(SCREEN_TEXTURE, sample_uv).rgb;
    vec3 echo = texture(SCREEN_TEXTURE, clamp(sample_uv - warp * 0.6, vec2(0.0), vec2(1.0))).rgb;
    refracted = mix(refracted, echo, 0.22 * strength);
    float ring = pow(max(0.0, pulse), 12.0) * smoothstep(0.25, 0.7, radius);
    refracted += vec3(0.45, 0.67, 0.85) * ring * 0.07 * strength;
    COLOR = vec4(refracted, envelope * strength);
}
