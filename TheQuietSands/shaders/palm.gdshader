shader_type spatial;
render_mode cull_disabled;
uniform bool leaf = false;
varying vec3 world_position;

void vertex() {
	world_position=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;
	if (leaf) {
		float tip=UV.y*UV.y;
		VERTEX.x+=sin(TIME*0.8+world_position.x*0.18+world_position.z*0.11)*tip*0.38;
		VERTEX.y+=sin(TIME*1.2+UV.y*7.0+world_position.x*0.1)*tip*0.18;
	}
}

void fragment() {
	if (leaf) {
		float vein=pow(abs(sin(UV.y*95.0+UV.x*8.0)),10.0);
		ALBEDO=mix(vec3(0.025,0.1,0.11),vec3(0.10,0.26,0.23),UV.y)*(0.85+vein*0.15);
		BACKLIGHT=vec3(0.04,0.14,0.13);
		ROUGHNESS=0.7;
	} else {
		float rings=sin(world_position.y*18.0+sin(world_position.x*5.0))*0.5+0.5;
		ALBEDO=mix(vec3(0.12,0.10,0.13),vec3(0.27,0.21,0.21),rings);
		ROUGHNESS=0.95;
	}
}
