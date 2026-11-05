shader_type spatial;
render_mode cull_disabled;

uniform vec4 ripples[8];
uniform float water_clock = 0.0;
varying vec3 world_position;
varying vec3 local_position;
varying float water_depth;

void vertex() {
	local_position=VERTEX;
	VERTEX.y += (sin(VERTEX.x*0.33+TIME*0.55)+sin(VERTEX.z*0.43-TIME*0.42))*0.035;
	world_position=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;
	water_depth=COLOR.r;
}

void fragment() {
	if (water_depth<0.005) { discard; }
	vec2 p=local_position.xz;
	vec2 slope=vec2(cos(p.x*0.33+TIME*0.55)*0.06,cos(p.y*0.43-TIME*0.42)*0.055);
	float rings=0.0;
	for (int i=0;i<8;i++) {
		float age=water_clock-ripples[i].z;
		float radius=length(p-ripples[i].xy);
		float envelope=exp(-pow((radius-age*2.4)*1.6,2.0))*exp(-age*0.65)*step(0.0,age);
		rings+=sin(radius*8.0-age*13.0)*envelope*ripples[i].w;
		slope+=normalize(p-ripples[i].xy+vec2(0.001))*rings*0.06;
	}
	vec3 n=normalize(vec3(-slope.x,1.0,-slope.y));
	NORMAL=normalize((VIEW_MATRIX*vec4(n,0)).xyz);
	float fresnel=pow(1.0-max(dot(NORMAL,VIEW),0.0),4.0);
	ALBEDO=mix(vec3(0.018,0.12,0.16),vec3(0.006,0.035,0.095),water_depth);
	ALBEDO=mix(ALBEDO,vec3(0.15,0.24,0.42),fresnel*0.55);
	ROUGHNESS=0.32;
	SPECULAR=0.32;
	METALLIC=0.05;
	float shoreline=(1.0-smoothstep(0.0,0.13,water_depth))*0.035;
	EMISSION=vec3(0.02,0.27,0.3)*(0.06+shoreline+max(rings,0.0)*0.07);
}
