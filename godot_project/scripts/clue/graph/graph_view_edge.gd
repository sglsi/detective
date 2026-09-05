extends RefCounted
class_name GraphViewEdge

## 图谱视图 · 边/关系层（拆自 graph_view_controller.gd，Request C 后架构分层）
##
## 职责：证据连线绘制（弧线/虚线/选中高亮）、建边/删边/改性质/改线型（含 UndoRedo）、
## 连线命中测试与右键菜单。读取/回写 owner（GraphViewController）状态；
## 常量（VERB_* / COL_* / State / ViewMode）归控制器经 owner. / GraphViewController. 引用。

var owner: GraphViewController

# ===================== 关系判定 =====================
## 线索是否参与了任意玩家连线
func _node_has_user_relation(id: String) -> bool:
	for r in owner._relations:
		if r.get("from", "") == id or r.get("to", "") == id:
			return true
	return false


func _node_tooltip(nd: Dictionary) -> String:
	match nd.kind:
		"clue":
			var c: Dictionary = nd.data
			var who := "未知"
			var rns: Array = c.get("related_npcs", [])
			if not rns.is_empty():
				who = "、".join(rns.map(func(p): return owner._data._person_name(p)))
			return "线索：%s\n%s\n和谁有关：%s" % [c.get("name", ""), c.get("desc", ""), who]
		"hypo":
			return "推断：%s" % [nd.data.get("text", "")]
		"person":
			return "焦点人物：%s" % [nd.label]
		"chain":
			return "推理链：%s" % [nd.label]
		"conclusion":
			return "当前结论：%s" % [nd.label]
	return ""


# ===================== 连线绘制 =====================
## 边缘绘制（按需求5：连线用弧线代替直线）
## 用二次贝塞尔（控制点偏移路径中点垂直方向）实现自然弧度；虚线沿弧线采样。
func _on_edge_draw() -> void:
	var _fh: Dictionary = owner._fold._compute_hidden()
	for e in owner._edge_list:
		var a: Vector2 = owner._node_center.get(e.from, Vector2.ZERO)
		var b: Vector2 = owner._node_center.get(e.to, Vector2.ZERO)
		if a == Vector2.ZERO or b == Vector2.ZERO: continue
		if _fh.has(e.from) or _fh.has(e.to): continue
		var show := false
		if e.always:
			show = true
		elif owner._dragging:
			# 问题3：拖拽节点过程中，悬停高亮会丢失，若仍按「仅高亮节点连线可见」规则会导致全部连线瞬间消失。
			# 拖拽时强制显示所有连线，让玩家在重排时能看清整张关系网。
			show = true
		elif owner._highlight_id != "" and (e.from == owner._highlight_id or e.to == owner._highlight_id):
			show = true
		if not show:
			continue
		if e.kind in ["relate", "imply", "support", "oppose", "contradict", "target"]:
			# 逻辑图流向连线：父右缘→子左缘的 S 曲线（col 间空带通过，不穿框/不交叉）
			_draw_flow_edge(e.from, e.to, e.color, 3, e.dashed)

	# 拖拽预览线（弧线）
	if owner._dragging and owner._drag_id != "":
		var a3: Vector2 = owner._node_center.get(owner._drag_id, Vector2.ZERO)
		if a3 != Vector2.ZERO:
			if owner._drag_mode == "edge":
				_draw_arc_line(a3, owner._drag_preview_pos(), owner._data._rel_color(owner._drag_kind), 2, 40.0)
			elif owner._drag_mode == "move":
				# move 模式不画预览线
				pass

	# 选中边高亮（点击连线后明显的视觉反馈，覆盖在普通边之上）
	if owner._selected_edge >= 0 and owner._selected_edge < owner._edge_list.size():
		var se: Dictionary = owner._edge_list[owner._selected_edge]
		var sa: Vector2 = owner._node_center.get(se.get("from", ""), Vector2.ZERO)
		var sb: Vector2 = owner._node_center.get(se.get("to", ""), Vector2.ZERO)
		if sa != Vector2.ZERO and sb != Vector2.ZERO:
			_draw_flow_edge(se.get("from", ""), se.get("to", ""), owner.COL_GOLD, 7, false)


## 沿 a→b 画一条二次贝塞尔弧线（控制点偏移中点垂直方向 curvature）
func _draw_arc_line(a: Vector2, b: Vector2, col: Color, w: float, curvature: float = 50.0, segments: int = 24) -> void:
	if (a - b).length() < 0.5:
		return
	var mid: Vector2 = (a + b) * 0.5
	var dir: Vector2 = (b - a).normalized()
	var perp: Vector2 = Vector2(-dir.y, dir.x) * curvature
	var ctrl: Vector2 = mid + perp
	var pts := PackedVector2Array()
	for i in segments + 1:
		var t: float = float(i) / float(segments)
		var omt: float = 1.0 - t
		var p: Vector2 = a * omt * omt + ctrl * 2.0 * omt * t + b * t * t
		pts.append(p)
	owner._edge_layer.draw_polyline(pts, col, w, true)


## 沿 a→b 画虚线弧线（沿贝塞尔采样，按 dash 长度切段）
func _draw_arc_dashed(a: Vector2, b: Vector2, col: Color, w: float, curvature: float = 50.0, segments: int = 48, dash_len: float = 8.0, gap_len: float = 6.0) -> void:
	if (a - b).length() < 0.5:
		return
	var mid: Vector2 = (a + b) * 0.5
	var dir: Vector2 = (b - a).normalized()
	var perp: Vector2 = Vector2(-dir.y, dir.x) * curvature
	var ctrl: Vector2 = mid + perp
	# 先采样出所有曲线点
	var pts := PackedVector2Array()
	for i in segments + 1:
		var t: float = float(i) / float(segments)
		var omt: float = 1.0 - t
		var p: Vector2 = a * omt * omt + ctrl * 2.0 * omt * t + b * t * t
		pts.append(p)
	# 沿线段累积长度，按 dash/gap 切段画
	var traveled: float = 0.0
	var next_break: float = dash_len
	var drawing := true
	for i in range(1, pts.size()):
		var p0: Vector2 = pts[i - 1]
		var p1: Vector2 = pts[i]
		var seg_len: float = p0.distance_to(p1)
		var t0: float = traveled
		var t1: float = traveled + seg_len
		while t1 >= next_break:
			if drawing:
				var k: float = (next_break - t0) / seg_len
				owner._edge_layer.draw_line(p0.lerp(p1, clamp(k, 0.0, 1.0)), p1, col, w)
				t0 = next_break
				drawing = false
				next_break += gap_len
			else:
				t0 = next_break
				drawing = true
				next_break += dash_len
		if drawing and i + 1 < pts.size():
			owner._edge_layer.draw_line(p0.lerp(p1, clamp((t1 - t0) / seg_len, 0.0, 1.0)), p0.lerp(p1, 1.0), col, w)
		traveled = t1


## 流向连线：父右缘 → 子左缘 的三次贝塞尔 S 曲线（逻辑图/整洁树专用，替代中心连线）。
## 约定 e.to = 父（高层·在左），e.from = 子（低层·在右）；端点取节点边缘，曲线留在列间空带，
## 不穿框、不交叉；垂直幅度仅限父子 y 差，水平流向贴合「推导方向 = 右向轴」。
func _draw_flow_edge(from_id: String, to_id: String, col: Color, w: float, dashed: bool = false) -> void:
	var pa: Vector2 = owner._node_center.get(to_id, Vector2.ZERO)    # 父（左）
	var cb: Vector2 = owner._node_center.get(from_id, Vector2.ZERO)  # 子（右）
	if pa == Vector2.ZERO or cb == Vector2.ZERO:
		return
	var pk: String = owner._node_kind.get(to_id, "hypo")
	var ck: String = owner._node_kind.get(from_id, "hypo")
	var pw: float = owner._layout._node_width_for_kind(pk) * 0.5
	var cw: float = owner._layout._node_width_for_kind(ck) * 0.5
	var start: Vector2 = pa + Vector2(pw, 0.0)
	var end: Vector2 = cb - Vector2(cw, 0.0)
	# 兜底：若子反而在父左侧（如 person→person 嵌套），退回中心连线，避免反向错位
	if start.x > end.x:
		start = pa
		end = cb
	if dashed:
		_draw_flow_dashed(start, end, col, w)
	else:
		_draw_flow_line(start, end, col, w)


## 父右缘→子左缘 的流向实线（水平 S 三次贝塞尔，控制点在两中点，曲线沿流向轴）
func _draw_flow_line(start: Vector2, end: Vector2, col: Color, w: float, segments: int = 28) -> void:
	if (start - end).length() < 0.5:
		return
	var dx: float = end.x - start.x
	var c1: Vector2 = Vector2(start.x + dx * 0.5, start.y)
	var c2: Vector2 = Vector2(end.x - dx * 0.5, end.y)
	var pts := PackedVector2Array()
	for i in segments + 1:
		var t: float = float(i) / float(segments)
		var omt: float = 1.0 - t
		var p: Vector2 = start * (omt * omt * omt) + c1 * (3.0 * omt * omt * t) + c2 * (3.0 * omt * t * t) + end * (t * t * t)
		pts.append(p)
	owner._edge_layer.draw_polyline(pts, col, w, true)


## 父右缘→子左缘 的流向虚线（沿曲线采样，按 dash/gap 切段）
func _draw_flow_dashed(start: Vector2, end: Vector2, col: Color, w: float, segments: int = 48) -> void:
	if (start - end).length() < 0.5:
		return
	var dx: float = end.x - start.x
	var c1: Vector2 = Vector2(start.x + dx * 0.5, start.y)
	var c2: Vector2 = Vector2(end.x - dx * 0.5, end.y)
	var pts := PackedVector2Array()
	for i in segments + 1:
		var t: float = float(i) / float(segments)
		var omt: float = 1.0 - t
		var p: Vector2 = start * (omt * omt * omt) + c1 * (3.0 * omt * omt * t) + c2 * (3.0 * omt * t * t) + end * (t * t * t)
		pts.append(p)
	var traveled: float = 0.0
	var next_break: float = 8.0
	var drawing := true
	for i in range(1, pts.size()):
		var p0: Vector2 = pts[i - 1]
		var p1: Vector2 = pts[i]
		var seg_len: float = p0.distance_to(p1)
		var t0: float = traveled
		var t1: float = traveled + seg_len
		while t1 >= next_break:
			if drawing:
				var kk: float = (next_break - t0) / seg_len
				owner._edge_layer.draw_line(p0.lerp(p1, clampf(kk, 0.0, 1.0)), p1, col, w)
				t0 = next_break
				drawing = false
				next_break += 6.0
			else:
				t0 = next_break
				drawing = true
				next_break += 8.0
		if drawing and i + 1 < pts.size():
			owner._edge_layer.draw_line(p0.lerp(p1, clampf((t1 - t0) / seg_len, 0.0, 1.0)), p0.lerp(p1, 1.0), col, w)
		traveled = t1


## 旧的直线虚线（保留兼容，未再使用）
func _draw_dashed(a: Vector2, b: Vector2, col: Color, w: float) -> void:
	var dist: float = a.distance_to(b)
	var dash: float = 10.0; var gap: float = 7.0; var seg: float = dash + gap
	if seg <= 0: return
	var steps: int = int(dist / seg)
	var dir: Vector2 = (b - a).normalized()
	var pos: Vector2 = a
	for i in steps:
		var p2: Vector2 = pos + dir * dash
		if p2.distance_to(a) > dist: p2 = b
		owner._edge_layer.draw_line(pos, p2, col, w)
		pos = p2 + dir * gap
	if pos.distance_to(b) > 1.0:
		owner._edge_layer.draw_line(pos, b, col, w)


# ===================== 建边 / 删边 / 改性质（含 UndoRedo） =====================
## 节点层级（ring_depth）：人物/事件=0 ≥ 结论=1 ≥ 推断/链=2 ≥ 线索=3。
## 布局约定 from=子（推导依据·低层）、to=父（被推导·高层）；_add_edge 据此自动归一化连线方向。
func _rd_of_kind(k: String) -> int:
	match k:
		"person", "event": return 0
		"conclusion": return 1
		"hypo", "chain": return 2
		"clue": return 3
		_: return 3

func _add_edge(from: String, to: String, kind: String, color_key: String = "", dashed: bool = false) -> void:
	if owner._state != GraphViewController.State.EDITABLE:
		owner._toast_msg("已封存，仅可浏览")
		return
	# 自动按层级归属（人物 ≥ 结论 ≥ 推断/链 ≥ 线索）：
	# 约定 from = 子（推导依据·层级低 / ring_depth 高），to = 父（被推导·层级高 / ring_depth 低）。
	# 玩家手动连线方向任意，此处统一规范：若 from 的层级高于 to（rd 更小），交换二者，
	# 使 from 始终为低层子节点、to 为高层父节点——即「人物-结论-推断-线索」的放射归属。
	# 仅「人物↔人物」两端 rd 同为 0 时不交换：其从属嵌套方向由 _build_parent_of 单独处理
	# （person→person 边约定 from=上级/父、to=下级/子，如 德雷伯→斯特兰森 = 斯特兰森服务于德雷伯）。
	if _rd_of_kind(owner._fold._kind_of(from)) < _rd_of_kind(owner._fold._kind_of(to)):
		var _sw: String = from
		from = to
		to = _sw
	if from == to:
		owner._toast_msg("线索不能指向自己")
		return
	if color_key == "":
		color_key = owner._data.kind_to_key(kind)
	for r in owner._relations:
		if r.from == from and r.to == to and r.kind == kind:
			owner._toast_msg("这条证据连线已存在")
			return
	owner._undo.create_action("add_edge")
	owner._undo.add_do_method(_do_edge.bind(from, to, kind, color_key, dashed, true))
	owner._undo.add_undo_method(_do_edge.bind(from, to, kind, color_key, dashed, false))
	owner._undo.commit_action()
	if owner._data._id_is_clue(from):
		owner._data._mark_clue_placed(from)
	if owner._data._id_is_clue(to):
		owner._data._mark_clue_placed(to)
	if owner._cb_relations_changed.is_valid():
		owner._cb_relations_changed.call(owner._relations.duplicate())
	owner._persist_view()
	# Issue 4：连边后按新结构树自动重排。被连子节点(from)若仍被钉为手动根锚点，须解除钉位，
	# 否则整棵新子树不随父节点归位（实测「未自动排列」根因）；解除 from 及其后代钉位，
	# 其余分支的手动锚点保留。_relayout_on_edge 令 _compute_layout 忽略 prev_center 全量重排。
	var _unpin_ids: Array = [from] + owner._layout._descendants(from)
	for _u in _unpin_ids:
		if owner._root_anchor_pos.has(_u):
			owner._root_anchor_pos.erase(_u)
		if owner._manual_nodes.has(_u):
			owner._manual_nodes.erase(_u)
	owner._layout._relayout_on_edge = true
	owner._rebuild_graph()
	owner._toast_msg("建立了%s的证据连线" % _rel_verb(kind))


func _rel_verb(kind: String) -> String:
	match kind:
		"support": return owner.VERB_SUPPORT
		"oppose": return owner.VERB_OPPOSE
		"contradict": return owner.VERB_CONTRADICT
		"target": return "归属结论"
		_: return owner.VERB_RELATE


## 两节点间已存在的玩家连线（不分方向，同对节点可能有多条不同 kind，如 support+contradict）
func _relations_between(a: String, b: String) -> Array:
	var out := []
	for r in owner._relations:
		var f: String = r.get("from", "")
		var t: String = r.get("to", "")
		if (f == a and t == b) or (f == b and t == a):
			out.append(r)
	return out


## 删除一条用户建立的连线（需求 2026-08-19：可取消误连；可撤销）
func _remove_edge(from: String, to: String, kind: String) -> void:
	if owner._state != GraphViewController.State.EDITABLE:
		owner._toast_msg("已封存，仅可浏览")
		return
	var target := {}
	for r in owner._relations:
		if r.get("from", "") == from and r.get("to", "") == to and r.get("kind", "") == kind:
			target = r
			break
	if target.is_empty():
		# 需求1：结论→人物 的「方案A」自动派生边不在 _relations，需单独处理删除
		if from.begins_with("conclusion_") and kind == "target":
			var _in_list := false
			for _e in owner._edge_list:
				if _e.get("from", "") == from and _e.get("to", "") == to and _e.get("kind", "") == kind:
					_in_list = true
					break
			if _in_list:
				owner._deleted_target_edges[from] = to
				owner._persist_view()
				owner._rebuild_graph()
				owner._toast_msg("已删除结论与人物连线（可重连）")
				return
		owner._toast_msg("没有这条连线")
		return
	var ck: String = target.get("color_key", "")
	var ds: bool = target.get("dashed", false)
	owner._undo.create_action("remove_edge")
	owner._undo.add_do_method(_do_edge.bind(from, to, kind, ck, ds, false))
	owner._undo.add_undo_method(_do_edge.bind(from, to, kind, ck, ds, true))
	owner._undo.commit_action()
	if owner._cb_relations_changed.is_valid():
		owner._cb_relations_changed.call(owner._relations.duplicate())
	owner._persist_view()
	owner._rebuild_graph()
	owner._toast_msg("已删除%s的连线（Ctrl+Z 可恢复）" % _rel_verb(kind))


func _do_edge(from: String, to: String, kind: String, color_key: String, dashed: bool, add: bool) -> void:
	var kept := []
	for r in owner._relations:
		if not (r.from == from and r.to == to and r.kind == kind):
			kept.append(r)
	if add:
		kept.append({"from": from, "to": to, "kind": kind, "color_key": color_key, "dashed": dashed})
	owner._relations = kept
	# 同步线索 associated 标记 → 节点实线绿边（已关联视觉反馈），无连线则复位
	owner._sync_clue_associated()


# ===================== 连线命中 / 右键菜单 =====================
func _bezier(a: Vector2, ctrl: Vector2, b: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return a * u * u + ctrl * 2.0 * u * t + b * t * t


func _edge_hit_test(lp: Vector2) -> int:
	var best := -1
	var best_d := 16.0
	for ei in owner._edge_list.size():
		var e: Dictionary = owner._edge_list[ei]
		var a: Vector2 = owner._node_center.get(e.get("from", ""), Vector2(-1e6, -1e6))
		var b: Vector2 = owner._node_center.get(e.get("to", ""), Vector2(-1e6, -1e6))
		if a.x < -1e5 or b.x < -1e5:
			continue
		var mid := (a + b) / 2.0
		var delta := b - a
		var perp := Vector2(-delta.y, delta.x).normalized() * 50.0
		var ctrl := mid + perp
		var dmin := 1e9
		var t := 0.0
		while t <= 1.0:
			var p := _bezier(a, ctrl, b, t)
			var d := lp.distance_to(p)
			if d < dmin:
				dmin = d
			t += 0.01
		if dmin < best_d:
			best_d = dmin
			best = ei
	return best


func _select_edge(ei: int, viewport_pos: Vector2) -> void:
	owner._selected_edge = ei
	_show_edge_menu(viewport_pos, owner._edge_list[ei])
	owner._toast_msg("已选中连线")


func _show_edge_menu(viewport_pos: Vector2, e: Dictionary) -> void:
	_close_edge_menu()
	var panel := PanelContainer.new()
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	var lab := Label.new()
	lab.text = "连线：%s → %s（%s）" % [e.get("from", ""), e.get("to", ""), _rel_verb(e.get("kind", ""))]
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lab)
	var sep := HSeparator.new()
	vbox.add_child(sep)
	var b_del := _mk_menu_btn("✕  删除连线")
	b_del.pressed.connect(func() -> void: _edge_delete(e))
	vbox.add_child(b_del)
	var b_dash := _mk_menu_btn("⊸  线型切换")
	b_dash.pressed.connect(func() -> void: _edge_toggle_dashed(e))
	vbox.add_child(b_dash)
	var b_kind := _mk_menu_btn("↻  性质切换")
	b_kind.pressed.connect(func() -> void: _edge_cycle_kind(e))
	vbox.add_child(b_kind)
	panel.add_child(vbox)
	panel.position = viewport_pos + Vector2(8, 8)
	owner.add_child(panel)
	panel.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			var lp := (owner.get_global_mouse_position() - owner._canvas.position) / owner._canvas.scale
			if _edge_hit_test(lp) != owner._selected_edge:
				owner._selected_edge = -1
				_close_edge_menu()
			owner._redraw_all()
	)
	owner._edge_menu = panel


func _mk_menu_btn(txt: String) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(180, 30)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


func _close_edge_menu() -> void:
	if owner._edge_menu and is_instance_valid(owner._edge_menu):
		owner._edge_menu.queue_free()
	owner._edge_menu = null


func _edge_delete(e: Dictionary) -> void:
	if owner._state != GraphViewController.State.EDITABLE:
		owner._toast_msg("已封存，仅可浏览")
		return
	_remove_edge(e.get("from", ""), e.get("to", ""), e.get("kind", ""))
	_close_edge_menu()
	owner._selected_edge = -1
	owner._toast_msg("连线已删除")


func _edge_toggle_dashed(e: Dictionary) -> void:
	if owner._state != GraphViewController.State.EDITABLE:
		owner._toast_msg("已封存，仅可浏览")
		return
	var from: String = e.get("from", "")
	var to: String = e.get("to", "")
	var kind: String = e.get("kind", "")
	var new_dash: bool = not bool(e.get("dashed", false))
	owner._undo.create_action("toggle_edge_dashed")
	owner._undo.add_do_method(_do_set_dashed.bind(from, to, kind, new_dash))
	owner._undo.add_undo_method(_do_set_dashed.bind(from, to, kind, not new_dash))
	owner._undo.commit_action()
	_close_edge_menu()
	if owner._cb_relations_changed.is_valid():
		owner._cb_relations_changed.call(owner._relations.duplicate())
	owner._persist_view()
	owner._rebuild_graph()
	owner._toast_msg("线型已切换")


func _do_set_dashed(from: String, to: String, kind: String, dashed: bool) -> void:
	for r in owner._relations:
		if r.from == from and r.to == to and r.kind == kind:
			r["dashed"] = dashed
			break


func _edge_cycle_kind(e: Dictionary) -> void:
	if owner._state != GraphViewController.State.EDITABLE:
		owner._toast_msg("已封存，仅可浏览")
		return
	var KINDS: Array[String] = ["relate", "support", "oppose", "contradict", "target"]
	var from: String = e.get("from", "")
	var to: String = e.get("to", "")
	var old_kind: String = e.get("kind", "relate")
	var idx: int = KINDS.find(old_kind)
	var new_kind: String = KINDS[(idx + 1) % KINDS.size()]
	var dashed: bool = e.get("dashed", false)
	owner._undo.create_action("change_edge_kind")
	owner._undo.add_do_method(_do_change_edge_kind.bind(from, to, old_kind, dashed, new_kind))
	owner._undo.add_undo_method(_do_change_edge_kind.bind(from, to, new_kind, dashed, old_kind))
	owner._undo.commit_action()
	_close_edge_menu()
	if owner._cb_relations_changed.is_valid():
		owner._cb_relations_changed.call(owner._relations.duplicate())
	owner._persist_view()
	owner._rebuild_graph()
	owner._toast_msg("连线性质已切换为 %s" % _rel_verb(new_kind))


func _do_change_edge_kind(from: String, to: String, old_kind: String, dashed: bool, new_kind: String) -> void:
	var changed := false
	for r in owner._relations:
		if r.from == from and r.to == to and r.kind == old_kind:
			r["kind"] = new_kind
			r["dashed"] = dashed
			r["color_key"] = owner._data.kind_to_key(new_kind)
			changed = true
			break
	if not changed:
		owner._relations.append({"from": from, "to": to, "kind": new_kind, "color_key": owner._data.kind_to_key(new_kind), "dashed": dashed})
