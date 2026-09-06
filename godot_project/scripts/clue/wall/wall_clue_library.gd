extends RefCounted
class_name WallClueLibrary

## 推理墙 · 线索库层（拆自 reasoning_wall.gd，Request C 后架构分层）
##
## 职责：线索库列表（过滤/搜索/去重=任务7）、线索卡片（状态/证据属性/可信度）、
## 线索详情弹窗（属性/可信度/放入对比台/关联操作）、关联切换、顶部过滤下拉。
## 读取/回写 owner（ReasoningWall）状态；常量与枚举归墙经 owner. / ReasoningWall. 引用。

var owner: ReasoningWall

# ===================== 基础按钮（左栏过滤器 / 统一动作按钮） =====================
func _make_filter_btn(text: String, active: bool) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.toggle_mode = true
	btn.button_pressed = active
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", owner.COL_GOLD_LIGHT)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.25, 0.20, 0.12, 0.95) if active else Color(0.14, 0.12, 0.08, 0.95)
	s.border_color = Color(0.65, 0.55, 0.30)
	s.border_width_left = 1; s.border_width_right = 1
	s.border_width_top = 1; s.border_width_bottom = 1
	s.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", s)
	btn.pressed.connect(_on_filter_pressed.bind(btn))
	return btn


# 统一风格的动作按钮（提交验证 / 返回 / 调查记录 共用）
func _make_action_btn(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 20)
	match text:
		"提交验证":
			btn.icon = load("res://assets/ui/icons/shield_star.png")
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		"返    回", "返回":
			btn.icon = load("res://assets/ui/icons/back_arrow.png")
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		"调查记录":
			btn.icon = load("res://assets/ui/icons/calendar.png")
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if btn.icon != null:
		btn.add_theme_constant_override("icon_max_width", 22)
	btn.add_theme_color_override("font_color", owner.COL_GOLD)
	btn.custom_minimum_size = Vector2(140, 44)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.50, 0.10, 0.10, 0.95)
	s.border_color = Color(0.85, 0.65, 0.25)
	s.border_width_left = 2; s.border_width_right = 2
	s.border_width_top = 2; s.border_width_bottom = 2
	s.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", s)
	return btn


# ===================== 线索查找 =====================
func _find_clue(cid: String) -> Dictionary:
	for c in owner._clues:
		if c.get("id", "") == cid: return c
	return {}


func _clue_name(cid: String) -> String:
	var c: Dictionary = _find_clue(cid)
	if c.is_empty(): return cid
	return c.get("name", cid)


# ===================== 线索库列表（过滤/搜索/去重） =====================
func _refresh_clue_list() -> void:
	if not owner._clue_list: return
	for c in owner._clue_list.get_children(): c.queue_free()
	owner._card_btns.clear()

	var term := owner._search_edit.text.strip_edges().to_lower()
	var filter := _current_filter()

	var placed: Array = owner._state_store.get("graph_placed_clues", []) as Array
	# 任务7：画布上当前可见的线索也视为「已入图」，从左栏去重——线索在推理墙整体中唯一，
	# 不能同时存在于左栏与画布（含因「关联焦点人物/有关系」而自动出现在画布上的线索）。
	var visible: Array = []
	if owner._graph_view and is_instance_valid(owner._graph_view) and owner._graph_view.has_method("visible_clue_ids"):
		visible = owner._graph_view.visible_clue_ids()
	for clue in owner._clues:
		var cid: String = clue.get("id", "")
		# 跨场景带入·任务：case_wide 左栏仅显示「本场景采集页收集到的线索」，
		# 上一场景收集但未拖入画布的线索在下一场景左栏不再出现（玩家认为其不重要）。
		if owner._case_wide and not owner._scene_clue_ids.is_empty() and not (cid in owner._scene_clue_ids):
			continue
		if placed.has(cid) or visible.has(cid):
			continue
		var name: String = clue.get("name", clue.get("label", cid))
		var state := _clue_state(clue)
		if filter != -1 and state != filter:
			continue
		if term != "" and not name.to_lower().contains(term):
			continue
		var card := _make_clue_card(clue)
		owner._clue_list.add_child(card)
		owner._card_btns[clue["id"]] = card


func _current_filter() -> int:
	if owner._filter_assoc and owner._filter_assoc.button_pressed: return ReasoningWall.ClueState.ASSOCIATED
	if owner._filter_unassoc and owner._filter_unassoc.button_pressed: return ReasoningWall.ClueState.COLLECTED
	if owner._filter_misleading and owner._filter_misleading.button_pressed: return ReasoningWall.ClueState.INVALID
	return -1


func _clue_state(clue: Dictionary) -> int:
	if clue.get("associated", false):
		return ReasoningWall.ClueState.ASSOCIATED if clue.get("correct", true) else ReasoningWall.ClueState.INVALID
	return ReasoningWall.ClueState.COLLECTED


# === 阶段2：证据属性标签 + 可信度（由 attribute_tags 派生）===
func _attribute_label_of(clue: Dictionary) -> String:
	var at: Array = clue.get("attribute_tags", [])
	if at.is_empty(): return "其他"
	return at[0]


func _credibility_of(clue: Dictionary) -> String:
	var at: Array = clue.get("attribute_tags", [])
	if at.has("直接物证"): return "高"
	if at.has("目击证词"): return "中"
	if at.has("嫌疑人陈述"): return "中"
	if at.has("二手传闻"): return "低"
	return "中"


func _make_clue_card(clue: Dictionary) -> Button:
	var card := Button.new()
	var name: String = clue.get("name", clue.get("label", clue.get("id", "")))
	var state := _clue_state(clue)
	var state_text: String = ["已收集", "已关联", "已验证", "已失效"][state]
	var attr: String = _attribute_label_of(clue)
	var cred: String = _credibility_of(clue)
	card.text = name
	if owner._difficulty != ReasoningWall.Diff.HARD:
		card.text += "  [%s]" % state_text
	card.text += "\n%s · 可信度:%s" % [attr, cred]
	card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.tooltip_text = clue.get("desc", "")
	card.custom_minimum_size = Vector2(200, 72)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_font_size_override("font_size", 20)

	var sn := StyleBoxFlat.new()
	match state:
		ReasoningWall.ClueState.ASSOCIATED:
			sn.bg_color = Color(0.08, 0.28, 0.08, 0.95)
			sn.border_color = Color(0.2, 0.8, 0.2)
			sn.border_width_left = 2; sn.border_width_right = 2
			sn.border_width_top = 2; sn.border_width_bottom = 2
		ReasoningWall.ClueState.INVALID:
			sn.bg_color = Color(0.25, 0.10, 0.10, 0.95)
			sn.border_color = Color(0.8, 0.35, 0.25)
			sn.border_width_left = 2; sn.border_width_right = 2
			sn.border_width_top = 2; sn.border_width_bottom = 2
		_:
			sn.bg_color = Color(0.18, 0.14, 0.09, 0.95)
			sn.border_color = Color(0.55, 0.42, 0.20)
			sn.border_width_left = 1; sn.border_width_right = 1
			sn.border_width_top = 1; sn.border_width_bottom = 1
	sn.set_corner_radius_all(6)
	card.add_theme_stylebox_override("normal", sn)
	card.add_theme_color_override("font_color", owner.COL_GOLD_LIGHT)
	card.pressed.connect(_on_clue_card_pressed.bind(clue["id"]))
	card.gui_input.connect(owner._rel_ctl._on_node_gui.bind(clue["id"]))
	card.gui_input.connect(owner._rel_ctl._on_clue_drag.bind(clue["id"]))
	card.mouse_default_cursor_shape = Control.CURSOR_CROSS if owner._connect_mode else Control.CURSOR_ARROW
	return card


func _on_filter_pressed(btn: Button) -> void:
	owner._filter_all.button_pressed = false
	owner._filter_assoc.button_pressed = false
	owner._filter_unassoc.button_pressed = false
	owner._filter_misleading.button_pressed = false
	btn.button_pressed = true
	_refresh_clue_list()


func _on_search_changed(_txt: String) -> void:
	_refresh_clue_list()


# ===================== 线索详情弹窗 =====================
func _show_clue_detail(clue: Dictionary) -> void:
	if owner._detail_popup and is_instance_valid(owner._detail_popup):
		owner._detail_popup.queue_free()

	owner._detail_popup = AcceptDialog.new()
	owner._detail_popup.title = "线索详情"
	owner._detail_popup.min_size = Vector2(440, 320)
	owner._detail_popup.exclusive = true
	owner._detail_popup.get_ok_button().add_theme_font_size_override("font_size", 20)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)

	var name_lbl := Label.new()
	name_lbl.text = clue.get("name", clue.get("label", clue.get("id", "")))
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.add_theme_color_override("font_color", owner.COL_GOLD)
	vb.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = clue.get("desc", "（暂无描述）")
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.custom_minimum_size = Vector2(380, 80)
	desc_lbl.add_theme_font_size_override("font_size", 15)
	desc_lbl.add_theme_color_override("font_color", owner.COL_GOLD_LIGHT)
	vb.add_child(desc_lbl)

	if owner._difficulty != ReasoningWall.Diff.HARD:
		var tags := HBoxContainer.new()
		var correct: bool = clue.get("correct", true)
		var ct := Button.new()
		ct.text = "✓ 正确线索" if correct else "⚠ 干扰项"
		ct.disabled = true
		ct.add_theme_color_override("font_color", owner.COL_GREEN if correct else owner.COL_RED)
		tags.add_child(ct)
		var src_tag := Label.new()
		src_tag.text = "来源: " + str(clue.get("source", "?"))
		src_tag.add_theme_color_override("font_color", Color(0.5, 0.48, 0.40))
		tags.add_child(src_tag)
		vb.add_child(tags)

	# 阶段2：证据属性（人证/物证）与可信度
	var ac_row := HBoxContainer.new()
	var ac_lbl := Label.new()
	ac_lbl.text = "证据属性: %s    可信度: %s" % [_attribute_label_of(clue), _credibility_of(clue)]
	ac_lbl.add_theme_font_size_override("font_size", 14)
	ac_lbl.add_theme_color_override("font_color", Color(0.78, 0.72, 0.50))
	ac_row.add_child(ac_lbl)
	vb.add_child(ac_row)

	# 阶段3：从详情弹窗把线索放入对比台
	var desk_row := HBoxContainer.new()
	var to_desk := Button.new()
	to_desk.text = "→ 放入对比台"
	to_desk.add_theme_font_size_override("font_size", 20)
	to_desk.add_theme_color_override("font_color", owner.COL_GOLD)
	to_desk.pressed.connect(func():
		owner._cmp_ctl._load_comparison(clue["id"])
		owner._detail_popup.hide()
	)
	desk_row.add_child(to_desk)
	vb.add_child(desk_row)

	var btn_row := HBoxContainer.new()
	var assoc_btn := Button.new()
	var is_assoc: bool = clue.get("associated", false)
	assoc_btn.text = "取消关联" if is_assoc else "→ 关联到假设面板"
	assoc_btn.pressed.connect(func():
		owner._detail_popup.hide()
		_toggle_association(clue["id"])
	)
	btn_row.add_child(assoc_btn)
	vb.add_child(btn_row)

	owner._detail_popup.add_child(vb)
	owner.add_child(owner._detail_popup)
	owner._detail_popup.popup_centered()


# === 关联逻辑 ===
func _on_clue_card_pressed(cid: String) -> void:
	if owner._connect_mode: return   # 连线模式下点击不弹详情，由拖拽建立关系
	var clue: Dictionary = _find_clue(cid)
	if not clue.is_empty():
		_show_clue_detail(clue)


func _toggle_association(cid: String) -> void:
	var clue: Dictionary = {}
	for c in owner._clues:
		if c["id"] == cid:
			clue = c; break
	if clue.is_empty(): return

	if clue.get("associated", false):
		clue["associated"] = false
		owner._associated -= 1
		if not clue.get("correct", true): owner._contradicting -= 1
		owner._status_lbl.text = "已取消关联: %s (共%d条)" % [cid, owner._associated]
		owner._status_lbl.add_theme_color_override("font_color", Color(0.65, 0.55, 0.35))
	else:
		clue["associated"] = true
		owner._associated += 1
		if not clue.get("correct", true): owner._contradicting += 1
	owner._status_lbl.text = "线索已关联: %s (共%d条)" % [cid, owner._associated]
	owner._status_lbl.add_theme_color_override("font_color", owner.COL_GREEN)

	owner._update_all()
	owner._state_ctl._persist_state()


# ===================== 顶部过滤下拉（图谱 status_filter 联动） =====================
func _on_filter_selected(idx: int) -> void:
	if owner._graph_view and not is_instance_valid(owner._graph_view): return
	var labels := ["all", "excluded", "pending", "key"]
	var key: String = labels[idx] if idx < labels.size() else "all"
	owner._graph_view.set_status_filter(key)
