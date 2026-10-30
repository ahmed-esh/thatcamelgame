shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
void fragment() {
    float column = pow(max(0.0, 1.0 - abs(UV.x * 2.0 - 1.0)), 4.0);
    float ends = smoothstep(0.0, 0.15, UV.y) * smoothstep(1.0, 0.45, UV.y);
    float pulse = 0.8 + 0.2 * sin(TIME * 0.8 + UV.y * 8.0);
    ALBEDO = vec3(0.22, 0.80, 0.77);
    ALPHA = column * ends * pulse * 0.5;
}
