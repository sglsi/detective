extends CanvasLayer

## SceneLoader -- 全局无缝过场（黑屏淡入 → 切换场景 → 黑屏淡出）
## 常驻 autoload，跨场景切换不被释放，因此能盖住整次换场。
## 用法：SceneLoader.transition_to("res://scenes/scene2.tscn")

const FADE_TIME := 0.35

var _panel: ColorRect
var _busy := false

func _ready() -> void:
	# 高于 ToolBar(128) 与一切场景 UI，确保过场时盖在最上层
	layer = 1000
	_panel = ColorRect.new()
	_panel.color = Color(0, 0, 0, 0)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP  # 过场期间吞掉点击
	_panel.visible = false
	add_child(_panel)

## 淡入黑屏 → 切换场景 → 淡出黑屏。可安全重复调用（_busy 防重入）。
func transition_to(scene_path: String, fade: float = FADE_TIME) -> void:
	if _busy:
		return
	_busy = true
	_panel.visible = true
	_panel.color.a = 0.0

	# 1) 淡入黑屏（当前场景仍可见，由玩家刚触发的推进动作驱动）
	await _fade(0.0, 1.0, fade)

	# 2) 切换场景（旧场景释放、新场景从磁盘加载并 _ready）
	var target := scene_path
	if not ResourceLoader.exists(target):
		target = "res://scenes/main_menu.tscn"
	get_tree().change_scene_to_file(target)

	# 3) 等新场景完成首帧布局，避免淡出瞬间露出未就绪画面
	await get_tree().process_frame
	await get_tree().process_frame

	# 4) 淡出黑屏，露出新场景
	await _fade(1.0, 0.0, fade)
	_panel.visible = false
	_busy = false

func _fade(from: float, to: float, dur: float) -> void:
	_panel.color.a = from
	var t := create_tween()
	t.tween_property(_panel, "color:a", to, dur)
	await t.finished
