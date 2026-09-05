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
# ===================== 统一可拖拽+可滚动弹窗外壳 =====================
# 返回 [popup, panel, content_vb]；panel = VBox(标题栏[拖拽手柄+✕] , MarginContainer>ScrollContainer>content_vb)。
# 调用方只往 content_vb 填内容即可；窗口可拖拽、内容超长可滚动（满足「统一弹窗」要求）。
func _popup_shell(title_text: String, panel_size: Vector2, scroll_min: Vector2) -> Array:
	var popup := Control.new()
	popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.z_index = 25
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.45)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup.add_child(overlay)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = panel_size
	panel.size = panel_size
	panel.position = (owner.get_viewport_rect().size - panel_size) * 0.5
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.10, 0.08, 0.06, 0.99)
	ps.border_color = owner.COL_GOLD
	ps.border_width_left = 2; ps.border_width_right = 2; ps.border_width_top = 2; ps.border_width_bottom = 2
	ps.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", ps)
	popup.add_child(panel)
	var root := VBoxContainer.new()
	panel.add_child(root)
	# 标题栏（拖动手柄）
	var title_bar := HBoxContainer.new()
	title_bar.custom_minimum_size = Vector2(0, 40)
	title_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	title_bar.add_theme_constant_override("separation", 10)
	var tbs := StyleBoxFlat.new()
	tbs.bg_color = Color(0.18, 0.14, 0.08, 1.0)
	tbs.set_corner_radius_all(6)
	title_bar.add_theme_stylebox_override("panel", tbs)
	title_bar.gui_input.connect(_on_popup_title_gui.bind(panel))
	root.add_child(title_bar)
	var cap := Label.new()
	cap.text = title_text
	cap.add_theme_font_size_override("font_size", 22)
	cap.add_theme_color_override("font_color", owner.COL_GOLD)
	cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_bar.add_child(cap)
	var xbtn := Button.new()
	xbtn.text = "✕"
	xbtn.add_theme_font_size_override("font_size", 18)
	xbtn.add_theme_color_override("font_color", Color(0.85, 0.55, 0.55))
	xbtn.custom_minimum_size = Vector2(40, 32)
	var xcs := StyleBoxFlat.new()
	xcs.bg_color = Color(0.30, 0.18, 0.18, 0.95)
	xcs.border_color = Color(0.7, 0.4, 0.4)
	xcs.set_corner_radius_all(4)
	xbtn.add_theme_stylebox_override("normal", xcs)
	xbtn.pressed.connect(_close_link_popup)
	title_bar.add_child(xbtn)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(margin)
	var scr := ScrollContainer.new()
	scr.custom_minimum_size = scroll_min
	scr.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scr.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scr.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(scr)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scr.add_child(vb)
	return [popup, panel, vb]


func _on_popup_title_gui(event: InputEvent, panel: PanelContainer) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			owner._popup_dragging = true
			owner._popup_drag_panel = panel
			owner._popup_drag_offset = owner.get_viewport().get_mouse_position() - panel.global_position
		else:
			owner._popup_dragging = false


func _open_free_link(cid: String) -> void:
	_close_link_popup()
	owner._link_popup_clue_id = cid
	var _clue_name: String = owner._data._find_clue(cid).get("name", cid)
	var _shell: Array = _popup_shell("把线索「%s」连到：" % _clue_name, Vector2(640, 560), Vector2(488, 440))
	var popup: Control = _shell[0]
	var panel: PanelContainer = _shell[1]
	var vb: VBoxContainer = _shell[2]

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
	for h in owner._hypo_current.get("hypotheses", []):
		if not owner._hypo_preset_visible(h):
			continue
		var hb := _mk_link_target("推断：%s" % h.get("text", h.get("id", "?")))
		var hid: String = h.get("id", "")
		hb.pressed.connect(func(): _confirm_link(cid, hid, "hypo"))
		vb.add_child(hb)
	# 多结论节点：列出当前已推导的全部结论作为连线目标（旧单 "conclusion" 节点已弃用）
	for _dc in owner._derived_conclusions:
		var _dnid: String = "conclusion_" + str(_dc.get("id", ""))
		var _ctxt: String = "结论：%s" % owner._conclusion_text(str(_dc.get("id", "")))
		var _ccb := _mk_link_target(_ctxt)
		_ccb.pressed.connect(func(): _confirm_link(cid, _dnid, "conclusion"))
		vb.add_child(_ccb)

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
	var cands := _derive_candidates()
	var _clue_name: String = owner._data._find_clue(cid).get("name", cid)
	var _shell: Array = _popup_shell("由线索「%s」推导推断（任选其一）：" % _clue_name, Vector2(640, 520), Vector2(488, 420))
	var popup: Control = _shell[0]
	var panel: PanelContainer = _shell[1]
	var vb: VBoxContainer = _shell[2]
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


## 候选口径：列出本场景全部（按难度可见的）预设推断，供玩家任选其一；
## 不再按 gate_clue_ids / gate_hypo_ids 过滤（与结论候选窗一致：gate 仅作后台触发与正确判定口径，
## 给玩家自由组链空间）。按数据顺序排列、不排序、不标注来源。
func _derive_candidates() -> Array:
	var hypos: Array = owner._hypo_current.get("hypotheses", [])
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
	_close_link_popup()
	owner._derive_hypo(cid, hid)


## 方案B：由「推断」推导下一层「推断」（如 W-C1+W-C2→W-C3）。
## 候选口径：列出 gate_hypo_ids 含源推断 src_hid 的预设推断（难度过滤后），随机排列。
func _open_hypo_derive_popup(src_hid: String) -> void:
	_close_link_popup()
	var hypos: Array = owner._hypo_current.get("hypotheses", [])
	var cands := []
	for h in hypos:
		if src_hid in h.get("gate_hypo_ids", []):
			if owner._hypo_preset_visible(h):
				cands.append(h)
	if cands.is_empty():
		owner._ui_toast("该推断暂无可向下组合推导的推断")
		return
	cands.shuffle()
	var _shell: Array = _popup_shell("由推断「%s」可组合推导的下一层推断：" % owner._node_label(src_hid), Vector2(640, 460), Vector2(488, 360))
	var popup: Control = _shell[0]
	var panel: PanelContainer = _shell[1]
	var vb: VBoxContainer = _shell[2]
	for c in cands:
		var hid: String = str(c.get("id", ""))
		var mislead: bool = str(c.get("kind", "true")) != "true"
		var txt: String = "推断：%s%s" % [c.get("text", hid), "（存疑）" if mislead else ""]
		var b := _mk_link_target(txt)
		b.pressed.connect(_derive_hypo_confirm.bind(src_hid, hid))
		vb.add_child(b)
	var cancel := Button.new()
	cancel.text = "取消"
	cancel.add_theme_font_size_override("font_size", 26)
	cancel.pressed.connect(_close_link_popup)
	vb.add_child(cancel)
	owner.add_child(popup)
	owner._link_popup = popup


func _derive_hypo_confirm(src_hid: String, dst_hid: String) -> void:
	_close_link_popup()
	owner._derive_hypo_from_hypo(src_hid, dst_hid)


# ===================== 结论候选窗（由推断推导结论） =====================
func _open_conclusion_popup(hid: String) -> void:
	_close_link_popup()
	# 候选口径：列出本场景全部结论（按难度过滤），不按 gate_hypo_ids 过滤、不排序、不标注来源，
	# 随机排列，让玩家从多条里选（含误导项，简单模式仅正确项）。gate_hypo_ids 仅作后台触发口径。
	var cons: Array = owner._hypo_current.get("conclusions", [])
	var cands := []
	if owner._difficulty == owner.Diff.NORMAL:
		# 普通模式：正确项全留 + 误导项按 mislead_chance 概率掺入（确定性种子，同墙同组合，避免每次重摇割裂）。
		var seed: int = int(owner._state_store.get("mislead_seed", 0))
		if seed == 0:
			seed = int(Time.get_ticks_msec()) + owner._graph_nodes.size()
			owner._state_store["mislead_seed"] = seed
		var chance: float = 0.0
		if DifficultyManager != null:
			chance = DifficultyManager.mislead_chance
		var misleads: Array = []
		for c in cons:
			if str(c.get("kind", "true")) != "true":
				misleads.append(c)
		var picked: Array = []
		for c in misleads:
			var hv: int = hash(str(c.get("id", "")) + "|" + str(seed))
			if (hv % 1000) < int(chance * 1000):
				picked.append(c)
		# 保证至少掺 1 条（否则难度感丢失）
		if picked.is_empty() and not misleads.is_empty() and chance > 0.0:
			picked.append(misleads[abs(hash(str(seed))) % misleads.size()])
		for c in cons:
			if str(c.get("kind", "true")) == "true":
				cands.append(c)
			elif picked.has(c):
				cands.append(c)
	else:
		# EASY 仅正确 / HARD 无候选（走原过滤）
		for c in cons:
			if _conclusion_preset_visible(c):
				cands.append(c)
	cands.shuffle()
	var _shell: Array = _popup_shell("由推断推导结论（任选其一）：", Vector2(640, 460), Vector2(488, 360))
	var popup: Control = _shell[0]
	var panel: PanelContainer = _shell[1]
	var vb: VBoxContainer = _shell[2]
	if cands.is_empty():
		var hint := Label.new()
		hint.text = "该场景暂无可选预设结论。可直接「✍ 自定义结论…」输入你的判断。"
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
	# 「自定义结论」入口常驻（无论候选多少），让玩家始终保留自定义空间
	var _cbtn := Button.new()
	_cbtn.text = "✍ 自定义结论…"
	_cbtn.add_theme_font_size_override("font_size", 26)
	_cbtn.pressed.connect(_on_custom_conclusion_pressed.bind(hid))
	vb.add_child(_cbtn)
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


func _on_custom_conclusion_pressed(hid: String) -> void:
	_open_custom_conclusion_popup(hid)


## 自定义结论输入窗：玩家输入自己的结论文本（不选预设项）
func _open_custom_conclusion_popup(hid: String) -> void:
	_close_link_popup()
	var popup := Control.new()
	popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.z_index = 25
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.45)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup.add_child(overlay)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 190)
	panel.position = (owner.get_viewport_rect().size - Vector2(360, 120)) * 0.5
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
	vb.add_theme_constant_override("separation", 10)
	margin.add_child(vb)
	var t := Label.new()
	t.text = "自定义结论（不选预设项）"
	t.add_theme_font_size_override("font_size", 28)
	t.add_theme_color_override("font_color", owner.COL_GOLD)
	vb.add_child(t)
	var le := LineEdit.new()
	le.placeholder_text = "输入你的结论…"
	le.add_theme_font_size_override("font_size", 26)
	vb.add_child(le)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	var ok := Button.new()
	ok.text = "确定"
	ok.add_theme_font_size_override("font_size", 24)
	ok.pressed.connect(_confirm_custom_conclusion.bind(hid, le))
	hb.add_child(ok)
	var cc := Button.new()
	cc.text = "取消"
	cc.add_theme_font_size_override("font_size", 24)
	cc.pressed.connect(_close_link_popup)
	hb.add_child(cc)
	vb.add_child(hb)
	owner.add_child(popup)
	owner._link_popup = popup


func _confirm_custom_conclusion(hid: String, le: LineEdit) -> void:
	var text: String = le.text
	_close_link_popup()
	owner._derive_conclusion_custom(hid, text)


func _conclusion_confirm(hid: String, con_id: String) -> void:
	_close_link_popup()
	owner._derive_conclusion(hid, con_id)


func _close_link_popup() -> void:
	owner._popup_dragging = false
	owner._popup_drag_panel = null
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
