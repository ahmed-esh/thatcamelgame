void light() {
    float strength = max(dot(NORMAL, LIGHT), 0.0);
    float first_stage = smoothstep(0.22, 0.26, strength);
    float second_stage = smoothstep(0.64, 0.68, strength);
    float band = mix(0.10, 0.48, first_stage);
    band = mix(band, 0.95, second_stage);
    float rim = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), 4.0);
    DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * (band + rim * strength * 0.24) * ATTENUATION / PI;
}
