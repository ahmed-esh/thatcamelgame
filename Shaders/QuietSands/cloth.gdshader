shader_type spatial;
render_mode cull_disabled;
uniform vec3 color : source_color = vec3(0.035,0.05,0.12);
uniform bool scarf = false;
uniform float motion = 0.0;

void vertex() {
	float tip = UV.y*UV.y;
	if (scarf) {
		VERTEX.x += sin(UV.y*9.0-TIME*3.1)*tip*(0.25+motion*0.16);
		VERTEX.y += sin(UV.y*7.5-TIME*4.0)*tip*0.3;
	} else {
		VERTEX.x += sin(VERTEX.y*2.0+TIME*2.7)*(1.0-UV.y)*0.06;
	}
}

void fragment() {
	float trim = (1.0-smoothstep(0.015,0.055,min(UV.x,1.0-UV.x)))*float(scarf);
	float stitching = step(0.65,sin(UV.y*100.0))*trim;
	ALBEDO = color;
	ROUGHNESS = 0.95;
	EMISSION = vec3(0.025,0.65,0.8)*(trim*0.4+stitching*0.4);
}
