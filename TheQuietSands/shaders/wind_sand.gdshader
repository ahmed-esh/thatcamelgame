shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

void vertex() {
	MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);
}

void fragment() {
	vec2 p=UV*2.0-1.0;
	float soft=pow(max(0.0,1.0-dot(p,p)),2.0);
	ALBEDO=vec3(0.21,0.31,0.53);
	ALPHA=soft*COLOR.a*0.055;
}
