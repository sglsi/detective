extends Node

## UIEventBus - UI事件总线
## 负责UI打开/关闭/切换/通知等事件的发布与订阅

# ============ 屏幕管理 ============
signal screen_opened(screen_id: int)
signal screen_closed(screen_id: int)

# ============ 通知与可见性 ============
signal show_notification(message: String)
signal ui_visibility_changed(visible: bool)
signal tool_selected(tool_id: String)
signal tool_used(tool_id: String, target_id: String)
signal tool_discovery_triggered(tool_id: String, target_id: String, result: String)

# 难度动态提示概率调整通知（设计 08 §3.5 on_progress_check 发出）
signal hint_probability_adjusted(new_prob: float, reason: StringName)

func _ready() -> void:
	pass
