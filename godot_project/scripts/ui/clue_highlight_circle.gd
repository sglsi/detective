extends Control
class_name ClueHighlightCircle

## 线索高亮圆圈：覆盖在角色立绘控件之上，用发光脉动圆圈圈定解剖部位。
## 替代旧的「文字 + 文本框 / 放大卡」呈现，让玩家直接在人物立绘上看到相关部位被高亮。

var _center := Vector2.ZERO
var _radius := 50.0
var _t := 0.0
var _color := Color(0.98, 0.82, 0.30)   # 烫金高亮色

func setup(center_local: Vector2, radius: float, col: Color = Color(0.98, 0.82, 0.30)) -> void:
	_center = center_local
	_radius = radius
	_color = col
	# 覆盖整个父控件（立绘控件），_draw 用局部坐标命中锚点
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _draw() -> void:
	var pulse: float = 0.5 + 0.5 * sin(_t * 3.0)   # 0..1 脉动
	var w: float = 3.0 + 2.0 * pulse
	# 外晕（宽、低透明）
	draw_arc(_center, _radius + 7.0, 0, TAU, 72, _color * Color(1, 1, 1, 0.22), 10)
	# 主圈线
	draw_arc(_center, _radius, 0, TAU, 72, _color, w)
	# 内亮圈（随脉动闪）
	draw_arc(_center, _radius - 4.0, 0, TAU, 72, Color(1, 1, 1, 0.55 * pulse), 2.0)

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
