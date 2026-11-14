shader_type spatial;
render_mode unshaded, blend_add, cull_disabled;

uniform vec4 laser_color : source_color = vec4(0.0, 0.9, 1.0, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float pulse_speed = 10.0;
uniform float intensity = 3.0;

void fragment() {
    float pulse = sin(TIME * pulse_speed) * 0.15 + 0.85;
    // Edge falloff based on fresnel-like / view normal
    float rim = 1.0 - abs(dot(NORMAL, VIEW));
    vec4 col = mix(core_color, laser_color, clamp(rim * 1.5, 0.0, 1.0));
    ALBEDO = col.rgb * intensity * pulse;
    ALPHA = 0.95;
}
