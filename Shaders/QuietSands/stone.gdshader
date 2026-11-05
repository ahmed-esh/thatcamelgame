shader_type spatial;

uniform bool masonry = false;
varying vec3 world_position;
varying vec3 local_position;
varying vec3 world_normal;

float hash(vec3 p) { return fract(sin(dot(p,vec3(12.9898,78.233,37.719)))*43758.5453); }
float noise(vec3 p) {
	vec3 i=floor(p);
	vec3 f=fract(p);
	f=f*f*(3.0-2.0*f);
	return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}

void vertex() {
	world_position=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;
	local_position=VERTEX;
	world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}

void fragment() {
	float erosion=noise(world_position*0.14);
	float layers=sin(world_position.y*2.2+erosion*4.0+sin(world_position.x*0.12));
	float grain=noise(world_position*4.5);
	vec3 dark=vec3(0.14,0.115,0.155);
	vec3 light=vec3(0.39,0.32,0.32);
	ALBEDO=mix(dark,light,erosion*0.6+0.18+layers*0.065)*(0.92+grain*0.16);
	float sand=pow(max(world_normal.y,0.0),5.0)*0.32;
	ALBEDO=mix(ALBEDO,vec3(0.39,0.23,0.12),sand);
	if (masonry) { ALBEDO*=vec3(1.04,1.02,0.97); }
	ROUGHNESS=0.9;
	NORMAL=normalize(NORMAL+vec3(dFdx(grain),dFdy(grain),0)*0.13);
}
