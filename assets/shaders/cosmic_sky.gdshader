shader_type sky;

// Eclipse direction in world space (angled overhead matching the dome roof aperture)
const vec3 ECLIPSE_DIR = vec3(0.15, 0.88, -0.45);

// Pseudo-random hash
float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// 2D Noise for nebula clouds
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    mat2 rot = mat2(vec2(0.8, -0.6), vec2(0.6, 0.8));
    for (int i = 0; i < 4; i++) {
        v += a * noise(p);
        p = rot * p * 2.0;
        a *= 0.5;
    }
    return v;
}

void sky() {
    vec3 dir = normalize(EYEDIR);
    
    // Base deep cosmic space gradient
    vec3 space_col = mix(vec3(0.003, 0.005, 0.012), vec3(0.012, 0.018, 0.038), clamp(dir.y * 0.5 + 0.5, 0.0, 1.0));
    
    // Milky Way / Galactic Dust Band
    vec2 galactic_uv = vec2(atan(dir.z, dir.x), dir.y);
    float milky_way = fbm(galactic_uv * 4.0 + vec2(1.2, 0.8));
    milky_way = smoothstep(0.35, 0.85, milky_way) * 0.18;
    vec3 nebula_col = mix(vec3(0.04, 0.02, 0.08), vec3(0.02, 0.05, 0.12), fbm(galactic_uv * 2.5));
    space_col += nebula_col * milky_way;
    
    // Starfield (Spherical projection)
    vec2 star_uv = vec2(atan(dir.z, dir.x) * 45.0, asin(clamp(dir.y, -1.0, 1.0)) * 45.0);
    vec2 star_id = floor(star_uv);
    float star_rnd = hash(star_id);
    if (star_rnd > 0.88) {
        vec2 star_pos = fract(star_uv) - vec2(hash(star_id + 0.1), hash(star_id + 0.7));
        float star_dist = length(star_pos);
        float star_brightness = smoothstep(0.18, 0.0, star_dist) * (star_rnd - 0.88) * 8.0;
        
        // Star spectral temperature tint
        vec3 star_color = mix(vec3(0.8, 0.9, 1.0), vec3(1.0, 0.85, 0.6), hash(star_id + 3.1));
        space_col += star_color * star_brightness;
    }
    
    // High-density fine star dust
    vec2 fine_uv = star_uv * 3.0;
    float fine_rnd = hash(floor(fine_uv));
    if (fine_rnd > 0.96) {
        float b = smoothstep(0.2, 0.0, length(fract(fine_uv) - 0.5)) * 0.5;
        space_col += vec3(0.7, 0.8, 1.0) * b;
    }
    
    // SOLAR ECLIPSE OVERHEAD
    vec3 norm_eclipse = normalize(ECLIPSE_DIR);
    float cos_angle = dot(dir, norm_eclipse);
    float angular_dist = acos(clamp(cos_angle, -1.0, 1.0));
    
    // Moon disc radius = ~0.045 radians (~2.5 degrees)
    float moon_radius = 0.045;
    
    if (angular_dist < moon_radius) {
        // Pitch-black lunar disc blocking the sun
        float edge = smoothstep(moon_radius, moon_radius - 0.003, angular_dist);
        // The Dark Anomaly (Perseus Void): faint eerie violet singularity in center of moon disc
        float anomaly = smoothstep(0.02, 0.0, angular_dist) * 0.3;
        vec3 anomaly_col = vec3(0.08, 0.02, 0.15) * anomaly;
        space_col = mix(space_col, anomaly_col, edge);
    } else {
        // Solar Corona glowing flares
        float corona_dist = angular_dist - moon_radius;
        if (corona_dist < 0.45) {
            float corona_falloff = pow(1.0 - (corona_dist / 0.45), 3.5);
            
            // Radial corona streamers
            vec3 v = cross(norm_eclipse, vec3(0.0, 1.0, 0.0));
            vec3 u = cross(norm_eclipse, v);
            float angle_around = atan(dot(dir, u), dot(dir, v));
            float streamers = 0.7 + 0.3 * sin(angle_around * 12.0 + sin(angle_around * 6.0));
            streamers += 0.2 * sin(angle_around * 24.0);
            
            vec3 corona_color = mix(vec3(0.6, 0.85, 1.0), vec3(0.85, 0.95, 1.0), corona_falloff);
            corona_color = mix(corona_color, vec3(0.4, 0.2, 0.7), smoothstep(0.1, 0.35, corona_dist));
            
            // Inner diamond ring / Baily's bead glint on northeast rim
            float glint = exp(-pow(angle_around - 0.8, 2.0) * 12.0) * exp(-corona_dist * 40.0) * 4.0;
            
            space_col += corona_color * (corona_falloff * streamers * 1.8 + glint);
        }
    }
    
    COLOR = space_col;
}
