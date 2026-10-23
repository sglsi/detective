shader_type canvas_item;

// 炉火闪烁光层（scene4 兰斯屋内壁炉专用）：SCREEN_TEXTURE 合成纯加色（bg += glow），
// 与 fog_atmosphere.gdshader 同款模式；flicker 用 value noise 多倍频叠加（低频起伏+高频抖动），
// 比煤气灯的 sin×sin 呼吸更"跳"。全屏 ColorRect 挂载，z 顺序在背景之上、立绘之下。
// 焰心精测（2026-10-20 连通域质心法）：空景/conv 帧火焰均在 x[0.00,0.03] y[0.86,0.97]（画面左缘），
// 主光斑中心取焰心稍内侧以覆盖壁炉前照亮区，勿凭目测改 UV。
// 半径按屏幕高度比例（UV 已做 16:9 纵横比校正）。

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform vec2 hearth_uv = vec2(0.06, 0.88);   // 主光斑：壁炉照亮区（焰心稍内侧）
uniform vec2 core_uv = vec2(0.02, 0.93);     // 焰心：贴边小半径强闪烁
uniform float hearth_radius : hint_range(0.0, 0.5) = 0.20;
uniform float core_radius : hint_range(0.0, 0.5) = 0.07;
uniform float intensity : hint_range(0.0, 2.0) = 0.9;
uniform float time_scale : hint_range(0.0, 2.0) = 1.0;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 uv = UV;
	vec2 asp = vec2(1.7778, 1.0);
	float t = TIME * time_scale;
	float n1 = vnoise(vec2(t * 1.7, 3.7));
	float n2 = vnoise(vec2(t * 6.3, 9.1));
	float n3 = vnoise(vec2(t * 11.0, 1.0));
	float flicker = clamp(0.72 + 0.28 * n1 + 0.12 * (n2 - 0.5) + 0.06 * (n3 - 0.5), 0.45, 1.15);
	float g1 = smoothstep(hearth_radius, 0.0, distance(uv * asp, hearth_uv * asp));
	float g2 = smoothstep(core_radius, 0.0, distance(uv * asp, core_uv * asp));
	float glow = (g1 * 0.85 + g2 * 0.7) * flicker * intensity;
	vec3 fire_col = mix(vec3(1.0, 0.60, 0.26), vec3(1.0, 0.78, 0.45), g2);
	vec3 bg = texture(SCREEN_TEXTURE, SCREEN_UV).rgb;
	// 仅光点范围内替换像素（alpha=遮罩），范围外完全透出背景：
	// 屏幕采样失效时最多丢失火光，不会整屏压黑。
	float mask = clamp(g1 * 0.9 + g2 * 0.8, 0.0, 1.0);
	COLOR = vec4(bg + fire_col * glow, mask);
}
