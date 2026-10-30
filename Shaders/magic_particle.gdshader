shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
uniform vec3 tint : source_color = vec3(0.25, 0.95, 0.88);
uniform float intensity = 1.0;
void vertex() {
    MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz), INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz), INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz), MODEL_MATRIX[3]);
}
void fragment() {
    float r = length(UV * 2.0 - 1.0);
    float core = 1.0 - smoothstep(0.0, 0.18, r);
    float halo = pow(max(1.0 - r, 0.0), 3.0) * 0.24;
    ALBEDO = tint * intensity;
    ALPHA = (core + halo) * COLOR.a;
}
