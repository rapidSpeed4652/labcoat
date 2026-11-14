shader_type spatial;
render_mode blend_mix, cull_disabled;

uniform vec4 base_color : source_color = vec4(0.02, 0.02, 0.03, 1.0);
uniform vec4 absorb_color : source_color = vec4(0.9, 0.1, 0.2, 1.0);
uniform vec4 banish_color : source_color = vec4(0.2, 0.9, 1.0, 1.0);
uniform float absorb_factor : hint_range(0.0, 1.0) = 0.0;
uniform float banish_progress : hint_range(0.0, 1.0) = 0.0;
uniform float halt_factor : hint_range(0.0, 1.0) = 0.0;
uniform float distort_speed = 8.0;

float random(vec2 uv) {
    return fract(sin(dot(uv.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

void vertex() {
    // Unsettling twitch / jitter vertex distortion
    float jitter = sin(TIME * distort_speed + VERTEX.y * 5.0) * 0.03;
    
    // High-frequency shudder when halted in photon stasis
    if (halt_factor > 0.01) {
        float stasis_shudder = sin(TIME * 50.0 + VERTEX.y * 25.0) * 0.04 * halt_factor;
        VERTEX.x += stasis_shudder;
        VERTEX.z += cos(TIME * 50.0 + VERTEX.y * 25.0) * 0.04 * halt_factor;
    }
    
    VERTEX += NORMAL * jitter * (1.0 + absorb_factor * 2.0);
}

void fragment() {
    float n = random(UV + vec2(TIME * 0.5, sin(TIME)));
    
    // Dissolve clipping when banished
    if (banish_progress > 0.01) {
        if (n < banish_progress) {
            discard;
        }
    }
    
    vec3 col = base_color.rgb;
    
    // If absorbing raw light, flash eerie agitated red/crimson
    if (absorb_factor > 0.0) {
        col = mix(col, absorb_color.rgb * 2.0, absorb_factor);
    }
    
    // If halted in photon stasis, glowing electric blue interference lines
    if (halt_factor > 0.0) {
        float grid = step(0.8, fract(UV.y * 30.0 + TIME * 4.0));
        vec3 stasis_col = vec3(0.2, 0.85, 1.0);
        col = mix(col, stasis_col * 2.2, halt_factor * grid);
    }
    
    // If banishing, brilliant blinding white/cyan edges
    if (banish_progress > 0.0) {
        col = mix(col, banish_color.rgb * 4.0, banish_progress);
    }
    
    ALBEDO = col;
    ROUGHNESS = 0.9;
    METALLIC = 0.0;
    EMISSION = col * (absorb_factor * 1.5 + halt_factor * 2.0 + banish_progress * 3.0);
}
