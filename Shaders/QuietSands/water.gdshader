shader_type spatial;
render_mode cull_disabled;

// Must match Oasis.gd MAX_RIPPLES.
uniform vec4 ripples[20]; // x, z, birth time, impact strength
uniform float water_clock = 0.0;

varying vec3 local_position;
varying float water_depth;

void vertex() {
    local_position = VERTEX;
    water_depth = COLOR.r;

    // Subtle baseline movement, independent of actors.
    VERTEX.y += (sin(VERTEX.x * 0.33 + TIME * 0.55)
               + sin(VERTEX.z * 0.43 - TIME * 0.42)) * 0.035;

    // Small physical displacement. For stronger geometric waves, use a denser mesh.
    float wave_height = 0.0;
    for (int i = 0; i < 20; i++) {
        float age = water_clock - ripples[i].z;
        if (age < 0.0 || age > 3.5) { continue; }

        float intensity = ripples[i].w;
        float speed = mix(1.55, 2.25, clamp(intensity / 2.5, 0.0, 1.0));
        float distance_to_impact = length(VERTEX.xz - ripples[i].xy);
        float front = distance_to_impact - age * speed;
        float width = 0.22 + age * 0.09 + intensity * 0.05;
        float envelope = exp(-pow(front / width, 2.0)) * exp(-age * 0.8);
        wave_height += cos(front * 7.0) * envelope * intensity * 0.018;
    }
    VERTEX.y += clamp(wave_height, -0.085, 0.085);
}

void fragment() {
    // Retain the original shoreline cutoff encoded in vertex colors.
    if (water_depth < 0.005) { discard; }

    vec2 p = local_position.xz;
    vec2 slope = vec2(
        cos(p.x * 0.33 + TIME * 0.55) * 0.01155,
        cos(p.y * 0.43 - TIME * 0.42) * 0.01505
    );
    float bright_crest = 0.0;
    float disturbance = 0.0;

    for (int i = 0; i < 20; i++) {
        float age = water_clock - ripples[i].z;
        if (age < 0.0 || age > 3.5) { continue; }

        vec2 from_impact = p - ripples[i].xy;
        float distance_to_impact = length(from_impact);
        vec2 radial = from_impact / max(distance_to_impact, 0.001);
        float intensity = ripples[i].w;
        float speed = mix(1.55, 2.25, clamp(intensity / 2.5, 0.0, 1.0));
        float front = distance_to_impact - age * speed;
        float width = 0.22 + age * 0.09 + intensity * 0.05;
        float envelope = exp(-pow(front / width, 2.0)) * exp(-age * 0.8);
        float wave = cos(front * 7.0) * envelope * intensity;

        // Derivative of the wave function makes light react to wave slopes.
        float derivative = intensity * envelope
            * (-2.0 * front / (width * width) * cos(front * 7.0) - 7.0 * sin(front * 7.0));
        slope += radial * derivative * 0.016;

        bright_crest += max(wave, 0.0);
        disturbance += abs(wave);
    }

    vec3 local_normal = normalize(vec3(-slope.x, 1.0, -slope.y));
    vec3 world_normal = normalize(MODEL_NORMAL_MATRIX * local_normal);
    NORMAL = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);

    float fresnel = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), 4.0);
    vec3 base_color = mix(vec3(0.018, 0.12, 0.16), vec3(0.006, 0.035, 0.095), water_depth);
    base_color = mix(base_color, vec3(0.15, 0.24, 0.42), fresnel * 0.55);

    float crest = clamp(bright_crest * 0.19, 0.0, 0.35);
    ALBEDO = base_color + vec3(0.10, 0.18, 0.17) * crest;
    ROUGHNESS = mix(0.32, 0.20, clamp(disturbance * 0.12, 0.0, 1.0));
    SPECULAR = 0.45;
    METALLIC = 0.0;

    float shoreline = (1.0 - smoothstep(0.0, 0.13, water_depth)) * 0.035;
    EMISSION = vec3(0.02, 0.27, 0.3) * (0.06 + shoreline)
             + vec3(0.035, 0.11, 0.12) * crest;
}
