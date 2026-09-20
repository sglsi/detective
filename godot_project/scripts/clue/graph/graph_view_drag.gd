extends RefCounted
class_name GraphViewDrag

## 图谱视图 · 拖拽/重叠子系统（拆自 graph_view_controller.gd 的「交互」段）
## 职责：节点移动提交(commit_move)、拖动落点建边(commit_drag)、换侧(try_switch_subtree_side)、
## 命中测试(drop_node_except/nearest_node_except/node_at)、推离与去重叠(nudge_away_from/resolve_overlap_for/node_collides)。
## 全部状态/常量/方法经 owner. 回读；本组件只持有自洽逻辑。

var owner: GraphViewController

func commit_move(id: String, at: Vector2 = Vector2.INF) -> void:
	var gp: Vector2 = owner.get_viewport().get_mouse_position() if at == Vector2.INF else at
	var moved := gp.distance_to(owner._drag_start) > 8.0
	var _side_switched := false
	var _edge_created := false   # 本次拖动是否建立了关系（=结构性变更，须跑去重叠）
	var _keep_x_pin := true      # 拖拽收尾是否把被拖节点钉在落点（人物关联边的非人物端不钉，见下方修订注释）
	if moved and owner._state == owner.State.EDITABLE:
		var drop: String = drop_node_except(gp, id)
		if drop == "":
			# 容错：未精确落在目标框内时，找 48px 内最近的节点（差几个像素也要能建边）
			drop = nearest_node_except(gp, id, 48.0)
		if drop != "":
			# 环防护：drop 已在拖动节点的子树里（id 是 drop 的祖先）时，id→drop 会闭合推理环，
			# 布局 BFS 会因此丢节点（树断、拖动全面异常）——拒绝建边，按「移动到落点」处理。
			if owner._layout._descendants(drop).has(id):
				owner._toast_msg("不能连接到自己的下级节点，已按移动处理")
				drop = ""
		if drop == "":
			# 需求（思傅 2026-09-09）：把「人物直接子（结论）」整棵子树拖过人物中线 → 换侧重排
			_side_switched = try_switch_subtree_side(id, gp)
		if drop != "":
			var drop_kind: String = owner._node_kind.get(drop, "")
			var id_kind: String = owner._node_kind.get(id, "")
			# 结论/推断/推理链 ↔ 人物：无论正向（结论拖到人物）还是反向（人物拖到结论），
			# 都强制建「归属边」(target 金边)。旧 bug：反向拖时 _add_edge 只交换端点、不修正 kind，
			# 结论→人物边被记成 support/relate，验证器按 kind=="target" 比对失败 → 误报"未连接到人物"。
			if drop_kind == "person" or id_kind == "person":
				var person_id: String = drop if drop_kind == "person" else id
				var other_id: String = id if drop_kind == "person" else drop
				var other_kind: String = owner._node_kind.get(other_id, "")
				if other_kind == "clue":
					owner._tag_person(other_id, person_id)
				else:
					owner._edge._add_edge(other_id, person_id, "target", "gold", false)
					_edge_created = true
					nudge_away_from(other_id, person_id)
			elif drop_kind in ["hypo", "clue", "conclusion"]:
				owner._edge._add_edge(id, drop, owner._data.key_to_kind(owner._pen_color_key), owner._pen_color_key, owner._pen_dashed)
				_edge_created = true
				# 任务4：建立关系后把被拖节点推离目标框，避免落点重叠、并按关系就近排布
				nudge_away_from(id, drop)
			# 建边/标记路径钉位（2026-09-19 思傅报「关联后人物被盖 / 中间链干右叶左」修订）：
			# 与人物的关联边 = 结构性变更（新边改变关系树拓扑）。被拖结论若钉在落点，会与
			# 左右平衡布局脱钩——干（结论）留在人物右侧旧落点、其叶枝被镜像派生到另一侧
			#（症状②「干右叶左」）；且与人物构成双刚性使全局去重叠永久跳过（症状①人物被盖）。
			# 与换侧（try_switch_subtree_side）同口径：清被拖结论及其后代、对端旧钉位，
			# 置 _relayout_on_edge 全量重排——新链按「以人物为中心、左=叶-枝-干-根 /
			# 右=根-干-枝-叶」整洁归位。被拖节点是人物本身（拖人物到结论上归属）→ 保留钉位
			#（玩家在移动人物，落点须尊重），仅清对端结论的旧钉位。
			var _person_assoc: bool = _edge_created and (drop_kind == "person" or id_kind == "person")
			if _person_assoc:
				if not (id_kind in ["person", "event"]):
					_keep_x_pin = false
					var _rel_ids: Array = [id]
					for _d in owner._layout._descendants(id):
						_rel_ids.append(str(_d))
					for _rid in _rel_ids:
						var _rs := str(_rid)
						owner._root_anchor_pos.erase(_rs)
						owner._manual_nodes.erase(_rs)
						owner._node_offsets.erase(_rs)
				if drop != "" and not (owner._node_kind.get(drop, "") in ["person", "event"]):
					owner._root_anchor_pos.erase(drop)
					owner._manual_nodes.erase(drop)
					owner._node_offsets.erase(drop)
				owner._state_store["graph_root_anchors"] = owner._root_anchor_pos
				owner._state_store["graph_manual_nodes"] = owner._manual_nodes.duplicate()
				owner._state_store["graph_node_offsets"] = owner._node_offsets.duplicate()
				owner._layout._relayout_on_edge = true   # 忽略拖前旧位，按新拓扑全量重排
			elif owner._node_center.has(id):
				owner._root_anchor_pos[id] = owner._node_center[id]
				if not (id in owner._manual_nodes):
					owner._manual_nodes.append(id)
		if moved and not _side_switched:
			# 规则1/2/3：被拖节点(X)停在玩家手动位(新位置钉入 owner._root_anchor_pos + 登记 owner._manual_nodes)，
			# 而其全部后代的「旧手动位」一律清空——让它们从 X 的新位置自动重新派生(向上不动、随上属走)。
			# 这同时修复两类观感异常：
			#  · 问题1 人物拖动后，曾被手动拖过的下属仍钉在旧位 → 清掉后代手动位→随人物新位重排；
			#  · 问题2 拖动结论/推断后，其下属仍相对根(人物)排列而非相对本节点 → 清掉后代手动位后，
			#    _assign_subtree 以 X(已钉手动位)为锚、下游子树据此生长，下属随本节点走。
			# 只清 X 的后代，不影响其它分支的手动位；X 自身保持手动位(玩家落点)。
			# 例外（2026-09-19）：人物关联边的非人物端（被拖结论）不钉位——钉住会与平衡布局
			# 脱钩（干留落点、叶枝镜像到另一侧），且与人物双刚性令去重叠永久跳过（人物被盖）。
			if _keep_x_pin:
				owner._root_anchor_pos[id] = owner._node_center[id]
				if not (id in owner._manual_nodes):
					owner._manual_nodes.append(id)
			for _d in owner._layout._descendants(id):
				if _d in owner._manual_nodes:
					owner._manual_nodes.erase(_d)
				if owner._root_anchor_pos.has(_d):
					owner._root_anchor_pos.erase(_d)
				if owner._node_offsets.has(_d):
					owner._node_offsets.erase(_d)
			owner._state_store["graph_root_anchors"] = owner._root_anchor_pos
			owner._state_store["graph_manual_nodes"] = owner._manual_nodes.duplicate()
			owner._state_store["graph_node_offsets"] = owner._node_offsets.duplicate()
	elif not moved:
		owner._on_node_clicked(id, owner._node_kind.get(id, ""))
	owner._layout._persist_node_positions()
	# 复位拖拽期间的视觉态（缩小/置顶/半透明），避免建关系后残留
	var nd: Control = owner._node_views.get(id)
	if nd and is_instance_valid(nd):
		nd.scale = Vector2.ONE
		nd.z_index = 0
		nd.modulate = Color(1, 1, 1, 1)
	owner._dragging = false
	owner._drag_id = ""
	owner._drag_mode = ""
	owner._fold._sync_fold_controls_positions()
	# 第8节改造（A①+B①）：移动/建关系后整树按星形重排——根锚点保留、子节点回派生位
	if moved:
		# 换侧 = 整墙按左右平衡重排，需要执行去重叠；普通拖动仍跳过（否则上游节点被推走=观感"自动排列"）。
		# 2026-09-15：**建立了关系的拖动**属结构性变更，必须执行去重叠——否则被拖节点停在落点、
		# 若压到第三个节点就永久互相覆盖（用户报 bug：调整文本框关系后出现覆盖）。
		owner._post_drag = (not _side_switched) and (not _edge_created)
		owner._rebuild_graph()
		if _side_switched:
			owner._persist_view()
			owner.fit_view()
	owner._redraw_all()


## 拖拽换侧（思傅 2026-09-09 需求2）：把「人物的直接子（结论）」整棵子树拖过人物中线 → 改挂另一侧。
## 判定：① 被拖节点的父必须是人物（换侧最小单位 = 整棵结论子树，拖推断/线索不触发）；
##       ② 落点相对人物中心越过 ±40px 阈值，且与当前所在侧相反。
## 触发后：记录 side（落盘持久）→ 进入左右平衡布局并定格 → 清掉本子树与人物根的钉位/偏移，
##       使人物回中心、本子树按「左=叶-枝-干-根 / 右=根-干-枝-叶」整洁重排。返回是否触发。
func try_switch_subtree_side(id: String, gp: Vector2) -> bool:
	if owner._canvas == null or not is_instance_valid(owner._canvas):
		return false
	var parent_of: Dictionary = owner._layout._build_parent_of()
	var par: String = str(parent_of.get(id, ""))
	if par == "" or str(owner._node_kind.get(par, "")) != "person":
		return false
	var root_c: Vector2 = owner._node_center.get(par, Vector2.ZERO)
	var local: Vector2 = owner._canvas.get_global_transform().affine_inverse() * gp
	# 当前侧：玩家已手动指定优先，其次取上次平衡布局的分派结果，默认右（默认布局纯右向）
	var cur_side: String = str(owner._subtree_sides.get(id, owner._last_layout_sides.get(id, "R")))
	var new_side: String = cur_side
	if local.x < root_c.x - 40.0:
		new_side = "L"
	elif local.x > root_c.x + 40.0:
		new_side = "R"
	if new_side == cur_side:
		return false
	owner._subtree_sides[id] = new_side
	owner._balanced_layout = true          # 换侧需侧向布局支撑：进入左右平衡布局并定格
	# 本子树 + 人物根回归自动排布（清钉位/偏移），否则会停在落点、不按整洁顺序展现
	var _release: Array = [id, par]
	for _d in owner._layout._descendants(id):
		_release.append(str(_d))
	for _rid in _release:
		var rs: String = str(_rid)
		owner._root_anchor_pos.erase(rs)
		owner._manual_nodes.erase(rs)
		owner._node_offsets.erase(rs)
	owner._state_store["graph_root_anchors"] = owner._root_anchor_pos
	owner._state_store["graph_manual_nodes"] = owner._manual_nodes.duplicate()
	owner._state_store["graph_node_offsets"] = owner._node_offsets.duplicate()
	owner._state_store["graph_subtree_sides"] = owner._subtree_sides.duplicate()
	owner._state_store["graph_balanced_layout"] = true
	owner._layout._relayout_on_edge = true   # 忽略拖前旧位，按新侧全量重排
	owner._toast_msg("已把该分支移到人物%s侧" % ("左" if new_side == "L" else "右"))
	return true


## 查找 gp 处命中的节点，排除 exclude_id（拖动中被拖节点自身可能压住目标）
func drop_node_except(gp: Vector2, exclude_id: String) -> String:
	var local := owner._canvas.get_global_transform().affine_inverse() * gp
	for id in owner._node_views:
		if id == exclude_id: continue
		var n: Control = owner._node_views[id]
		if not is_instance_valid(n): continue
		if Rect2(n.position, n.size).has_point(local):
			return id
	return ""


## 找距离 gp 最近且不超过 max_dist 的节点（排除 exclude_id）
func nearest_node_except(gp: Vector2, exclude_id: String, max_dist: float) -> String:
	var local := owner._canvas.get_global_transform().affine_inverse() * gp
	var best := ""
	var best_d := max_dist
	for id in owner._node_views:
		if id == exclude_id: continue
		var n: Control = owner._node_views[id]
		if not is_instance_valid(n): continue
		var c := n.position + n.size * 0.5
		var d := c.distance_to(local)
		if d < best_d:
			best_d = d
			best = id
	return best


## 任务4：建立关系后把被拖节点推离目标框，避免落点重叠（拖到目标上即建边，易压住目标）。
## 仅当两框中心距 < 两框半宽之和+余量才推；推到目标外侧 min_dist 处，并更新位置缓存与持久化。
func nudge_away_from(id: String, drop: String) -> void:
	var a: Control = owner._node_views.get(id)
	var b: Control = owner._node_views.get(drop)
	if a == null or b == null or not is_instance_valid(a) or not is_instance_valid(b): return
	var ac: Vector2 = a.position + a.size * 0.5
	var bc: Vector2 = b.position + b.size * 0.5
	var dv: Vector2 = ac - bc
	if dv == Vector2.ZERO: dv = Vector2(0, 1)
	var min_dist: float = (a.size.x + b.size.x) * 0.5 + 24.0
	if dv.length() < min_dist:
		dv = dv.normalized()
		var new_c: Vector2 = bc + dv * min_dist
		a.position = new_c - a.size * 0.5
		owner._node_center[id] = new_c
		owner._all_positions[id] = new_c
	# 2026-09-15：只推离「目标框」不够——若推开的落点又压住**第三个**节点，
	# 松手后 X 会被钉在此处，而全局去重叠又不动钉位节点 → 永久互相覆盖（用户报 bug）。
	# 故这里再确保落点与任何现有节点都不相交（螺旋找空位）。
	resolve_overlap_for(id)
	owner._layout._persist_node_positions()
	owner._redraw_all()


## 把节点放到「不与任何其它节点相交（留 24px 间隙）」的位置：原位可用则不动，否则螺旋外扩找空位。
## 判定用**真实视图矩形**（Control.position/size），与玩家所见一致。
func resolve_overlap_for(id: String) -> void:
	var v: Control = owner._node_views.get(id)
	if v == null or not is_instance_valid(v): return
	var base: Vector2 = v.position + v.size * 0.5
	if not node_collides(id, base):
		owner._node_center[id] = base
		owner._all_positions[id] = base
		return
	for ring in range(1, 13):
		var count: int = maxi(8, ring * 8)
		var r: float = 60.0 * (1.0 + ring * 0.5)
		for i in count:
			var ang: float = float(i) / float(count) * TAU + ring * 0.4
			var cand: Vector2 = base + Vector2(cos(ang), sin(ang)) * r
			if not node_collides(id, cand):
				v.position = cand - v.size * 0.5
				owner._node_center[id] = cand
				owner._all_positions[id] = cand
				return
	owner._node_center[id] = base
	owner._all_positions[id] = base


## 以「真实视图矩形 + 24px 间隙」判断 center 处是否与其它节点相撞（含钉位节点，一律避开）
func node_collides(id: String, center: Vector2) -> bool:
	var v: Control = owner._node_views.get(id)
	if v == null or not is_instance_valid(v): return false
	var mine := Rect2(center - v.size * 0.5, v.size).grow(24.0)
	for other in owner._node_views:
		if str(other) == id: continue
		var o: Control = owner._node_views[other]
		if o == null or not is_instance_valid(o): continue
		if Rect2(o.position, o.size).intersects(mine):
			return true
	return false


## 提交建边（拖到另一节点上 = 加证据连线；落空 = 取消）
func commit_drag(id: String) -> void:
	var gp: Vector2 = owner.get_viewport().get_mouse_position()
	var drop: String = node_at(gp)
	owner._dragging = false
	owner._drag_id = ""
	owner._drag_mode = ""
	owner._redraw_all()
	if drop == "" or drop == id:
		if drop == id:
			owner._on_node_clicked(id, owner._node_kind.get(id, ""))
		return
	if owner._state != owner.State.EDITABLE:
		owner._toast_msg("已封存，仅可浏览")
		return
	var drop_kind: String = owner._node_kind.get(drop, "")
	var id_kind: String = owner._node_kind.get(id, "")
	# 结论/推断/推理链 ↔ 人物：正向/反向拖都强制建 target 金边（修反向拖 kind 错配，同 commit_move）
	if drop_kind == "person" or id_kind == "person":
		var person_id: String = drop if drop_kind == "person" else id
		var other_id: String = id if drop_kind == "person" else drop
		var other_kind: String = owner._node_kind.get(other_id, "")
		if other_kind == "clue":
			owner._tag_person(other_id, person_id)
		else:
			owner._edge._add_edge(other_id, person_id, "target", "gold", false)
	elif drop_kind in ["hypo", "clue", "conclusion"]:
		owner._edge._add_edge(id, drop, owner._drag_kind, owner._drag_color_key, owner._drag_dashed)
	else:
		owner._on_node_clicked(id, owner._node_kind.get(id, ""))


func node_at(gp: Vector2) -> String:
	# 把全局坐标转画布本地，命中节点包围盒
	for id in owner._node_views:
		var n: Control = owner._node_views[id]
		if not is_instance_valid(n): continue
		var local := owner._canvas.get_global_transform().affine_inverse() * gp
		if Rect2(n.position, n.size).has_point(local):
			return id
	return ""