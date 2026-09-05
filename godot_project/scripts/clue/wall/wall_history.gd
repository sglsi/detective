extends RefCounted
class_name WallHistory

## 推理墙 · 调查历史面板层（拆自 reasoning_wall.gd，Request C 后架构分层）
##
## 职责：「调查历史记录」信息面板——当前推理状态/已收集线索清单/结论里程碑展示，
## 可拖拽窗口（标题栏）+ 底部关闭。读取/回写 owner（ReasoningWall）状态。

var owner: ReasoningWall

func _on_investigate_pressed() -> void:
	if owner._verifying: return
	_show_history_panel()


func _show_history_panel() -> void:
	if owner._history_panel and is_instance_valid(owner._history_panel):
		owner._history_panel.queue_free()
		owner._history_panel = null
		return

	owner._history_panel = Control.new()
	owner._history_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	owner._history_panel.z_index = 10
	owner._history_panel.name = "HistoryPanel"
	owner.add_child(owner._history_panel)

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.55)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	owner._history_panel.add_child(overlay)

	# 可自由拖动的窗口本体
	var win := PanelContainer.new()
	win.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	win.custom_minimum_size = Vector2(720, 560)
	win.size = Vector2(720, 560)
	var wstyle := StyleBoxFlat.new()
	wstyle.bg_color = Color(0.10, 0.08, 0.06, 0.98)
	wstyle.border_color = Color(0.65, 0.55, 0.30)
	wstyle.border_width_left = 2; wstyle.border_width_right = 2
	wstyle.border_width_top = 2; wstyle.border_width_bottom = 2
	wstyle.set_corner_radius_all(8)
	win.add_theme_stylebox_override("panel", wstyle)
	overlay.add_child(win)
	owner._hist_win = win
	win.position = (owner.get_viewport_rect().size - win.size) / 2

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	win.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	margin.add_child(vb)

	# 标题栏（拖拽手柄）
	var title_bar := HBoxContainer.new()
	title_bar.custom_minimum_size = Vector2(0, 42)
	title_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	title_bar.add_theme_constant_override("separation", 10)
	var tstyle := StyleBoxFlat.new()
	tstyle.bg_color = Color(0.18, 0.14, 0.08, 1.0)
	tstyle.set_corner_radius_all(6)
	title_bar.add_theme_stylebox_override("panel", tstyle)
	title_bar.gui_input.connect(_on_hist_title_gui)
	vb.add_child(title_bar)

	var title := Label.new()
	title.text = "📋 调查历史记录"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", owner.COL_GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_bar.add_child(title)

	var hclose := Button.new()
	hclose.text = "✕"
	hclose.add_theme_font_size_override("font_size", 20)
	hclose.add_theme_color_override("font_color", Color(0.85, 0.55, 0.55))
	hclose.custom_minimum_size = Vector2(40, 32)
	var hcstyle := StyleBoxFlat.new()
	hcstyle.bg_color = Color(0.30, 0.18, 0.18, 0.95)
	hcstyle.border_color = Color(0.7, 0.4, 0.4)
	hcstyle.set_corner_radius_all(4)
	hclose.add_theme_stylebox_override("normal", hcstyle)
	hclose.pressed.connect(_close_history_panel)
	title_bar.add_child(hclose)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	scroll.add_child(content)

	# 1. 当前推理状态
	var state_sec := _history_section(content, "当前推理状态")
	var v := owner.get_verdict()
	var verdict_text: String = ["矛盾冲突", "证据不足", "倾向成立", "已获证实"][v]
	var state_lbl := Label.new()
	state_lbl.text = "核心问题：%s\n当前判定：%s\n已关联线索：%d 条" % [owner._hypothesis.get("title", ""), verdict_text, owner._associated]
	state_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	state_lbl.add_theme_font_size_override("font_size", 15)
	state_lbl.add_theme_color_override("font_color", owner.COL_GOLD_LIGHT)
	state_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	state_lbl.custom_minimum_size = Vector2(200, 60)
	state_sec.add_child(state_lbl)

	# 2. 已收集线索
	var clue_sec := _history_section(content, "已收集线索 (%d)" % owner._clues.size())
	if owner._clues.is_empty():
		var empty := Label.new()
		empty.text = "（暂无已收集线索）"
		empty.add_theme_color_override("font_color", Color(0.55, 0.50, 0.40))
		clue_sec.add_child(empty)
	else:
		for c in owner._clues:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			clue_sec.add_child(row)

			var mark := Label.new()
			var is_assoc: bool = c.get("associated", false)
			var correct: bool = c.get("correct", true)
			mark.text = "✓" if is_assoc else "○"
			mark.add_theme_color_override("font_color", owner.COL_GREEN if is_assoc else Color(0.55, 0.50, 0.40))
			mark.custom_minimum_size = Vector2(24, 24)
			row.add_child(mark)

			var info := VBoxContainer.new()
			info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(info)

			var name_lbl := Label.new()
			name_lbl.text = c.get("name", c.get("id", ""))
			name_lbl.add_theme_font_size_override("font_size", 15)
			name_lbl.add_theme_color_override("font_color", owner.COL_GOLD_LIGHT)
			name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			info.add_child(name_lbl)

			var desc_lbl := Label.new()
			desc_lbl.text = c.get("desc", "")
			desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			desc_lbl.add_theme_font_size_override("font_size", 13)
			desc_lbl.add_theme_color_override("font_color", Color(0.60, 0.55, 0.45))
			desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			desc_lbl.custom_minimum_size = Vector2(160, 20)
			info.add_child(desc_lbl)

			if owner._difficulty != ReasoningWall.Diff.HARD:
				var tag := Label.new()
				tag.text = "已关联" if is_assoc else ("正确" if correct else "干扰")
				tag.add_theme_color_override("font_color", owner.COL_GREEN if is_assoc else (owner.COL_GREEN if correct else owner.COL_RED))
				tag.custom_minimum_size = Vector2(60, 24)
				row.add_child(tag)

	# 3. 结论里程碑
	var ms_sec := _history_section(content, "结论里程碑")
	var ms_lbl := Label.new()
	var ms_text := ""
	for m in owner._milestones:
		ms_text += "■ " if m["lit"] else "□ "
		ms_text += m["text"] + "\n"
	ms_lbl.text = ms_text.strip_edges() if ms_text != "" else "（暂无里程碑）"
	ms_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ms_lbl.add_theme_font_size_override("font_size", 14)
	ms_lbl.add_theme_color_override("font_color", owner.COL_GOLD_LIGHT)
	ms_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ms_lbl.custom_minimum_size = Vector2(200, 40)
	ms_sec.add_child(ms_lbl)

	# 底部按钮
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.custom_minimum_size = Vector2(200, 48)
	vb.add_child(btn_row)

	var close_btn := Button.new()
	close_btn.text = "关闭"
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.add_theme_color_override("font_color", owner.COL_GOLD_LIGHT)
	close_btn.custom_minimum_size = Vector2(120, 44)
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(0.22, 0.18, 0.12, 0.95)
	cs.border_color = Color(0.55, 0.45, 0.25)
	cs.border_width_left = 2; cs.border_width_right = 2
	cs.border_width_top = 2; cs.border_width_bottom = 2
	cs.set_corner_radius_all(4)
	close_btn.add_theme_stylebox_override("normal", cs)
	close_btn.pressed.connect(_close_history_panel)
	btn_row.add_child(close_btn)


func _history_section(parent: VBoxContainer, title: String) -> VBoxContainer:
	var sec := VBoxContainer.new()
	sec.add_theme_constant_override("separation", 6)
	sec.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(sec)

	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 17)
	lbl.add_theme_color_override("font_color", owner.COL_GOLD)
	lbl.custom_minimum_size = Vector2(200, 26)
	sec.add_child(lbl)

	var line := ColorRect.new()
	line.color = Color(0.45, 0.35, 0.15, 0.5)
	line.custom_minimum_size = Vector2(200, 2)
	sec.add_child(line)

	return sec


func _close_history_panel() -> void:
	owner._hist_drag = false
	owner._hist_win = null
	if owner._history_panel and is_instance_valid(owner._history_panel):
		owner._history_panel.queue_free()
	owner._history_panel = null


# 标题栏拖拽
func _on_hist_title_gui(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		owner._hist_drag = true
		if owner._hist_win and is_instance_valid(owner._hist_win):
			owner._hist_drag_offset = owner.get_viewport().get_mouse_position() - owner._hist_win.global_position
