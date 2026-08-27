extends RefCounted
class_name GraphViewDock

## 图谱视图 · 左线索栏 dock + 建关系建议弹窗层（拆自 graph_view_controller.gd）
##
## 职责：左侧「已收集线索」栏（可收缩/拖拽入图）、线索拖拽预览、「推断/结论」建议弹窗
## （含线型/性质笔）、笔状态同步（pen_color/pen_dashed → on_pen_changed 回调）。
## 读取/回写 owner（GraphViewController）状态；常量归控制器经 owner. 引用。
## 注意：_create_clue_dock 当前在 build 中被注释（dock 由推理墙左侧栏承担），
## 本层方法整体照搬保持行为中性。

var owner: GraphViewController

# ===================== 左线索栏 dock =====================
func _create_clue_dock() -> void:
	owner._dock = Control.new()
	owner._dock.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	owner._dock.offset_top = 64
	owner._dock.offset_bottom = -44
	owner._dock.offset_right = 26 if owner._dock_collapsed else 340
	owner._dock.mouse_filter = Control.MOUSE_FILTER_STOP
	owner._dock.z_index = 5
	owner.add_child(owner._dock)

	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.08, 0.06, 0.62)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owner._dock.add_child(bg)

	owner._dock_toggle_btn = Button.new()
	owner._dock_toggle_btn.text = "›" if owner._dock_collapsed else "‹"
	owner._dock_toggle_btn.add_theme_font_size_override("font_size", 30)
	owner._dock_toggle_btn.add_theme_color_override("font_color", owner.COL_GOLD_LIGHT)
	owner._dock_toggle_btn.custom_minimum_size = Vector2(44, 48)
	owner._dock_toggle_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	owner._dock_toggle_btn.offset_right = -6; owner._dock_toggle_btn.offset_left = -52
	owner._dock_toggle_btn.offset_top = 4; owner._dock_toggle_btn.offset_bottom = 32
	owner._dock_toggle_btn.pressed.connect(_on_dock_toggle)
	owner._dock.add_child(owner._dock_toggle_btn)

	var title := Label.new()
	title.text = "已收集线索"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", owner.COL_GOLD)
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_left = 10; title.offset_top = 8; title.offset_right = -44; title.offset_bottom = 58
	title.visible = not owner._dock_collapsed
	owner._dock.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 62; scroll.offset_bottom = -8; scroll.offset_left = 6; scroll.offset_right = -6
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	scroll.visible = not owner._dock_collapsed
	owner._dock.add_child(scroll)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vb)
	owner._dock_list = vb

	_refresh_dock()


func _refresh_dock() -> void:
	if not owner._dock_list: return
	for c in owner._dock_list.get_children(): c.queue_free()
	owner._dock_cards = {}
	for c in owner._clues:
		var card := _make_dock_clue_card(c)
		owner._dock_list.add_child(card)
		owner._dock_cards[c.get("id", "")] = card


func _make_dock_clue_card(clue: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(300, 100)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.08, 0.28, 0.08, 0.95)
	s.border_color = Color(0.2, 0.8, 0.2)
	s.border_width_left = 2; s.border_width_right = 2; s.border_width_top = 2; s.border_width_bottom = 2
	s.set_corner_radius_all(6)
	card.add_theme_stylebox_override("panel", s)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 4)
	card.add_child(margin)
	var vb := VBoxContainer.new()
	margin.add_child(vb)
	var name := Label.new()
	name.text = clue.get("name", clue.get("id", "?"))
	name.add_theme_font_size_override("font_size", 40)
	name.add_theme_color_override("font_color", owner.COL_GOLD_LIGHT)
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(name)
	var sub := Label.new()
	sub.text = "拖入图谱建立关系"
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", owner.COL_GREY)
	vb.add_child(sub)
	var cid: String = clue.get("id", "")
	card.gui_input.connect(_on_dock_card_gui.bind(cid))
	card.tooltip_text = clue.get("desc", "")
	return card


func _on_dock_card_gui(event: InputEvent, cid: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if owner._state != GraphViewController.State.EDITABLE:
			owner._toast_msg("已封存，仅可浏览")
			return
		owner._dock_dragging = true
		owner._dock_clue_id = cid
		owner._dock_moved = false
		owner._dock_start = owner.get_viewport().get_mouse_position()
		_make_dock_preview(cid)
		# 声明吃掉这次按下：防止 dock 所在 ScrollContainer 把按下当成滚动起点而抢走后续拖动
		owner.get_viewport().set_input_as_handled()


func _on_dock_drop() -> void:
	owner._dock_dragging = false
	var cid := owner._dock_clue_id
	owner._dock_clue_id = ""
	_clear_dock_preview()
	if not owner._dock_moved:
		return
	var gp := owner.get_viewport().get_mouse_position()
	if owner._dock and is_instance_valid(owner._dock) and owner._dock.get_global_rect().has_point(gp):
		return   # 落回线索栏内，视为取消
	_open_derive_popup(cid)


func _make_dock_preview(cid: String) -> void:
	_clear_dock_preview()
	var clue: Dictionary = owner._data._find_clue(cid)
	var prev := PanelContainer.new()
	prev.custom_minimum_size = Vector2(300, 100)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.10, 0.30, 0.10, 0.95)
	s.border_color = owner.COL_GOLD
	s.border_width_left = 2; s.border_width_right = 2; s.border_width_top = 2; s.border_width_bottom = 2
	s.set_corner_radius_all(6)
	prev.add_theme_stylebox_override("panel", s)
	var lab := Label.new()
	lab.text = clue.get("name", cid)
	lab.add_theme_font_size_override("font_size", 40)
	lab.add_theme_color_override("font_color", owner.COL_GOLD_LIGHT)
	prev.add_child(lab)
	prev.z_index = 40
	# 纯视觉预览：设为 IGNORE，绝不作为命中控件拦截松开事件
	prev.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owner.add_child(prev)
	owner._dock_preview = prev
	_move_dock_preview(owner.get_viewport().get_mouse_position())


func _move_dock_preview(gp: Vector2) -> void:
	if owner._dock_preview and is_instance_valid(owner._dock_preview):
		owner._dock_preview.position = gp - owner._dock_preview.size * 0.5


func _clear_dock_preview() -> void:
	if owner._dock_preview and is_instance_valid(owner._dock_preview):
		owner._dock_preview.queue_free()
	owner._dock_preview = null


func _on_dock_toggle() -> void:
	owner._dock_collapsed = not owner._dock_collapsed
	if owner._dock and is_instance_valid(owner._dock):
		owner._dock.offset_right = 26 if owner._dock_collapsed else 340
	if owner._dock_toggle_btn and is_instance_valid(owner._dock_toggle_btn):
		owner._dock_toggle_btn.text = "›" if owner._dock_collapsed else "‹"
	var title_child: Array = owner._dock.get_children().filter(func(c): return c is Label)
	for t in title_child: t.visible = not owner._dock_collapsed
	if owner._dock_list and is_instance_valid(owner._dock_list):
		# 滚动容器是 _dock_list 的父节点
		var sc := owner._dock_list.get_parent()
		if sc and is_instance_valid(sc): sc.visible = not owner._dock_collapsed


# ===================== 「推断/结论」建议弹窗 =====================
# ===================== 自由连线窗（候选推导窗的次级入口） =====================
func _open_free_link(cid: String) -> void:
	_close_link_popup()
	owner._link_popup_clue_id = cid
	var popup := Control.new()
	popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.z_index = 25
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.45)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup.add_child(overlay)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 560)
	panel.position = (owner.get_viewport_rect().size - Vector2(440, 380)) * 0.5
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.10, 0.08, 0.06, 0.99)
	ps.border_color = owner.COL_GOLD
	ps.border_width_left = 2; ps.border_width_right = 2; ps.border_width_top = 2; ps.border_width_bottom = 2
	ps.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", ps)
	popup.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	# 问题Q2：详情卡内容增多，用 ScrollContainer 包裹，保证全部内容可滚动查看、底部按钮可点
	var scr := ScrollContainer.new()
	scr.custom_minimum_size = Vector2(488, 600)
	scr.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scr.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scr.add_theme_constant_override("separation", 8)
	margin.add_child(scr)
	var vbw := VBoxContainer.new()
	vbw.add_theme_constant_override("separation", 8)
	scr.add_child(vbw)
	# 下面原 vb 直接改为 vbw
	vb = vbw

	var t := Label.new()
	t.text = "把线索「%s」连到：" % owner._data._find_clue(cid).get("name", cid)
	t.add_theme_font_size_override("font_size", 30)
	t.add_theme_color_override("font_color", owner.COL_GOLD)
	vb.add_child(t)

	var pen_row := HBoxContainer.new()
	vb.add_child(pen_row)
	pen_row.add_child(_mk_pen_label("线型"))
	var solid := _mk_pen_btn("实线", not owner._pen_dashed, Color(0.8, 0.8, 0.8))
	solid.pressed.connect(func(): _set_pen_dashed(false))
	pen_row.add_child(solid)
	var dashed := _mk_pen_btn("虚线", owner._pen_dashed, owner.COL_GREY)
	dashed.pressed.connect(func(): _set_pen_dashed(true))
	pen_row.add_child(dashed)

	var col_row := HBoxContainer.new()
	vb.add_child(col_row)
	col_row.add_child(_mk_pen_label("性质"))
	var keys := ["green", "orange", "red", "grey"]
	var labels := ["支持", "矛盾存疑", "反对", "弱关联"]
	for i in keys.size():
		var b := _mk_pen_btn(labels[i], owner._pen_color_key == keys[i], owner._data.color_from_key(keys[i]))
		var k: String = keys[i]
		b.pressed.connect(func(): _set_pen_color(k))
		col_row.add_child(b)

	var sep := HSeparator.new()
	vb.add_child(sep)
	var hint := Label.new()
	hint.text = "选择要连接的目标："
	hint.add_theme_font_size_override("font_size", 40)
	hint.add_theme_color_override("font_color", owner.COL_GREY)
	vb.add_child(hint)

	var pname: String = owner._data._person_name(owner._focus_person)
	var pb := _mk_link_target("★ %s（星型归属）" % pname)
	pb.pressed.connect(func(): _confirm_link(cid, owner._focus_person, "person"))
	vb.add_child(pb)
	for h in owner._hypo.get("battlefield", {}).get("hypotheses", []):
		if not owner._hypo_preset_visible(h):
			continue
		var hb := _mk_link_target("推断：%s" % h.get("text", h.get("id", "?")))
		var hid: String = h.get("id", "")
		hb.pressed.connect(func(): _confirm_link(cid, hid, "hypo"))
		vb.add_child(hb)
	var cb := _mk_link_target("结论：%s" % owner._data._verdict_text())
	cb.pressed.connect(func(): _confirm_link(cid, "conclusion", "conclusion"))
	vb.add_child(cb)

	var cancel := Button.new()
	cancel.text = "取消"
	cancel.add_theme_font_size_override("font_size", 26)
	cancel.pressed.connect(_close_link_popup)
	vb.add_child(cancel)

	owner.add_child(popup)
	owner._link_popup = popup


# ===================== 正向推导：拖线索候选窗 =====================
func _open_derive_popup(cid: String) -> void:
	_close_link_popup()
	owner._link_popup_clue_id = cid
	var cands := _derive_candidates(cid)
	var popup := Control.new()
	popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.z_index = 25
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.45)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup.add_child(overlay)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 520)
	panel.position = (owner.get_viewport_rect().size - Vector2(440, 360)) * 0.5
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.10, 0.08, 0.06, 0.99)
	ps.border_color = owner.COL_GOLD
	ps.border_width_left = 2; ps.border_width_right = 2; ps.border_width_top = 2; ps.border_width_bottom = 2
	ps.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", ps)
	popup.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	var scr := ScrollContainer.new()
	scr.custom_minimum_size = Vector2(488, 420)
	scr.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scr.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	margin.add_child(scr)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	scr.add_child(vb)
	var t := Label.new()
	t.text = "由线索「%s」可推导的推断：" % owner._data._find_clue(cid).get("name", cid)
	t.add_theme_font_size_override("font_size", 30)
	t.add_theme_color_override("font_color", owner.COL_GOLD)
	vb.add_child(t)
	if cands.is_empty():
		var hint := Label.new()
		hint.text = "该线索没有预设的可推导推断。可用「自定义连线…」手动建立关系，或用顶部按钮自行添加推断。"
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.add_theme_font_size_override("font_size", 26)
		hint.add_theme_color_override("font_color", owner.COL_GREY)
		vb.add_child(hint)
	else:
		for cnd in cands:
			var hid: String = str(cnd.get("id", ""))
			var mislead: bool = str(cnd.get("kind", "true")) != "true"
			var txt: String = "推断：%s%s" % [cnd.get("text", hid), "（存疑）" if mislead else ""]
			var b := _mk_link_target(txt)
			b.pressed.connect(_derive_confirm.bind(cid, hid))
			vb.add_child(b)
	var sep := HSeparator.new()
	vb.add_child(sep)
	var free_btn := Button.new()
	free_btn.text = "自定义连线…"
	free_btn.add_theme_font_size_override("font_size", 26)
	free_btn.pressed.connect(_on_free_link_btn.bind(cid))
	vb.add_child(free_btn)
	var cancel := Button.new()
	cancel.text = "取消"
	cancel.add_theme_font_size_override("font_size", 26)
	cancel.pressed.connect(_close_link_popup)
	vb.add_child(cancel)
	owner.add_child(popup)
	owner._link_popup = popup


## 候选口径：列出本场景全部推断（难度过滤后），按数据顺序排列（不排序、不标注）
func _derive_candidates(cid: String) -> Array:
	var hypos: Array = owner._hypo.get("battlefield", {}).get("hypotheses", [])
	var out := []
	for h in hypos:
		if not owner._hypo_preset_visible(h):
			continue
		out.append({"id": str(h.get("id", "")), "text": h.get("text", ""), "kind": h.get("kind", "true")})
	return out


func _on_free_link_btn(cid: String) -> void:
	_close_link_popup()
	_open_free_link(cid)


func _derive_confirm(cid: String, hid: String) -> void:
	print("[derive_confirm] clicked cid=", cid, " hid=", hid)
	_close_link_popup()
	owner._derive_hypo(cid, hid)


# ===================== 结论候选窗（由推断推导结论） =====================
func _open_conclusion_popup(hid: String) -> void:
	_close_link_popup()
	var cons: Array = owner._hypo.get("battlefield", {}).get("conclusions", [])
	var cands := []
	for c in cons:
		if not _conclusion_preset_visible(c):
			continue
		if (c.get("gate_hypo_ids", []) as Array).has(hid):
			cands.append(c)
	var popup := Control.new()
	popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.z_index = 25
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.45)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup.add_child(overlay)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 460)
	panel.position = (owner.get_viewport_rect().size - Vector2(440, 320)) * 0.5
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.10, 0.08, 0.06, 0.99)
	ps.border_color = owner.COL_GOLD
	ps.border_width_left = 2; ps.border_width_right = 2; ps.border_width_top = 2; ps.border_width_bottom = 2
	ps.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", ps)
	popup.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	var scr := ScrollContainer.new()
	scr.custom_minimum_size = Vector2(488, 360)
	scr.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scr.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	margin.add_child(scr)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	scr.add_child(vb)
	var t := Label.new()
	t.text = "由推断推导结论："
	t.add_theme_font_size_override("font_size", 30)
	t.add_theme_color_override("font_color", owner.COL_GOLD)
	vb.add_child(t)
	if cands.is_empty():
		var hint := Label.new()
		hint.text = "该推断暂无预设结论。可自由连线连接结论，或自行添加结论节点。"
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.add_theme_font_size_override("font_size", 26)
		hint.add_theme_color_override("font_color", owner.COL_GREY)
		vb.add_child(hint)
	else:
		for c in cands:
			var con_id: String = str(c.get("id", ""))
			var cmis: bool = str(c.get("kind", "true")) != "true"
			var ctxt: String = "结论：%s%s" % [c.get("text", con_id), "（存疑）" if cmis else ""]
			var cb := _mk_link_target(ctxt)
			cb.pressed.connect(_conclusion_confirm.bind(hid, con_id))
			vb.add_child(cb)
	var cancel2 := Button.new()
	cancel2.text = "取消"
	cancel2.add_theme_font_size_override("font_size", 26)
	cancel2.pressed.connect(_close_link_popup)
	vb.add_child(cancel2)
	owner.add_child(popup)
	owner._link_popup = popup


## 结论难度过滤：EASY 仅正确 / NORMAL 正确+误导 / HARD 无候选
func _conclusion_preset_visible(c: Dictionary) -> bool:
	if owner._difficulty == owner.Diff.HARD:
		return false
	if owner._difficulty == owner.Diff.EASY:
		return str(c.get("kind", "true")) == "true"
	return true


func _conclusion_confirm(hid: String, con_id: String) -> void:
	_close_link_popup()
	owner._derive_conclusion(hid, con_id)


func _close_link_popup() -> void:
	if owner._link_popup and is_instance_valid(owner._link_popup):
		owner._link_popup.queue_free()
		owner._link_popup = null


func _confirm_link(cid: String, target_id: String, kind_hint: String) -> void:
	_close_link_popup()
	if target_id == "" or target_id == cid: return
	if kind_hint == "person":
		owner._tag_person(cid, target_id)
	else:
		var kind: String = owner._data.key_to_kind(owner._pen_color_key)
		owner._edge._add_edge(cid, target_id, kind, owner._pen_color_key, owner._pen_dashed)


# ===================== 笔（pen）控件 =====================
func _mk_pen_label(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 40)
	l.add_theme_color_override("font_color", owner.COL_GREY)
	l.custom_minimum_size = Vector2(60, 44)
	return l


func _mk_pen_btn(t: String, active: bool, col: Color) -> Button:
	var b := Button.new()
	b.text = t
	b.toggle_mode = true
	b.button_pressed = active
	b.add_theme_font_size_override("font_size", 40)
	b.add_theme_color_override("font_color", col if active else owner.COL_GOLD_LIGHT)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.25, 0.20, 0.12, 0.95) if active else Color(0.14, 0.12, 0.08, 0.95)
	s.border_color = col if active else Color(0.45, 0.38, 0.20)
	s.border_width_left = 1; s.border_width_right = 1; s.border_width_top = 1; s.border_width_bottom = 1
	s.set_corner_radius_all(4)
	b.add_theme_stylebox_override("normal", s)
	b.custom_minimum_size = Vector2(110, 44)
	return b


func _mk_link_target(t: String) -> Button:
	var b := Button.new()
	b.text = t
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 26)
	b.add_theme_color_override("font_color", owner.COL_GOLD_LIGHT)
	b.custom_minimum_size = Vector2(560, 52)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.16, 0.13, 0.08, 0.95)
	s.border_color = Color(0.45, 0.38, 0.20)
	s.border_width_left = 1; s.border_width_right = 1; s.border_width_top = 1; s.border_width_bottom = 1
	s.set_corner_radius_all(5)
	b.add_theme_stylebox_override("normal", s)
	return b


func _set_pen_color(key: String) -> void:
	owner._pen_color_key = key
	_emit_pen_changed()
	_refresh_link_popup_pen()


func _set_pen_dashed(d: bool) -> void:
	owner._pen_dashed = d
	_emit_pen_changed()
	_refresh_link_popup_pen()


func _emit_pen_changed() -> void:
	if owner._cb_pen_changed.is_valid():
		owner._cb_pen_changed.call(owner._pen_color_key, owner._pen_dashed)


func _refresh_link_popup_pen() -> void:
	if owner._link_popup and is_instance_valid(owner._link_popup):
		var cid := owner._link_popup_clue_id
		_close_link_popup()
		_open_free_link(cid)
