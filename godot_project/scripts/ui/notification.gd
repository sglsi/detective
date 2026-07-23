extends Control

## NotificationSystem — 全局通知系统（autoload 单例，autoload 名即 NotificationSystem，
## 注意不要在此声明 class_name NotificationSystem，否则会与同名 autoload 单例冲突导致解析错误）
## 常驻于视口顶部的居中条幅，接收 UIEventBus "show_notification" 信号并淡出显示。
##
## 修复：原先本脚本依赖场景内 $NotificationLabel 子节点，但 NotificationSystem 从未被
## 任何 autoload 或 .tscn 实例化，导致 UIManager.show_notification() 发出的信号无人接收，
## 所有「只发通知」的按钮（观察/对话/工具/知识库/笔记/保存）点击后毫无可见反馈，
## 表现为「点击按钮无反应」。现改为 autoload 常驻层，在 _ready 中动态创建 UI。

var _label: Label
var _tween: Tween

func _ready() -> void:
	# 常驻通知层：全屏覆盖、鼠标穿透（不拦截交互）、置于最上层
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 4096
	process_mode = Node.PROCESS_MODE_ALWAYS

	_label = Label.new()
	_label.name = "NotificationLabel"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_label.offset_top = 18
	_label.offset_bottom = 72
	_label.add_theme_font_size_override("font_size", 24)
	_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.82, 1.0))
	_label.modulate.a = 0
	add_child(_label)

	if UIEventBus:
		UIEventBus.connect("show_notification", show_notification)

func show_notification(message: String, duration: float = 2.5) -> void:
	if not is_instance_valid(_label):
		return
	_label.text = message
	_label.modulate.a = 1

	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(duration)
	_tween.tween_property(_label, "modulate:a", 0.0, 0.5)
