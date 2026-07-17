extends Node

## UIManager - UI管理器
## 管理界面栈、屏幕切换、UI元素显隐
## 遵循可隐藏框架设计：按 H 键可隐藏所有 UI 元素

enum UIScreen {
	NONE,
	MAIN_MENU,
	GAME_HUD,
	REASONING_WALL,
	TIMELINE,
	INVENTORY,
	NOTEBOOK,
	SETTINGS,
	REGISTER,
	DIALOGUE,
	MAP,
	CASE_SELECT
}

var screen_stack: Array = []
var is_ui_visible: bool = true

func _ready() -> void:
	pass

func open_screen(screen: UIScreen) -> void:
	if screen_stack.has(screen):
		return
	screen_stack.append(screen)
	UIEventBus.emit_signal("screen_opened", screen)

func close_screen(screen: UIScreen) -> void:
	screen_stack.erase(screen)
	UIEventBus.emit_signal("screen_closed", screen)

func close_top_screen() -> void:
	if screen_stack.is_empty():
		return
	var top = screen_stack.pop_back()
	UIEventBus.emit_signal("screen_closed", top)

func is_screen_open(screen: UIScreen) -> bool:
	return screen_stack.has(screen)

func toggle_ui() -> void:
	is_ui_visible = not is_ui_visible
	UIEventBus.emit_signal("ui_visibility_changed", is_ui_visible)

func show_notification(message: String, duration: float = 3.0) -> void:
	UIEventBus.emit_signal("show_notification", message, duration)
