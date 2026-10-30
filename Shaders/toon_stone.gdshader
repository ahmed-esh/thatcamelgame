shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform vec4 stone_color : source_color = vec4(0.29, 0.30, 0.47, 1.0);
uniform vec3 glow_color : source_color = vec3(0.27, 0.92, 0.85);
uniform float glow_strength = 0.0;
void fragment() {
    ALBEDO = stone_color.rgb;
    float rim = pow(1.0 - max(dot(normalize(NORMAL), VIEW), 0.0), 4.0);
    EMISSION = glow_color * glow_strength * (0.86 + sin(TIME * 1.2) * 0.14);
    EMISSION += vec3(0.15, 0.27, 0.45) * rim * 0.055;
    ROUGHNESS = 1.0;
}
#include "res://Shaders/toon_light.gdshaderinc"
