extends Control
## 程序化生成的「场景一客厅」简化预览（仅能力验证，非游戏资产）
## 参照 assets/backgrounds/screen01-sofa01.png 的构图/色调：
## 绿墙纸 + 左侧碎花窗帘窗 + 大书柜 + 棕色皮沙发 + 风景油画 + 右侧壁炉/金镜 + 红地毯 + 木地板
## 零图片素材，全部 _draw 矢量绘制。

const W := 1280
const H := 960

func _ready() -> void:
	custom_minimum_size = Vector2(W, H)
	size = Vector2(W, H)
	clip_contents = true   # 防止暗角等绘制溢出画布

func _draw() -> void:
	_draw_wall()
	_draw_window_and_curtains()
	_draw_paintings()
	_draw_wall_clock()
	_draw_mirror()
	_draw_bookshelf()
	_draw_floor()
	_draw_fireplace()
	_draw_rug()
	_draw_furniture()
	_draw_atmosphere()

# ---------- 墙面 ----------
func _draw_wall() -> void:
	# 主墙：暗绿
	draw_rect(Rect2(0, 0, W, 660), Color8(85, 102, 66))
	# 墙纸竖向花纹带（每 96px 一条稍暗绿带 + 细点纹）
	var band := Color(0, 0, 0, 0.06)
	var x := 48
	while x < W:
		draw_rect(Rect2(x, 0, 34, 660), band)
		x += 96
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 340:
		var px := rng.randf_range(0, W)
		var py := rng.randf_range(0, 640)
		draw_rect(Rect2(px, py, 3, 3), Color(1, 1, 1, 0.045))
	# 顶部线脚
	draw_rect(Rect2(0, 0, W, 26), Color8(112, 88, 58))
	draw_rect(Rect2(0, 26, W, 6), Color8(70, 54, 36))
	# 踢脚线
	draw_rect(Rect2(0, 614, W, 6), Color8(126, 100, 66))
	draw_rect(Rect2(0, 620, W, 40), Color8(74, 54, 32))

# ---------- 窗户与窗帘 ----------
func _draw_window_and_curtains() -> void:
	# 窗框（木）
	draw_rect(Rect2(24, 56, 212, 388), Color8(107, 74, 44))
	# 窗外景：天 + 远树 + 草地
	draw_rect(Rect2(36, 68, 188, 150), Color8(168, 196, 200))   # 天
	draw_rect(Rect2(36, 190, 188, 120), Color8(122, 148, 80))   # 远树带
	draw_rect(Rect2(36, 288, 188, 144), Color8(150, 172, 96))   # 草地
	# 树冠剪影
	draw_circle(Vector2(80, 196), 34, Color8(90, 118, 62))
	draw_circle(Vector2(150, 210), 40, Color8(80, 106, 54))
	draw_circle(Vector2(210, 200), 30, Color8(96, 124, 66))
	# 窗棂
	draw_rect(Rect2(126, 68, 10, 364), Color8(74, 54, 32))
	draw_rect(Rect2(36, 236, 188, 10), Color8(74, 54, 32))
	# 窗台
	draw_rect(Rect2(14, 438, 232, 18), Color8(122, 90, 54))
	# 窗帘（左右两片，暖黄底 + 红花点）
	var curt := Color8(200, 160, 90)
	var floral := Color8(168, 72, 48)
	# 左片
	draw_rect(Rect2(0, 0, 62, 520), curt)
	draw_rect(Rect2(62, 0, 12, 520), Color8(160, 122, 62))
	# 右片（略宽，有收拢褶皱感）
	draw_rect(Rect2(198, 0, 76, 520), curt)
	draw_rect(Rect2(190, 0, 10, 520), Color8(160, 122, 62))
	# 褶皱竖线
	draw_rect(Rect2(216, 0, 4, 520), Color(0, 0, 0, 0.10))
	draw_rect(Rect2(234, 0, 4, 520), Color(0, 0, 0, 0.10))
	draw_rect(Rect2(252, 0, 4, 520), Color(0, 0, 0, 0.10))
	# 红花点
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 46:
		var cx := rng.randf_range(4, 58)
		var cy := rng.randf_range(10, 500)
		draw_circle(Vector2(cx, cy), 3.2, floral)
	for i in 56:
		var cx := rng.randf_range(202, 270)
		var cy := rng.randf_range(10, 500)
		draw_circle(Vector2(cx, cy), 3.2, floral)

# ---------- 挂画 ----------
func _draw_paintings() -> void:
	# 大风景油画（沙发上方）
	draw_rect(Rect2(552, 144, 196, 196), Color8(184, 150, 74))    # 金框
	draw_rect(Rect2(562, 154, 176, 176), Color8(96, 78, 40))      # 内框深
	draw_rect(Rect2(570, 162, 160, 160), Color8(176, 184, 168))   # 天空
	draw_rect(Rect2(570, 220, 160, 60), Color8(85, 102, 62))      # 远树带
	draw_rect(Rect2(570, 262, 160, 60), Color8(120, 136, 152))    # 河
	draw_rect(Rect2(570, 288, 160, 34), Color8(90, 106, 66))      # 近岸
	draw_circle(Vector2(610, 216), 26, Color8(70, 88, 54))        # 树冠
	draw_circle(Vector2(692, 226), 30, Color8(62, 80, 48))
	# 小肖像画（右侧）
	draw_rect(Rect2(846, 186, 100, 124), Color8(120, 96, 50))
	draw_rect(Rect2(854, 194, 84, 108), Color8(58, 48, 40))
	draw_ellipse(Vector2(896, 232), 18, 22, Color8(216, 184, 144))  # 脸
	draw_ellipse(Vector2(896, 268), 30, 20, Color8(44, 36, 30))     # 肩

# ---------- 壁钟（挂在绿墙开放处） ----------
func _draw_wall_clock() -> void:
	# 木框 + 表盘
	draw_circle(Vector2(512, 120), 30, Color8(110, 78, 44))
	draw_circle(Vector2(512, 120), 24, Color8(238, 234, 220))
	# 12 刻度
	for i in 12:
		var a := TAU * i / 12.0 - PI / 2.0
		draw_circle(Vector2(512 + cos(a) * 20, 120 + sin(a) * 20), 2.0, Color8(40, 32, 26))
	# 指针（10:10 经典姿态）
	draw_line(Vector2(512, 120), Vector2(512, 104), Color8(30, 26, 22), 2.6)   # 时针
	draw_line(Vector2(512, 120), Vector2(529, 127), Color8(30, 26, 22), 2.0)   # 分针
	draw_circle(Vector2(512, 120), 3.0, Color8(30, 26, 22))                     # 中心轴

# ---------- 壁炉镜 ----------
func _draw_mirror() -> void:
	draw_rect(Rect2(1054, 54, 184, 284), Color8(200, 164, 82))    # 金框
	draw_rect(Rect2(1066, 66, 160, 260), Color8(138, 106, 48))    # 内框
	# 镜面（冷灰蓝渐变 3 段）
	draw_rect(Rect2(1074, 74, 144, 90), Color8(154, 168, 180))
	draw_rect(Rect2(1074, 164, 144, 90), Color8(178, 192, 200))
	draw_rect(Rect2(1074, 254, 144, 72), Color8(200, 212, 218))
	# 对角高光
	draw_polygon(
		PackedVector2Array([
			Vector2(1074, 300), Vector2(1180, 74),
			Vector2(1218, 74), Vector2(1108, 330)
		]),
		PackedColorArray([Color(1, 1, 1, 0.13), Color(1, 1, 1, 0.13),
			Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.03)])
	)

# ---------- 书柜 ----------
func _draw_bookshelf() -> void:
	# 柜体
	draw_rect(Rect2(248, 76, 226, 570), Color8(95, 65, 38))
	draw_rect(Rect2(260, 90, 202, 286), Color8(58, 40, 18))       # 书架背板
	# 4 层书脊
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var palette: Array[Color] = [
		Color8(138, 64, 48), Color8(64, 80, 112), Color8(74, 106, 64),
		Color8(122, 85, 48), Color8(192, 168, 120), Color8(96, 60, 40),
		Color8(110, 120, 90)
	]
	var shelf_top := 100.0
	for s in 4:
		var y := shelf_top + s * 70.0
		var cx := 266.0
		while cx < 452.0:
			var bw := rng.randf_range(9.0, 17.0)
			var bh := rng.randf_range(40.0, 52.0)
			var col := palette[rng.randi_range(0, palette.size() - 1)]
			draw_rect(Rect2(cx, y + 54.0 - bh, bw, bh), col)
			cx += bw + 2.0
		draw_rect(Rect2(260, y + 54.0, 202, 9), Color8(122, 85, 48))  # 层板
	# 顶层摆件（瓷器）
	draw_ellipse(Vector2(286, 96), 12, 8, Color8(216, 208, 192))
	draw_ellipse(Vector2(316, 94), 9, 11, Color8(138, 120, 88))
	draw_ellipse(Vector2(430, 96), 13, 9, Color8(200, 190, 170))
	# 中层摆件（小瓷瓶，原挂表已移至墙面）
	draw_ellipse(Vector2(418, 250), 12, 16, Color8(150, 130, 96))
	draw_ellipse(Vector2(418, 236), 7, 5, Color8(176, 156, 120))
	# 底柜（两扇门）
	draw_rect(Rect2(260, 384, 202, 252), Color8(107, 74, 44))
	draw_rect(Rect2(268, 394, 90, 232), Color8(96, 64, 36))
	draw_rect(Rect2(364, 394, 90, 232), Color8(96, 64, 36))
	draw_circle(Vector2(352, 508), 5, Color8(210, 180, 110))
	draw_circle(Vector2(372, 508), 5, Color8(210, 180, 110))

# ---------- 地板 ----------
func _draw_floor() -> void:
	draw_rect(Rect2(0, 640, W, H - 640), Color8(74, 54, 36))
	# 木板竖缝
	var x := 20
	while x < W:
		draw_rect(Rect2(x, 640, 3, H - 640), Color(0, 0, 0, 0.28))
		x += 46
	# 错位横接缝
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 26:
		var px := rng.randf_range(0, W)
		var py := rng.randf_range(650, H)
		draw_rect(Rect2(px, py, 40, 2), Color(0, 0, 0, 0.20))

# ---------- 壁炉 ----------
func _draw_fireplace() -> void:
	# 大理石台面 + 两柱
	draw_rect(Rect2(986, 350, 292, 28), Color8(213, 207, 194))
	draw_rect(Rect2(986, 350, 292, 6), Color8(238, 234, 224))
	draw_rect(Rect2(986, 378, 36, 430), Color8(205, 198, 184))
	draw_rect(Rect2(1242, 378, 36, 430), Color8(205, 198, 184))
	draw_rect(Rect2(1022, 378, 6, 430), Color8(160, 152, 138))
	draw_rect(Rect2(1236, 378, 6, 430), Color8(160, 152, 138))
	# 炉膛开口（黑）
	draw_rect(Rect2(1040, 440, 190, 310), Color8(23, 18, 14))
	draw_rect(Rect2(1040, 428, 190, 16), Color8(60, 48, 38))
	# 火光（同心圆暖光）
	draw_ellipse(Vector2(1135, 700), 96, 52, Color8(122, 52, 24))
	draw_ellipse(Vector2(1135, 706), 72, 40, Color8(200, 106, 40))
	draw_ellipse(Vector2(1135, 712), 48, 27, Color8(240, 160, 80))
	draw_ellipse(Vector2(1135, 716), 26, 15, Color8(248, 208, 128))
	# 柴
	draw_rect(Rect2(1092, 726, 96, 10), Color8(58, 36, 20))
	draw_rect(Rect2(1108, 738, 80, 10), Color8(48, 30, 16))
	# 金色围栏
	for i in 6:
		var fx := 1058.0 + i * 36.0
		draw_rect(Rect2(fx, 742, 5, 96), Color8(176, 138, 58))
	draw_rect(Rect2(1048, 738, 208, 8), Color8(196, 156, 66))
	draw_rect(Rect2(1048, 834, 208, 8), Color8(196, 156, 66))
	# 台面摆件：烛台 + 瓶
	draw_rect(Rect2(1010, 300, 6, 50), Color8(190, 190, 196))
	draw_circle(Vector2(1013, 296), 6, Color8(248, 192, 96))
	draw_ellipse(Vector2(1076, 322), 12, 16, Color8(120, 128, 140))
	draw_ellipse(Vector2(1214, 318), 10, 20, Color8(90, 110, 120))

# ---------- 地毯 ----------
func _draw_rug() -> void:
	var cx := Vector2(645, 815)
	# 外圈暗红
	draw_ellipse(cx, 395, 150, Color8(122, 52, 34))
	draw_ellipse(cx, 372, 134, Color8(150, 66, 46))
	# 内部主红
	draw_ellipse(cx, 300, 104, Color8(150, 66, 46))
	# 同心金线菱形
	var pts_outer := PackedVector2Array()
	var pts_inner := PackedVector2Array()
	for i in 4:
		pts_outer.append(cx + Vector2(0, -88).rotated(TAU * i / 4.0) * Vector2(1.0, 0.62))
		pts_inner.append(cx + Vector2(0, -56).rotated(TAU * i / 4.0) * Vector2(1.0, 0.62))
	draw_polyline(pts_outer + PackedVector2Array([pts_outer[0]]), Color8(201, 162, 90), 4.0)
	draw_polyline(pts_inner + PackedVector2Array([pts_inner[0]]), Color8(201, 162, 90), 3.0)
	# 中心花纹
	draw_ellipse(cx, 34, 22, Color8(168, 86, 58))
	var pts_center := PackedVector2Array()
	for i in 4:
		pts_center.append(cx + Vector2(0, -37).rotated(TAU * i / 4.0) * Vector2(1.0, 0.62))
	draw_polyline(pts_center + PackedVector2Array([pts_center[0]]), Color8(226, 196, 130), 2.0)
	# 边缘点串
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 30:
		var a := TAU * i / 30.0
		var p := cx + Vector2(cos(a) * 340, sin(a) * 140)
		draw_circle(p, 3, Color8(201, 162, 90))

# ---------- 家具（前景） ----------
func _draw_furniture() -> void:
	# 右中小木柜 + 小提琴（略右移，避免遮挡加宽后的沙发）
	draw_rect(Rect2(848, 424, 152, 216), Color8(90, 61, 36))
	draw_rect(Rect2(856, 432, 136, 30), Color8(110, 78, 46))
	draw_rect(Rect2(856, 500, 136, 10), Color8(60, 42, 24))
	draw_circle(Vector2(922, 560), 6, Color8(210, 180, 110))
	draw_rect(Rect2(856, 590, 136, 10), Color8(60, 42, 24))
	# 小提琴（斜靠柜右侧）
	draw_ellipse(Vector2(1016, 560), 18, 27, Color8(138, 90, 42))
	draw_ellipse(Vector2(1016, 560), 11, 18, Color8(158, 110, 56))
	draw_line(Vector2(1016, 538), Vector2(1036, 480), Color8(70, 46, 22), 6.0)
	# ---- 棕色皮沙发（切斯特菲尔德，加宽 5/4，整体左移 16px 保持视觉居中） ----
	var base := Color8(140, 92, 56)
	# 底部阴影
	draw_ellipse(Vector2(624, 668), 235, 26, Color(0, 0, 0, 0.30))
	# 靠背（带弧顶）
	draw_rect(Rect2(429, 438, 390, 130), base)
	draw_ellipse(Vector2(624, 440), 195, 26, base)
	# 座垫
	draw_rect(Rect2(417, 540, 414, 66), Color8(158, 106, 66))
	# 扶手（两端圆柱）
	draw_circle(Vector2(445, 560), 36, base)
	draw_circle(Vector2(803, 560), 36, base)
	draw_rect(Rect2(417, 560, 56, 82), base)
	draw_rect(Rect2(775, 560, 56, 82), base)
	# 拉扣（深棕点阵）
	for gx in 4:
		for gy in 3:
			draw_circle(Vector2(494 + gx * 93, 470 + gy * 34), 4, Color8(82, 52, 30))
	# 抱枕（两个旋转方块）
	_draw_pillow(Vector2(529, 520), -0.18)
	_draw_pillow(Vector2(719, 520), 0.15)
	# 沙发脚
	draw_rect(Rect2(436, 648, 18, 16), Color8(52, 34, 18))
	draw_rect(Rect2(794, 648, 18, 16), Color8(52, 34, 18))
	# ---- 左下圆桌（圆木面 + 白桌布垂坠）+ 椅 ----
	# 圆桌面（木色，露出桌布上沿，明确是"圆桌"）
	draw_ellipse(Vector2(118, 636), 120, 22, Color8(120, 82, 48))
	draw_ellipse(Vector2(118, 632), 120, 20, Color8(142, 98, 58))
	# 桌布主体（从桌面垂下）
	draw_rect(Rect2(2, 640, 232, 158), Color8(232, 226, 210))
	# 桌沿高光
	draw_rect(Rect2(2, 632, 232, 12), Color8(244, 240, 228))
	# 下摆柔和扇形波浪（替代尖锐锯齿，避免与地板形成木栅感）
	for i in 6:
		draw_ellipse(Vector2(22.0 + i * 40.0, 802), 20, 15, Color8(232, 226, 210))
	# 桌腿（布料间露出两根）
	draw_rect(Rect2(64, 782, 12, 38), Color8(90, 60, 34))
	draw_rect(Rect2(160, 782, 12, 38), Color8(90, 60, 34))
	# ---- 椅子（左侧，加宽 1/3，明确椅形） ----
	# 椅背（带圆角顶）
	draw_rect(Rect2(30, 556, 128, 124), Color8(90, 61, 36))
	draw_ellipse(Vector2(94, 558), 64, 18, Color8(90, 61, 36))
	# 椅背内凹（稍暗，显厚度）
	draw_rect(Rect2(44, 574, 100, 98), Color8(74, 50, 28))
	# 座面（横条，强调"座位"）
	draw_rect(Rect2(24, 676, 140, 26), Color8(110, 76, 46))
	# 椅腿（四根，前端两根更粗；底部略尖，像真实椅脚）
	_draw_chair_leg(Vector2(41, 702), 14, 158)
	_draw_chair_leg(Vector2(147, 702), 14, 158)
	_draw_chair_leg(Vector2(70, 702), 12, 150)
	_draw_chair_leg(Vector2(118, 702), 12, 150)

func _draw_chair_leg(top_center: Vector2, width: int, length: int) -> void:
	# 椅腿：上粗下略收，底部微圆
	var c := Color8(60, 40, 22)
	var x := top_center.x - width / 2.0
	var y := top_center.y
	draw_rect(Rect2(x, y, width, length - 6), c)
	var pts := PackedVector2Array([
		Vector2(x, y + length - 6),
		Vector2(x + width, y + length - 6),
		Vector2(x + width - 2, y + length),
		Vector2(x + 2, y + length)
	])
	draw_polygon(pts, PackedColorArray([c, c, c, c]))

func _draw_pillow(center: Vector2, rot: float) -> void:
	var half := 34.0
	var pts := PackedVector2Array()
	for corner in [Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)]:
		pts.append(center + corner.rotated(rot))
	draw_polygon(pts, PackedColorArray([
		Color8(216, 199, 154), Color8(216, 199, 154),
		Color8(196, 178, 132), Color8(196, 178, 132)
	]))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(center.x)
	for i in 12:
		var ox := rng.randf_range(-22.0, 22.0)
		var oy := rng.randf_range(-22.0, 22.0)
		draw_circle(center + Vector2(ox, oy).rotated(rot), 2.6, Color8(168, 72, 48))

# ---------- 氛围 ----------
func _draw_atmosphere() -> void:
	# 窗光（左侧暖色斜光带）
	draw_polygon(
		PackedVector2Array([
			Vector2(40, 100), Vector2(240, 100), Vector2(680, 960), Vector2(180, 960)
		]),
		PackedColorArray([
			Color(232, 200, 130, 0.10), Color(232, 200, 130, 0.10),
			Color(232, 200, 130, 0.02), Color(232, 200, 130, 0.02)
		])
	)
	# 壁炉光晕（暖橙）
	draw_circle(Vector2(1135, 690), 240, Color(235, 140, 60, 0.06))
	draw_circle(Vector2(1135, 690), 150, Color(235, 140, 60, 0.07))
	# 整体压暗 + 暗角（轻）
	draw_rect(Rect2(0, 0, W, H), Color(24, 20, 12, 0.06))
	draw_circle(Vector2(-120, -80), 520, Color(0, 0, 0, 0.10))
	draw_circle(Vector2(W + 120, -80), 520, Color(0, 0, 0, 0.10))
	draw_circle(Vector2(-120, H + 80), 560, Color(0, 0, 0, 0.14))
	draw_circle(Vector2(W + 120, H + 80), 560, Color(0, 0, 0, 0.14))

# ---------- 工具 ----------
func _ellipse(center: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 64:
		var a := TAU * i / 64.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_polygon(pts, PackedColorArray([col]))
