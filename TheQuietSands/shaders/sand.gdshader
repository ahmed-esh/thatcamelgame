shader_type spatial;
render_mode specular_disabled;

uniform vec3 base_sand_color : source_color = vec3(0.34,0.43,0.67);
uniform vec3 slope_color : source_color = vec3(0.19,0.25,0.44);
uniform vec2 ripple_direction = vec2(0.87,0.49);
uniform float ripple_frequency : hint_range(0.1,12.0) = 5.3;
uniform float ripple_intensity : hint_range(0.0,1.0) = 0.10;
uniform float normal_strength : hint_range(0.0,1.0) = 0.15;
uniform float specular_intensity : hint_range(0.0,3.0) = 0.32;
uniform float specular_softness : hint_range(2.0,100.0) = 24.0;
uniform float glitter_density : hint_range(0.0,1.0) = 0.11;
uniform float glitter_brightness : hint_range(0.0,10.0) = 1.4;
uniform float moonlight_response : hint_range(0.0,3.0) = 1.1;
uniform float magical_emission : hint_range(0.0,1.0) = 0.05;
uniform float disturbance_intensity : hint_range(0.0,3.0) = 0.19;
uniform sampler2D grain_texture : filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool local_surface = false;
uniform vec2 patch_min = vec2(-9999.0);
uniform vec2 patch_max = vec2(-9998.0);
uniform int layer_view : hint_range(0,6) = 0;

varying vec3 world_position;
varying vec3 world_normal;
varying float disturbance;
varying vec3 facet_normal;
varying float sparkle_mask;
varying float detail_filter;
varying vec3 smooth_normal_view;

float hash(vec2 p) {
	return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}

vec3 grain_sample(vec2 uv) {
	float field = noise(world_position.xz*0.017)*7.0;
	float a = floor(field);
	vec2 dx = dFdx(uv);
	vec2 dy = dFdy(uv);
	vec3 first = textureGrad(grain_texture,uv+vec2(sin(a*2.3),cos(a*4.7)),dx,dy).rgb;
	vec3 second = textureGrad(grain_texture,uv+vec2(sin((a+1.0)*2.3),cos((a+1.0)*4.7)),dx,dy).rgb;
	return mix(first,second,smoothstep(0.15,0.85,fract(field)));
}

vec2 ripple(vec2 p, vec2 direction, float frequency, float bend) {
	vec2 perpendicular = vec2(-direction.y,direction.x);
	float across = dot(p,direction);
	float along = dot(p,perpendicular);
	float warp = noise(p*0.065+vec2(bend))*3.5 + sin(along*0.17+bend)*0.6;
	float phase = (across+warp)*frequency;
	float filtering = 1.0-smoothstep(0.7,3.0,fwidth(phase));
	float shape = cos(phase)+0.28*cos(phase*2.0+0.7);
	return direction * shape * filtering;
}

void vertex() {
	world_position = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX*NORMAL);
	disturbance = local_surface ? COLOR.r : 0.0;
}

void fragment() {
	if (!local_surface && world_position.x>patch_min.x && world_position.z>patch_min.y && world_position.x<patch_max.x && world_position.z<patch_max.y) { discard; }
	vec3 n = normalize(world_normal);
	smooth_normal_view = normalize((VIEW_MATRIX*vec4(n,0.0)).xyz);
	vec3 tangent = normalize(vec3(n.y,-n.x,0.0));
	vec3 bitangent = normalize(cross(tangent,n));
	vec2 wind = normalize(ripple_direction);
	vec2 crosswind = vec2(-wind.y,wind.x);
	float facing = smoothstep(-0.35,0.35,dot(n.xz,wind));
	float steep = 1.0-smoothstep(0.68,0.96,n.y);
	vec2 r0 = ripple(world_position.xz,wind,ripple_frequency,0.0);
	vec2 r1 = ripple(world_position.xz,normalize(wind+crosswind*0.55),ripple_frequency*0.79,4.0);
	vec2 r2 = ripple(world_position.xz,normalize(wind-crosswind*0.42),ripple_frequency*0.63,9.0);
	vec2 r3 = ripple(world_position.xz,crosswind,ripple_frequency*0.48,13.0);
	vec2 slope_ripples = mix(mix(r0,r1,facing),mix(r2,r3,facing),steep);
	slope_ripples *= ripple_intensity*mix(1.0,0.18,steep*facing)*(1.0-disturbance*0.7);
	vec3 grains = grain_sample(world_position.xz*0.42);
	float distance_to_camera = distance(CAMERA_POSITION_WORLD,world_position);
	float near_detail = 1.0-smoothstep(15.0,75.0,distance_to_camera);
	vec2 granular = (grains.rg*2.0-1.0)*normal_strength*near_detail;
	vec2 broad = vec2(noise(world_position.xz*0.21),noise(world_position.zx*0.18+7.0))*0.014-0.007;
	vec2 perturb = broad;
	if (layer_view==0 || layer_view>=2) { perturb+=granular; }
	if (layer_view==0 || layer_view>=3) { perturb+=slope_ripples; }
	vec3 final_normal = normalize(n+tangent*perturb.x+bitangent*perturb.y);
	NORMAL = normalize((VIEW_MATRIX*vec4(final_normal,0.0)).xyz);
	vec3 facet_world = normalize(n+tangent*(grains.r*2.0-1.0)*1.7+bitangent*(grains.g*2.0-1.0)*1.7);
	facet_normal = normalize((VIEW_MATRIX*vec4(facet_world,0.0)).xyz);
	float variance = noise(world_position.xz*0.012);
	ALBEDO = mix(slope_color,base_sand_color,smoothstep(0.65,1.0,n.y))*(0.92+variance*0.14);
	ROUGHNESS = 0.84;
	float grain_width = max(length(dFdx(world_position.xz*8.0)),length(dFdy(world_position.xz*8.0)));
	detail_filter = 1.0-smoothstep(0.55,2.2,grain_width);
	vec2 cell = world_position.xz*8.0;
	float grain_id = hash(floor(cell));
	float dot_size = length(fract(cell)-vec2(0.5));
	float aa = max(fwidth(dot_size),0.05);
	sparkle_mask = (1.0-smoothstep(0.09,0.09+aa,dot_size))*smoothstep(1.0-glitter_density,1.0,grain_id);
	EMISSION = ALBEDO*magical_emission + vec3(0.06,0.58,0.69)*disturbance*disturbance_intensity;
}

void light() {
	vec3 up = normalize((VIEW_MATRIX*vec4(0,1,0,0)).xyz);
	vec3 compressed = NORMAL - up*dot(NORMAL,up)*0.67;
	float contrast = smoothstep(-0.035,0.47,dot(compressed,LIGHT));
	float lambert = max(dot(NORMAL,LIGHT),0.0);
	float diffuse = mix(lambert,contrast,0.76);
	DIFFUSE_LIGHT += ALBEDO*LIGHT_COLOR*ATTENUATION*diffuse*moonlight_response/PI;
	if (layer_view==0 || layer_view>=4) {
		vec3 half_vector = normalize(LIGHT+VIEW);
		float ocean = pow(max(dot(mix(smooth_normal_view,NORMAL,0.3),half_vector),0.0),specular_softness)*specular_intensity;
		float rim = pow(1.0-max(dot(smooth_normal_view,VIEW),0.0),4.5)*0.2*max(dot(smooth_normal_view,LIGHT)+0.2,0.0);
		SPECULAR_LIGHT += vec3(0.60,0.75,1.0)*max(ocean,rim)*LIGHT_COLOR*ATTENUATION/PI;
	}
	if (layer_view==0 || layer_view>=5) {
		float alignment = max(dot(reflect(-LIGHT,facet_normal),VIEW),0.0);
		float sparkle = smoothstep(0.88,0.995,alignment)*sparkle_mask*detail_filter;
		SPECULAR_LIGHT += vec3(0.62,0.87,1.0)*sparkle*glitter_brightness*LIGHT_COLOR*ATTENUATION;
	}
}
