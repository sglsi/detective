class_name HumanBone
extends Node2D

# 单段（一个人体部位）。本身是关节节点：原点=近端关节(锚点)。
# 负责：按 length/width/shape/color 在本地坐标绘制该部位，并画出关节锚点标记。
# 旋转由父级层级 + set_pose 决定的 local rotation 控制（FK 自然成立）。

var seg_id: String = ""
var length: float = 0.0
var width: float = 0.0
var shape: String = "capsule"
var color: Color = Color.WHITE
var rom: Vector2 = Vector2(-TAU, TAU)
var rest_angle: float = 0.0

func _draw() -> void:
	var half_w := width * 0.5
	match shape:
		"circle":
			# 头：圆心在原点上方 length/2 处，使颈部关节落在原点(底端)
			draw_circle(Vector2(0.0, -length * 0.5), length * 0.5, color)
		"capsule":
			# 沿 +Y 从 0 到 length 的胶囊（圆角矩形）
			draw_colored_polygon([
				Vector2(-half_w, 0.0),
				Vector2(-half_w, length),
				Vector2(half_w, length),
				Vector2(half_w, 0.0),
			], color)
			draw_circle(Vector2(0.0, 0.0), half_w, color)
			draw_circle(Vector2(0.0, length), half_w, color)
		_:
			draw_line(Vector2.ZERO, Vector2(0.0, length), color, width)
	# 关节锚点标记：红点 = 该部位旋转的基准中心
	draw_circle(Vector2.ZERO, 3.5, Color(0.85, 0.15, 0.15, 0.95))
	draw_circle(Vector2.ZERO, 1.6, Color(1.0, 1.0, 1.0, 0.95))
