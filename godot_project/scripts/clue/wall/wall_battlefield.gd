extends RefCounted
class_name WallBattlefield

## 推理墙 · 推理战场层（拆自 reasoning_wall.gd，Request C 后架构分层）
##
## 职责：「推理战场」面板——活跃假设卡（未定→采纳→排除 循环）、矛盾标记卡
## （已识别/未识别）、命中状态条（假设命中 x/y · 矛盾识别 x/y，供三星洞察之星读取）。
## 读取/回写 owner（ReasoningWall）状态；常量/枚举归墙经 owner. 引用。

var owner: ReasoningWall

func _refresh_battlefield() -> void:
	if not owner._battlefield_box: return
	for c in owner._battlefield_box.get_children(): c.queue_free()
	owner._battle_hypo_btns.clear()
	owner._battle_contra_btns.clear()

	var hypos: Array = owner._battle.get("hypotheses", [])
	var contras: Array = owner._battle.get("contradictions", [])

	if hypos.is_empty() and contras.is_empty():
		var empty := Label.new()
		empty.text = "（本推理链未配置推理战场）"
		empty.add_theme_font_size_override("font_size", 14)
		empty.add_theme_color_override("font_color", Color(0.55, 0.50, 0.40))
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty.custom_minimum_size = Vector2(160, 40)
		owner._battlefield_box.add_child(empty)
		return

	if not hypos.is_empty():
		var hl := Label.new()
		hl.text = "活跃假设（点击标记：未定→采纳→排除）"
		hl.add_theme_font_size_override("font_size", 14)
		hl.add_theme_color_override("font_color", Color(0.70, 0.85, 0.95))
		hl.custom_minimum_size = Vector2(160, 22)
		owner._battlefield_box.add_child(hl)
		for h in hypos:
			owner._battlefield_box.add_child(_make_battle_hypo_card(h))

	if not contras.is_empty():
		var cl := Label.new()
		cl.text = "矛盾标记（点击标记是否已识别）"
		cl.add_theme_font_size_override("font_size", 14)
		cl.add_theme_color_override("font_color", Color(0.95, 0.80, 0.70))
		cl.custom_minimum_size = Vector2(160, 22)
		owner._battlefield_box.add_child(cl)
		for c in contras:
			owner._battlefield_box.add_child(_make_battle_contra_card(c))

	var status := Label.new()
	status.text = _battle_status_text()
	status.add_theme_font_size_override("font_size", 14)
	status.add_theme_color_override("font_color", owner.COL_GREEN)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.custom_minimum_size = Vector2(160, 40)
	owner._battlefield_box.add_child(status)


func _make_battle_hypo_card(h: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(180, 96)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.10, 0.08, 0.95)
	style.border_color = Color(0.45, 0.35, 0.15, 0.5)
	style.border_width_left = 1; style.border_width_right = 1
	style.border_width_top = 1; style.border_width_bottom = 1
	style.set_corner_radius_all(6)
	card.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)

	# 纵向布局：上方为假设文字，下方为整行铺满卡片宽度的状态按钮（点击区=整个按钮区域）
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	margin.add_child(vb)

	var id: String = h.get("id", "?")
	var text: String = h.get("text", "")
	var lbl := Label.new()
	lbl.text = id + "  " + text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", owner.COL_GOLD_LIGHT)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.custom_minimum_size = Vector2(0, 32)
	vb.add_child(lbl)

	var btn := Button.new()
	var hst: int = owner._battle_hypo_states.get(id, 0)
	btn.text = ["未定", "采纳✓", "排除✗"][hst]
	btn.add_theme_font_size_override("font_size", 22)
	btn.custom_minimum_size = Vector2(93, 40)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(_on_battle_hypo_pressed.bind(id))
	_style_battle_btn(btn, hst)
	vb.add_child(btn)
	owner._battle_hypo_btns[id] = btn

	return card


func _make_battle_contra_card(c: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(180, 84)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.10, 0.08, 0.95)
	style.border_color = Color(0.45, 0.35, 0.15, 0.5)
	style.border_width_left = 1; style.border_width_right = 1
	style.border_width_top = 1; style.border_width_bottom = 1
	style.set_corner_radius_all(6)
	card.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	margin.add_child(vb)

	var id: String = c.get("id", "?")
	var text: String = c.get("text", "")
	var lbl := Label.new()
	lbl.text = id + "  " + text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", owner.COL_GOLD_LIGHT)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.custom_minimum_size = Vector2(0, 32)
	vb.add_child(lbl)

	var btn := Button.new()
	var cst: bool = owner._battle_contra_states.get(id, false)
	btn.text = "已识别" if cst else "未识别"
	btn.add_theme_font_size_override("font_size", 22)
	btn.custom_minimum_size = Vector2(93, 40)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(_on_battle_contra_pressed.bind(id))
	_style_battle_btn(btn, 1 if cst else 0)
	vb.add_child(btn)
	owner._battle_contra_btns[id] = btn

	return card


func _on_battle_hypo_pressed(id: String) -> void:
	var st: int = owner._battle_hypo_states.get(id, 0)
	st = (st + 1) % 3
	owner._battle_hypo_states[id] = st
	var btn = owner._battle_hypo_btns.get(id)
	if btn:
		btn.text = ["未定", "采纳✓", "排除✗"][st]
		_style_battle_btn(btn, st)
	_refresh_battlefield_status_only()
	owner._state_ctl._persist_state()


func _on_battle_contra_pressed(id: String) -> void:
	var st: bool = not owner._battle_contra_states.get(id, false)
	owner._battle_contra_states[id] = st
	var btn = owner._battle_contra_btns.get(id)
	if btn:
		btn.text = "已识别" if st else "未识别"
		_style_battle_btn(btn, 1 if st else 0)
	_refresh_battlefield_status_only()
	owner._state_ctl._persist_state()


func _style_battle_btn(btn: Button, st: int) -> void:
	var sn := StyleBoxFlat.new()
	match st:
		1:
			sn.bg_color = Color(0.08, 0.28, 0.08, 0.95)
			sn.border_color = Color(0.2, 0.8, 0.2)
		2:
			sn.bg_color = Color(0.32, 0.08, 0.08, 0.95)
			sn.border_color = Color(0.85, 0.35, 0.25)
		_:
			sn.bg_color = Color(0.18, 0.14, 0.09, 0.95)
			sn.border_color = Color(0.55, 0.42, 0.20)
	sn.border_width_left = 1; sn.border_width_right = 1
	sn.border_width_top = 1; sn.border_width_bottom = 1
	sn.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", sn)


func _battle_status_text() -> String:
	var hypos: Array = owner._battle.get("hypotheses", [])
	var contras: Array = owner._battle.get("contradictions", [])
	var h_ok := 0; var h_tot := hypos.size()
	for h in hypos:
		var id: String = h.get("id", "")
		var st: int = owner._battle_hypo_states.get(id, 0)
		var correct: bool = h.get("correct", false)
		if (st == 1 and correct) or (st == 2 and not correct):
			h_ok += 1
	var c_ok := 0; var c_tot := contras.size()
	for c in contras:
		var cid: String = c.get("id", "")
		if owner._battle_contra_states.get(cid, false):
			c_ok += 1
	return "推理战场：假设命中 %d/%d · 矛盾识别 %d/%d" % [h_ok, h_tot, c_ok, c_tot]


func _refresh_battlefield_status_only() -> void:
	if not owner._battlefield_box: return
	for c in owner._battlefield_box.get_children():
		if c is Label and c.text.begins_with("推理战场："):
			c.text = _battle_status_text()
			return
