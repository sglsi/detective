extends Control
class_name SidePanel

## SidePanel - 侧栏导航面板
## 提供场景内快捷操作按钮

var buttons: Dictionary = {}

func _ready() -> void:
	_create_buttons()

func _create_buttons() -> void:
	var btn_defs = [
		{"id": "observe", "text": "🔍 观察", "hint": "观察模式"},
		{"id": "talk", "text": "💬 对话", "hint": "与人物交谈"},
		{"id": "examine", "text": "🔬 检查", "hint": "使用工具检查"},
		{"id": "think", "text": "🧠 推理", "hint": "打开推理墙"},
		{"id": "journal", "text": "📓 笔记", "hint": "侦探笔记"},
		{"id": "save", "text": "💾 保存", "hint": "保存进度"},
		{"id": "load", "text": "📂 读取", "hint": "读取存档"},
	]
	
	for i in btn_defs.size():
		var def = btn_defs[i]
		var btn = Button.new()
		btn.text = def["text"]
		btn.tooltip_text = def["hint"]
		btn.position = Vector2(5, 5 + i * 52)
		btn.size = Vector2(110, 46)
		btn.pressed.connect(_on_btn_pressed.bind(def["id"]))
		
		# 样式
		var normal_style = StyleBoxFlat.new()
		normal_style.bg_color = Color(0.15, 0.11, 0.07, 0.9)
		normal_style.border_width_left = 1
		normal_style.border_width_right = 1
		normal_style.border_width_top = 1
		normal_style.border_width_bottom = 1
		normal_style.border_color = Color(0.5, 0.35, 0.2)
		normal_style.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", normal_style)
		
		var hover_style = StyleBoxFlat.new()
		hover_style.bg_color = Color(0.22, 0.16, 0.10, 0.95)
		hover_style.border_width_left = 1
		hover_style.border_width_right = 1
		hover_style.border_width_top = 1
		hover_style.border_width_bottom = 1
		hover_style.border_color = Color(0.8, 0.65, 0.25)
		hover_style.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("hover", hover_style)
		
		btn.add_theme_font_size_override("font_size", 14)
		btn.add_theme_color_override("font_color", Color(0.85, 0.75, 0.45))
		
		add_child(btn)
		buttons[def["id"]] = btn

func _on_btn_pressed(action: String) -> void:
	match action:
		"observe":
			UIManager.show_notification("观察模式：点击场景中的可交互区域")
		"talk":
			UIManager.show_notification("对话模式：点击人物进行交谈")
		"examine":
			SceneEventBus.emit_signal("tool_requested", "toolbar")
		"think":
			if UIManager.is_screen_open(UIManager.UIScreen.REASONING_WALL):
				UIManager.close_screen(UIManager.UIScreen.REASONING_WALL)
			else:
				UIManager.open_screen(UIManager.UIScreen.REASONING_WALL)
		"journal":
			UIManager.show_notification("侦探笔记已打开")
		"save":
			SaveManager.save_game()
			UIManager.show_notification("游戏已保存")
		"load":
			var loaded = await SaveManager.load_game()
			if loaded:
				UIManager.show_notification("存档已加载")
			else:
				UIManager.show_notification("没有可用的存档")
