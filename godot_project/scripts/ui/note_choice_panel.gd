extends Control
class_name NoteChoicePanel

## NoteChoicePanel — 侦探笔记选择面板
## 玩家观察完一个部位后，由 GameScene 弹出，询问是否将该线索「加入笔记」。
## 修复 Issue 2：用玩家主动选择替代原先 0.15s 自动跳转到「侦探笔记」页。

signal choice_made(confirmed: bool)

var _clue_id: String = ""
var _panel: Panel

func setup(clue_id: String, clue_text: String) -> void:
	_clue_id = clue_id

	# 全屏半透明遮罩（不影响下方放大镜视图的显示）
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.25)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	# 居中面板
	_panel = Panel.new()
	_panel.size = Vector2(560, 260)
	_panel.position = Vector2(1920 / 2 - 280, 1080 / 2 + 40)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.09, 0.06, 0.97)
	sb.border_color = Color(0.6, 0.45, 0.2, 1.0)
	sb.border_width_left = sb.border_width_right = sb.border_width_top = sb.border_width_bottom = 3
	sb.set_corner_radius_all(10)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	var title = Label.new()
	title.text = "🔍 发现线索"
	title.position = Vector2(30, 18)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4, 1.0))
	_panel.add_child(title)

	var desc = Label.new()
	desc.text = clue_text
	desc.position = Vector2(30, 64)
	desc.size = Vector2(500, 90)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 18)
	desc.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7, 1.0))
	_panel.add_child(desc)

	var confirm_btn = Button.new()
	confirm_btn.text = "📝 加入笔记"
	confirm_btn.position = Vector2(40, 180)
	confirm_btn.size = Vector2(220, 56)
	confirm_btn.add_theme_font_size_override("font_size", 20)
	confirm_btn.pressed.connect(_on_confirm_pressed)
	_panel.add_child(confirm_btn)

	var skip_btn = Button.new()
	skip_btn.text = "跳过"
	skip_btn.position = Vector2(300, 180)
	skip_btn.size = Vector2(220, 56)
	skip_btn.add_theme_font_size_override("font_size", 20)
	skip_btn.pressed.connect(_on_skip_pressed)
	_panel.add_child(skip_btn)

func _on_confirm_pressed() -> void:
	choice_made.emit(true)
	queue_free()

func _on_skip_pressed() -> void:
	choice_made.emit(false)
	queue_free()
