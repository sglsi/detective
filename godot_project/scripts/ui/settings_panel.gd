extends Control
class_name SettingsPanel

## SettingsPanel - 最小可用设置界面（P5-6 体验收尾）
## 绑定 SettingsManager 的真实设置键（music_volume / sfx_volume / fullscreen），
## 纯代码构建（不依赖 .tscn），便于无头环境实例化与冒烟测试。
## 关闭时发 closed 信号，由调用方 queue_free。

signal closed

var _bg: Panel
var _title: Label
var _music_slider: HSlider
var _sfx_slider: HSlider
var _full_toggle: CheckButton
var _close_btn: Button


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# 半透明遮罩，聚焦设置面板
	_bg = Panel.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_bg.modulate = Color(0, 0, 0, 0.55)
	add_child(_bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.custom_minimum_size = Vector2(420, 340)
	vbox.add_child(_spacer(20))
	add_child(vbox)

	_title = Label.new()
	_title.text = "设置"
	vbox.add_child(_title)

	# 音乐音量（初始值在读 SettingsManager 后、连接信号前设置，避免初始化即回写）
	_music_slider = HSlider.new()
	_music_slider.min_value = 0.0
	_music_slider.max_value = 1.0
	_music_slider.step = 0.01  # Range 默认 step=1.0 会把 0.8 吸附到 1.0
	_music_slider.value = float(SettingsManager.get_setting("music_volume"))
	_music_slider.value_changed.connect(_on_music_changed)
	vbox.add_child(_labeled("音乐音量", _music_slider))

	# 音效音量
	_sfx_slider = HSlider.new()
	_sfx_slider.min_value = 0.0
	_sfx_slider.max_value = 1.0
	_sfx_slider.step = 0.01
	_sfx_slider.value = float(SettingsManager.get_setting("sfx_volume"))
	_sfx_slider.value_changed.connect(_on_sfx_changed)
	vbox.add_child(_labeled("音效音量", _sfx_slider))

	# 全屏开关
	_full_toggle = CheckButton.new()
	_full_toggle.text = "全屏"
	_full_toggle.button_pressed = bool(SettingsManager.get_setting("fullscreen"))
	_full_toggle.toggled.connect(_on_full_toggled)
	vbox.add_child(_full_toggle)

	vbox.add_child(_spacer(16))
	_close_btn = Button.new()
	_close_btn.text = "关闭"
	_close_btn.pressed.connect(_on_close)
	vbox.add_child(_close_btn)


## 标签 + 控件的纵向组合
func _labeled(text: String, control: Control) -> VBoxContainer:
	var box := VBoxContainer.new()
	var lbl := Label.new()
	lbl.text = text
	box.add_child(lbl)
	box.add_child(control)
	return box


func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _on_music_changed(v: float) -> void:
	SettingsManager.set_setting("music_volume", v)


func _on_sfx_changed(v: float) -> void:
	SettingsManager.set_setting("sfx_volume", v)


func _on_full_toggled(on: bool) -> void:
	SettingsManager.set_setting("fullscreen", on)


func _on_close() -> void:
	closed.emit()
	queue_free()
