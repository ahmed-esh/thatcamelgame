shader_type sky;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void sky() {
    float elevation = max(EYEDIR.y, 0.0);
    vec3 sky_color = mix(vec3(0.065, 0.085, 0.17), vec3(0.03137, 0.04706, 0.12941), pow(smoothstep(0.0, 0.75, elevation), 0.55));
    vec2 celestial = vec2(atan(EYEDIR.x, -EYEDIR.z), asin(clamp(EYEDIR.y, -1.0, 1.0)));
    vec2 star_grid = celestial * 155.0;
    vec2 cell = floor(star_grid);
    vec2 star_offset = vec2(hash(cell), hash(cell + 37.9)) * 0.7 + 0.15;
    float star_distance = length(fract(star_grid) - star_offset);
    float star = (1.0 - smoothstep(0.015, 0.095, star_distance)) * step(0.935, hash(cell + 91.2));
    star *= 0.6 + 0.4 * sin(TIME * (0.3 + hash(cell)) + hash(cell + 15.0) * 6.28);
    float veil = sin(celestial.x * 2.8 + sin(celestial.x * 4.0 + TIME * 0.035) * 0.35) * 0.06 + 0.32;
    float aurora = exp(-pow((celestial.y - veil) * 13.0, 2.0));
    float curtain = pow(0.5 + 0.5 * sin(celestial.x * 95.0 + TIME * 0.12), 3.0);
    sky_color += mix(vec3(0.08, 0.035, 0.18), vec3(0.035, 0.20, 0.19), sin(celestial.x * 3.0) * 0.5 + 0.5) * aurora * (0.35 + curtain * 0.4);
    sky_color += vec3(0.65, 0.86, 1.0) * star * smoothstep(0.015, 0.12, elevation);
    vec3 moon_direction = normalize(vec3(-0.48, 0.34, -1.0));
    float moon_distance = length(EYEDIR - moon_direction);
    float moon_disc = 1.0 - smoothstep(0.048, 0.050, moon_distance);
    float eclipse_distance = length(EYEDIR - normalize(moon_direction + vec3(0.028, 0.012, 0.0)));
    float crescent = moon_disc * smoothstep(0.041, 0.043, eclipse_distance);
    float halo = exp(-moon_distance * 18.0) * 0.19;
    sky_color += vec3(0.28, 0.50, 0.72) * halo;
    sky_color = mix(sky_color, vec3(0.76, 0.90, 1.0), crescent);
    COLOR = sky_color;
}
