shader_type spatial;
render_mode cull_back, depth_draw_opaque;

uniform vec4 void_color : source_color = vec4(0.01, 0.012, 0.02, 1.0);
uniform vec4 rim_color : source_color = vec4(0.15, 0.7, 1.0, 1.0);
uniform vec4 surge_color : source_color = vec4(1.0, 0.15, 0.1, 1.0);
uniform float rim_power : hint_range(0.5, 8.0) = 3.0;
uniform float jitter_intensity : hint_range(0.0, 0.2) = 0.04;
uniform float absorb_intensity : hint_range(0.0, 2.0) = 0.0;
uniform float banish_intensity : hint_range(0.0, 2.0) = 0.0;

// High-speed pseudo random hash
float hash(vec3 p) {
    p = fract(p * 0.3183099 + 0.1);
    p *= 17.0;
    return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void vertex() {
    float t = TIME * 6.0;
    float n = hash(VERTEX + vec3(floor(t * 8.0)));
    
    // Quantum phase jitter on vertices
    vec3 glitch = NORMAL * (sin(t * 4.0 + VERTEX.y * 10.0) * jitter_intensity);
    
    // Violent boiling expansion when absorbing raw light
    if (absorb_intensity > 0.01) {
        glitch += NORMAL * (sin(TIME * 25.0 + VERTEX.y * 20.0) * 0.08 * absorb_intensity);
        glitch += (vec3(n) - 0.5) * 0.06 * absorb_intensity;
    }
    
    // Catastrophic phase disintegration when struck by reflected light
    if (banish_intensity > 0.01) {
        glitch += NORMAL * (sin(TIME * 40.0) * 0.15 * banish_intensity);
        glitch += (vec3(n) - 0.5) * 0.2 * banish_intensity;
    }
    
    VERTEX += glitch;
}

void fragment() {
    // Pitch-black cosmic core that swallows light
    ALBEDO = void_color.rgb;
    ROUGHNESS = 0.9;
    METALLIC = 0.0;
    
    // Fresnel quantum event-horizon edge
    float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
    
    vec3 emission_glow = rim_color.rgb * fresnel * 2.2;
    
    // Pulse red surge during hunting charge
    if (surge_color.a > 0.5) {
        emission_glow = mix(emission_glow, surge_color.rgb * 3.5, 0.65);
    }
    
    // Intense blinding electric flash on banishment
    if (banish_intensity > 0.01) {
        emission_glow += vec3(0.7, 0.95, 1.0) * banish_intensity * 8.0;
    }
    
    // Violent gravitational flare when absorbing raw laser
    if (absorb_intensity > 0.01) {
        emission_glow += vec3(0.9, 0.3, 0.1) * absorb_intensity * 3.0;
    }
    
    EMISSION = emission_glow;
}
