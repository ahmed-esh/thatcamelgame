shader_type spatial;
render_mode cull_disabled, diffuse_lambert;
uniform vec4 cloth_color : source_color = vec4(0.32, 0.075, 0.24, 1.0);
uniform bool scarf = false;
uniform float motion = 0.0;
void vertex() {
    if (scarf) {
        float weight = UV.y;
        VERTEX.x += sin(TIME * 3.7 - weight * 8.0) * weight * (0.28 + motion * 0.16);
        VERTEX.y += sin(TIME * 4.3 - weight * 10.0) * weight * 0.18;
    } else {
        float weight = 1.0 - UV.y;
        VERTEX.x += sin(TIME * 3.0 + VERTEX.z * 3.0) * weight * 0.065;
        VERTEX.z += cos(TIME * 3.5 + VERTEX.x * 3.0) * weight * 0.08;
    }
}
void fragment() {
    float border = scarf ? step(0.37, abs(UV.x - 0.5)) : 1.0 - smoothstep(0.04, 0.085, UV.y);
    float motif = scarf ? step(0.75, sin(UV.y * 95.0)) * step(abs(UV.x - 0.5), 0.22) : step(0.87, sin(UV.x * 100.0)) * (1.0 - step(0.16, UV.y));
    ALBEDO = mix(cloth_color.rgb, vec3(0.63, 0.96, 0.91), max(border, motif) * 0.9);
    ROUGHNESS = 0.95;
    float rim = pow(1.0 - max(dot(normalize(NORMAL), VIEW), 0.0), 3.0);
    EMISSION = vec3(0.16, 0.74, 0.66) * max(border * 0.45, motif) * 0.65;
    EMISSION += cloth_color.rgb * 0.18;
    EMISSION += vec3(0.19, 0.10, 0.27) * rim * 0.2;
}

#include "res://Shaders/toon_light.gdshaderinc"
