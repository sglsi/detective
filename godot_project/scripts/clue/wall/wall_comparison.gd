extends RefCounted
class_name WallComparison

## 推理墙 · 线索对比台层（拆自 reasoning_wall.gd，Request C 后架构分层）
##
## 职责：「线索对比台」面板——两槽放入线索比对、矛盾检测（relation_tags 的 C* 交集）、
## 疑点册（doubt_book，去重追加）、比对结果文案。读取/回写 owner（ReasoningWall）状态。

var owner: ReasoningWall

func _build_comparison_desk() -> Control:
	var desk := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.09, 0.11, 0.09, 0.98)
	s.border_color = Color(0.55, 0.65, 0.45, 0.7)
	s.border_width_left = 1; s.border_width_right = 1
	s.border_width_top = 1; s.border_width_bottom = 1
	s.set_corner_radius_all(6)
	desk.add_theme_stylebox_override("panel", s)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	vb.add_theme_constant_override("margin_left", 10)
	vb.add_theme_constant_override("margin_top", 6)
	vb.add_theme_constant_override("margin_right", 10)
	vb.add_theme_constant_override("margin_bottom", 6)
	desk.add_child(vb)

	var hdr := HBoxContainer.new()
	var title := Label.new()
	title.text = "线索对比台（放入两条线索比对，发现矛盾即入疑点册）"
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", owner.COL_GOLD_LIGHT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(title)
	var collapse_btn := Button.new()
	collapse_btn.text = "▾"
	collapse_btn.add_theme_font_size_override("font_size", 14)
	collapse_btn.pressed.connect(_on_desk_collapse)
	hdr.add_child(collapse_btn)
	vb.add_child(hdr)

	owner._desk_body = VBoxContainer.new()
	owner._desk_body.add_theme_constant_override("separation", 6)
	vb.add_child(owner._desk_body)

	var rowA := HBoxContainer.new()
	owner._slot_a_lbl = Label.new()
	owner._slot_a_lbl.text = "槽A：空"
	owner._slot_a_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	owner._slot_a_lbl.add_theme_font_size_override("font_size", 14)
	owner._slot_a_lbl.add_theme_color_override("font_color", Color(0.80, 0.78, 0.65))
	rowA.add_child(owner._slot_a_lbl)
	owner._desk_body.add_child(rowA)

	var rowB := HBoxContainer.new()
	owner._slot_b_lbl = Label.new()
	owner._slot_b_lbl.text = "槽B：空"
	owner._slot_b_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	owner._slot_b_lbl.add_theme_font_size_override("font_size", 14)
	owner._slot_b_lbl.add_theme_color_override("font_color", Color(0.80, 0.78, 0.65))
	rowB.add_child(owner._slot_b_lbl)
	owner._desk_body.add_child(rowB)

	var cmp_row := HBoxContainer.new()
	var cmp_btn := Button.new()
	cmp_btn.text = "比对"
	cmp_btn.add_theme_font_size_override("font_size", 15)
	cmp_btn.add_theme_color_override("font_color", owner.COL_GOLD)
	cmp_btn.pressed.connect(_on_compare_pressed)
	cmp_row.add_child(cmp_btn)
	var clr_btn := Button.new()
	clr_btn.text = "清空"
	clr_btn.add_theme_font_size_override("font_size", 13)
	clr_btn.pressed.connect(func(): owner._compare_slots = []; _refresh_desk())
	cmp_row.add_child(clr_btn)
	owner._desk_body.add_child(cmp_row)

	owner._result_lbl = Label.new()
	owner._result_lbl.text = "（把两条线索放入对比台，点击「比对」）"
	owner._result_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	owner._result_lbl.add_theme_font_size_override("font_size", 14)
	owner._result_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.6))
	owner._desk_body.add_child(owner._result_lbl)

	owner._notebook_vb = VBoxContainer.new()
	owner._notebook_vb.add_theme_constant_override("separation", 3)
	owner._desk_body.add_child(owner._notebook_vb)

	return desk


func _on_desk_collapse() -> void:
	if not owner._desk_body: return
	owner._desk_body.visible = not owner._desk_body.visible


func _load_comparison(cid: String) -> void:
	var clue: Dictionary = owner._clue_ctl._find_clue(cid)
	if clue.is_empty(): return
	if owner._compare_slots.size() < 2:
		for i in range(owner._compare_slots.size()):
			if owner._compare_slots[i].get("id", "") == cid:
				owner._compare_slots.remove_at(i)
				break
		owner._compare_slots.append(clue)
	else:
		owner._compare_slots.remove_at(0)
		owner._compare_slots.append(clue)
	_refresh_desk()


func _refresh_desk() -> void:
	if not owner._slot_a_lbl or not owner._slot_b_lbl: return
	var a: String = "空"
	var b: String = "空"
	if owner._compare_slots.size() >= 1: a = owner._compare_slots[0].get("name", owner._compare_slots[0].get("id", "?"))
	if owner._compare_slots.size() >= 2: b = owner._compare_slots[1].get("name", owner._compare_slots[1].get("id", "?"))
	owner._slot_a_lbl.text = "槽A：" + a
	owner._slot_b_lbl.text = "槽B：" + b
	if owner._notebook_vb:
		for c in owner._notebook_vb.get_children(): c.queue_free()
		if owner._doubt_book.is_empty():
			var empty := Label.new()
			empty.text = "（疑点册为空）"
			empty.add_theme_font_size_override("font_size", 12)
			empty.add_theme_color_override("font_color", Color(0.5, 0.48, 0.40))
			owner._notebook_vb.add_child(empty)
		else:
			for d in owner._doubt_book:
				var lab := Label.new()
				lab.text = "• %s  （%s ↔ %s）" % [_contradiction_title(d.get("cid", "")), owner._clue_ctl._clue_name(d.get("a", "")), owner._clue_ctl._clue_name(d.get("b", ""))]
				lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				lab.add_theme_font_size_override("font_size", 13)
				lab.add_theme_color_override("font_color", Color(0.9, 0.7, 0.5))
				owner._notebook_vb.add_child(lab)


func _contradiction_title(cid: String) -> String:
	for c in owner._battle.get("contradictions", []):
		if c.get("id", "") == cid: return c.get("text", cid)
	return cid


func _detect_contradiction(a: Dictionary, b: Dictionary) -> Array:
	var ta: Array = a.get("relation_tags", [])
	var tb: Array = b.get("relation_tags", [])
	var ca: Array = []
	var cb: Array = []
	for t in ta:
		if t.begins_with("C"): ca.append(t)
	for t in tb:
		if t.begins_with("C"): cb.append(t)
	var out := []
	for t in ca:
		if cb.has(t) and not out.has(t):
			out.append(t)
	return out


func _on_compare_pressed() -> void:
	if owner._compare_slots.size() < 2:
		if owner._result_lbl: owner._result_lbl.text = "请先放入两条线索再比对"
		return
	var a: Dictionary = owner._compare_slots[0]
	var b: Dictionary = owner._compare_slots[1]
	var hits: Array = _detect_contradiction(a, b)
	if hits.is_empty():
		if owner._result_lbl: owner._result_lbl.text = "暂未发现冲突（无矛盾，无任何惩罚）"
		return
	var names := []
	for cid in hits:
		names.append(_contradiction_title(cid))
	if owner._result_lbl: owner._result_lbl.text = "发现疑点：" + ", ".join(names)
	for cid in hits:
		_add_doubt(cid, a.get("id", ""), b.get("id", ""))
		owner._battle_contra_states[cid] = true   # 直接标记（键可能原不存在，幂等）
	owner._bf_ctl._refresh_battlefield_status_only()
	_refresh_desk()
	owner._state_ctl._persist_state()


func _add_doubt(cid: String, a: String, b: String) -> void:
	for d in owner._doubt_book:
		if d.get("cid", "") == cid:
			return
	owner._doubt_book.append({"cid": cid, "a": a, "b": b})
