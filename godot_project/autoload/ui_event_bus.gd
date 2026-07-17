extends Node

## UIEventBus - UI事件总线
## 负责UI打开/关闭/切换/通知等事件的发布与订阅

# ============ 屏幕管理 ============
signal screen_opened(screen_id: int)
signal screen_closed(screen_id: int)

# ============ 通知与可见性 ============
signal show_notification(message: String)
signal ui_visibility_changed(visible: bool)

func _ready() -> void:
	pass
