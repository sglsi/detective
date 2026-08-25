extends RefCounted
class_name WallRelations

## 推理墙 · 自由连线/拖拽关系层（拆自 reasoning_wall.gd，Request C 后架构分层）
##
## 职责：关系 CRUD（connect_nodes/remove/clear/get + auto 矛盾检测）、连线模式开关与
## 顶栏联动、图谱回调（on_tag/on_pen_changed）、统一顶栏 pen 同步、左栏线索拖入图谱、
## 关系层绘制（虚线/实线/拖拽预览）。读取/回写 owner（ReasoningWall）状态；
## 常量/枚举归墙经 owner. 引用。

var owner: ReasoningWall

## 建立一条关系。kind="auto" 时（线索↔线索）自动跑矛盾检测：有矛盾→"contradict"，否则→"relate"。
## 返回 false 表示无效或重复（不建立）。
func connect_nodes(from_id: String, to_id: String, kind: String, color_key: String = "", dashed: bool = false) -> bool:
	if from_id == "" or to_id == "" or from_id == to_id: return false
	for r in owner._relations:
		if r.from == from_id and r.to == to_id and r.kind == kind: return false
	var resolved := kind
	if kind == "auto":
		var a := owner._clue_ctl._find_clue(from_id); var b := owner._clue_ctl._find_clue(to_id)
		if not a.is_empty() and not b.is_empty() and not owner._cmp_ctl._detect_contradiction(a, b).is_empty():
			resolved = "contradict"
		else:
			resolved = "relate"
	var ck := color_key if color_key != "" else _kind_to_key(resolved)
	owner._relations.append({"from": from_id, "to": to_id, "kind": resolved, "color_key": ck, "dashed": dashed})
	_refresh_relations()
	owner._state_ctl._persist_state()
	return true


func remove_relation(from_id: String, to_id: String) -> void:
	var kept := []
	for r in owner._relations:
		if not (r.from == from_id and r.to == to_id):
			kept.append(r)
	owner._relations = kept
	_refresh_relations()
	owner._state_ctl._persist_state()


func clear_relations() -> void:
	owner._relations = []
	_refresh_relations()
	owner._state_ctl._persist_state()


func get_relations() -> Array:
	return owner._relations.duplicate()


func set_connect_mode(on: bool) -> void:
	owner._connect_mode = on


func _on_connect_toggled() -> void:
	owner._connect_mode = not owner._connect_mode
	owner.mouse_default_cursor_shape = Control.CURSOR_CROSS if owner._connect_mode else Control.CURSOR_ARROW
	if owner._connect_btn and is_instance_valid(owner._connect_btn):
		owner._connect_btn.text = "🔗 连线：" + ("开" if owner._connect_mode else "关")
		if owner._connect_mode:
			owner._connect_btn.add_theme_color_override("font_color", owner.COL_GREEN)
		else:
			owner._connect_btn.add_theme_color_override("font_color", owner.COL_GOLD_LIGHT)
	for n in owner._card_btns.values():
		if is_instance_valid(n): n.mouse_default_cursor_shape = Control.CURSOR_CROSS if owner._connect_mode else Control.CURSOR_ARROW
	for n in owner._hypo_nodes.values():
		if is_instance_valid(n): n.mouse_default_cursor_shape = Control.CURSOR_CROSS if owner._connect_mode else Control.CURSOR_ARROW
	if owner._status_lbl:
		owner._status_lbl.text = "连线模式：" + ("开（在节点上按住左键拖到另一节点建立关系；Shift=反对，否则支持）" if owner._connect_mode else "关（点击线索查看详情；点「🔗连线」可拖拽建立关系）")


func _on_clear_relations() -> void:
	clear_relations()
	if owner._status_lbl:
		owner._status_lbl.text = "已清除全部关系（%d 条）" % owner._relations.size()


# ===================== 图谱视图回调回写 =====================
func _gv_tag_person(clue_id: String, person_id: String) -> void:
	var clue: Dictionary = owner._clue_ctl._find_clue(clue_id)
	if clue.is_empty(): return
	var rns: Array = clue.get("related_npcs", [])
	if not rns.has(person_id):
		rns.append(person_id)
		clue["related_npcs"] = rns
	owner._state_ctl._persist_state()
	owner._update_all()


func _gv_add_edge(from_id: String, to_id: String, kind: String, color_key: String = "", dashed: bool = false) -> void:
	connect_nodes(from_id, to_id, kind, color_key, dashed)
	owner._update_all()


func _gv_remove_relation(from_id: String, to_id: String) -> void:
	remove_relation(from_id, to_id)
	owner._update_all()


# === 统一顶栏：线型/颜色/视图/焦点 选择器驱动图谱 ===
func _set_pen_dashed(d: bool) -> void:
	print("[topbar] _set_pen_dashed(%s) gv=%s _pen_color_key=%s" % [
		d, "YES" if (owner._graph_view and is_instance_valid(owner._graph_view)) else "NULL",
		owner._graph_view._pen_color_key if (owner._graph_view and is_instance_valid(owner._graph_view)) else "?"
	])
	if owner._graph_view and is_instance_valid(owner._graph_view):
		owner._graph_view.set_pen(owner._graph_view._pen_color_key, d)
		owner._graph_view._toast_msg("线型：%s" % ("虚线" if d else "实线"))
	_sync_pen_buttons()


func _set_pen_color(key: String) -> void:
	var names := {"green": "支持", "orange": "矛盾存疑", "red": "反对", "grey": "弱关联"}
	print("[topbar] _set_pen_color(%s) gv=%s" % [key, "YES" if (owner._graph_view and is_instance_valid(owner._graph_view)) else "NULL"])
	if owner._graph_view and is_instance_valid(owner._graph_view):
		owner._graph_view.set_pen(key, owner._graph_view._pen_dashed)
		owner._graph_view._toast_msg("性质：%s" % names.get(key, key))
	_sync_pen_buttons()


func _sync_pen_buttons() -> void:
	if not owner._graph_view or not is_instance_valid(owner._graph_view): return
	owner._pen_solid_btn.button_pressed = not owner._graph_view._pen_dashed
	owner._pen_dashed_btn.button_pressed = owner._graph_view._pen_dashed
	owner._pen_solid_btn.add_theme_color_override("font_color", owner.COL_GOLD if not owner._graph_view._pen_dashed else owner.COL_GOLD_LIGHT)
	owner._pen_dashed_btn.add_theme_color_override("font_color", owner.COL_GOLD if owner._graph_view._pen_dashed else owner.COL_GOLD_LIGHT)
	for k in owner._color_btns.keys():
		var active2: bool = (k == owner._graph_view._pen_color_key)
		owner._color_btns[k].button_pressed = active2
		owner._color_btns[k].add_theme_color_override("font_color", owner._gw_color(owner._COLOR_LABELS.get(k, "支持")) if active2 else owner.COL_GREY)


func _gv_pen_changed(color_key: String, dashed: bool) -> void:
	_sync_pen_buttons()


func _on_top_connect_toggle() -> void:
	print("[topbar] _on_top_connect_toggle pressed=%s gv=%s" % [
		owner._connect_btn.button_pressed if owner._connect_btn else "NULL_BTN",
		"YES" if (owner._graph_view and is_instance_valid(owner._graph_view)) else "NULL"
	])
	if not owner._graph_view or not is_instance_valid(owner._graph_view):
		owner._connect_btn.button_pressed = false
		return
	var want: bool = owner._connect_btn.button_pressed
	# 已结案（verdict 已出）→ 禁止进入连线模式
	if want and owner._graph_view._state != 0:   # State.EDITABLE
		owner._connect_btn.button_pressed = false
		if owner._status_lbl:
			owner._status_lbl.text = "已结案，推理墙只读（不能新增连线）"
		return
	owner._graph_view.set_connect_mode(want)
	owner._connect_btn.text = "🔗 连线：" + ("开" if want else "关")
	owner._connect_btn.add_theme_color_override("font_color", owner.COL_GREEN if want else owner.COL_GOLD_LIGHT)
	if want:
		if owner._status_lbl:
			owner._status_lbl.text = "连线模式：依次点两个节点建边（线型+性质决定连线颜色/虚实）；点「🔗 连线：关」退出"
	else:
		if owner._status_lbl:
			owner._status_lbl.text = "连线模式已关：可拖动线索到推断上直接建立关系"


func _sync_connect_btn() -> void:
	if not owner._connect_btn or not owner._graph_view or not is_instance_valid(owner._graph_view): return
	var on: bool = owner._graph_view.get_connect_mode()
	owner._connect_btn.button_pressed = on
	owner._connect_btn.text = "🔗 连线：" + ("开" if on else "关")
	owner._connect_btn.add_theme_color_override("font_color", owner.COL_GREEN if on else owner.COL_GOLD_LIGHT)


func _kind_to_key(kind: String) -> String:
	match kind:
		"support", "imply": return "green"
		"contradict": return "orange"
		"oppose": return "red"
		_: return "grey"


func _sync_top_bar() -> void:
	if not owner._graph_view or not is_instance_valid(owner._graph_view): return
	_sync_pen_buttons()
	owner._mode_c_btn.button_pressed = (owner._graph_view._mode == 0)
	owner._mode_b_btn.button_pressed = (owner._graph_view._mode == 1)
	owner._top_focus_sel.clear()
	var persons := owner._state_ctl._derive_persons()
	for p in persons:
		owner._top_focus_sel.add_item(p.get("name", p.get("id", "?")))
		owner._top_focus_sel.set_item_metadata(owner._top_focus_sel.get_item_count() - 1, p.get("id", ""))
	for i in owner._top_focus_sel.get_item_count():
		if owner._top_focus_sel.get_item_metadata(i) == owner._graph_view._focus_person:
			owner._top_focus_sel.select(i)
	if owner._top_verify_btn:
		owner._top_verify_btn.disabled = owner._verified


## 节点 gui_input：连线模式下，左键按下即开始拖拽建立关系（Shift=反对，否则=支持）
func _on_node_gui(event: InputEvent, id: String) -> void:
	if not owner._connect_mode: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_start_link(id, event.shift_pressed)
		owner.get_viewport().set_input_as_handled()


## 左栏「已收集线索」卡拖入图谱：把线索拖到图谱画布区（左栏之外）即放入图谱为节点。
func _on_clue_drag(event: InputEvent, cid: String) -> void:
	if not owner._graph_view or not is_instance_valid(owner._graph_view):
		return
	if owner._state_store.get("graph_placed_clues", []).has(cid):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if owner._drag_src == "":
				owner._drag_src = cid
				owner._drag_origin = owner.get_viewport().get_mouse_position()
		else:
			var was: String = owner._drag_src
			owner._drag_src = ""
			_clear_drag_ghost()
			if was == cid and owner._drag_origin != Vector2(-1, -1):
				_finish_clue_drag(cid)
	elif event is InputEventMouseMotion and owner._drag_src == cid and owner._drag_origin != Vector2(-1, -1):
		var mp := owner.get_viewport().get_mouse_position()
		if mp.distance_to(owner._drag_origin) > 12:
			_ensure_drag_ghost(cid)
			if owner._drag_ghost and is_instance_valid(owner._drag_ghost):
				owner._drag_ghost.global_position = mp - owner._drag_ghost.size * 0.5


func _ensure_drag_ghost(cid: String) -> void:
	if owner._drag_ghost and is_instance_valid(owner._drag_ghost):
		return
	var label := Label.new()
	var clue := owner._clue_ctl._find_clue(cid)
	label.text = clue.get("name", cid)
	label.add_theme_font_size_override("font_size", 16)
	label.modulate = Color(1, 1, 1, 0.9)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.2, 0.3, 0.2, 0.9)
	sb.border_color = Color(0.4, 0.9, 0.4)
	sb.border_width_left = 2; sb.border_width_right = 2
	sb.border_width_top = 2; sb.border_width_bottom = 2
	sb.set_corner_radius_all(6)
	label.add_theme_stylebox_override("normal", sb)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 30
	owner.add_child(label)
	owner._drag_ghost = label


func _clear_drag_ghost() -> void:
	if owner._drag_ghost and is_instance_valid(owner._drag_ghost):
		owner._drag_ghost.queue_free()
	owner._drag_ghost = null


func _finish_clue_drag(cid: String) -> void:
	var gp := owner.get_viewport().get_mouse_position()
	# 只有放到图谱画布上（左栏矩形之外）才算「拖入图谱」；丢回左栏内则取消。
	var inside_panel := owner._left_panel and is_instance_valid(owner._left_panel) and owner._left_panel.get_global_rect().has_point(gp)
	if not inside_panel and owner._graph_view and is_instance_valid(owner._graph_view):
		# 落点若命中图上一个节点，place_clue 会在放置线索同时自动建绿实线支持关系
		owner._graph_view.place_clue(cid, gp)
		owner._state_ctl._persist_state()
		owner._clue_ctl._refresh_clue_list()
	else:
		owner._ui_show_toast("把线索拖到右侧图谱画布上即可放入图谱")


func _start_link(id: String, shift: bool) -> void:
	owner._dragging_link = true
	owner._link_src = id
	owner._link_kind = "oppose" if shift else "support"
	owner._link_preview = owner.get_viewport().get_mouse_position()
	if owner._rel_layer: owner._rel_layer.queue_redraw()


## 松开时命中测试：返回光标下、且非源节点的线索/假设节点 id
func _link_target_at(gp: Vector2) -> String:
	for cid in owner._card_btns.keys():
		var n: Control = owner._card_btns[cid]
		if is_instance_valid(n) and n.get_global_rect().has_point(gp): return cid
	for hid in owner._hypo_nodes.keys():
		var n: Control = owner._hypo_nodes[hid]
		if is_instance_valid(n) and n.get_global_rect().has_point(gp): return hid
	return ""


func _commit_link(src: String, dst: String) -> void:
	var src_clue := owner._card_btns.has(src)
	var dst_clue := owner._card_btns.has(dst)
	var kind := "relate"
	if src_clue and dst_clue:
		kind = "auto"          # 线索↔线索：自动矛盾检测
	elif src_clue != dst_clue:
		kind = owner._link_kind      # 线索↔假设：支持/反对
	connect_nodes(src, dst, kind)


func _refresh_relations() -> void:
	if owner._rel_layer: owner._rel_layer.queue_redraw()


func _node_center(id: String) -> Vector2:
	var node: Control = null
	if owner._card_btns.has(id): node = owner._card_btns[id]
	elif owner._hypo_nodes.has(id): node = owner._hypo_nodes[id]
	if node == null or not is_instance_valid(node): return Vector2.ZERO
	return owner._rel_layer.get_global_transform().affine_inverse() * (node.global_position + node.size * 0.5)


func _rel_color(kind: String) -> Color:
	var key := _kind_to_key(kind)
	match key:
		"green": return Color(0.4, 0.85, 0.4)
		"orange": return Color(0.95, 0.55, 0.25)
		"red": return Color(0.95, 0.3, 0.3)
		_: return Color(0.55, 0.50, 0.42)


func _draw_dashed_line(canvas: Control, a: Vector2, b: Vector2, col: Color) -> void:
	var dist := a.distance_to(b)
	var dash := 12.0; var gap := 8.0
	var seg := dash + gap
	if seg <= 0: return
	var steps := int(dist / seg)
	var dir := (b - a).normalized()
	var pos := a
	for i in steps:
		var p2 := pos + dir * dash
		if p2.distance_to(a) > dist: p2 = b
		canvas.draw_line(pos, p2, col, 2)
		pos = p2 + dir * gap
	if pos.distance_to(b) > 1.0:
		canvas.draw_line(pos, b, col, 2)


func _on_rel_layer_draw() -> void:
	if owner._relations.is_empty() and not owner._dragging_link:
		return
	for r in owner._relations:
		var a := _node_center(r.from); var b := _node_center(r.to)
		if a == Vector2.ZERO or b == Vector2.ZERO: continue
		var col := _rel_color(r.get("color_key", _kind_to_key(r.kind)))
		if r.get("dashed", false):
			_draw_dashed_line(owner._rel_layer, a, b, col)
		else:
			owner._rel_layer.draw_line(a, b, col, 3)
	if owner._dragging_link and owner._link_src != "":
		var a := _node_center(owner._link_src)
		if a != Vector2.ZERO:
			owner._rel_layer.draw_line(a, owner._rel_layer.get_global_transform().affine_inverse() * owner._link_preview, _rel_color(owner._link_kind), 2)
