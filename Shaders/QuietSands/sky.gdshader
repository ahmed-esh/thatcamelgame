shader_type sky;

uniform vec3 moon_direction = vec3(0.42,0.34,0.84);

float hash(vec3 p) {
	p = fract(p*vec3(0.1031,0.1030,0.0973));
	p += dot(p,p.yxz+33.33);
	return fract((p.x+p.y)*p.z);
}

void sky() {
	vec3 ray = normalize(EYEDIR);
	float elevation = max(ray.y,0.0);
	vec3 color = mix(vec3(0.009,0.014,0.045),vec3(0.0008,0.0015,0.008),pow(elevation,0.45));
	vec3 moon = normalize(moon_direction);
	float halo = pow(max(dot(ray,moon),0.0),90.0);
	color += vec3(0.025,0.042,0.085)*halo;
	vec3 axis = normalize(cross(moon,vec3(0,1,0)));
	vec3 vertical = normalize(cross(axis,moon));
	vec2 mp = vec2(dot(ray,axis),dot(ray,vertical));
	float radius = 0.027;
	float disk = 1.0-smoothstep(radius-0.0005,radius+0.0005,length(mp));
	float cut = smoothstep(radius*0.91-0.0005,radius*0.91+0.0005,length(mp-vec2(0.011,0.004)));
	float crescent = disk*cut*step(0.0,dot(ray,moon));
	color += vec3(1.65,2.0,2.4)*crescent;
	vec3 grid = ray*630.0;
	vec3 cell = floor(grid);
	float chance = hash(cell);
	float star = pow(max(1.0-length(fract(grid)-0.5)*2.0,0.0),4.0);
	star *= smoothstep(0.978,0.999,chance)*smoothstep(0.02,0.18,elevation);
	color += mix(vec3(0.4,0.6,0.95),vec3(1.2,1.05,0.85),hash(cell+12.0))*star*4.5;
	float milky = exp(-pow((ray.x*0.7+ray.y*0.3-ray.z*0.5+0.14)*4.0,2.0));
	color += vec3(0.009,0.008,0.019)*milky*elevation;
	COLOR = color;
}
