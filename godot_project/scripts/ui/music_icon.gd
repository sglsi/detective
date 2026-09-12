extends Control
## 喇叭图标（矢量绘制）：金色喇叭；开=带声波弧线，关=暗金带静音斜杠。
## 供顶栏常驻音乐开关按钮使用。无 class_name，避免类缓存重建依赖。

var on: bool = true


func set_on(v: bool) -> void:
	if on == v:
		return
	on = v
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	var c: Color = Color(0.88, 0.72, 0.34) if on else Color(0.60, 0.50, 0.32)
	var edge := Color(0.10, 0.07, 0.03, 0.9)
	var s: float = minf(size.x, size.y)
	var cx: float = size.x * 0.5
	var cy: float = size.y * 0.5
	var u: float = s / 24.0
	# 喇叭主体：矩形 + 锥形
	var poly := PackedVector2Array([
		Vector2(cx - 8.5 * u, cy - 3.5 * u),
		Vector2(cx - 3.0 * u, cy - 3.5 * u),
		Vector2(cx + 2.0 * u, cy - 9.0 * u),
		Vector2(cx + 2.0 * u, cy + 9.0 * u),
		Vector2(cx - 3.0 * u, cy + 3.5 * u),
		Vector2(cx - 8.5 * u, cy + 3.5 * u),
	])
	draw_colored_polygon(poly, c)
	var outline := PackedVector2Array(poly)
	outline.append(poly[0])
	draw_polyline(outline, edge, maxf(1.0, 0.8 * u), true)
	if on:
		# 声波弧线
		draw_arc(Vector2(cx + 2.0 * u, cy), 5.5 * u, -PI / 3.0, PI / 3.0, 16, c, maxf(1.0, 1.4 * u), true)
		draw_arc(Vector2(cx + 2.0 * u, cy), 9.0 * u, -PI / 3.0, PI / 3.0, 20, c, maxf(1.0, 1.4 * u), true)
	else:
		# 静音斜杠
		draw_line(
			Vector2(cx - 9.0 * u, cy - 9.0 * u),
			Vector2(cx + 8.0 * u, cy + 9.0 * u),
			Color(0.74, 0.24, 0.18),
			maxf(1.5, 1.8 * u),
			true
		)
