shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float scanline_count : hint_range(0.0, 1080.0) = 360.0;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.15;
uniform float vignette_intensity : hint_range(0.0, 2.0) = 0.7;
uniform float aberration_amount : hint_range(0.0, 0.02) = 0.002;
uniform float static_noise : hint_range(0.0, 0.5) = 0.03;

float random(vec2 uv) {
    return fract(sin(dot(uv.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
    vec2 uv = SCREEN_UV;
    
    // Chromatic aberration
    vec2 offset = (uv - 0.5) * aberration_amount;
    float r = texture(screen_texture, uv + offset).r;
    float g = texture(screen_texture, uv).g;
    float b = texture(screen_texture, uv - offset).b;
    vec3 color = vec3(r, g, b);
    
    // Scanlines
    float scanline = sin(uv.y * scanline_count * 3.14159) * 0.5 + 0.5;
    color -= scanline * scanline_intensity;
    
    // Vignette
    vec2 vig_uv = uv * (1.0 - uv.yx);
    float vig = vig_uv.x * vig_uv.y * 15.0;
    vig = clamp(pow(vig, vignette_intensity), 0.0, 1.0);
    color *= vig;
    
    // Subtle static noise
    float noise = (random(uv + vec2(TIME * 0.1, 0.0)) - 0.5) * static_noise;
    color += vec3(noise);
    
    COLOR = vec4(color, 1.0);
}
