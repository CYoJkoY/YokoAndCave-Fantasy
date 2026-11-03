shader_type canvas_item;
render_mode blend_add, unshaded;

void fragment() {
    vec4 ray = texture(TEXTURE, UV);
    float luminance = dot(ray.rgb, vec3(0.2126, 0.7152, 0.0722));
    COLOR = vec4(vec3(luminance) * MODULATE.rgb, ray.a * MODULATE.a);
}
