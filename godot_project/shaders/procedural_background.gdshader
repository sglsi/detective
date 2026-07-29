shader_type canvas_item;

// 纯程序化维多利亚夜景氛围背景 —— 不依赖任何位图。
// 用 fbm 噪声生成天际线剪影 + 雾 + 煤气灯辉光 + 暗角 + 慢摇镜头。

uniform vec4 sky_top : source_color = vec4(0.04, 0.05, 0.11, 1.0);
uniform vec4 sky_bottom : source_color = vec4(0.20, 0.15, 0.17, 1.0);
uniform vec4 building_far : source_color = vec4(0.05, 0.05, 0.08, 1.0);
uniform vec4 building_near : source_color = vec4(0.015, 0.015, 0.03, 1.0);
uniform vec4 fog_color : source_color = vec4(0.20, 0.22, 0.28, 0.55);
uniform float fog_density : hint_range(0.0, 1.0) = 0.40;
uniform float vignette_strength : hint_range(0.0, 2.0) = 1.25;
uniform float lamp_glow_intensity : hint_range(0.0, 3.0) = 1.3;
uniform float lamp_glow_radius : hint_range(0.0, 0.4) = 0.11;
uniform vec2 lamp_1 = vec2(0.25, 0.55);
uniform vec2 lamp_2 = vec2(0.74, 0.47);
uniform float window_glow : hint_range(0.0, 1.0) = 0.6;
uniform float time_scale : hint_range(0.0, 3.0) = 1.0;
uniform float pan_offset : hint_range(-0.15, 0.15) = 0.0;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 5; i++) {
        v += a * noise(p);
        p *= 2.0;
        a *= 0.5;
    }
    return v;
}

// 天际线高度轮廓：多频正弦 + 噪声叠加，生成起伏屋顶
float skyline(float x) {
    float h = 0.46;
    h += 0.11 * sin(x * 7.0);
    h += 0.05 * sin(x * 19.0 + 1.3);
    h += 0.06 * fbm(vec2(x * 4.0, 3.0));
    return h;
}

void fragment() {
    vec2 uv = UV;
    float px = uv.x + pan_offset;          // 慢摇：水平漂移

    // --- 天空渐变 ---
    float sky_t = smoothstep(0.0, 0.75, 1.0 - uv.y);
    vec3 col = mix(sky_bottom.rgb, sky_top.rgb, sky_t);

    // --- 远处月晕 ---
    float moon = smoothstep(0.20, 0.0, distance(uv, vec2(0.82, 0.24)));
    col += vec3(0.55, 0.60, 0.66) * moon * 0.35;

    // --- 天际线剪影（远 + 近两层，营造纵深）---
    float horizon_far = skyline(px);
    float horizon_near = horizon_far - 0.09 + 0.03 * fbm(vec2(px * 6.0, 5.0));
    float b_far = step(uv.y, horizon_far);
    float b_near = step(uv.y, horizon_near);
    col = mix(col, building_far.rgb, b_far * 0.65);
    col = mix(col, building_near.rgb, b_near);

    // --- 建筑窗户暖光（近景随机点，轻微闪烁）---
    if (b_near > 0.5) {
        float wx = floor(px * 130.0);
        float wy = floor(uv.y * 130.0);
        float w = hash(vec2(wx, wy));
        if (w > 0.90) {
            float flick = 0.55 + 0.45 * sin(TIME * 1.7 + w * 30.0);
            col += vec3(1.0, 0.78, 0.40) * window_glow * flick;
        }
    }

    // --- 雾：fbm 漂移，越近地面越浓 ---
    float fog_n = fbm(uv * vec2(3.0, 2.0) + vec2(TIME * 0.02 * time_scale, TIME * 0.008));
    float fog = fog_n * fog_density * smoothstep(0.75, 0.08, uv.y);
    col = mix(col, fog_color.rgb, fog * fog_color.a);

    // --- 暗角 ---
    float d = length(uv - 0.5);
    float vig = 1.0 - smoothstep(0.32, 0.85, d) * vignette_strength;
    col *= vig;

    // --- 煤气灯辉光（双点 + 闪烁）---
    float flick = 0.90 + 0.10 * sin(TIME * 7.0 * time_scale) * sin(TIME * 3.3 * time_scale);
    vec3 lamp_c = vec3(1.0, 0.72, 0.35);
    float g1 = smoothstep(lamp_glow_radius, 0.0, distance(uv, lamp_1)) * flick;
    float g2 = smoothstep(lamp_glow_radius * 0.85, 0.0, distance(uv, lamp_2)) * flick;
    col += lamp_c * (g1 + g2) * lamp_glow_intensity;

    COLOR = vec4(col, 1.0);
}
