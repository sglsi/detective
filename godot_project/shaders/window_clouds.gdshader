shader_type canvas_item;

// 窗外云雾（场景四 兰斯屋内）：窗玻璃上缓慢右→左飘移的云团，若隐若现。
// SCREEN_TEXTURE 合成（fog_atmosphere / fire_flicker 同款先例）：bg 与雾色 mix，雾是遮蔽不是加光。
// 三层不同尺度/速度的 value noise 叠加出视差；reveal 用低频 fbm 做块状显隐（若隐若现）。
// 飘移方向：噪声采样坐标 x + TIME*speed 随时间右移 → 图案相对屏幕向左（从右至左）。
// 只作用在玻璃/天空亮区（按背景亮度取 mask），窗框保持清晰。
// 窗位精测（2026-10-24 连通域/亮度法）：两版背景一致 x[0.42,0.67]，天空带 y[0.01,0.28]，
// 玻璃下沿含少量建筑顶部故取 y 至 0.33；勿凭目测改窗口参数。

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform vec2 win_min = vec2(0.415, 0.010);
uniform vec2 win_max = vec2(0.670, 0.330);
uniform float edge_soft : hint_range(0.001, 0.2) = 0.018;
uniform float cloud_speed : hint_range(0.0, 0.2) = 0.004;   // 基础飘移速度（窗口宽约 20s 掠过）
uniform float cloud_density : hint_range(0.0, 1.0) = 0.5;
uniform vec3 cloud_color = vec3(0.80, 0.82, 0.86);

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

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		v += a * vnoise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	vec3 bg = texture(SCREEN_TEXTURE, SCREEN_UV).rgb;
	vec2 lo = smoothstep(win_min - vec2(edge_soft), win_min + vec2(edge_soft), uv);
	vec2 hi = 1.0 - smoothstep(win_max - vec2(edge_soft), win_max + vec2(edge_soft), uv);
	float win = lo.x * lo.y * hi.x * hi.y;
	float t = TIME;
	float c1 = fbm(vec2((uv.x + t * cloud_speed) * 3.0, uv.y * 2.2 + 1.7));
	float c2 = fbm(vec2((uv.x + t * cloud_speed * 1.8) * 6.0, uv.y * 4.5 + 9.2));
	float c3 = vnoise(vec2((uv.x + t * cloud_speed * 2.6) * 11.0, uv.y * 8.0 + 3.1));
	float cloud = c1 * 0.6 + c2 * 0.3 + c3 * 0.1;
	// 若隐若现：低频块状显隐（周期远长于一次飘移），与云同向右→左
	float reveal = smoothstep(0.34, 0.64, fbm(vec2(uv.x * 1.6 + t * 0.012, uv.y * 1.2 + 4.0)));
	float alpha = cloud_density * reveal * smoothstep(0.26, 0.58, cloud);
	// 只雾玻璃/天空亮区，窗框与室内保持清晰
	float lum = dot(bg, vec3(0.299, 0.587, 0.114));
	alpha *= smoothstep(0.28, 0.52, lum) * win;
	alpha = clamp(alpha, 0.0, 0.55);
	// 半透明叠加而非整屏替换：窗口外 alpha=0 完全透出背景，采样异常时也只会退化成"无雾"
	COLOR = vec4(cloud_color, alpha);
}
