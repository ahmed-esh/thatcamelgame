shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec3 tint : source_color = vec3(0.24, 0.42, 0.63);
uniform float opacity = 0.12;
void vertex() {
    MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz), INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz), INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz), MODEL_MATRIX[3]);
}
void fragment() {
    float falloff = pow(max(0.0, 1.0 - length(UV * 2.0 - 1.0)), 2.0);
    ALBEDO = tint;
    ALPHA = falloff * COLOR.a * opacity;
}
