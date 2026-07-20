extends Control
class_name ToolBar

## ToolBar - 工具栏
## 管理侦破工具的选择与使用：放大镜、卷尺 (M2+: 化学试验盒等)

enum Tool {
	NONE,
	MAGNIFIER,
	TAPE_MEASURE,
}

var current_tool: Tool = Tool.NONE
var tool_buttons: Dictionary = {}
var is_tool_active: bool = false
var magnifier_overlay: ColorRect
var target_hotspot_id: String = ""

@onready var tool_panel: Panel = $ToolPanel
@onready var magnifier_btn: Button = $ToolPanel/MagnifierBtn
@onready var tape_btn: Button = $ToolPanel/TapeBtn

func _ready() -> void:
	_setup_buttons()
	_create_magnifier_overlay()
	SceneEventBus.connect("hotspot_clicked", _on_hotspot_clicked_for_tool)
	hide()

func _setup_buttons() -> void:
	# 放大镜按钮
	magnifier_btn.text = "🔍 放大镜"
	magnifier_btn.pressed.connect(_on_magnifier_selected)
	tool_buttons[Tool.MAGNIFIER] = magnifier_btn
	
	# 卷尺按钮
	tape_btn.text = "📏 卷尺"
	tape_btn.pressed.connect(_on_tape_selected)
	tool_buttons[Tool.TAPE_MEASURE] = tape_btn

func _create_magnifier_overlay() -> void:
	magnifier_overlay = ColorRect.new()
	magnifier_overlay.size = Vector2(150, 150)
	magnifier_overlay.color = Color(0, 0, 0, 0.3)
	
	var circle = StyleBoxFlat.new()
	circle.bg_color = Color(0, 0, 0, 0)
	circle.border_color = Color(0.8, 0.7, 0.3)
	circle.border_width_left = 3
	circle.border_width_right = 3
	circle.border_width_top = 3
	circle.border_width_bottom = 3
	circle.set_corner_radius_all(75)
	magnifier_overlay.add_theme_stylebox_override("panel", circle)
	
	magnifier_overlay.hide()
	add_child(magnifier_overlay)

	# 立绘图像（让放大镜真正"有图像"，修复 Issue 2：原先只有边框无内容）
	var tex_path = "res://assets/portraits/sherlock_凝思.png"
	var img = TextureRect.new()
	img.name = "MagnifierImage"
	img.size = Vector2(140, 140)
	img.position = Vector2(5, 5)
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(tex_path):
		img.texture = load(tex_path)
	magnifier_overlay.add_child(img)

func show_toolbar() -> void:
	show()
	is_tool_active = true

func hide_toolbar() -> void:
	hide()
	current_tool = Tool.NONE
	is_tool_active = false
	magnifier_overlay.hide()

func _on_magnifier_selected() -> void:
	current_tool = Tool.MAGNIFIER
	_highlight_button(Tool.MAGNIFIER)
	UIManager.show_notification("放大镜已选择 — 点击场景中的目标区域进行观察")

func _on_tape_selected() -> void:
	current_tool = Tool.TAPE_MEASURE
	_highlight_button(Tool.TAPE_MEASURE)
	UIManager.show_notification("卷尺已选择 — 拖拽测量起点和终点")

func _highlight_button(tool: Tool) -> void:
	for t in tool_buttons:
		var btn = tool_buttons[t]
		if t == tool:
			btn.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
		else:
			btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))

func _on_hotspot_clicked_for_tool(hotspot_id: String) -> void:
	if not is_tool_active or current_tool == Tool.NONE:
		return
	
	target_hotspot_id = hotspot_id
	
	match current_tool:
		Tool.MAGNIFIER:
			_start_magnifier()
		Tool.TAPE_MEASURE:
			_start_tape_measure()

func _start_magnifier() -> void:
	magnifier_overlay.show()
	UIManager.show_notification("移动放大镜到目标区域，停留 3 秒完成观察")
	# 简化：直接完成观察（延长显示时间，修复 Issue 2：原先 1.5s 过短）
	await get_tree().create_timer(3.0).timeout
	_complete_tool_use("magnifier")

func _start_tape_measure() -> void:
	UIManager.show_notification("从起点拖拽到终点进行测量")
	# 简化：直接完成测量
	await get_tree().create_timer(1.0).timeout
	_complete_tool_use("tape_measure")

func _complete_tool_use(tool_name: String) -> void:
	magnifier_overlay.hide()
	SceneEventBus.emit_signal("tool_used", tool_name, target_hotspot_id)
	current_tool = Tool.NONE
