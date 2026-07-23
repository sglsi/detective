extends Control

## DebugOverlay — 轻量诊断浮层（autoload 单例）
## 仅监听 UIEventBus.show_notification 并把每条通知文本追加到底部左侧小字区域。
## 作用：当主通知系统（NotificationSystem）因任何原因不显示时，这里仍能提供独立的
## 可见反馈，便于在浏览器中直接看到“按钮是否真的触发了信号 / 网络层返回了什么”。
## 不影响游戏输入（mouse_filter=IGNORE）。

var _label: Label
var _lines: PackedStringArray = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 5000

	_label = Label.new()
	_label.name = "DebugLog"
	_label.position = Vector2(12, 1080 - 220)
	_label.size = Vector2(900, 200)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7, 0.9))
	add_child(_label)

	# 顶栏一行固定说明，确认本浮层已加载
	dbg("[DebugOverlay] 已加载 — 所有通知将在此显示")

	if UIEventBus:
		UIEventBus.connect("show_notification", _on_note)

func _on_note(message: String, _duration: float = 3.0) -> void:
	dbg("NOTE: " + message)

func dbg(msg: String) -> void:
	_lines.append(msg)
	if _lines.size() > 10:
		_lines = _lines.slice(_lines.size() - 10)
	_label.text = "\n".join(_lines)
