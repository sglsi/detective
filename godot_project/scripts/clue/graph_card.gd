extends PanelContainer
class_name GraphCard

## 图谱节点卡：继承 PanelContainer，用 _draw 手动补虚线边框
## （Godot 4.7 StyleBoxFlat 暂不支持 border_style 虚线，本类补齐）。
##
## 边框样式：
##   - solid（默认）：由父节点传入的 style.bg_color + border_color 决定（实线）
##   - dashed：把 stylebox 边框隐藏（border_width=0），由本类的 _draw 画虚线
##
## 用法：实例化后调 setup_dashed(true, color, width)。

var dashed_border: bool = false
var dashed_color: Color = Color(0.42, 0.34, 0.18)
var dashed_width: float = 2.0
var _dashed_dash_len: float = 6.0
var _dashed_gap_len: float = 4.0


func _ready() -> void:
	# connect to draw signal so _on_my_draw runs after stylebox draws
	# (the stylebox draws bg_color + solid border; then we overlay dashed if enabled)
	if not draw.is_connected(_on_my_draw):
		draw.connect(_on_my_draw)


## 配置虚线边框（启用后由本类绘制，stylebox 边框应被父节点设为 width=0）
func setup_dashed(enabled: bool, col: Color, width: float = 2.0, dash_len: float = 6.0, gap_len: float = 4.0) -> void:
	dashed_border = enabled
	dashed_color = col
	dashed_width = width
	_dashed_dash_len = dash_len
	_dashed_gap_len = gap_len
	queue_redraw()


func _on_my_draw() -> void:
	if not dashed_border: return
	# 略向内缩（避免覆盖 stylebox 的圆角）
	var inset: float = max(1.0, dashed_width * 0.5)
	var rect := Rect2(Vector2(inset, inset), size - Vector2(inset * 2.0, inset * 2.0))
	_dash_edge(rect.position, rect.position + Vector2(rect.size.x, 0), 0)
	_dash_edge(rect.position + Vector2(rect.size.x, 0), rect.position + rect.size, 1)
	_dash_edge(rect.position + rect.size, rect.position + Vector2(0, rect.size.y), 2)
	_dash_edge(rect.position + Vector2(0, rect.size.y), rect.position, 3)


## 沿一条直线边循环 dash
func _dash_edge(a: Vector2, b: Vector2, _side: int) -> void:
	var dist: float = a.distance_to(b)
	if dist < 1.0: return
	var seg: float = _dashed_dash_len + _dashed_gap_len
	if seg <= 0: return
	var steps: int = int(dist / seg)
	var dir: Vector2 = (b - a).normalized()
	var pos: Vector2 = a
	for i in steps:
		var p2: Vector2 = pos + dir * _dashed_dash_len
		if p2.distance_to(a) > dist: p2 = b
		draw_line(pos, p2, dashed_color, dashed_width)
		pos = p2 + dir * _dashed_gap_len
	if pos.distance_to(b) > 1.0:
		draw_line(pos, b, dashed_color, dashed_width)