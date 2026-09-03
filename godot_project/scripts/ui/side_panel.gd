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
		{"id": "export_save", "text": "📤 导出", "hint": "导出最新存档 JSON（诊断用）"},
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
			var sc = get_tree().current_scene
			if sc and sc.has_method("_do_save"):
				sc._do_save()
			else:
				SaveManager.save_game()
				UIManager.show_notification("游戏已保存")
		"load":
			var sc = get_tree().current_scene
			if sc and sc.has_method("_do_load"):
				sc._do_load()
			else:
				var loaded = await SaveSystem.load_game()
				if loaded:
					UIManager.show_notification("存档已加载")
				else:
					UIManager.show_notification("没有可用的存档")
		"export_save":
			_export_latest_save()

## 导出最新存档槽位的 JSON：弹窗展示 + Web 环境自动触发下载。
## 白名单只带诊断相关键（scene_state 内含场景一 wall_state_watson/messenger），
## 避免整包过大导致 TextEdit 卡顿与剪贴板截断。
func _export_latest_save() -> void:
	var slots: Array = SaveManager.get_slot_list_sorted()
	if slots.is_empty():
		UIManager.show_notification("没有可用的存档")
		return
	var slot := int(slots[0].get("slot", 0))
	var f := FileAccess.open(SaveManager.slot_path(slot), FileAccess.READ)
	if f == null:
		UIManager.show_notification("存档文件读取失败")
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed == null or not (parsed is Dictionary):
		UIManager.show_notification("存档解析失败")
		return
	var data: Dictionary = parsed
	var out := {
		"slot": slot,
		"save_version": data.get("save_version", 0),
		"timestamp": data.get("timestamp", 0),
		"case_id": data.get("case_id", ""),
		"scene_id": data.get("scene_id", ""),
		"difficulty": data.get("difficulty", ""),
		"observation_score": data.get("observation_score", 0),
		"reasoning_score": data.get("reasoning_score", 0),
		"insight_score": data.get("insight_score", 0),
		"star_chains": data.get("star_chains", {}),
		"scene_state": data.get("scene_state", {}),
		"collected_clues": data.get("collected_clues", []),
		"case_wall_state": data.get("case_wall_state", {}),
	}
	var txt := JSON.stringify(out, "\t")
	_show_export_dialog(slot, txt)

func _show_export_dialog(slot: int, txt: String) -> void:
	var dlg := AcceptDialog.new()
	dlg.title = "存档导出 · 最新槽位 %d" % slot
	dlg.ok_button_text = "关闭"
	dlg.size = Vector2(900, 560)
	var te := TextEdit.new()
	te.text = txt
	te.editable = true
	te.wrap_mode = TextEdit.LINE_WRAPPING_NONE
	te.custom_minimum_size = Vector2(860, 500)
	dlg.add_child(te)
	add_child(dlg)
	dlg.popup_centered()
	if OS.has_feature("web"):
		var b64 := Marshalls.utf8_to_base64(txt)
		JavaScriptBridge.eval("var a=document.createElement('a');a.href='data:application/json;base64," + b64 + "';a.download='save_export_slot" + str(slot) + ".json';document.body.appendChild(a);a.click();setTimeout(function(){a.remove();},100);")
