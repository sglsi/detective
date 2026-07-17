extends Control
class_name NotificationSystem

## NotificationSystem - 通知系统
## 屏幕上方悬浮通知，自动淡出

@onready var label: Label = $NotificationLabel
var tween: Tween

func _ready() -> void:
	label.modulate.a = 0
	UIEventBus.connect("show_notification", show_notification)

func show_notification(message: String, duration: float = 2.5) -> void:
	label.text = message
	label.modulate.a = 1
	
	if tween:
		tween.kill()
	
	tween = create_tween()
	tween.tween_interval(duration)
	tween.tween_property(label, "modulate:a", 0, 0.5)
