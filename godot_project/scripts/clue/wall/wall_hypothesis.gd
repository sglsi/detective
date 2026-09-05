extends RefCounted
class_name WallHypothesis

## 推理墙 · 假设树层（拆自 reasoning_wall.gd，Request C 后架构分层）
##
## 职责：中栏「假设树」（假设节点卡片：id/文案/正确标记/证据行）、
## 证据按 relation_tags 标签驱动匹配（阶段1）、右栏「关联面板」（已关联线索清单）。
## 读取/回写 owner（ReasoningWall）状态；常量/枚举归墙经 owner. / ReasoningWall. 引用。

var owner: ReasoningWall

func _refresh_hypothesis_tree() -> void:
	if not owner._tree_root: return
	for c in owner._tree_root.get_children(): c.queue_free()

	var hypos: Array = owner._battle.get("hypotheses", [])
	if hypos.is_empty():
		var empty := Label.new()
		empty.text = "（本推理链暂无结构化假设节点，请直接关联线索）"
		empty.add_theme_font_size_override("font_size", 15)
		empty.add_theme_color_override("font_color", Color(0.55, 0.50, 0.40))
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty.custom_minimum_size = Vector2(200, 40)
		owner._tree_root.add_child(empty)
		return

	for h in hypos:
		var node := _make_hypothesis_node(h)
		owner._tree_root.add_child(node)


func _make_hypothesis_node(h: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(200, 90)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.10, 0.08, 0.95)
	style.border_color = Color(0.45, 0.35, 0.15, 0.5)
	style.border_width_left = 1; style.border_width_right = 1
	style.border_width_top = 1; style.border_width_bottom = 1
	style.set_corner_radius_all(6)
	card.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	margin.add_child(vb)

	var id: String = h.get("id", "?")
	var text: String = h.get("text", "")
	var correct: bool = h.get("correct", false)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	vb.add_child(top_row)

	var lbl := Label.new()
	lbl.text = id + "  " + text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", owner.COL_GOLD_LIGHT)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.custom_minimum_size = Vector2(160, 24)
	top_row.add_child(lbl)

	# 状态标记
	if owner._difficulty != ReasoningWall.Diff.HARD:
		var tag := Label.new()
		tag.text = "正确" if correct else "待定"
		tag.add_theme_font_size_override("font_size", 12)
		tag.add_theme_color_override("font_color", Color(0.4, 0.85, 0.4) if correct else Color(0.7, 0.7, 0.7))
		tag.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_RIGHT
		tag.custom_minimum_size = Vector2(48, 20)
		top_row.add_child(tag)

	# 子假设/证据行
	var evi := _evidence_for_hypothesis(id)
	var evi_lbl := Label.new()
	evi_lbl.text = "证据：" + (", ".join(evi) if not evi.is_empty() else "（暂无）")
	evi_lbl.add_theme_font_size_override("font_size", 13)
	evi_lbl.add_theme_color_override("font_color", Color(0.55, 0.70, 0.55) if not evi.is_empty() else Color(0.50, 0.45, 0.38))
	evi_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	evi_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	evi_lbl.custom_minimum_size = Vector2(160, 20)
	vb.add_child(evi_lbl)
	card.gui_input.connect(owner._rel_ctl._on_node_gui.bind(id))
	card.mouse_default_cursor_shape = Control.CURSOR_CROSS if owner._connect_mode else Control.CURSOR_ARROW
	owner._hypo_nodes[id] = card
	return card


func _evidence_for_hypothesis(hid: String) -> Array:
	var out := []
	# 标签驱动（阶段1）：仅当线索「已关联」且其 relation_tags 含该假设节点 id 时，
	# 才作为该节点的证据。替换原退化逻辑（relation_tags 为空则全量罗列），
	# 实现「线索按标签自动匹配假设」——不同线索精确落到对应假设/矛盾节点。
	for c in owner._clues:
		if c.get("associated", false):
			var tags: Array = c.get("relation_tags", [])
			if tags.has(hid):
				out.append(c.get("name", c.get("id", "")))
	return out


# === 关联面板 ===
func _refresh_assoc_panel() -> void:
	if not owner._assoc_list: return
	for c in owner._assoc_list.get_children(): c.queue_free()
	var assoc: Array = []
	for c in owner._clues:
		if c.get("associated", false): assoc.append(c)
	if assoc.is_empty():
		var ph := Label.new()
		ph.text = "（暂无关联线索）"
		ph.add_theme_font_size_override("font_size", 14)
		ph.add_theme_color_override("font_color", Color(0.55, 0.50, 0.40))
		ph.custom_minimum_size = Vector2(160, 40)
		owner._assoc_list.add_child(ph)
		return
	for c in assoc:
		var b := Button.new()
		b.text = c.get("name", c.get("id", ""))
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # 长线索名在格子内换行，宽度跟随列宽，不撑破中心面板
		b.custom_minimum_size = Vector2(120, 44)
		b.size_flags_horizontal = Control.SIZE_FILL
		b.size_flags_vertical = Control.SIZE_FILL
		b.add_theme_font_size_override("font_size", 20)
		b.add_theme_color_override("font_color", owner.COL_GOLD_LIGHT)
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.08, 0.30, 0.08, 0.95)
		s.border_color = Color(0.2, 0.8, 0.2)
		s.border_width_left = 1; s.border_width_right = 1
		s.border_width_top = 1; s.border_width_bottom = 1
		s.set_corner_radius_all(4)
		b.add_theme_stylebox_override("normal", s)
		b.pressed.connect(owner._clue_ctl._show_clue_detail.bind(c))
		owner._assoc_list.add_child(b)
