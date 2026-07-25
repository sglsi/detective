shader_type canvas_item;

// Atmospheric fog / vignette / gas-lamp glow for the London background.
// Drawn over the background sprite as a full-screen ColorRect.

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform vec4 fog_color : source_color = vec4(0.20, 0.22, 0.28, 0.35);
uniform float fog_density : hint_range(0.0, 1.0) = 0.35;
uniform float vignette_strength : hint_range(0.0, 2.0) = 1.2;
uniform float lamp_glow_intensity : hint_range(0.0, 2.0) = 1.0;
uniform float lamp_glow_radius : hint_range(0.0, 0.5) = 0.12;
uniform vec2 lamp_1_uv = vec2(0.265, 0.42);
uniform vec2 lamp_2_uv = vec2(0.78, 0.52);
uniform float time_scale : hint_range(0.0, 2.0) = 0.8;

// Pseudo-random helper for flicker.
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
    vec2 uv = UV;
    vec2 center = uv - vec2(0.5);
    float dist = length(center);

    // Vignette: darker towards the corners, classic gas-lamp noir look.
    float vignette = 1.0 - smoothstep(0.35, 1.0, dist) * vignette_strength;

    // Fog layers: low-frequency noise drifting horizontally.
    float fog_noise = noise(uv * vec2(4.0, 3.0) + vec2(TIME * 0.03 * time_scale, TIME * 0.01 * time_scale));
    fog_noise = fog_noise * 0.5 + 0.5;
    float fog = fog_noise * fog_density;

    // Gas lamp glow: warm orange point lights.
    float flicker = 0.92 + 0.08 * sin(TIME * 8.0 * time_scale) * sin(TIME * 3.7 * time_scale);
    vec3 lamp_color = vec3(1.0, 0.72, 0.35);
    float glow_1 = smoothstep(lamp_glow_radius, 0.0, distance(uv, lamp_1_uv)) * flicker;
    float glow_2 = smoothstep(lamp_glow_radius * 0.8, 0.0, distance(uv, lamp_2_uv)) * flicker;
    vec3 glow = lamp_color * (glow_1 + glow_2) * lamp_glow_intensity;

    // Combine with background (sampled via SCREEN_TEXTURE).
    vec3 bg = texture(SCREEN_TEXTURE, SCREEN_UV).rgb;
    bg *= vignette;
    bg = mix(bg, fog_color.rgb, fog * fog_color.a);
    bg += glow;

    COLOR = vec4(bg, 1.0);
}
