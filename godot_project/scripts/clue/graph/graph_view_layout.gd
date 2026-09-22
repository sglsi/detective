extends RefCounted
class_name GraphViewLayout

## 图谱视图 · 布局层（拆自 graph_view_controller.gd，Request C 后架构分层）
##
## 职责：模式 C 关系树布局 / 模式 B 纵向分层 / XMind 自由布局（保留但当前未启用）/
## 节点尺寸估算（宽高）/ 画布钳制（clamp_free 放开范围=任务6）/ 位置持久化。
## 读取 owner（GraphViewController）的画布与状态；常量 _RING_BANDS 归控制器经 owner. 引用。

var owner: GraphViewController

## 连边后请求一次「按结构全量重排」：置 true 后下一次 _compute_layout 会忽略 prev_center
## （不沿用拖前旧位），让非锚定节点按新父子树结构重新放射，仅保留玩家手动锚定的根位置。
## 由 graph_view_edge._add_edge 在 _rebuild_graph 前点亮，_compute_layout 内消费后归位。
var _relayout_on_edge := false

## 测量前置复用的临时 Label（加入 _canvas 树以解析默认字体/主题）：
## 布局期（视图尚未建）用它与 _make_node 同口径的字体度量即时测算节点真实高度。
var _meas_lab: Label = null

## 行距放宽系数（残留重叠兜底专用 · 2026-09-21）：整洁树网格被「钉位/存盘位」或比
## 预估更高的卡片撑破、去重叠又无法整分量平移解决（同分量相交）时，
## 整体放宽带间间隙再排一次——同律加宽，美学1~5 全部保持。
var _row_step_scale: float = 1.0

## ⚠️ 待定产品决策（P4 · 2026-09-22）：一个弱连通分量的「多棵结构树根」如何统一？
##   false（当前默认，= 既有语义 + test_wrap_layout G1 断言）：
##     悬空根按其**真实连线**挂到目标节点之下（relate 相连的结论/推断/线索**同行**成一条水平链）；
##     实质性支撑树各自独立水平带（fc38bdc）—— 即旧的 _merge_component_forest。
##   true（P4 新语义）：整分量挂一个**虚拟根**，各结构树根成为其**兄弟**（各自占一行，呈"一个树的多分支"）。
##   两者都满足"组件=一棵视觉树"，差别只在「同一条视觉链的节点是否同行」。
##   切换后跑 tools/test_wrap_layout.gd 段 G + tools/test_p4_vroot_repro.gd 即可看到差异。
var _unify_component_as_branch_tree: bool = false   # 运行期可切换，便于测试与 A/B 评估（见上方说明）

# ===================== 节点尺寸估算 =====================
## 节点卡片真实高度：视图已测量用视图，否则回退字符估算
func _view_height(id: String) -> float:
	var v: Variant = owner._node_views.get(id)
	if v != null:
		var _sz: Vector2 = v.size
		if _sz.y > 1.0:
			return _sz.y
	return _est_node_h({})


## 节点卡片真实宽度：视图已测量用视图，否则回退 kind 估算宽
## 2026-09-08 修复：_make_node 实际宽度常大于 _node_width_for_kind 估算（如 hypo 140→238、conclusion 160→216），
## 布局若按估算宽定列距，会导致相邻列节点左右贴在一起 / 重叠。
func _view_width(id: String) -> float:
	var v: Variant = owner._node_views.get(id)
	if v != null:
		var _sz: Vector2 = v.size
		if _sz.x > 1.0:
			return _sz.x
	return _node_width_for_kind(str(owner._node_kind.get(id, "")))


## 同列纵向去重叠：同一列（x 相邻）节点按真实卡片高度，保证相邻卡片上下边距 ≥15px，
## 并把整列回居中避免整体下沉堆出画布
func _apply_column_overlap_fix() -> void:
	# 钉位子树全集：拖动过的根及其后代整体刚性，去重叠时跳过（不让后代被推散）
	var _prot: Dictionary = _pinned_subtree_nodes()
	var cols: Dictionary = {}
	for id in owner._node_center:
		var x: float = (round(owner._node_center[id].x / 8.0) * 8.0)
		if not cols.has(x):
			cols[x] = []
		cols[x].append(id)
	for x in cols:
		var arr: Array = cols[x]
		if arr.size() < 2:
			continue
		arr.sort_custom(func(a, b): return owner._node_center[a].y < owner._node_center[b].y)
		var _cy_before: float = 0.0
		for i in arr.size():
			_cy_before += owner._node_center[arr[i]].y
		_cy_before /= float(arr.size())
		for i in range(1, arr.size()):
			# 钉位子树（根+后代）整体刚性：去重叠时跳过，避免后代被推散（与 _apply_global_overlap_fix 同口径）
			if owner._manual_nodes.has(str(arr[i])) or _prot.has(str(arr[i])):
				continue
			var _ha: float = _view_height(arr[i - 1])
			var _hb: float = _view_height(arr[i])
			var _min_cy: float = owner._node_center[arr[i - 1]].y + (_ha + _hb) * 0.5 + 80.0
			if owner._node_center[arr[i]].y < _min_cy:
				owner._node_center[arr[i]] = Vector2(owner._node_center[arr[i]].x, _min_cy)
		var _cy_after: float = 0.0
		for i in arr.size():
			_cy_after += owner._node_center[arr[i]].y
		_cy_after /= float(arr.size())
		var _shift: float = _cy_before - _cy_after
		for i in arr.size():
			var id2: String = arr[i]
			owner._node_center[id2] = Vector2(owner._node_center[id2].x, owner._node_center[id2].y + _shift)
			var vv: Variant = owner._node_views.get(id2)
			if vv != null:
				vv.position = owner._node_center[id2] - vv.size * 0.5


## 被手动拖拽钉住的「子树」全集（含钉位根自身 + 其全部后代）。
## 供去重叠修复跳过：被拖动过的整棵子树保持刚性、不被去重叠推散
## （2026-09-05 修复「松手后子节点偏移/回弹」根因之二——原只保护钉位根、不保护后代，
## 导致后代重叠时被独立推开、与父错位）。
func _pinned_subtree_nodes() -> Dictionary:
	var pinned: Array = owner._root_anchor_pos.keys()
	if pinned.is_empty():
		return {}
	var parent_of := _build_parent_of()
	var child_map := {}
	for ch in parent_of:
		var p: String = parent_of[ch]
		if not child_map.has(p): child_map[p] = []
		if not (ch in child_map[p]): child_map[p].append(ch)
	var prot := {}
	for _r in pinned:
		var rs := str(_r)
		prot[rs] = true
		var q := [rs]
		while q.size() > 0:
			var u: String = q.pop_back()
			for c in child_map.get(u, []):
				var cs := str(c)
				if prot.has(cs): continue
				prot[cs] = true
				q.append(cs)
	return prot


## 全局跨列去重叠（仅自动排列时调用）：AABB 相交检测 + 垂直推开，保持各列 x 结构不变。
##
## 2026-09-15 修复「调整（新建/删除）文本框关系后互相覆盖」：
##   旧实现**只推 `id_b`（y 较大者）**，且当 `id_b` 是钉位节点时直接 `continue`。
##   于是「非钉位节点压在被钉住的节点上」这一类相交**永远修不掉**——
##   而"钉位节点"恰恰来自玩家刚拖动/刚建过关系的那一个（_manual_nodes），
##   所以每次调整关系后就会看到文本框互相覆盖（用户截图：两个相邻推断框叠在一起）。
## 新实现：按「谁刚性」决定推谁——
##   · 双方刚性   → 跳过（不动玩家落点，避免"自动排列"观感）
##   · 下方刚性   → 把**上方可动**节点往上推到不相交
##   · 上方刚性   → 把**下方可动**节点往下推到不相交
##   · 双方可动   → 推下方（保持原行为，改动最小）
## 并改为多轮迭代：推开一个节点可能又与邻居相撞，迭代至收敛（上限 4 轮）。
func _apply_global_overlap_fix() -> void:
	var ids: Array = owner._node_center.keys()
	if ids.size() < 2:
		return
	# 钉位子树全集：拖动过的根及其后代整体刚性，去重叠时跳过（不让后代被推散）
	var _prot: Dictionary = _pinned_subtree_nodes()
	# 2026-09-21（思傅截图2：首条纯链被孤立人物顶成阶梯）——推挤单位从「单节点」升格为
	# 「弱连通分量整块」：旧实现把与人物相撞的结论单独垂直推下（推断/线索留在原 y），
	# 父居中于子/同层共线当场破坏，链条成阶梯。整洁树美学为纲（思傅定案）→ 任何避让都
	# 不得改变树内相对形状：整分量同 dy 刚性平移（x 不变=列结构不变；相对 y 不变=五律不变）。
	#   · 分量 = _relation_components()（忽略方向与 kind）；孤立节点各自成单点分量。
	#   · 含刚性节点（_manual_nodes/钉位子树）的分量整块视为刚性，不可推。
	#   · 双方皆可动 → 推「节点数更少的分量」（孤立单点让位，整树保持居中整洁带位）；
	#     同为单点或同为多节点 → 沿旧口径推下方分量。
	#   · 同分量内部重叠：整块平移无法解决，跳过（由布局本身的兄弟/父子间隔保证不发生）。
	var _comp: Dictionary = _relation_components()
	var _comp_of := {}
	var _comp_members := {}
	for id in ids:
		var key: String = ("c" + str(int(_comp[id]))) if _comp.has(id) else ("s" + str(id))
		_comp_of[id] = key
		if not _comp_members.has(key):
			_comp_members[key] = []
		_comp_members[key].append(id)
	var _comp_fixed := {}
	for key in _comp_members:
		var fx := false
		for mid in _comp_members[key]:
			if owner._manual_nodes.has(mid) or _prot.has(mid):
				fx = true
				break
		_comp_fixed[key] = fx
	ids.sort_custom(func(a, b): return owner._node_center[a].y < owner._node_center[b].y)
	var rects := {}
	for id in ids:
		rects[id] = _node_rect(id)
	for _pass in range(4):
		var moved_any := false
		for i in ids.size():
			var id_a: String = ids[i]
			for j in range(i + 1, ids.size()):
				var id_b: String = ids[j]
				if _comp_of[id_a] == _comp_of[id_b]:
					continue   # 同分量内部重叠：整块平移无解，跳过（布局间隔保证不发生）
				var ra: Rect2 = rects[id_a]
				var rb: Rect2 = rects[id_b]
				if not ra.intersects(rb):
					continue
				var a_fixed: bool = _comp_fixed[_comp_of[id_a]]
				var b_fixed: bool = _comp_fixed[_comp_of[id_b]]
				if a_fixed and b_fixed:
					# 双方都是玩家落点（刚性）：不挪动，避免拖动松手后被"自动排列"
					continue
				# 选被推方：对侧刚性 → 推本侧；双方可动 → 推节点数更少的分量（孤立单点让位）
				var push_a := false
				if b_fixed:
					push_a = true
				elif not a_fixed:
					var sa: int = (_comp_members[_comp_of[id_a]] as Array).size()
					var sb: int = (_comp_members[_comp_of[id_b]] as Array).size()
					if sa < sb:
						push_a = true
				if push_a:
					# 上方分量整块上移：使 a 底边 ≤ b 顶边 − 80
					var push_up: float = ra.end.y - rb.position.y + 80.0
					for pid in _comp_members[_comp_of[id_a]]:
						owner._node_center[pid] = Vector2(owner._node_center[pid].x,
							owner._node_center[pid].y - push_up)
						rects[pid] = _node_rect(pid)
						_sync_node_view(pid)
				else:
					# 下方分量整块下移
					var push: float = ra.end.y - rb.position.y + 80.0
					for pid in _comp_members[_comp_of[id_b]]:
						owner._node_center[pid] = Vector2(owner._node_center[pid].x,
							owner._node_center[pid].y + push)
						rects[pid] = _node_rect(pid)
						_sync_node_view(pid)
				moved_any = true
		if not moved_any:
			break
		# 位置已变：按新 y 重排（保证推挤方向性）并重算矩形
		ids.sort_custom(func(a, b): return owner._node_center[a].y < owner._node_center[b].y)
		for id in ids:
			rects[id] = _node_rect(id)
	for id in ids:
		owner._node_center[id] = _clamp_to_canvas(owner._node_center[id])
		_sync_node_view(id)


## ===================== 残留重叠兜底（整洁树优先 · 2026-09-21） =====================
## 背景：思傅截图3——链路卡片上下叠压（同列相邻卡间距 245px 而非 480px）。
##   端到端复现证明「干净拓扑 + 干净状态」布局零重叠，故残留重叠必来自卡片位置状态
##   （玩家钉位/存盘位把卡片放到了非网格位置），且整分量平移无法解决（同分量相交 → 跳过）。
## 取舍（思傅定案「整洁树美学为纲，其余皆为补充」）：钉位是补充，冲突时让位——
##   ① 先撤掉相交双方里「非人物/事件」的钉位 → 重排（回到整洁树位）；
##   ② 仍相交 → 行距放宽（同律加宽，美学1~5 不变）→ 重排；
##   ③ 仍相交 → 兜底把相交双方中「节点更少的分量」整块刚性平移分开（最终硬保证零重叠）。
## 全程有界（≤3 轮），且仅在真的残留重叠时才触发，正常路径行为不变。
func _has_overlap() -> bool:
	var ids: Array = owner._node_center.keys()
	ids.sort()
	var rects := {}
	for id in ids:
		rects[id] = _node_rect(id)
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			if rects[ids[i]].intersects(rects[ids[j]]):
				return true
	return false


## 相交双方的 id 集合（用于撤钉位）
func _overlapping_ids() -> Dictionary:
	var ids: Array = owner._node_center.keys()
	ids.sort()
	var rects := {}
	for id in ids:
		rects[id] = _node_rect(id)
	var hit := {}
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			if rects[ids[i]].intersects(rects[ids[j]]):
				hit[str(ids[i])] = true
				hit[str(ids[j])] = true
	return hit


## 撤掉相交参与方中的「非人物/事件」钉位（整洁树为纲：钉位是补充，与树美学冲突时让位）。
## 返回是否真的撤掉了什么。
func _unpin_overlapping_pins() -> bool:
	var hit: Dictionary = _overlapping_ids()
	var changed := false
	for nid in hit:
		var k: String = owner._fold._kind_of(str(nid))
		if k == "person" or k == "event":
			continue
		if owner._root_anchor_pos.has(nid):
			owner._root_anchor_pos.erase(nid)
			changed = true
		if owner._manual_nodes.has(nid):
			owner._manual_nodes.erase(nid)
			changed = true
	if changed:
		owner._state_store["graph_root_anchors"] = owner._root_anchor_pos.duplicate()
		owner._state_store["graph_manual_nodes"] = owner._manual_nodes.duplicate()
	return changed


## 残留重叠兜底：按「整洁树优先」有界重排，返回最终坐标。仅在有残留重叠时被调用。
func _resolve_residual_overlaps(nodes: Array, pre_center: Dictionary = {}) -> Dictionary:
	var out := owner._node_center.duplicate()
	for attempt in range(3):
		if attempt == 0:
			_unpin_overlapping_pins()          # ① 冲突钉位让位
		elif attempt == 1:
			_row_step_scale = 1.5              # ② 行距同律放宽
		else:
			_row_step_scale = 2.0              # ③ 再放宽一档
		out = _compute_layout(nodes, pre_center)
		owner._node_center = out.duplicate()
		_apply_global_overlap_fix()            # 整分量刚性平移（不同分量）
		out = owner._node_center.duplicate()
		if not _has_overlap():
			break
	_row_step_scale = 1.0
	# ③ 终极兜底：仍相交（双方皆刚性/同分量）→ 硬性把「节点更少的分量」整块推开
	if _has_overlap():
		_force_separate_overlaps()
		out = owner._node_center.duplicate()
	_sync_all_views()
	return out


## 终极兜底：无视钉位刚性，把「相交双方中节点数更少的分量」整块垂直平移分开（硬保证零重叠）。
func _force_separate_overlaps() -> void:
	for _guard in range(6):
		var hit: Dictionary = _overlapping_ids()
		if hit.is_empty():
			return
		var comp: Dictionary = _relation_components()
		var members := {}
		for id in hit:
			var key: String = ("c" + str(int(comp[id]))) if comp.has(id) else ("s" + str(id))
			if not members.has(key):
				members[key] = []
			members[key].append(str(id))
		# 取「节点数最少」的分量整块下移（该分量若含钉位则一并让位——零重叠优先）
		var best_key := ""
		var best_n := 1 << 30
		for key in members:
			var n: int = (members[key] as Array).size()
			if n < best_n:
				best_n = n
				best_key = key
		if best_key == "":
			return
		var ids: Array = owner._node_center.keys()
		ids.sort_custom(func(a, b): return owner._node_center[a].y < owner._node_center[b].y)
		var rects := {}
		for id in ids:
			rects[id] = _node_rect(id)
		# 找该分量的最小 y，下移到与上方任意相交卡的底边 + 80 之下
		var top: float = 1e18
		for pid in members[best_key]:
			top = minf(top, rects[pid].position.y)
		var need: float = 0.0
		for pid in members[best_key]:
			for qid in ids:
				if (qid in members[best_key]):
					continue
				if rects[pid].intersects(rects[qid]):
					need = maxf(need, rects[qid].end.y + 80.0 - rects[pid].position.y)
		if need <= 0.0:
			return
		for pid in members[best_key]:
			owner._node_center[pid] = Vector2(owner._node_center[pid].x, owner._node_center[pid].y + need)
			if owner._root_anchor_pos.has(pid):
				owner._root_anchor_pos.erase(pid)
			if owner._manual_nodes.has(pid):
				owner._manual_nodes.erase(pid)
		owner._state_store["graph_root_anchors"] = owner._root_anchor_pos.duplicate()
		owner._state_store["graph_manual_nodes"] = owner._manual_nodes.duplicate()


## 把当前 _node_center 同步到所有卡片视图（兜底重排后统一刷新）
func _sync_all_views() -> void:
	for id in owner._node_center:
		_sync_node_view(str(id))


## 中心坐标 → 同步节点视图位置（去重叠后统一刷新，避免出现"数据动了画面没动"）
func _sync_node_view(id: String) -> void:
	var vv: Variant = owner._node_views.get(id)
	if vv != null and is_instance_valid(vv):
		vv.position = owner._node_center[id] - vv.size * 0.5


## 节点卡片 AABB（中心坐标 → Rect2；尺寸按 kind 估算宽 + 文本估算高）
func _node_rect(id: String) -> Rect2:
	var c: Vector2 = owner._node_center.get(id, Vector2.ZERO)
	var k: String = str(owner._node_kind.get(id, "hypo"))
	var w: float = _node_width_for_kind(k)
	# 测量前置（2026-09-08）：_rebuild_graph 已改为「先建视图→再布局→再去重叠」，故去重叠阶段
	# _node_views 已就绪，直接用真实渲染高（_view_height 读 v.size.y）；不再套 110 兜底。
	# 旧 110 兜底会让 48~77px 的真实线索被当成 110px 高，半框高间距(24~38px)误判重叠而被推开，
	# 抵消 _sibling_sep 的「半框高」意图。仅视图确实未就绪时回退保守 110 模型，避免漏判重叠推散节点。
	var h: float = _view_height(id)
	if not owner._node_views.has(id) or h <= 1.0:
		h = maxf(_est_node_h(owner._node_data.get(id, {})), 110.0)
	return Rect2(c - Vector2(w, h) * 0.5, Vector2(w, h))


## 按节点 kind 估算渲染宽度（用于自适应半径防重叠；与 _make_node 卡片尺寸×2 同步）
func _node_width_for_kind(kind: String) -> float:
	# 2026-09-17：统一卡片版式——五类节点统一宽 260（见 graph_view_controller._CARD_W）
	return 260.0


## 各 kind 卡片真实最小高度（与 _make_node 的 _base_h+12 口径一致）。
## 布局 est_h 必须 ≥ 真实卡高，否则同列兄弟/子树带按「估算矮框」排开后，真实高卡渲染必然重叠。
## ⚠️ 已知偏差（2026-09-07 · 详见 agent/reasoning_wall_layout_proposal.md §0.6/§8.5）：此表是「布局期防重叠安全高度上限」，
##    非真实渲染高度。线索卡 `_make_node` 真实渲染仅 48~130px（line 951/1114 `_base_h=130`），但本表把 clue 兜底到 200，
##    导致兄弟线索视觉空隙被放大 3~4 倍（中心距恒 224 = 200/2+200/2+_CONTOUR_SEP）。
##    治本方向（XMind 式测量前置）：布局前先 `_make_node` 测得真实 size.y 喂入 _pack_contour，删此过度保守兜底（至多 +8px 防字体抖动）。
##    注：`_logic_tree_layout` 已于 2026-09-08 改走「测量前置」消费真实 size，本表只作为
##    「视图/字体尚未就绪」时的碰撞估算兜底；原用以固定 200 高度模型的那条过期测试已删除（2026-09-15）。
const _KIND_MIN_H := {
	# 2026-09-17：统一卡片高 400（_CARD_H）+ 布局安全余量 → 412
	"person": 412.0, "conclusion": 412.0, "chain": 412.0,
	"hypo": 412.0, "clue": 412.0, "event": 412.0, "_": 412.0,
}
## 兄弟子树轮廓打包间隙（BuchheimWalker 轮廓法）：相邻兄弟子树在共现深度上的最小 y 间隙。
## 取 24（≥ _sib_gap 下限 12，留出呼吸空间），兼顾紧凑与可读。
const _CONTOUR_SEP := 80.0   # 2026-09-17：节点间垂直间距（用户指定 80px）
func _kind_min_h(kind: String) -> float:
	return _KIND_MIN_H.get(kind, 150.0)


## 布局期节点高度估算（非真实渲染高度 · 详见 proposal §0.6/§8.5）。
## 用途：节点尚未进树/渲染时，给碰撞感知落点(_find_non_overlapping_position)与轮廓打包预留垂直空间防重叠。
## ⚠️ 此估算值会被 line 426 `maxf(_est_node_h, _kind_min_h)` 的 _KIND_MIN_H 下限兜底（线索→200），
##    故对短线索本函数算出的矮值(≈52)被 200 吃掉，布局实际按 200 排 → 与 _make_node 真实 48~130px 脱节。
## 治本（XMind 式测量前置）：布局应改消费 _make_node 真实 size.y，本函数仅作 headless 字体未就绪时的回退估计。
func _est_node_h(nd: Dictionary) -> float:
	var fs: float = 28.0
	var line_h: float = fs * 1.35
	var sub_h: float = 0.0   # 2026-08-28：取消状态副标题显示，副标题行高归零
	var txt: String = str(nd.get("label", ""))
	# 2026-09-07：wrap 宽度必须按真实卡片宽度（kind-specific）。旧代码固定 420 对结论/推断等
	# 窄框严重低估行数 → 实际渲染高度 > 估算高度 → 串行结论等节点重叠。
	var kind: String = str(nd.get("kind", ""))
	if kind == "" and nd.has("id"):
		kind = owner._fold._kind_of(str(nd.get("id")))
	var wrap_w: float = maxf(1.0, _node_width_for_kind(kind) - 18.0)
	var natural: float = maxf(float(txt.length()) * fs, 1.0)
	var nlines: float = maxf(1.0, ceil(natural / wrap_w))
	return nlines * line_h + sub_h + 2.0 + 12.0


## 节点真实高度（测量前置 · XMind 式尺寸单一事实来源 · 2026-09-08 治本）：
## 与 _make_node 同一套字体度量（Label.get_minimum_size），布局消费真实尺寸，消除「估算/兜底」两套口径。
## 视图已渲染且尺寸可靠 → 直接读真实 size.y（最高保真）；否则用 _meas_lab 即时测量（同 _make_node 口径）。
## 仅字体彻底不可用时回退 _base_h 估算（与 _make_node 同款兜底）。
func _real_node_height(id: String, nd: Dictionary) -> float:
	# 视图优先：已渲染节点直接消费真实 size.y（测量前置 · 视图已建则零误差）
	var v: Variant = owner._node_views.get(id)
	if v != null and v.size.y > 1.0:
		return v.size.y
	# 视图不可靠（首帧/布局期尚未建视图）→ 用与 _make_node 同口径的字体度量即时测量
	if _meas_lab == null or not is_instance_valid(_meas_lab):
		_meas_lab = Label.new()
		_meas_lab.visible = false
		_meas_lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if owner._canvas != null and is_instance_valid(owner._canvas):
			owner._canvas.add_child(_meas_lab)   # 入画布树 → 默认字体/主题解析就绪
	var kind: String = owner._fold._kind_of(id)
	var _cap: float = 840.0 if kind == "clue" else 420.0   # 与 _make_node 一致：线索封顶加倍
	_meas_lab.add_theme_font_size_override("font_size", 28)
	_meas_lab.text = str(nd.get("label", ""))
	_meas_lab.autowrap_mode = TextServer.AUTOWRAP_OFF
	var _nat := _meas_lab.get_minimum_size()   # 单行自然宽
	_meas_lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var _wrap_w := clampf(_nat.x, 0.0, _cap)
	if _wrap_w < 1.0:
		# 字体未就绪：回退统一卡片高（与 _make_node 同款，_CARD_H=400 + 安全余量）
		return 412.0
	_meas_lab.custom_minimum_size = Vector2(_wrap_w, 0)   # 设定换行宽度
	var _lm := _meas_lab.get_minimum_size()   # 换行后真实高
	_meas_lab.custom_minimum_size = Vector2.ZERO
	if _lm.y > 1.0:
		return _lm.y + 14.0   # +margin(12)+vb分离(2)，与 _make_node 卡片真实高度一致
	return 130.0 + 12.0


## 一个线索文本框的高度（需求3）：取当前所有 clue 节点视图的最大实测高；
## 无可测时回退估算高/基准高 130。用于把列间距(col_gap)下限抬到「≥ 一个线索文本框高度」。
func _clue_box_height() -> float:
	var h := 130.0   # 线索卡 _base_h 基准；长线索按文本实测更高
	for id in owner._node_center:
		if str(owner._node_kind.get(str(id), "")) == "clue":
			var v = owner._node_views.get(str(id))
			if v != null and v.size.y > 1.0:
				h = maxf(h, v.size.y)
			else:
				h = maxf(h, _est_node_h(owner._node_data.get(str(id), {})))
	return h


# ===================== 主布局入口 =====================
func _compute_layout(nodes: Array, pre_center: Dictionary = {}) -> Dictionary:
	# 链路亲和邻接缓存：每次布局重建（relations 可能已变）
	_aff_adj_dirty = true
	# 2026-09-21（思傅「整洁树美学为纲」）：钉位只对「真根」生效。孤儿吸收（_build_parent_of
	# 已删除钉位豁免）会把多父竞争落选、被支持者拉回树内的前根重新挂到树下——此类节点
	# 不再是根，其历史钉位（每次拖动都会写入并持久化）若保留，锚点位移会把节点从整洁
	# 树位上硬拽走（布局服从卡片位置）。凡已获得父节点的非人物/事件钉位，一律清除。
	var _pin_pf := _build_parent_of()
	var _purged := false
	for _pk in owner._root_anchor_pos.keys():
		var _ps := str(_pk)
		var _pkd: String = owner._fold._kind_of(_ps)
		if _pkd == "person" or _pkd == "event":
			continue
		if _pin_pf.has(_ps):
			owner._root_anchor_pos.erase(_ps)
			owner._manual_nodes.erase(_ps)
			_purged = true
	if _purged:
		owner._state_store["graph_root_anchors"] = owner._root_anchor_pos.duplicate()
		owner._state_store["graph_manual_nodes"] = owner._manual_nodes.duplicate()
	var center := owner._canvas.size * 0.5
	# 真实浏览器画布足够大；headless/极小画布时用虚拟中心兜底，避免布局把所有节点挤进一小块（生产不受影响）
	if owner._canvas.size.x < 800.0 or owner._canvas.size.y < 600.0:
		center = Vector2(960.0, 540.0)
	var out := {}

	# 加载已持久化「根锚点」（仅关系树根的位置；子节点全部自动派生）
	var saved_pos: Dictionary = owner._root_anchor_pos

	# 2026-09-18（思傅报「多个兄弟推理链全挤一侧，不是左右排列」）默认左右平衡自动触发：
	# 当某人物根有 ≥2 条直接结论分支时，自动开启左右平衡布局（与顶栏「自动排列」同构），
	# 使兄弟链左右分摊而非全列一侧。仅在用户未显式关闭（_balanced_layout==false）且非 rank 布局时自动开；
	# 显式关闭仍保持纯右向（test_balanced_layout G 验证：_should_auto_balance 不覆盖关闭开关，
	# 故触发逻辑放在此调度层而非 _should_auto_balance 内）。
	if not owner._balanced_layout and not owner._use_rank_layout:
		var _pf := _build_parent_of()
		var _cm := {}
		for _ch in _pf:
			var _p: String = _pf[_ch]
			if not _cm.has(_p):
				_cm[_p] = []
			if not (_ch in _cm[_p]):
				_cm[_p].append(_ch)
		for nd in nodes:
			var _rid: String = str(nd.id)
			if owner._fold._kind_of(_rid) == "person" and _cm.get(_rid, []).size() >= 2:
				owner._balanced_layout = true
				break

	if owner._mode == GraphViewController.ViewMode.MODE_C:
		# 拖前各节点实际位置（_rebuild_graph 清空 _node_center 前捕获传入）：钉位重派生以「实际位移」
		# 平移后代，保证后代严格随动 = 拖前位 + delta，不因初次去重叠修正而漂移（2026-09-05 修复）。
		var prev_center := pre_center if not pre_center.is_empty() else owner._node_center.duplicate()
		if _relayout_on_edge:
			prev_center = {}
			_relayout_on_edge = false
		if saved_pos.is_empty():
			# 无钉位：一次布局即可
			_run_main_layout(nodes, center, saved_pos, out)
		else:
			# 有钉位：先清空钉位捕获纯布局，供未钉节点（非拖动子树）重新自动排布
			var _backup: Dictionary = owner._root_anchor_pos.duplicate()
			var _manual_backup: Array = owner._manual_nodes.duplicate()
			owner._root_anchor_pos = {}
			var _layout_out := {}
			_run_main_layout(nodes, center, {}, _layout_out)
			# 恢复钉位（供后续 _build_parent_of 等读取）
			owner._root_anchor_pos = _backup
			owner._manual_nodes = _manual_backup
			out = _layout_out
			# 锚点跟随重派生（2026-09-18 思傅报「折叠移动人物后展开，推理链滞留旧位 / 新建关系的
			# 推理链排在人物之前的位置」根因）：纯布局把钉位根放在画布中心默认列，其全部后代
			# （含折叠隐藏节点、新建立关系的节点）都相对默认位排布；旧逻辑只把根钉回锚点，
			# 可见后代靠 prev_center 重派生兜底，而隐藏/新节点没有 prev_center → 滞留画布中心默认位，
			# 观感即「排布以画布为中心，不是以人物为中心」。此处把每个钉位节点的整棵子树按
			# delta = 锚点 − 纯布局位 平移，使子树严格以锚点（人物新位）为基准生长。
			var _shift_parent_of := _build_parent_of()
			var _shift_children := {}
			for _sch in _shift_parent_of:
				var _spa := str(_shift_parent_of[_sch])
				if not _shift_children.has(_spa):
					_shift_children[_spa] = []
				_shift_children[_spa].append(str(_sch))
			for pin_id in saved_pos:
				var pin_s := str(pin_id)
				var _psv: Variant = saved_pos.get(pin_id, null)
				if not (_psv is Vector2) or not out.has(pin_s):
					continue
				var delta: Vector2 = _psv - out[pin_s]
				if delta.length() < 0.5:
					continue
				var stack: Array = [pin_s]
				while stack.size() > 0:
					var u2: String = stack.pop_back()
					for c2 in _shift_children.get(u2, []):
						var cs2 := str(c2)
						# 后代自身也被钉位的，交给其自身锚点处理（自由放置优先循环会再钉回）
						if out.has(cs2) and not saved_pos.has(cs2):
							out[cs2] = out[cs2] + delta
						stack.append(cs2)
		# 2026-09-21（思傅定案「整洁树美学为纲，不能因小失大」）：
		# 旧逻辑（out[nid]=prev_center[nid]，2026-09-05）把「所有未钉节点」冻结在拖前/读档历史位，
		# 导致关系树变了布局不变、坐标不再由关系图推算——即「布局服从于各卡片的位置关系，不是
		# 服从于树的美学关系」（图1 带间组配错乱 / 图2 散乱皆源于此）。
		# 修正（取舍）：**关系树内的未钉节点一律重排到纯整洁树位**（美学1~5 完全由关系决定，为纲）；
		# **仅「孤立（无任何关系边）节点」保持拖前实际位**——它们无树美学可服从，稳定不动才是合理
		# 补充，强行重排只会因去重叠而乱漂（test_isolated_clue 禁令：孤立线索不应随人物漂走）。
		# 玩家显式钉位的子树仍走下方「锚点跟随」+「钉位重派生」刚性平移，属美学之上的玩家补充。
		var _prot2: Dictionary = _pinned_subtree_nodes()
		var _rel_nodes: Dictionary = _relation_components()   # 含任意关系边的节点 → 属某棵关系树
		for nd in nodes:
			var nid := str(nd.id)
			if _prot2.has(nid):
				continue
			if not _rel_nodes.has(nid) and prev_center.has(nid):
				out[nid] = prev_center[nid]   # 孤立节点：稳定不动
		# 自由放置优先：被钉节点（拖动落点）保持自身位置
		for _id2 in out:
			var _sp2: Variant = saved_pos.get(_id2, null)
			if _sp2 is Vector2:
				out[_id2] = _sp2
		# 钉位重派生（2026-09-05 修复）：被钉节点的后代（拖动子树）保持拖拽末位的实际坐标，
		# 不被重新自动排布打回——拖拽过程里子树已随根平移，此处刚性保留，松手后严格随根走、不回弹。
		# （直接沿用 prev_center 而非纯布局位：纯布局不含初次去重叠修正，会令后代相对拖前位漂移）
		var parent_of := _build_parent_of()
		var child_map := {}
		for ch in parent_of:
			var pa := str(parent_of[ch])
			if not child_map.has(pa): child_map[pa] = []
			child_map[pa].append(str(ch))
		for pin_id in saved_pos:
			var pin_s := str(pin_id)
			# 关系树根（人物）钉位：其全部后代交由「锚点跟随」（上方块）按 delta 平移派生，
			# 不在此处刚性钉回 prev_center。原因（2026-09-18 思傅报「折叠移动人物后展开，推理链滞留旧位」）：
			# 折叠态拖人物时隐藏后代在拖拽过程中无视图、未被 _drag_subtree 平移，其 prev_center 仍是拖前旧位；
			# 若在此刚性钉回 prev_center，隐藏链便停留在旧坐标、展开后不随人物走。锚点跟随对可见/隐藏后代
			# 一视同仁（均按 delta = 钉位新位 − 纯布局位 平移），故根钉位走锚点跟随即可让整棵子树随人物。
			# 非根钉位（玩家拖动中间节点）仍走此处：其可见后代已在拖拽中随根平移、prev_center=拖末位，
			# 刚性保留即等于跟随；隐藏后代极少见，沿用旧行为。
			if not parent_of.has(pin_s): continue
			# 钉位根的子树（玩家显式拖动/钉位的整棵子树）：刚性保留拖拽末位（prev_center=拖末位，
			# 已在拖拽过程中随根平移），松手后严格随根走、不回弹也不被纯布局打回——这是「玩家手动摆放」
			# 这一合法补充（区别于下方非钉位节点的纯整洁树位）。后代若自身也被钉则交给其自身钉位处理。
			var stack: Array = [pin_s]
			while stack.size() > 0:
				var u: String = stack.pop_back()
				for c in child_map.get(u, []):
					var cs := str(c)
					if saved_pos.has(cs): continue   # 后代若本身也被钉，交给其自身钉位处理
					if prev_center.has(cs):
						out[cs] = prev_center[cs]     # 保持拖拽末位（含拖拽平移）
					stack.append(cs)
	if owner._mode != GraphViewController.ViewMode.MODE_C:
		# 兜底（实际恒定 MODE_C）：非 C 模式直接逻辑图布局，保证编译期全路径返回
		_run_main_layout(nodes, center, saved_pos, out)
	return out


## 主布局分流（单一入口，避免多处 if/else 漂移）：
##   _use_rank_layout（一次性 BFS 分列，DEPRECATED 保留）> _balanced_layout（左右平衡整洁树，
##   顶栏「自动排列」进入后定格）> 自动平衡（2026-09-17：默认右向树打包高度超阈值时，
##   自动分摊到人物两侧，避免线索越收越多、单条竖列越拉越长浪费画布横向空间）>
##   _logic_tree_layout（默认纯右向整洁树，小树行为不变）。
##
## —— P1 装配线（2026-09-22 统一阶段定义；所有路径共用同一套原语）——
##   [1] 组件划分：_relation_components（全部边，忽略方向/kind）=「视觉相连即同组件」
##   [2] 组件内整洁树：_build_parent_of → 深度列 col_x → _pack_contour（变尺寸轮廓；父居中于子/兄弟有序）
##   [3] 组件/带堆叠：_band_next / _band_root_y / _place_band（四处路径共用；此前为四处复制粘贴）
##   [4] 钉位约束：仅真根生效（_compute_layout 顶部 purge），非人物/事件根 y 吸附行网格
##   [5] 去重叠兜底：_apply_global_overlap_fix（分量刚性平移）→ _resolve_residual_overlaps（有界重排）
##   [6] 自检：check_invariants + layout_diagnostic（Ctrl+Shift+D 导出真值 JSON / 可直接当 fixture）
## 收敛目标（P2+）：[1]~[6] 做成显式 pipeline，四路径收敛为 1 条 + 2 个策略开关；
##   用变尺寸 tidy 内核（contour/apportion/thread，van der Ploeg 式）替换 slot 与行网格常量。
func _run_main_layout(nodes: Array, center: Vector2, saved_pos: Dictionary, out: Dictionary) -> void:
	if owner._use_rank_layout:
		_auto_rank_layout(nodes, center, saved_pos, out)
	elif owner._balanced_layout or _should_auto_balance(nodes):
		_balanced_tree_layout(nodes, center, saved_pos, out)
	else:
		_logic_tree_layout(nodes, center, saved_pos, out)


## 自动平衡阈值（2026-09-17）：默认纯右向树的整树打包高度超过该值时自动改走左右平衡布局。
## 统一卡 412 高 + 80 间距 ≈ 492/行：1500 ≈ 3 行，第 4 行起触发左右分摊。
const _AUTO_BALANCE_H := 1500.0


## 判定：默认（非「自动排列定格」）布局下，主根（人物）整树打包高度是否超阈值。
## 复用 _pack_contour（与正式布局同口径，含亲和排序），估算与实际布局一致；
## 无节点/主根无子树时恒 false（小树保持纯右向，行为不变）。
func _should_auto_balance(nodes: Array) -> bool:
	if nodes.is_empty():
		return false
	var parent_of := _build_parent_of()
	var child_map := {}
	for ch in parent_of:
		var p: String = parent_of[ch]
		if not child_map.has(p):
			child_map[p] = []
		if not (ch in child_map[p]):
			child_map[p].append(ch)
	var main_root := ""
	for nd in nodes:
		if owner._fold._kind_of(str(nd.id)) == "person":
			main_root = str(nd.id)
			break
	if main_root == "":
		main_root = str(nodes[0].id)
	# 注：兄弟链自动左右平衡不再在此处（_should_auto_balance 须尊重显式 _balanced_layout=false 的
	# 关闭开关，由 test_balanced_layout G 验证）。多兄弟自动平衡的触发改在 _compute_layout 调度层
	# 自动置 _balanced_layout=true（见下方注释），以人物直接子 ≥2 为判定，且不覆盖显式关闭。
	if not child_map.has(main_root):
		return false
	var est_h := {}
	var node_by_id := {}
	var depth_of := {}
	for nd in nodes:
		node_by_id[nd.id] = nd
		est_h[nd.id] = _real_node_height(nd.id, nd)
		depth_of[nd.id] = 0
	var sub := _pack_contour(main_root, child_map, depth_of, est_h, node_by_id)
	var gmin: float = 1e18
	var gmax: float = -1e18
	for rd in sub["contour"].keys():
		gmin = minf(gmin, sub["contour"][rd][0])
		gmax = maxf(gmax, sub["contour"][rd][1])
	return (gmax - gmin) > _AUTO_BALANCE_H


# ===================== 模式 C：按关系驱动的横向阶梯树（DEPRECATED · 已被 _logic_tree_layout 取代，保留不调用） =====================
## 旧版按 kind 分列（person=0,conclusion=1,hypo=2,clue=3）的阶梯布局；因「串行结论会被并列同列」、
## 且非真正按关系树深铺开，已被 _logic_tree_layout（真实树深右向、兄弟垂直、父居子）取代。保留作回退参考。
func _relation_tree_layout_DEPRECATED(nodes: Array, center: Vector2, saved_pos: Dictionary, out: Dictionary) -> void:
	# 性质层：决定节点所在纵向阶梯列（人物最内、线索最外）
	var depth_of := {}
	for nd in nodes:
		match nd.get("kind", ""):
			"person": depth_of[nd.id] = 0
			"conclusion": depth_of[nd.id] = 1
			"hypo", "chain": depth_of[nd.id] = 2
			"clue": depth_of[nd.id] = 3
			_: depth_of[nd.id] = 4
	# 根集合 = 人物节点（当前单焦点人物；算法支持多人物各成一树）
	var roots: Array = []
	for nd in nodes:
		if nd.get("kind", "") == "person" and not (nd.id in roots):
			roots.append(nd.id)
	if roots.is_empty() and not nodes.is_empty():
		roots = [nodes[0].id]
	var adj := owner._fold._build_adjacency()
	# 构建父子关系树：从根 BFS，邻居"性质层更深"者作子，每节点只承接一次（防环）
	var child_map := {}
	var assigned := {}
	var q: Array = []
	for r in roots:
		if assigned.has(r): continue
		assigned[r] = true
		q.append(r)
		child_map[r] = []
	while q.size() > 0:
		var rest: Array = []
		for u in q:
			for nb in adj.get(u, []):
				if assigned.has(nb): continue
				if not (depth_of.get(nb, 4) > depth_of.get(u, 4)):
					continue
				assigned[nb] = true
				if not child_map.has(u): child_map[u] = []
				child_map[u].append(nb)
				child_map[nb] = []
				rest.append(nb)
		q = rest
	# 子树叶子高：内部 = Σ 子叶子高，用于垂直带划分
	var high := {}
	for r in roots:
		high[r] = 1
	for u in assigned:
		high[u] = 1
	_collect_high(roots, child_map, high)
	# 节点估算高度（文字行数×行高 + 副标题 + 内边距），用于垂直带切分；兄弟间距见 _sib_gap（文本框高一半）。
	# 跨场景累积改造（2026-08-29）：下限抬到 140，与碰撞模型（max(view_h,110)+clearance 24 ⇒ 需 ≥134
	# 中心距）对齐；否则估算高度（短标签约 52）远小于真实卡片高，密集兄弟会被带内堆叠压成重叠。
	var est_h := {}
	for nd in nodes:
		est_h[nd.id] = maxf(_est_node_h(nd), 140.0)
	var memo := {}
	for _nd in nodes:
		_subtree_span_est(_nd.id, child_map, est_h, memo)
	# 人物定位：保存位优先（人物可自由拖动）；多人物水平错开
	var col_gap: float = maxf(_clue_box_height(), 300.0)   # 需求3：列间距下限 = 一个线索文本框高度
	# 跨场景带入·任务：上一场景携带内容偏左、本场景新内容偏右，建立关系前分区域放置（建立关系后自然并入同一层级树）
	var _is_cw := owner._case_wide and not owner._carried_ids.is_empty()
	var _carried_x: float = center.x - 380.0
	var _new_x: float = center.x + 380.0
	for r in roots:
		var _sv: Variant = saved_pos.get(r, null)
		var _rx: float
		if _sv is Vector2:
			_rx = _sv.x
		else:
			_rx = _carried_x if (_is_cw and (r in owner._carried_ids)) else _new_x
		var ry: float = _sv.y if (_sv is Vector2) else center.y
		out[r] = Vector2(_rx, ry)
	for r in roots:
		var _sv2: Variant = saved_pos.get(r, null)
		var rx2: float = _sv2.x if (_sv2 is Vector2) else out[r].x
		var ry2: float = _sv2.y if (_sv2 is Vector2) else center.y
		# 根偏右→树向左生长，偏左→向右（方向不硬性统一，保持画布内）
		var dirv := 1.0
		if rx2 >= owner._canvas.size.x * 0.5:
			dirv = -1.0
		var _half3: float = maxf(memo.get(r, 140.0) * 0.5, 60.0)
		var top2: float = ry2 - _half3
		var bot2: float = ry2 + _half3
		_assign_subtree(r, child_map, memo, est_h, out, top2, bot2, rx2, dirv, col_gap)
	# 孤立（未接入树）节点：保存位优先；跨场景带入区分「携带/新」种子区，碰撞感知放置保证零重叠
	var existing_spare := {}
	for _k in out:
		if out[_k] is Vector2:
			existing_spare[_k] = out[_k]
	for nd in nodes:
		if out.has(nd.id): continue
		var sv: Variant = saved_pos.get(nd.id, null)
		if sv is Vector2:
			out[nd.id] = sv
			existing_spare[nd.id] = sv
			continue
		var _kind: String = owner._fold._kind_of(nd.id)
		var _seed := Vector2(_new_x - 40.0, center.y - 220.0)
		if _is_cw and (nd.id in owner._carried_ids):
			_seed = Vector2(_carried_x + 40.0, center.y - 220.0)
		out[nd.id] = _find_non_overlapping_position(_seed, nd.id, _kind, existing_spare, 24.0)
		existing_spare[nd.id] = out[nd.id]
	# 手动拖动过的节点保持原位，不被自动布局覆盖（保证每个人物/结论/推断/线索都能自由移动）
	for mid2 in owner._manual_nodes:
		var _sv3: Variant = saved_pos.get(mid2, null)
		if _sv3 is Vector2 and out.has(mid2):
			out[mid2] = _sv3
	for idf in out:
		out[idf] = _clamp_to_canvas(out[idf])


# ===================== 模式 C 默认：XMind 逻辑图（偏右侧整洁树 · REWRITE 2026-09-05） =====================
## 基于 XMind「结构服从关系」：推理墙 = 逻辑图（root 在最左、向右演绎，水平流向）。
##   · 深度（父子推导）映射到右向轴：x = col_x[depth]，列间距随父列最大节点宽自适应；
##   · 兄弟（并列推导）映射到垂直轴：同父子节点在父的垂直带内堆叠、父居中于子（BuchheimWalker 美学3）；
##   · 串行结论 A→B→C（conclusion→conclusion 边）沿右向轴连续更深层级，绝不并排——结构服从关系；
##   · 多人物 = 多棵独立水平带树，垂直堆叠、带间留 subtreeSeparation（亲近分组：异人物/异组留空）。
## 连线由 graph_view_edge 的流向 S 曲线（父右缘→子左缘）绘制，列间空带保证不穿框、不交叉。
## 复用 _build_parent_of（from=子,to=父）构建关系树；布局完全由关系图算出，无几何硬编码、无上下/环维度。
## ===================== 弱连通分量（视觉上相连的树不被别的树分隔） =====================
## 2026-09-21 思傅截图：同一棵无根树的两个树枝被另一棵无根树分隔开、单看连线难辨关系。
## 根因：布局树只认 support/target 边；玩家用「弱关联 relate / 反对 oppose / 矛盾 contradict」
##   把几条链连成**视觉上的一棵树**时，它们在布局里仍是**多个独立根**，而旧实现
##   ① 根排序按 kind→id 字典序 ② 分列按「根数」平均切块 —— 于是这棵树的枝被切到不同列、
##   并被别的树插在中间。
## 修复：按「全部关系（忽略方向与 kind）」求弱连通分量；同分量的根在排序与分列时始终相邻、
##   绝不被拆到不同列。无关联边时每个根各自成分量 → 行为与旧版一致（小案不打散）。
func _relation_components() -> Dictionary:
	var adj := {}
	for r in owner._relations:
		var f := str(r.get("from", ""))
		var t := str(r.get("to", ""))
		if f == "" or t == "" or f == t:
			continue
		if not adj.has(f):
			adj[f] = []
		if not adj.has(t):
			adj[t] = []
		if not (t in adj[f]):
			adj[f].append(t)
		if not (f in adj[t]):
			adj[t].append(f)
	var comp := {}
	var cid: int = 0
	for n in adj.keys():
		if comp.has(n):
			continue
		var stack: Array = [n]
		comp[n] = cid
		while stack.size() > 0:
			var u: String = str(stack.pop_back())
			for v in adj.get(u, []):
				if not comp.has(v):
					comp[v] = cid
					stack.append(v)
		cid += 1
	return comp


## 把 roots 重排为「同一弱连通分量相邻」的顺序；分量之间按代表根（kind_rank 最小、其次 id）
## 稳定排序，分量内部按 kind 聚类 + id。
func _group_roots_by_component(roots: Array) -> Array:
	var comp := _relation_components()
	var groups := {}
	var order: Array = []
	for r in roots:
		var c: int = int(comp.get(str(r), -1))
		if not groups.has(c):
			groups[c] = []
			order.append(c)
		groups[c].append(r)
	var rank_of := {"person": 0, "event": 0, "conclusion": 1, "chain": 2, "hypo": 2, "clue": 3}
	var rep_key := {}
	for c in order:
		var best_rank: int = 9
		var best_id: String = "\uffff"
		for r in groups[c]:
			var kr: int = int(rank_of.get(owner._fold._kind_of(str(r)), 3))
			var rs := str(r)
			if kr < best_rank or (kr == best_rank and rs < best_id):
				best_rank = kr
				best_id = rs
		rep_key[c] = [best_rank, best_id]
		groups[c].sort_custom(func(a, b):
			var ra: int = int(rank_of.get(owner._fold._kind_of(str(a)), 3))
			var rb: int = int(rank_of.get(owner._fold._kind_of(str(b)), 3))
			if ra != rb:
				return ra < rb
			return str(a) < str(b))
	order.sort_custom(func(a, b):
		var ka: Array = rep_key[a]
		var kb: Array = rep_key[b]
		if ka[0] != kb[0]:
			return ka[0] < kb[0]
		return ka[1] < kb[1])
	var out: Array = []
	for c in order:
		out.append_array(groups[c])
	return out


## 以「弱连通分量」为最小单位把无根链切进 ≤ ncols 列：同分量的根永远落在同一列。
## 每列目标叶数 = max(单列上限, 总叶/期望列数)；单个分量超限时独占一列（不拆开）。
func _split_roots_into_columns(loose: Array, total_leaf: int, leaf_of_root: Dictionary, max_leaf: int, ncols: int) -> Array:
	var comp := _relation_components()
	var blocks: Array = []
	for r in loose:
		var c: int = int(comp.get(str(r), -1))
		var found: int = -1
		for bi in blocks.size():
			if int(blocks[bi]["cid"]) == c:
				found = bi
				break
		if found < 0:
			blocks.append({"cid": c, "roots": [], "leaf": 0})
			found = blocks.size() - 1
		blocks[found]["roots"].append(r)
		blocks[found]["leaf"] = int(blocks[found]["leaf"]) + int(leaf_of_root.get(str(r), 0))
	var target: int = maxi(1, ncols)
	var per_col_leaf: int = maxi(max_leaf, ceili(float(total_leaf) / float(target)))
	var cols: Array = []
	var cur: Array = []
	var cur_leaf: int = 0
	for b in blocks:
		var bleaf: int = int(b["leaf"])
		if cur.size() > 0 and cur_leaf + bleaf > per_col_leaf and cols.size() + 1 < target:
			cols.append(cur)
			cur = []
			cur_leaf = 0
		cur.append_array(b["roots"])
		cur_leaf += bleaf
	if cur.size() > 0:
		cols.append(cur)
	if cols.is_empty():
		cols.append([])
	return cols



## 弱连通分量多根合并（2026-09-21 思傅图1/图2 退化根治）：
## support/target 之外的连线（弱关联 relate / 反对 oppose / 矛盾 contradict）把多棵布局树
## 连成「视觉上的一棵树」时，布局必须按一棵树排——否则各根按独立根带堆叠（带间 subtree_sep），
## 链内节点水平起伏、结构观感断裂（上一版仅做「相邻排序」不够）。
## 合并规则：分量内按调用方传入顺序（组件分组内 kind 层级自顶向底），把后续根 r 挂到
## 「与 r 的子树有任意性质连线的、已合并结构中层级最高（kind rank 最小）的节点 u」之下；
## 同层级取连线多者，再取 id 稳定序。人物/事件根与玩家钉位根永不合并
## （与 _build_parent_of 的人物保护、孤儿吸收的钉位豁免同哲学）。
## 就地修改 child_map（追加合并子边），返回被吸收的根 id 数组（调用方从 roots 中移除）。
## 弱连通分量多根合并（2026-09-21 思傅图1/图2 退化根治）：
## support/target 之外的连线（弱关联 relate / 反对 oppose / 矛盾 contradict）把多棵布局树
## 连成「视觉上的一棵树」时，布局必须按一棵树排——否则各根按独立根带堆叠（带间 subtree_sep），
## 链内节点水平起伏、结构观感断裂（上一版仅做「相邻排序」不够）。
## 合并规则：分量内按调用方传入顺序（组件分组内 kind 层级自顶向底），把后续根 r 挂到
## 「与 r 的子树有任意性质连线的、已合并结构中层级最高（kind rank 最小）的节点 u」之下；
## 同层级取连线多者，再取 id 稳定序。人物/事件根与玩家钉位根永不合并
## （与 _build_parent_of 的人物保护、孤儿吸收的钉位豁免同哲学）。
## 就地修改 child_map（追加合并子边），返回被吸收的根 id 数组（调用方从 roots 中移除）。
func _merge_component_forest(roots: Array, child_map: Dictionary) -> Array:
	var comp := _relation_components()
	var rank_of := {"person": 0, "event": 0, "conclusion": 1, "chain": 2, "hypo": 2, "clue": 3}
	var merged_nodes := {}    # cid -> Dictionary{node_id: true}：该分量已合并结构的节点全集
	var anchor_dangling := {} # cid -> bool：锚点（首个根）是否「无 support 后代」的悬空节点
	var absorbed: Array = []
	for r in roots:
		var rs := str(r)
		var cid := int(comp.get(rs, -1))
		if not merged_nodes.has(cid):
			var _sub0 := _subtree_ids(rs, child_map)
			merged_nodes[cid] = _sub0
			anchor_dangling[cid] = (_sub0.size() <= 1)   # 锚点无 support 后代 = 悬空
			continue
		var rk: String = owner._fold._kind_of(rs)
		var own := _subtree_ids(rs, child_map)
		var is_substantial: bool = own.size() > 1   # 含 support 后代 = 实质性支撑子树
		if rk == "person" or rk == "event" or owner._root_anchor_pos.has(rs):
			# 人物/事件根、玩家钉位根保持独立根；子树并入候选集供后续根挂接
			for nid in own:
				merged_nodes[cid][nid] = true
			continue
		if is_substantial and not anchor_dangling.get(cid, false):
			# 分量锚点已是实质性支撑树（如 H 的 HR0 / E 的 E1），后续另一棵实质性支撑树（HR1/E3）
			# 不得被吸收——否则压成深链、破坏「结构服从关系」单链横向齐整（图2 退化根因）。
			# 各自保持独立水平带即可，relate/oppose/contradict 仅作视觉连线。
			for nid in own:
				merged_nodes[cid][nid] = true
			continue
		# 悬空根（无 support 后代），或「锚点为悬空 + 自身为实质性支撑树」（G：GR0 锚点 + GH0）：
		# 挂到「与 own 有任意性质连线、已合并结构中层级最高的节点」之下，整分量收为一棵树才水平齐整。
		# 收集 u(已合并结构) — v(r 子树内) 的全部连线（任意性质，双向）
		var links := {}    # u -> 连线数
		for rel in owner._relations:
			var vf := str(rel.get("from", ""))
			var vt := str(rel.get("to", ""))
			if vf == "" or vt == "" or vf == vt:
				continue
			var u := ""
			if merged_nodes[cid].has(vf) and own.has(vt):
				u = vf
			elif merged_nodes[cid].has(vt) and own.has(vf):
				u = vt
			else:
				continue
			if own.has(u):
				continue    # 防环：挂接目标不得在 r 自己的子树内
			links[u] = int(links.get(u, 0)) + 1
		if links.is_empty():
			# 暂无候选（连通路径经由尚未合并的根）：保持独立根，子树并入候选集
			for nid in own:
				merged_nodes[cid][nid] = true
			continue
		# 选 u：kind 层级最高（rank 最小=越靠根向）> 连线最多 > id 稳定序
		var best_u := ""
		var best_rank := 99
		var best_n := -1
		for u in links:
			var ur: int = int(rank_of.get(owner._fold._kind_of(str(u)), 3))
			var un: int = int(links[u])
			if best_u == "" or ur < best_rank or (ur == best_rank and (un > best_n or (un == best_n and str(u) < best_u))):
				best_u = str(u)
				best_rank = ur
				best_n = un
		if not child_map.has(best_u):
			child_map[best_u] = []
		if not (rs in child_map[best_u]):
			child_map[best_u].append(rs)
		absorbed.append(rs)
		for nid in own:
			merged_nodes[cid][nid] = true
	return absorbed





## ===================== P4：组件虚拟根（2026-09-22 · 思傅决策①） =====================
## 「组件 = 一棵视觉树」：一个弱连通分量内的**多棵结构树根**（以及只被 relate/oppose/contradict
## 相连的悬空卡）统一挂到一个**虚拟根**下，使该分量在布局内核眼里就是一棵树 ——
## 于是组件内共享同一套轮廓/行序，不再出现「同一视觉树的枝被别的枝隔开」或「各自成带、行错位」。
## 虚拟根不渲染：est_h 记 0、不写入 out；其子（真实根）仍视为第 0 层（x 列不右移）。
## 取代旧的 _merge_component_forest 启发式（把悬空根挂到"层级最高的已合并节点"下，属人为造父子）。
func _build_virtual_roots(roots_ordered: Array, child_map: Dictionary, est_h: Dictionary) -> Array:
	var comp := _relation_components()
	var groups := {}
	var order: Array = []
	for r in roots_ordered:
		var cid: int = int(comp.get(str(r), -1))
		if not groups.has(cid):
			groups[cid] = []
			order.append(cid)
		groups[cid].append(str(r))
	var out_roots: Array = []
	for cid in order:
		var members: Array = groups[cid]
		if members.size() <= 1:
			out_roots.append(members[0])
			continue
		var vroot: String = "__vroot_%d" % cid
		child_map[vroot] = members.duplicate()
		est_h[vroot] = 0.0
		out_roots.append(vroot)
	return out_roots


## 布局根的代表性 kind（虚拟根取分量内层级最高者）：用于「人物整洁树 vs 无根链」分流判定。
func _layout_root_kind(r: String, child_map: Dictionary) -> String:
	var rs := str(r)
	if not rs.begins_with("__vroot_"):
		return owner._fold._kind_of(rs)
	var rank_of := {"person": 0, "event": 0, "conclusion": 1, "chain": 2, "hypo": 2, "clue": 3}
	var best: String = ""
	var best_rank: int = 99
	for c in child_map.get(rs, []):
		var k: String = owner._fold._kind_of(str(c))
		var rk: int = int(rank_of.get(k, 3))
		if rk < best_rank:
			best_rank = rk
			best = k
	return best


## 虚拟根的子若带钉位（玩家钉住某条链的根/某个人物），仍按钉位**刚性平移该子树** ——
## 保持「钉位是玩家正当布设」的语义（思傅决策②）；若因此与其它卡相交，交由
## `_apply_global_overlap_fix` / `_resolve_residual_overlaps` 按「整洁树优先、钉位冲突时让位」收拾。
func _apply_vroot_child_pins(roots: Array, child_map: Dictionary, saved_pos: Dictionary, out: Dictionary) -> void:
	for r in roots:
		var rs := str(r)
		if not _is_virtual_root(rs):
			continue
		for c in child_map.get(rs, []):
			var cs := str(c)
			var pv: Variant = saved_pos.get(cs, null)
			if not (pv is Vector2):
				continue
			if not out.has(cs):
				continue
			var target: Vector2 = pv
			var delta: Vector2 = target - out[cs]
			if delta.length() < 0.01:
				continue
			var members: Array = [cs]
			members.append_array(_descendants(cs))
			for sid in members:
				var ks := str(sid)
				if out.has(ks):
					out[ks] = out[ks] + delta


## 虚拟根 id（不渲染、不参与 out/诊断）
func _is_virtual_root(id: String) -> bool:
	return str(id).begins_with("__vroot_")


func _logic_tree_layout(nodes: Array, center: Vector2, saved_pos: Dictionary, out: Dictionary) -> void:
	var parent_of := _build_parent_of()
	var child_map := {}
	for ch in parent_of:
		var p: String = parent_of[ch]
		if not child_map.has(p):
			child_map[p] = []
		if not (ch in child_map[p]):
			child_map[p].append(ch)
	var has_parent := {}
	for ch in parent_of:
		has_parent[ch] = true
	# 根集合 = 无父节点（人物恒为根；无关系推断/结论/线索/孤立线索各自成根）
	var roots := []
	for nd in nodes:
		if not has_parent.has(nd.id):
			if not (nd.id in roots):
				roots.append(nd.id)
	if roots.is_empty() and not nodes.is_empty():
		roots = [nodes[0].id]

	# 链路亲和重排：每父节点直接子按「同链相邻」原则排序（_ordered_children），
	# 使 tidy-Y 纵向铺开时同链分支在垂直序中相邻（A2 要求）；与提交版轮廓打包前同序处理一致。
	for _p in child_map.keys():
		child_map[_p] = _ordered_children(str(_p), child_map)

	# 估算高度（测量前置治本 · 2026-09-08）：布局消费真实渲染高，不再套 _KIND_MIN_H 过度保守兜底；
	# X=深度列（右向轴）仍按真实宽自适应列距。
	var est_h := {}
	var node_by_id := {}
	for nd in nodes:
		node_by_id[nd.id] = nd
		est_h[nd.id] = _real_node_height(nd.id, nd)

	# 根排序：先按弱连通分量聚拢（视觉上相连的树始终相邻），再做多根合并（2026-09-21 图1/图2）：
	# 非 support/target 连线（弱关联/反对/矛盾）把多棵布局树连成视觉上的一棵树时，按一棵树排布
	# （后续根挂到层级最高的已合并节点下），链内节点才能水平对齐；否则各根独立根带堆叠（40px
	# 错位）即「水平起伏」。注意必须先于深度 BFS：合并会改变树深与子级集合。
	roots = _group_roots_by_component(roots)
	# P4（待定开关）：分支式虚拟根 vs 连线式吸收（见 _UNIFY_COMPONENT_AS_BRANCH_TREE 说明）
	if _unify_component_as_branch_tree:
		roots = _build_virtual_roots(roots, child_map, est_h)
	else:
		for ar in _merge_component_forest(roots, child_map):
			roots.erase(ar)

	# BFS 真实树深（按 _build_parent_of 关系，非 kind）：串行结论沿链更深一层
	var depth_of := {}
	var q := []
	for r in roots:
		if depth_of.has(r):
			continue
		if _is_virtual_root(str(r)):
			# 虚拟根不占层级：其子（真实根）即第 0 层（x 列不右移）
			for c in child_map.get(str(r), []):
				var cs := str(c)
				if not depth_of.has(cs):
					depth_of[cs] = 0
					q.append(cs)
			continue
		depth_of[r] = 0
		q.append(r)
	while q.size() > 0:
		var rest := []
		for u in q:
			for nb in child_map.get(u, []):
				if depth_of.has(nb):
					continue
				depth_of[nb] = depth_of[u] + 1
				rest.append(nb)
		q = rest
	var max_depth: int = 0
	for d in depth_of.values():
		max_depth = maxi(max_depth, d)

	# X = 深度列（右向轴）：col_x[d] = col_x[d-1] + 上一列最大节点全宽 + levelSep
	var width_of := {}
	for nd in nodes:
		width_of[nd.id] = _view_width(nd.id)
	var max_w := {}
	for id in depth_of:
		var d: int = depth_of[id]
		var w: float = width_of.get(id, 150.0)
		if not max_w.has(d) or w > max_w[d]:
			max_w[d] = w
	var level_sep: float = 120.0   # 列间水平间隙（父右缘→子左缘的流向连线空间）
	var col_x := {}
	col_x[0] = center.x
	for d in range(1, max_depth + 1):
		var prev_half: float = max_w.get(d - 1, 150.0) * 0.5
		var cur_half: float = max_w.get(d, 150.0) * 0.5
		col_x[d] = col_x[d - 1] + prev_half + level_sep + cur_half

	# Y = 变尺寸 tidy 内核（P2 · 2026-09-22）：由 `_pack_contour`（RT 经典「轮廓合并 + 父居中于子」）
	# 产出**相对根**的 y 偏移 rel，间距按**真实卡高**（含卡片外接矩形）计算，不再用离散 slot/ROW_STEP。
	# 这样「半行间距（240 < 卡高 400）叠压」在算法层面不可能出现 —— 正是业界"只分离中心会漏掉外接尺寸"的病根。
	# 与平衡布局共用同一内核（_pack_contour），右侧/左右镜像只是放置时的 dx 策略差异。
	var max_h: float = 140.0
	for nd in nodes:
		max_h = maxf(max_h, est_h[nd.id])
	# 组件/带「原点对齐」用的粗粒度步长（跨组件视觉对齐；组件内部间距完全由内容决定）
	var _pack_step: float = (max_h + _CONTOUR_SEP) * _row_step_scale


	# 各根水平带垂直堆叠（多人物各占一独立水平带）。先算每根 tidy-Y 跨度，再森林垂直居中、自上而下铺开。
	var subtree_sep: float = 40.0   # 根带间垂直间隙（亲近分组：异人物/异组留少量空）
	var root_tidy := {}
	var root_range := {}
	var total_h: float = 0.0
	_aff_adj_dirty = true   # 链路亲和邻接缓存：单次布局内复用，跨次布局重建（relations 可能已变）
	for r in roots:
		var _pk: Dictionary = _pack_contour(str(r), child_map, depth_of, est_h, node_by_id)
		var ty: Dictionary = _pk["rel"]                 # 相对根 y 偏移（根 = 0）
		var kc: Dictionary = _pk["contour"]             # 各深度 [ymin, ymax]（相对根，含半卡高）
		root_tidy[r] = ty
		var gmin: float = 1e18
		var gmax: float = -1e18
		for rd in kc.keys():
			gmin = minf(gmin, kc[rd][0])
			gmax = maxf(gmax, kc[rd][1])
		if gmin > gmax:
			gmin = 0.0
			gmax = 0.0
		root_range[r] = [gmin, gmax]
		total_h += (gmax - gmin) + subtree_sep
	total_h = maxf(0.0, total_h - subtree_sep)

	# 叶子计数触发分散（2026-09-19 思傅定案；2026-09-21 修订：纯无根森林**永不拆列**）：
	#   有树（person/event 根）且主列叶子(树叶+同列无根叶) > 6 → 无根链整体搬到**树右侧**新空区域
	#   （单列竖向、允许超高、不递归切分，B/C 定案）。
	#   纯无根森林（无人物/事件根）**一律单主列垂直堆叠**（2026-09-21 思傅 图1/图3 根治：原「>6 叶
	#   自身多列铺开」把树切进不同 x 列、各列独立垂直居中——整棵树被横向甩飞（图3「飞到哪去了」）、
	#   树带互相交错起伏（图1），「结构服从关系」被斩断；图2 证明单主列带状堆叠才是正确形态，
	#   故「自身多列铺开」整支移除，任意叶数都落 else 单主列）。
	#   整洁树（person/event 根）结构完全不动、永不镜像、始终主列垂直堆叠居中。
	var col_gap: float = 160.0   # 列间水平间隙
	# 根分类：人物根（整洁树） vs 无根链（零散链路）。kind 同 roots 排序口径（owner._fold._kind_of）。
	var person_roots: Array = []
	var loose_roots: Array = []
	for r in roots:
		var rk: String = _layout_root_kind(str(r), child_map)
		if rk == "person" or rk == "event":
			person_roots.append(r)
		else:
			loose_roots.append(r)
	# 各节点归属根（人物根=整洁树，其余=无根链）；统计主列叶子数（child_map 中无条目=叶子节点）
	var root_of := {}
	for r in roots:
		var stack: Array = [r]
		while stack.size() > 0:
			var u: String = str(stack.pop_back())
			root_of[u] = r
			for c in child_map.get(u, []):
				stack.append(c)
	var leaf_count_of_root: Dictionary = {}
	var tree_leaf_count: int = 0
	var loose_leaf_count: int = 0
	for nd in nodes:
		var nid: String = str(nd.id)
		if child_map.has(nid):
			continue
		var rr: String = str(root_of.get(nid, nid))
		leaf_count_of_root[rr] = leaf_count_of_root.get(rr, 0) + 1
		var rk: String = owner._fold._kind_of(rr)
		if rk == "person" or rk == "event":
			tree_leaf_count += 1
		else:
			loose_leaf_count += 1
	# 两分支判定（2026-09-21 修订：纯无根森林不再拆列，任意叶数都落 else 单主列堆叠）：
	#   do_relocate = 有树 + 无根链 + 主列叶子 > 6 → 无根链整体搬树右侧（B/C 定案，保留）；
	#   其余（含纯无根森林）→ 全部单主列垂直堆叠（else）。
	var do_relocate: bool = (not loose_roots.is_empty()) and (not person_roots.is_empty()) and (tree_leaf_count + loose_leaf_count > 6)

	if do_relocate:
		# ===== 搬迁：人物整洁树独占主列；无根链整体搬到树右侧新空区域（单列竖向、允许超高）=====
		# 人物带：主列（col_x[0]）垂直堆叠、整体居中（根-干-枝-叶层展结构保持，永不镜像）
		var ph_total: float = 0.0
		for r in person_roots:
			ph_total += (root_range[r][1] - root_range[r][0]) + subtree_sep
		ph_total = maxf(0.0, ph_total - subtree_sep)
		# 2026-09-21 修复：人物带同样按「实际绘制底」推进，避免相邻人物树 root_y0 不同导致带交错（同 else 路径）。
		# 2026-09-21 行网格：人物带起点吸附整行网格；每带绘制顶再 ceil 吸附同一网格（防 subtree_sep 累积漂移）。
		var pgrid: float = _snap_row(center.y - ph_total * 0.5, center.y, _pack_step)
		var pband: float = pgrid - subtree_sep
		var _dx_person := func(nid: String) -> float:
			return float(col_x.get(int(depth_of.get(nid, 0)), col_x[0])) - float(col_x[0])
		for r in person_roots:
			var ty: Dictionary = root_tidy[r]
			var rg: Array = root_range[r]
			var _bn: Array = _band_next(pband, float(rg[1]) - float(rg[0]), pgrid, _pack_step, subtree_sep)
			var pband_top: float = float(_bn[0])
			var rx: float = col_x[0]
			var ry: float = _band_root_y(pband_top, 0.0, float(rg[0]))
			var sv: Variant = saved_pos.get(r, null)
			if sv is Vector2:
				rx = (sv as Vector2).x
				ry = (sv as Vector2).y
			_place_band(str(r), ty, 0.0, rx, ry, _dx_person, out)
			pband = float(_bn[1])
		# 无根链新区域：树最右沿 + 清晰间隔 起点；按 >6 叶分列（与平衡布局同口径）。
		var maxd: int = 0
		for d in col_x.keys():
			maxd = maxi(maxd, int(d))
		var main_right: float = float(col_x.get(maxd, col_x[0])) - float(col_x[0]) + max_w.get(maxd, 150.0) * 0.5
		var loose_max_w: float = 0.0
		for r in loose_roots:
			for d in col_x.keys():
				var _dd: int = int(d)
				loose_max_w = maxf(loose_max_w, float(col_x.get(_dd, col_x[0])) - float(col_x[0]) + max_w.get(_dd, 150.0))
		var start_x: float = col_x[0] + main_right + col_gap + loose_max_w * 0.5
		var ncols: int = maxi(1, ceili(float(loose_leaf_count) / 6.0))
		# 按「弱连通分量」为最小单位切列：同一棵视觉树（同分量的多个根）绝不被拆到两列
		var lcols: Array = _split_roots_into_columns(loose_roots, loose_leaf_count, leaf_count_of_root, 6, ncols)
		var col_widths: Array = []
		for col in lcols:
			var w: float = 0.0
			for r in col:
				for d in col_x.keys():
					var _dd: int = int(d)
					w = maxf(w, float(col_x.get(_dd, col_x[0])) - float(col_x[0]) + max_w.get(_dd, 150.0) * 0.5)
			col_widths.append(w)
		var cur_x: float = start_x
		for ci in lcols.size():
			var col: Array = lcols[ci]
			var ch_h: float = 0.0
			for r in col:
				ch_h += (root_range[r][1] - root_range[r][0]) + subtree_sep
			ch_h = maxf(0.0, ch_h - subtree_sep)
			# 2026-09-21 修复：列内无根链同样按「实际绘制底」推进（同 else 路径），避免 root_y0 不同导致带交错。
			# 2026-09-21 行网格：无根链列与人物带共用同一网格基准 pgrid（跨列同行对齐）。
			var cband: float = _snap_row(center.y - ch_h * 0.5, pgrid, _pack_step) - subtree_sep
			var _dx_loose := func(nid: String) -> float:
				return float(col_x.get(int(depth_of.get(nid, 0)), col_x[0])) - float(col_x[0])
			for r in col:
				var ty: Dictionary = root_tidy[r]
				var rg: Array = root_range[r]
				var _bn: Array = _band_next(cband, float(rg[1]) - float(rg[0]), pgrid, _pack_step, subtree_sep)
				var cband_top: float = float(_bn[0])
				var rx: float = cur_x
				var ry: float = _band_root_y(cband_top, 0.0, float(rg[0]))
				var sv: Variant = saved_pos.get(r, null)
				if sv is Vector2:
					rx = (sv as Vector2).x
					ry = (sv as Vector2).y
				_place_band(str(r), ty, 0.0, rx, ry, _dx_loose, out)
				cband = float(_bn[1])
			# 两列无根链之间也遵循「160 + 无根链半宽」规则，与「树最右沿→首列」间隔一致（思傅 2026-09-19）
			cur_x += col_widths[ci] + col_gap + loose_max_w * 0.5
	else:
		# ===== 纯无根森林 / 无无根链：全部根单主列垂直堆叠、整体垂直居中 =====
		# 2026-09-21 修复：相邻树带交错重叠。
		#   实际绘制带 = [cur_y - root_y0, cur_y + (rg[1]-rg[0]) - root_y0]，
		#   其中 root_y0 = 根自身 tidy-y（根在自身子群中心，未必是带顶）。
		#   旧代码按 (rg[1]-rg[0]) 推进锚点 cur_y，忽略了 root_y0 —— 当相邻树 root_y0 不同
		#   （如 7 叶比 6 叶多出的叶子抬高了根中点）时，后一棵树会"窜"到前一棵内部（图1 交错、图3 飞列）。
		#   改为用「实际绘制底」推进：band_bottom 累积真实绘制最大 y，下一棵绘制顶贴其下 + subtree_sep。
		var start_y: float = _snap_row(center.y - total_h * 0.5, center.y, _pack_step)
		var band_bottom: float = start_y - subtree_sep   # 使首棵绘制顶恰为 start_y（整体居中，绘制跨度 = total_h）
		var _dx_else := func(nid: String) -> float:
			return float(col_x.get(int(depth_of.get(nid, 0)), col_x[0])) - float(col_x[0])
		for r in roots:
			var ty: Dictionary = root_tidy[r]
			var rg: Array = root_range[r]
			# P1 统一原语：带推进（实际绘制底 + 组件原点网格吸附）——防累积漂移导致带间错行
			var _bn: Array = _band_next(band_bottom, float(rg[1]) - float(rg[0]), start_y, _pack_step, subtree_sep)
			var band_top: float = float(_bn[0])
			var rx: float = col_x[0]
			# 根置于「子群中点」而非带顶（XMind 局部对称 · 美学3）
			var ry: float = _band_root_y(band_top, 0.0, float(rg[0]))
			var sv: Variant = saved_pos.get(r, null)
			if sv is Vector2:
				rx = (sv as Vector2).x
				ry = (sv as Vector2).y
				# 松散链根（非人物/事件）钉位 y 吸附整行网格：保留玩家「哪一行」的意图，
				# 但不再让钉位把整条链拖到半行/错行处（人物/事件锚点钉位保持原样，避免"自动排列"观感）。
				var _rk_else: String = owner._fold._kind_of(str(r))
				if _rk_else != "person" and _rk_else != "event":
					ry = _snap_row((sv as Vector2).y, start_y, _pack_step)
			# 子节点 x 相对根偏移（根被钉位时子树随根走，不再滞留在画布中心绝对列）
			_place_band(str(r), ty, 0.0, rx, ry, _dx_else, out)
			# 本带绘制底（下一带据此吸附整行，避免 40px 累积漂移）
			band_bottom = float(_bn[1])
	# P4：虚拟根的子（原松散根/人物根）若带钉位，仍按其钉位刚性平移其子树
	_apply_vroot_child_pins(roots, child_map, saved_pos, out)
	# 手动拖动过的根保持钉位（钉位由 _compute_layout 外层统一覆盖，此处冗余保险）
	for mid2 in owner._manual_nodes:
		var sv3: Variant = saved_pos.get(mid2, null)
		if sv3 is Vector2 and out.has(mid2):
			out[mid2] = sv3

	for idf in out:
		out[idf] = _clamp_to_canvas(out[idf])


## ===================== 左右平衡整洁树（顶栏「自动排列」· 美学4 镜像对称） =====================
## 思傅 2026-09-09 定案：
##   ① 默认仍是纯右向 _logic_tree_layout；点顶栏「自动排列」→ 进入本布局并**定格**（不再切回）。
##   ② 人物（中心节点）锚定画布中心；其**直接子（结论）整棵子树**为最小单位分派到左/右两侧。
##   ③ 分派规则（思傅口述 = 数量均分前提下重量差最小的平衡划分）：
##        n=1 → 全右；n=2 → 1左1右；n=3 → 最「茂盛」者独占一侧、另 2 个在另一侧；
##        n=4 → 2左2右且「1茂盛+1稀疏」配对；以此类推。重量 = 子树节点数（茂盛度）。
##   ④ 左右**只是 UI 展现差异**：不复制节点、不共享数据，每棵子树整体固定在被分派的一侧，
##      改一侧的文本/结构绝不影响另一侧（不存在任何「联动镜像」）。
##   ⑤ 列偏移相对根计算，左侧取相反方向（严格镜像 A4）：左侧天然呈「叶-枝-干-根」、
##      右侧「根-干-枝-叶」。
##   ⑥ 玩家把某结论拖过人物中线可覆盖自动分派（owner._subtree_sides，落盘持久）。
func _balanced_tree_layout(nodes: Array, center: Vector2, saved_pos: Dictionary, out: Dictionary) -> void:
	var parent_of := _build_parent_of()
	var child_map := {}
	for ch in parent_of:
		var p: String = parent_of[ch]
		if not child_map.has(p):
			child_map[p] = []
		if not (ch in child_map[p]):
			child_map[p].append(ch)
	var has_parent := {}
	for ch in parent_of:
		has_parent[ch] = true
	var roots := []
	for nd in nodes:
		if not has_parent.has(nd.id):
			if not (nd.id in roots):
				roots.append(nd.id)
	if roots.is_empty() and not nodes.is_empty():
		roots = [nodes[0].id]

	# 根排序（弱连通分量聚拢，与默认布局同口径）；先于深度 BFS 与左右分派。
	roots = _group_roots_by_component(roots)

	# 真实高度（测量前置，与默认布局同口径）
	var est_h := {}
	var node_by_id := {}
	for nd in nodes:
		node_by_id[nd.id] = nd
		est_h[nd.id] = _real_node_height(nd.id, nd)

	# P4（待定开关）：分支式虚拟根 vs 连线式吸收（见 _UNIFY_COMPONENT_AS_BRANCH_TREE 说明）
	if _unify_component_as_branch_tree:
		roots = _build_virtual_roots(roots, child_map, est_h)
	else:
		for ar in _merge_component_forest(roots, child_map):
			roots.erase(ar)

	# BFS 真实树深
	var depth_of := {}
	var q := []
	for r in roots:
		if depth_of.has(r):
			continue
		if _is_virtual_root(str(r)):
			# 虚拟根不占层级：其子（真实根）即第 0 层（x 列不右移）
			for c in child_map.get(str(r), []):
				var cs := str(c)
				if not depth_of.has(cs):
					depth_of[cs] = 0
					q.append(cs)
			continue
		depth_of[r] = 0
		q.append(r)
	while q.size() > 0:
		var rest := []
		for u in q:
			for nb in child_map.get(u, []):
				if depth_of.has(nb):
					continue
				depth_of[nb] = depth_of[u] + 1
				rest.append(nb)
		q = rest
	var max_depth: int = 0
	for d in depth_of.values():
		max_depth = maxi(max_depth, d)

	# 各深度最大真实宽 → 相对根的列偏移（左右共用同一组偏移，保证严格镜像）
	var width_of := {}
	for nd in nodes:
		width_of[nd.id] = _view_width(nd.id)
	var max_w := {}
	for id in depth_of:
		var d: int = depth_of[id]
		var w: float = width_of.get(id, 150.0)
		if not max_w.has(d) or w > max_w[d]:
			max_w[d] = w
	var level_sep: float = 120.0
	var col_off := {}
	col_off[0] = 0.0
	for d in range(1, max_depth + 1):
		var prev_half: float = max_w.get(d - 1, 150.0) * 0.5
		var cur_half: float = max_w.get(d, 150.0) * 0.5
		col_off[d] = float(col_off[d - 1]) + prev_half + level_sep + cur_half

	# 左右分派（2026-09-18 扩展：**每个人物根**都做左右平衡分派——思傅报「多个兄弟推理链
	# 全挤一侧，不是左右排列」；旧实现只平衡首个主根、其余根整棵右向堆叠）。
	# 玩家手动换侧覆盖（_subtree_sides）优先：即使该人物仅 1 条直接结论分支，也要走 _assign_balanced_sides
	# 以应用显式 L/R 覆盖（test_balanced_layout E 验证）；非人物根保持整棵右向（n=1 全右手感不变）。
	var sides: Dictionary = {}
	var root_groups := {}   # root_id(str) -> {"L": Array, "R": Array}
	for r in roots:
		var rs := str(r)
		var kids_all: Array = _ordered_children(rs, child_map)
		if owner._fold._kind_of(rs) == "person":
			var s_r: Dictionary = _assign_balanced_sides(rs, child_map)
			for k in s_r:
				sides[k] = s_r[k]
			var gl := []
			var gr := []
			for c in kids_all:
				if str(s_r.get(str(c), "R")) == "L":
					gl.append(c)
				else:
					gr.append(c)
			root_groups[rs] = {"L": gl, "R": gr}
		else:
			root_groups[rs] = {"L": [], "R": kids_all}
	owner._last_layout_sides = sides.duplicate()

	# 每根叶数统计（供无根链分列按叶数装箱）：口径与默认布局一致——child_map 中无条目即为叶节点。
	var leaf_count_of_root := {}
	for nd in nodes:
		var _lc_id: String = str(nd.id)
		if child_map.has(_lc_id):
			continue
		var _lc_rt: String = _lc_id
		var _lc_guard: int = 0
		while parent_of.has(_lc_rt) and _lc_guard < 100000:
			_lc_rt = str(parent_of[_lc_rt])
			_lc_guard += 1
		leaf_count_of_root[_lc_rt] = int(leaf_count_of_root.get(_lc_rt, 0)) + 1


	# 预打包：主根按「左右两半各自轮廓打包」（两侧都垂直居中于根 = 美学3+4），其余根照旧整棵右向
	var subtree_sep: float = 40.0
	_aff_adj_dirty = true   # 链路亲和邻接缓存：单次布局内复用，跨次布局重建（relations 可能已变）
	var root_contours := {}
	var root_packed_h := {}
	var total_h: float = 0.0
	for r in roots:
		var parts := {}
		var grp: Dictionary = root_groups.get(str(r), {"L": [], "R": []})
		var gl2: Array = grp.get("L", [])
		var gr2: Array = grp.get("R", [])
		if not gl2.is_empty():
			var cm_l: Dictionary = child_map.duplicate()
			cm_l[str(r)] = gl2
			parts["L"] = _pack_contour(str(r), cm_l, depth_of, est_h, node_by_id)
		if not gr2.is_empty():
			var cm_r: Dictionary = child_map.duplicate()
			cm_r[str(r)] = gr2
			parts["R"] = _pack_contour(str(r), cm_r, depth_of, est_h, node_by_id)
		if parts.is_empty():
			parts["R"] = _pack_contour(str(r), child_map, depth_of, est_h, node_by_id)
		root_contours[r] = parts
		var gmin: float = 1e18
		var gmax: float = -1e18
		for sk in parts.keys():
			var cont: Dictionary = parts[sk]["contour"]
			for rd in cont.keys():
				gmin = minf(gmin, cont[rd][0])
				gmax = maxf(gmax, cont[rd][1])
		var ph: float = gmax - gmin
		root_packed_h[r] = ph
		total_h += ph + subtree_sep
	total_h = maxf(0.0, total_h - subtree_sep)

	# ===== 无根链分流（与 _logic_tree_layout 同语义；2026-09-21 修订：纯无根森林永不拆列）=====
	# 平衡布局（person 根左右分派）下，无根链（非 person/event 根的独立根）与逻辑树布局同口径分流：
	#   do_relocate = 有树 + 无根链 + 主列叶子(树叶+同列无根叶) > 6 → 无根链整体搬树右侧单列（允许超高、不递归切分）
	#   否则（含纯无根森林任意叶数——多列铺开已删，2026-09-21 思傅 图1/图3）→ 无根链并入主堆叠
	var person_roots: Array = []
	var loose_roots: Array = []
	for r in roots:
		var _rk: String = _layout_root_kind(str(r), child_map)
		if _rk == "person" or _rk == "event":
			person_roots.append(r)
		else:
			loose_roots.append(r)
	var _root_of := {}
	for r in roots:
		var _st: Array = [r]
		while _st.size() > 0:
			var _u: String = str(_st.pop_back())
			_root_of[_u] = r
			for _c in child_map.get(_u, []):
				_st.append(_c)
	var tree_leaf_count: int = 0
	var loose_leaf_count: int = 0
	for nd in nodes:
		var _nid: String = str(nd.id)
		if child_map.has(_nid):
			continue
		var _rr: String = str(_root_of.get(_nid, _nid))
		var _rk2: String = owner._fold._kind_of(_rr)
		if _rk2 == "person" or _rk2 == "event":
			tree_leaf_count += 1
		else:
			loose_leaf_count += 1
	var do_relocate: bool = (not loose_roots.is_empty()) and (not person_roots.is_empty()) and (tree_leaf_count + loose_leaf_count > 6)
	var main_roots: Array = person_roots.duplicate()
	if not do_relocate:
		main_roots.append_array(loose_roots)

	# 主堆叠（人物树；未触发时无根链并入）：仅对 main_roots 居中铺开
	var total_main_h: float = 0.0
	for r in main_roots:
		total_main_h += root_packed_h[r] + subtree_sep
	total_main_h = maxf(0.0, total_main_h - subtree_sep)
	# 行网格（2026-09-21）：balanced 布局行距基准 = 最高卡 + 兄弟间隙（与 _pack_contour/_sibling_sep 同口径），
	# 主堆叠起点与每带绘制顶吸附同一网格（防 subtree_sep 累积漂移导致带间错行）。
	var _b_max_h: float = 140.0
	for _nd_b in nodes:
		_b_max_h = maxf(_b_max_h, float(est_h.get(_nd_b.id, 140.0)))
	var _b_step: float = _b_max_h + _CONTOUR_SEP * _row_step_scale
	var _b_grid: float = _snap_row(center.y - total_main_h * 0.5, center.y, _b_step)
	var cur_y: float = _b_grid
	for r in main_roots:
		var parts2: Dictionary = root_contours[r]
		var ph2: float = root_packed_h[r]
		# P1 统一原语：带推进（绘制顶吸附行网格 + 按实高推进）
		var _bn: Array = _band_next(cur_y - subtree_sep, ph2, _b_grid, _b_step, subtree_sep)
		var band_top: float = float(_bn[0])
		var min_c: float = 0.0
		for sk in parts2.keys():
			var cont2: Dictionary = parts2[sk]["contour"]
			for rd in cont2.keys():
				min_c = minf(min_c, cont2[rd][0])
		var sv: Variant = saved_pos.get(r, null)
		var rx: float = center.x
		# 根 y：带顶按轮廓 min_c 校准（左右两半共用同一根位）
		var ry: float = band_top - min_c
		if sv is Vector2:
			rx = (sv as Vector2).x
			ry = (sv as Vector2).y
		out[r] = Vector2(rx, ry)
		for sk in parts2.keys():
			var dirv: float = -1.0 if str(sk) == "L" else 1.0
			var rel: Dictionary = parts2[sk]["rel"]
			# 每个 part（L/R）用同一原语放置，dx 方向按侧取反（镜像 A4）
			var _dx_part := func(nid: String) -> float:
				return dirv * float(col_off.get(int(depth_of.get(nid, 0)), 0.0))
			_place_band(str(r), rel, 0.0, rx, ry, _dx_part, out)
		cur_y = float(_bn[1]) + subtree_sep

	# 树最右沿（仅右向扩展，do_relocate 用）：person 根的 R part 最远列偏移 + 半宽（根在 center.x）
	var tree_right_edge: float = 0.0
	for r in person_roots:
		var _p2: Dictionary = root_contours[r]
		for sk in _p2.keys():
			if str(sk) != "R":
				continue
			var _c2: Dictionary = _p2[sk]["contour"]
			for rd in _c2.keys():
				var _d: int = int(rd)
				tree_right_edge = maxf(tree_right_edge, float(col_off.get(_d, 0.0)) + max_w.get(_d, 150.0) * 0.5)

	if do_relocate:
		# 无根链整体搬到「树最右沿 + 清晰间隔」起点的多列区域；列间留 col_gap；整体相对 center.y 垂直居中。
		# 间隔 = col_gap + 无根链自身半宽 → 保证无根链最左节点与整洁树最右节点留 ≥ 一张卡宽的可见空隙，
		# 玩家一眼可辨二者非同一整体（原仅留 ~30px 几乎贴合，思傅 2026-09-19 指摘）。
		var col_gap: float = 160.0
		var loose_max_w: float = 0.0
		for r in loose_roots:
			var _p: Dictionary = root_contours[r]
			for sk in _p.keys():
				var _c: Dictionary = _p[sk]["contour"]
				for rd in _c.keys():
					var _d: int = int(rd)
					loose_max_w = maxf(loose_max_w, float(col_off.get(_d, 0.0)) + max_w.get(_d, 150.0))
		var start_x: float = center.x + tree_right_edge + col_gap + loose_max_w * 0.5
		# 按每列 ≤6 叶目标切 ncols 列（与纯无根森林同口径），顺序切块、列间留 col_gap
		var ncols: int = maxi(1, ceili(float(loose_leaf_count) / 6.0))
		# 按「弱连通分量」为最小单位切列：同一棵视觉树（同分量的多个根）绝不被拆到两列
		var lcols: Array = _split_roots_into_columns(loose_roots, loose_leaf_count, leaf_count_of_root, 6, ncols)
		var col_widths: Array = []
		for col in lcols:
			var w: float = 0.0
			for r in col:
				var wmax: float = 0.0
				var _p3: Dictionary = root_contours[r]
				for sk in _p3.keys():
					var _c3: Dictionary = _p3[sk]["contour"]
					for rd in _c3.keys():
						var _d: int = int(rd)
						wmax = maxf(wmax, float(col_off.get(_d, 0.0)) + max_w.get(_d, 150.0) * 0.5)
				w = maxf(w, wmax)
			col_widths.append(w)
		var cur_x: float = start_x
		for ci in lcols.size():
			var col: Array = lcols[ci]
			var ch_h: float = 0.0
			for r in col:
				ch_h += root_packed_h[r] + subtree_sep
			ch_h = maxf(0.0, ch_h - subtree_sep)
			var cury: float = center.y - ch_h * 0.5
			for r in col:
				var parts2: Dictionary = root_contours[r]
				var ph2: float = root_packed_h[r]
				var min_c: float = 0.0
				for sk in parts2.keys():
					var cont2: Dictionary = parts2[sk]["contour"]
					for rd in cont2.keys():
						min_c = minf(min_c, cont2[rd][0])
				var sv: Variant = saved_pos.get(r, null)
				var rx: float = cur_x
				var ry: float = cury - min_c
				if sv is Vector2:
					rx = sv.x
					ry = sv.y
				out[r] = Vector2(rx, ry)
				for sk in parts2.keys():
					var dirv: float = -1.0 if str(sk) == "L" else 1.0
					var rel: Dictionary = parts2[sk]["rel"]
					for nid in rel.keys():
						if str(nid) == str(r):
							continue
						var d2: int = int(depth_of.get(nid, 0))
						out[nid] = Vector2(rx + dirv * float(col_off.get(d2, 0.0)), ry + float(rel[nid]))
				cury += ph2 + subtree_sep
			# 两列无根链之间也遵循「160 + 无根链半宽」规则，与「树最右沿→首列」间隔一致（思傅 2026-09-19）
			cur_x += col_widths[ci] + col_gap + loose_max_w * 0.5

	# P4：虚拟根的子（原松散根/人物根）若带钉位，仍按其钉位刚性平移其子树
	_apply_vroot_child_pins(roots, child_map, saved_pos, out)
	# 手动拖动过的根保持钉位（钉位由 _compute_layout 外层统一覆盖，此处冗余保险）
	for mid2 in owner._manual_nodes:
		var sv3: Variant = saved_pos.get(mid2, null)
		if sv3 is Vector2 and out.has(mid2):
			out[mid2] = sv3

	for idf in out:
		out[idf] = _clamp_to_canvas(out[idf])


## 左右平衡划分：把根的直接子（结论）**整棵子树**分成 L/R 两组。
## 数量均分（左 floor(n/2)、右 ceil(n/2)——右侧多担一枝，延续「默认向右」手感），
## 在数量约束下使两侧茂盛度总和差最小；并列时偏好把较重的一组放右侧、首枝留右侧（稳定可复现）。
## 玩家手动 side（owner._subtree_sides）优先固定，其余在剩余名额内做最优划分。
## 返回 {子节点id: "L"/"R"}；n=1 恒为 "R"（除玩家显式指定左）。
func _assign_balanced_sides(root: String, child_map: Dictionary) -> Dictionary:
	var res := {}
	if root == "":
		return res
	var kids: Array = _ordered_children(root, child_map)
	var n: int = kids.size()
	if n == 0:
		return res
	var wmemo := {}
	var wt := {}
	for c in kids:
		wt[str(c)] = float(_subtree_node_count(str(c), child_map, wmemo))
	var forced_l := []
	var forced_r := []
	var free := []
	for c in kids:
		var s: String = str(owner._subtree_sides.get(str(c), ""))
		if s == "L":
			forced_l.append(str(c))
		elif s == "R":
			forced_r.append(str(c))
		else:
			free.append(str(c))
	if n == 1:
		res[str(kids[0])] = "L" if forced_l.size() > 0 else "R"
		return res
	var target_l: int = n / 2      # 整除 = floor：左少右多
	var need_l: int = clampi(target_l - forced_l.size(), 0, free.size())
	var wl0: float = 0.0
	for c in forced_l:
		wl0 += float(wt.get(c, 1.0))
	var wr0: float = 0.0
	for c in forced_r:
		wr0 += float(wt.get(c, 1.0))
	# 链路亲和（2026-09-17「同链相邻」原则）：相关子树被分到人物两侧会形成跨中线深U连线
	# （用户截图：血字链被拉成深U）。穷举 cost 中加入「跨侧亲和惩罚」，权重远大于重量平衡——
	# 思傅明确优先级：同链相邻 > 左右重量均衡；零亲和时行为与旧版完全一致。
	var aff_lf: Array = []
	var aff_rf: Array = []
	var aff_free := {}
	var total_aff: int = 0
	if free.size() > 0:
		var fsets := {}
		for c in kids:
			fsets[str(c)] = _subtree_ids(str(c), child_map)
		for i in free.size():
			var al: int = 0
			var ar: int = 0
			for f in forced_l:
				al += _cross_affinity(fsets[str(f)], fsets[str(free[i])])
			for f in forced_r:
				ar += _cross_affinity(fsets[str(f)], fsets[str(free[i])])
			aff_lf.append(al)
			aff_rf.append(ar)
			for j in range(i + 1, free.size()):
				var aij: int = _cross_affinity(fsets[str(free[i])], fsets[str(free[j])])
				aff_free["%d_%d" % [i, j]] = aij
				total_aff += aij
			total_aff += al + ar
	var best_mask: int = -1
	var best_cost: float = 1e18
	if free.size() <= 14:
		# 穷举（实际结论数 2~8，C(14,7)=3432 上限可忽略）：取「跨侧亲和惩罚 + 两侧茂盛度差」最小的组合
		var total_masks: int = 1 << free.size()
		for mask in total_masks:
			var cnt: int = 0
			var wl: float = wl0
			var wr: float = wr0
			var cross: int = 0
			for i in free.size():
				var i_l: bool = (mask & (1 << i)) != 0
				if i_l:
					cnt += 1
					wl += float(wt.get(free[i], 1.0))
				else:
					wr += float(wt.get(free[i], 1.0))
				if total_aff > 0:
					# free_i 与 forced 组的跨侧边：free 在左则其与 forced_r 的连边跨侧，反之亦然
					cross += int(aff_rf[i]) if i_l else int(aff_lf[i])
					for j in range(i + 1, free.size()):
						var j_l: bool = (mask & (1 << j)) != 0
						if i_l != j_l:
							cross += int(aff_free["%d_%d" % [i, j]])
			if cnt != need_l:
				continue
			var cost: float = absf(wl - wr) + float(cross) * 50.0
			if wl > wr:
				cost += 0.01          # 并列时较重一组优先放右
			if (mask & 1) != 0:
				cost += 0.001         # 并列时首枝优先留右
			if cost < best_cost:
				best_cost = cost
				best_mask = mask
	if best_mask < 0:
		# 兜底贪心（超大分枝数）：按茂盛度降序，逐枝投给「当前较轻且仍有名额」的一侧
		var order: Array = free.duplicate()
		order.sort_custom(func(a, b): return float(wt.get(str(a), 1.0)) > float(wt.get(str(b), 1.0)))
		var wl2: float = wl0
		var wr2: float = wr0
		var lslot: int = need_l
		var rslot: int = free.size() - need_l
		for c in order:
			var put_left := false
			if lslot > 0 and rslot > 0:
				put_left = wl2 < wr2
			elif lslot > 0:
				put_left = true
			if put_left:
				res[str(c)] = "L"
				wl2 += float(wt.get(str(c), 1.0))
				lslot -= 1
			else:
				res[str(c)] = "R"
				wr2 += float(wt.get(str(c), 1.0))
				rslot -= 1
	else:
		for i in free.size():
			res[str(free[i])] = "L" if (best_mask & (1 << i)) != 0 else "R"
	for c in forced_l:
		res[str(c)] = "L"
	for c in forced_r:
		res[str(c)] = "R"
	return res


## 子树「茂盛度」= 子树节点总数（含自身），左右平衡划分的重量口径
func _subtree_node_count(u: String, child_map: Dictionary, memo: Dictionary) -> int:
	if memo.has(u):
		return int(memo[u])
	memo[u] = 1        # 先占位防环（_build_parent_of 已保证单父树，此处纯防御）
	var s: int = 1
	for c in child_map.get(u, []):
		s += _subtree_node_count(str(c), child_map, memo)
	memo[u] = s
	return s


## BuchheimWalker 轮廓打包（左向右向 tidy tree · G3 升级 2026-09-07）：深度→x 列，兄弟沿 y 用轮廓比较紧凑打包。
## 返回 {"contour": {相对深度:[ymin,ymax]}, "rel": {节点id: 相对父中心 y}}，纯相对坐标，不写 out。
## 关键：兄弟不按「整棵子树跨度」顺序堆叠（那会令大子树独占整条垂直带），
## 而是用轮廓比较把后放兄弟上提进先放兄弟深层子树在右侧留出的空白——紧凑性达理论上限。
## 父居中于「直接子节点首尾 y 范围中点」（XMind 局部对称细化，非整棵子树质心，见建议书 §0.3 美学3）。
## ⚠️ 不用 INF/-INF 哨兵（Godot mini/maxi 与其组合会吐 -2^63 脏值），用 -1e18 字面量兜底。
func _pack_contour(u: String, child_map: Dictionary, depth_of: Dictionary, est_h: Dictionary, node_by_id: Dictionary = {}) -> Dictionary:
	var kids: Array = _ordered_children(u, child_map)
	var rel := {}
	rel[u] = 0.0
	var h_u: float = est_h.get(u, 140.0)
	if kids.is_empty():
		return {"contour": {0: [-h_u * 0.5, h_u * 0.5]}, "rel": rel}
	var merged := {}
	var sub_list := []
	var ky_list := []
	var first_y: float = 0.0
	var last_y: float = 0.0
	var prev_bottom: float = -1e18
	for i in range(kids.size()):
		var c: String = kids[i]
		var sub: Dictionary = _pack_contour(c, child_map, depth_of, est_h, node_by_id)
		sub_list.append(sub)
		var kc: Dictionary = sub["contour"]
		var ch_h: float = est_h.get(c, 140.0)
		# 兜底顺序堆叠：兄弟沿 y 自上而下，上一兄弟子树底 + 间隙
		var tentative: float = 0.0 if (i == 0) else (prev_bottom + _sibling_sep(c, node_by_id))
		# 轮廓比较：把 c 上提，直到其轮廓在共现深度上不与已放左兄弟轮廓重叠（留 _CONTOUR_SEP）。
		# c 在父深+1，其子树的相对深度 rd 映射到父相对深度 rd+1；要求 c 顶 ≥ 左轮廓底 + 间隙。
		var need: float = -1e18
		for rd in kc.keys():
			var abs_rd: int = rd + 1
			if merged.has(abs_rd):
				var kymin: float = kc[rd][0]
				var kymax: float = kc[rd][1]
				var mymin: float = merged[abs_rd][0]
				var mymax: float = merged[abs_rd][1]
				var req: float = mymax + _sibling_sep(c, node_by_id) - kymin
				need = maxf(need, req)
		var ky: float = maxf(tentative, need)
		ky_list.append(ky)
		# 合并 c 轮廓进 merged（按 ky 偏移）
		for rd in kc.keys():
			var abs_rd: int = rd + 1
			var lo: float = kc[rd][0] + ky
			var hi: float = kc[rd][1] + ky
			if not merged.has(abs_rd):
				merged[abs_rd] = [lo, hi]
			else:
				merged[abs_rd] = [minf(merged[abs_rd][0], lo), maxf(merged[abs_rd][1], hi)]
		# prev_bottom：c 子树在父相对坐标系下的最下沿（顺序堆叠兜底用）
		var c_bottom: float = ky
		for rd in kc.keys():
			c_bottom = maxf(c_bottom, ky + kc[rd][1])
		prev_bottom = c_bottom
		if i == 0:
			first_y = ky
		last_y = ky
	# 父居中于直接子首尾 y 中点（XMind 局部对称细化）
	var mid: float = (first_y + last_y) * 0.5
	var contour := {0: [-est_h.get(u, 140.0) * 0.5, est_h.get(u, 140.0) * 0.5]}
	for i in range(kids.size()):
		var c: String = kids[i]
		var sub: Dictionary = sub_list[i]
		var kc: Dictionary = sub["contour"]
		var final_rel: float = ky_list[i] - mid
		# 合并子 rel（子中心 = final_rel，其后代再叠加）
		for nid in sub["rel"].keys():
			rel[str(nid)] = final_rel + sub["rel"][nid]
		# 合并子轮廓（按 final_rel 偏移）进父轮廓
		for rd in kc.keys():
			var abs_rd: int = rd + 1
			var lo: float = kc[rd][0] + final_rel
			var hi: float = kc[rd][1] + final_rel
			if not contour.has(abs_rd):
				contour[abs_rd] = [lo, hi]
			else:
				contour[abs_rd] = [minf(contour[abs_rd][0], lo), maxf(contour[abs_rd][1], hi)]
	return {"contour": contour, "rel": rel}



func _snap_row(y: float, anchor: float, row_step: float) -> float:
	if row_step <= 1.0:
		return y
	return anchor + round((y - anchor) / row_step) * row_step


func _snap_row_ceil(y: float, anchor: float, row_step: float) -> float:
	if row_step <= 1.0:
		return y
	return anchor + ceil((y - anchor) / row_step) * row_step


## ===================== P1：统一「带」放置原语（2026-09-22） =====================
## 背景：此前 4 条布局路径各自复制了同一段带堆叠数学（实际绘制底推进 + 行网格吸附 + 带内相对放置），
##   形成"修一处漏三处"的历史 bug 类（ce82409 / 012a11f 都要改多处且容易不同步）。
## 现收敛为三个原语，所有路径共用；行为与收敛前逐点一致（由 tools/fixtures 金标准证明）。
## 术语：带（band）= 一个「根 + 其整棵子树」的绘制块，沿 y 依次堆叠。
## ① 推进：给定上一带绘制底，求本带绘制顶（≥ prev_bottom + gap，并吸附行网格）与绘制底。
func _band_next(prev_bottom: float, height: float, grid_ref: float, step: float, gap: float) -> Array:
	var top: float = _snap_row_ceil(prev_bottom + gap, grid_ref, step)
	return [top, top + height]


## ② 带根 y：根在自己的子群中点（off_root），带顶按 min_off 校准 → 根居中于子群（美学3），不落带顶。
func _band_root_y(band_top: float, off_root: float, min_off: float) -> float:
	return band_top + off_root - min_off


## ③ 带内一次性放置：根 + 全部后代。
##   offsets[nid] = 该节点相对根子群的 y 偏移（右向树 = ty[nid]；平衡布局 = rel[nid]）
##   base_off     = 根的 y 偏移基准（右向树 = ty[root]；平衡布局 = 0）
##   dx_of(nid)   = 该节点「相对根」的 x 偏移（右向树 = col_x[d]-col_x[0]；平衡布局 = dirv*col_off[d]）
func _place_band(root: String, offsets: Dictionary, base_off: float, rx: float, ry: float,
		dx_of: Callable, out: Dictionary) -> void:
	# 虚拟根不渲染：不写入 out（其子节点照常相对它定位）
	if not _is_virtual_root(root):
		out[root] = Vector2(rx, ry)
	for nid in offsets.keys():
		var sid := str(nid)
		if sid == root or _is_virtual_root(sid):
			continue
		out[nid] = Vector2(rx + float(dx_of.call(sid)), ry + (float(offsets[nid]) - base_off))


## ===================== 链路亲和排序（2026-09-17 · 思傅「同链相邻」原则） =====================
## 以「子树之间真实连边数」为亲和度做贪心重排：有连边 ⇒ 属同一链，排序时让彼此相邻，
## 使链上结论-推断-线索不被其他链隔离、连线短且不成深 U。
## 布局期邻接缓存：_build_adjacency 结果在单次布局内不变（_compute_layout 置脏）
var _aff_adj_cache: Dictionary = {}
var _aff_adj_dirty := true


func _aff_adjacency() -> Dictionary:
	if _aff_adj_dirty:
		_aff_adj_cache = owner._fold._build_adjacency()
		_aff_adj_dirty = false
	return _aff_adj_cache


## 子树节点全集（含自身），id 均转 str
func _subtree_ids(root: String, child_map: Dictionary) -> Dictionary:
	var seen := {root: true}
	var q: Array = [root]
	while q.size() > 0:
		var u: String = str(q.pop_back())
		for c in child_map.get(u, []):
			var cs := str(c)
			if seen.has(cs):
				continue
			seen[cs] = true
			q.append(cs)
	return seen


## 两个兄弟子树间的「链路亲和度」＝ 两子树节点之间的连边数（任一方向）。
## 例：线索 C 同时 support 推断 H1/H2 ⇒ H1、H2 所在子树亲和 ≥1，布局必须相邻。
func _cross_affinity(sa: Dictionary, sb: Dictionary) -> int:
	var adj := _aff_adjacency()
	var n: int = 0
	for u in sa:
		for v in adj.get(str(u), []):
			if sb.has(str(v)):
				n += 1
	return n


## 兄弟顺序稳定（XMind 美学5 · 建议书 §0.3）：按 kind_rank（人物>结论>推断>线索）再按 id 排序，
## 保证同序输入产生同构布局（多父/共有前提时顺序可复现、可读）。
## 2026-09-17 追加「同链相邻」亲和重排：在稳定基础序之上，从首枝出发贪心接上与当前末枝
## 亲和度最高的兄弟子树（亲和并列时保持基础序），零亲和时与原序完全一致（行为不变）。
func _ordered_children(u: String, child_map: Dictionary) -> Array:
	var kids: Array = child_map.get(u, []).duplicate()
	var kind_rank := {"person": 0, "event": 0, "conclusion": 1, "chain": 2, "hypo": 2, "clue": 3, "_": 3}
	kids.sort_custom(func(a, b):
		var ra: int = kind_rank.get(owner._fold._kind_of(a), 3)
		var rb: int = kind_rank.get(owner._fold._kind_of(b), 3)
		if ra != rb:
			return ra < rb
		return str(a) < str(b))
	if kids.size() >= 3:
		var sets := {}
		for k in kids:
			sets[str(k)] = _subtree_ids(str(k), child_map)
		var placed: Array = [kids[0]]
		var rest: Array = kids.slice(1)
		while rest.size() > 0:
			var last: String = str(placed[placed.size() - 1])
			var best_i: int = 0
			var best_a: int = -1
			for i in rest.size():
				var a: int = _cross_affinity(sets[last], sets[str(rest[i])])
				if a > best_a:
					best_a = a
					best_i = i
			placed.append(rest[best_i])
			rest.remove_at(best_i)
		kids = placed
	return kids






## 兄弟子树轮廓间距（测量前置 · 2026-09-08）：线索兄弟按「半个线索文本框真实高度」分隔
## （思傅要求：上一线索下沿→下一线索上沿 = 半个框高），其余类型沿用 _CONTOUR_SEP 紧凑间隙。
func _sibling_sep(c_id: String, node_by_id: Dictionary = {}) -> float:
	# 2026-09-17：所有类型统一垂直间距（_CONTOUR_SEP = 80px）
	# 2026-09-21：乘行距放宽系数（残留重叠兜底），默认 1.0 时与旧行为完全一致。
	return _CONTOUR_SEP * _row_step_scale


## 兄弟节点垂直间距：约文本框高度的 1/4（XMind 式紧凑），下限 80（用户指定 80px）。
func _sib_gap(h: float) -> float:
	return maxf(h * 0.25, 80.0)




## 节点是否为「关系树根」（手动拖拽时仅根的位置被持久化）
## 与 _star_tree_layout 同口径：人物恒为根；结论若有领域 target（→人物）或作为 support/target 入边（有父）则为非根；
## 其余「从未作为有向边 from（即无父）」的节点即为根（如无人物的结论、孤立推断起点）。
func _is_tree_root(id: String) -> bool:
	if owner._fold._kind_of(id) == "person":
		return true
	# 作为任意 support/target 边的 from（推导依据方）⇒ 有父，非根
	# 2026-09-21 补：作为「from=人物/事件」边的 to ⇒ 同样有父（人物恒为根、非人物端
	# 反转挂为其子，与 _build_parent_of 同口径），非根。
	var _idk: String = owner._fold._kind_of(id)
	for r in owner._relations:
		if r.get("kind", "") not in ["support", "target"]:
			continue
		if str(r.get("from", "")) == id:
			return false
		if str(r.get("to", "")) == id and _idk != "person" and _idk != "event" \
				and owner._fold._kind_of(str(r.get("from", ""))) in ["person", "event"]:
			return false
	# 结论领域 target 金边（conclusion → person）→ 挂在人物下，非根
	if owner._fold._kind_of(id) == "conclusion":
		var _cid: String = str(id).replace("conclusion_", "")
		var _cdef: Dictionary = owner._conclusion_def(_cid)
		if _cdef.get("target", "") != "":
			return false
	return true


## 推理树「唯一父」映射（布局与拖拽子树计算共用口径）：from=子，to=父；
## 关系树「子→父」唯一化：用 DAG 最长路径层级（两遍遍历）替代脆弱的 ring_depth 平局裁决，
## 落实 XMind「结构服从关系」+ 思傅思路（线索恒为叶、自叶向上逐级定级），使根/枝/叶判定唯一稳健。
func _build_parent_of() -> Dictionary:
	var parent_cand := {}
	var add_parent := func(child: String, parent: String) -> void:
		if child == "" or parent == "" or child == parent: return
		if not parent_cand.has(child): parent_cand[child] = []
		if not (parent in parent_cand[child]): parent_cand[child].append(parent)
	for r in owner._relations:
		var k: String = r.get("kind", "")
		if k != "support" and k != "target": continue
		var _f := str(r.get("from", "")); var _t := str(r.get("to", ""))
		var _fk := owner._fold._kind_of(_f); var _tk := owner._fold._kind_of(_t)
		if _fk == "person" and _tk == "person":
			# 人物↔人物：约定 from=上级(父)、to=下级(子/下属)。与常规(from=子,to=父)相反，
			# 故 add_parent(子,父)=add_parent(to,from)。例：德雷伯→斯特兰森 ⇒ 斯特兰森嵌套于德雷伯下。
			add_parent.call(_t, _f)
		elif (_fk == "person" or _fk == "event") and _tk != "person" and _tk != "event":
			# 2026-09-21（思傅定案·截图真病灶）：人物/事件恒为放射根。当边方向写成
			# from=人物、to=非人物（「拖人物到结论上归属」交互、从人物起笔画线、或旧存档
			# 历史边——_add_edge 的 rd 归一化只管新建边）时，旧逻辑按 from=子 把人物挂为
			# 非人物之子，随后被下方「人物恒为根」强制剔除父候选——这条边从布局树上脱落，
			# 人物与该结论沦为两个独立根、竖向摞进同一列（截图「结论排在人物下面、推断
			# 线索在人物右边」的成因），整洁树五规则全被撕裂。现按根语义反转挂接：
			# 非人物端挂为人物之子，树结构对边方向免疫（与 _add_edge 归一化同语义）。
			add_parent.call(_t, _f)
		else:
			# 非人物边尊重既有约定 from=子(更深层)、to=父：由 _add_edge 在新建时归一化，
			# 此处不再按 kind 层级强转——交替链（推断→线索→推断…）等「浅层挂深层之下」
			# 的合法画法须按玩家绘制顺序认定父子（test_balanced_layout 交替链为权威口径）。
			add_parent.call(_f, _t)
	# 布局树仅由玩家建立的 _relations（support/target 边）驱动——玩家连线即玩家布局结构。
	# 「结论→结论」推导边继承：玩家从结论 A 推导综合结论 B（A→B support）时，新结论 B 应
	# 继承 A 的父链（如人物锚 P），形成 P ← B ← A 紧凑三段——B 在 A 上一级（root 向）且 A 经 B 仍
	# 挂在人物链上（拖动人物根带动下游）。否则 B 会与 P 并列为孤立 root、A 脱离人物链
	# （思傅报的「新结论层级不对」二级表现：新结论成孤立根、源结论脱离人物锚）。故把 A 的
	# 全部父候选登记为 B 的父候选，拓扑最长路径会自然算出 P←B←A（B 父=P、A 父=B）。
	for _r in owner._relations:
		if str(_r.get("kind", "")) != "support": continue
		var _af := str(_r.get("from", "")); var _at := str(_r.get("to", ""))
		if owner._fold._kind_of(_af) == "conclusion" and owner._fold._kind_of(_at) == "conclusion":
			for _ap in parent_cand.get(_af, []):
				if _ap == _at or _ap == _af: continue
				if not parent_cand.has(_at): parent_cand[_at] = []
				if not (_ap in parent_cand[_at]):
					parent_cand[_at].append(_ap)
	# 预设数据（gate_clue_ids/gate_hypo_ids/target/related_npcs）仅用于提交验证评分，不进入布局/拖拽跟随。
	# 兜底：人物节点恒为放射根，但允许「人物↔人物」的从属嵌套。
	# 若某人物的全部父候选都不是人物（即仅被非人物当成子），才强制其为根、剔除非人物父候选，
	# 防止人物沦为推断/结论/线索之子（旧 bug：整墙根错位、拖拽不跟随）。
	# 若它确有「人物父候选」（person→person support 边，from=上级父、to=下级子），则保留嵌套，
	# 使 德雷伯↔斯特兰森 这类从属关系在布局中体现为下级挂在上级之下、并随上级拖动而跟随。
	for _pc in parent_cand.keys():
		if owner._fold._kind_of(_pc) == "person":
			var _has_person_parent := false
			for _p in parent_cand[_pc]:
				if owner._fold._kind_of(_p) == "person":
					_has_person_parent = true
					break
			if _has_person_parent:
				continue
			# 无人物父 → 强制为根：剔除非人物父候选
			var _kept := []
			for _p in parent_cand[_pc]:
				if owner._fold._kind_of(_p) != "person":
					continue
				_kept.append(_p)
			if _kept.is_empty():
				parent_cand.erase(_pc)
	# === 2026-09-05 修复：多选父时优先接入「人物锚定」链，避免共享推断被随意挂到无 target 的
	# 独立结论，导致「人物→结论→推断→线索」整链断裂、拖人物根时下游不跟随（用户报 bug 根因）。===
	# 1) person_anchored：人物本身 + 带 target 的结论 + 沿父链可达人物的节点（多轮传播）
	var person_anchored := {}
	for _pk in parent_cand.keys():
		if owner._fold._kind_of(_pk) == "person":
			person_anchored[_pk] = true
	for _dc in owner._derived_conclusions:
		var _cid2: String = str(_dc.get("id", ""))
		if _cid2 == "": continue
		var _cdef2: Dictionary = owner._conclusion_def(_cid2)
		var _tgt2: String = _cdef2.get("target", "")
		if _tgt2.begins_with("person:"):
			person_anchored["conclusion_" + _cid2] = true
	for _pass in range(8):
		var _changed := false
		for _ch2 in parent_cand.keys():
			if person_anchored.has(_ch2): continue
			for _p2 in parent_cand[_ch2]:
				if person_anchored.has(_p2):
					person_anchored[_ch2] = true
					_changed = true
					break
		if not _changed: break
	# 2) 计算最长路径层级（两遍遍历 · 自根向下拓扑/BFS）：
	#    硬锚 person/event = 0（根）；clue 自然落到最深（叶）。这正是「结构服从关系」的算法化身——
	#    边的方向（from=子/to=父）决定流向轴位移，深度完全由关系图算出，无 kind 硬编码、无环/星维度。
	var child_map := {}
	for _ch2 in parent_cand:
		for _p2 in parent_cand[_ch2]:
			if not child_map.has(_p2): child_map[_p2] = []
			if not (_ch2 in child_map[_p2]): child_map[_p2].append(_ch2)
	var all_nodes := {}
	for _ch2 in parent_cand:
		all_nodes[_ch2] = true
		for _p2 in parent_cand[_ch2]:
			all_nodes[_p2] = true
	# 入度 = 父候选数；入度 0 = 根（person/event 或无关系的孤立节点）
	var indeg := {}
	for _n in all_nodes:
		indeg[_n] = 0
	for _ch2 in parent_cand:
		indeg[_ch2] = parent_cand[_ch2].size()
	var depth_of := {}
	for _n in all_nodes:
		depth_of[_n] = 0
	var _q := []
	for _n in all_nodes:
		if indeg[_n] == 0:
			_q.append(_n)
	var _guard: int = 0
	while _q.size() > 0 and _guard < all_nodes.size() + 16:
		_guard += 1
		var _u: String = _q.pop_front()
		for _c in child_map.get(_u, []):
			if depth_of[_c] < depth_of[_u] + 1:
				depth_of[_c] = depth_of[_u] + 1
			indeg[_c] -= 1
			if indeg[_c] == 0:
				_q.append(_c)
	# 3) 选父：优先「depth 恰为子 depth-1 的即时父」（最长路径保证唯一主层级），
	#    其次 person_anchored（锚定链不断），再次 depth 较大者（更靠 root 向）；
	#    同 depth 多候选仅作 tie-break（图的固有歧义，属预期），不再靠 ring_depth 随机颠倒根/枝/叶。
	var parent_of := {}
	for _ch in parent_cand:
		var _target: int = depth_of.get(_ch, 0) - 1
		var _best: String = ""
		var _best_score: int = -1
		for _p in parent_cand[_ch]:
			var _anc: int = 1 if person_anchored.has(_p) else 0
			var _depth_ok: int = 1 if depth_of.get(_p, 0) == _target else 0
			var _score: int = _depth_ok * 100000 + _anc * 1000 + depth_of.get(_p, 0)
			if _score > _best_score:
				_best_score = _score
				_best = _p
		parent_of[_ch] = _best
	# === 2026-09-17 深U根治：悬空孤儿根吸收（思傅截图：场景二推理墙深U再现） ===
	# 机制：DAG 共享节点被唯一父化后，「落选的父」若因此成为孤儿根（无父、非人物/事件），
	# 会在布局中独占一条根带堆在主树之外，而它与其原支持者之间的连边变成跨树悬空长边
	# （如 H2-01 被选到三线合一的 CL2-4 下，浅层结论 CL2-1 成空根、边 H2-01→CL2-1 从墙顶
	# 拉到墙底 = 深U）。兄弟亲和排序/分侧亲和都只在同一棵树内部起作用，管不到跨树边。
	# 修复：孤儿根 R 的子树若有外部入边（v→u：v 支持 u∈subtree(R)，即 R 链本就是被 v
	# 推导出来的），把 R 挂到入边最多的 v 之下当孩子——与关系方向一致（被支持者挂在
	# 支持者下方），跨带长边变父子短边。只处理入边方向；出边方向（u→v）挂接会形成
	# v→R→u→v 视觉环，保持原状。
	# 2026-09-21（思傅「整洁树美学为纲」）：**删除钉位豁免**。钉位根若豁免吸收，会留下
	# 「纯布局按吸收后结构排、最终树按未吸收解释」的两棵树不一致——H2 居中失准、被钉结
	# 论悬挂跨树长边（复现 test_screenshot_aesthetic_repro 钉位场景 FAIL）。吸收后该节点
	# 不再是根，其历史钉位由 _compute_layout 顶部的「非根钉位清除」统一回收。
	# 子树/父子判定必须用【最终 parent_of】建树（候选图 child_map 会把共享节点算进
	# 每个落选父的子树，令外部入边恒为空、吸收永不触发——已踩）。
	var final_child := {}
	for _c4 in parent_of:
		var _p4: String = parent_of[_c4]
		if not final_child.has(_p4):
			final_child[_p4] = []
		if not (_c4 in final_child[_p4]):
			final_child[_p4].append(_c4)
	for _r in all_nodes:
		var rs := str(_r)
		if parent_of.has(rs):
			continue
		var rk: String = owner._fold._kind_of(rs)
		if rk == "person" or rk == "event":
			continue
		# 孤儿子树全集（按最终树）
		var sub := {rs: true}
		var q3: Array = [rs]
		while q3.size() > 0:
			var u3: String = str(q3.pop_back())
			for c3 in final_child.get(u3, []):
				if not sub.has(str(c3)):
					sub[str(c3)] = true
					q3.append(c3)
		# 收集外部入边：v(外) → u(子树内)，按 v 聚合计数
		var in_deg := {}
		for r3 in owner._relations:
			var k3: String = str(r3.get("kind", ""))
			if k3 != "support" and k3 != "target":
				continue
			var vf := str(r3.get("from", ""))
			var vt := str(r3.get("to", ""))
			if vf == "" or sub.has(vf) or not sub.has(vt):
				continue
			in_deg[vf] = int(in_deg.get(vf, 0)) + 1
		if in_deg.is_empty():
			continue
		# 选 v：入边最多 > 深度最浅（树更矮）> id 稳定序
		var bv := ""
		var bv_n := -1
		for v in in_deg:
			var vn: int = int(in_deg[v])
			var vd: int = depth_of.get(str(v), 0)
			if bv == "" or vn > bv_n or (vn == bv_n and (vd < depth_of.get(bv, 1 << 30) or (vd == depth_of.get(bv, 1 << 30) and str(v) < bv))):
				bv = str(v)
				bv_n = vn
		parent_of[rs] = bv
	return parent_of


## 拖拽子树：返回 id 的全部后代（不含自身），沿 _build_parent_of 的同款有向父子边 BFS。
## 用于「拖动结论/推断时其分枝/叶子随之一并移动」（需求3）。
func _descendants(id: String) -> Array:
	var parent_of := _build_parent_of()
	var child_map := {}
	for ch in parent_of:
		var p: String = parent_of[ch]
		if not child_map.has(p): child_map[p] = []
		if not (ch in child_map[p]): child_map[p].append(ch)
	var out: Array = []
	var seen := {}
	seen[id] = true
	var q := [id]
	while q.size() > 0:
		var u: String = q.pop_back()
		for c in child_map.get(u, []):
			if seen.has(c): continue
			seen[c] = true
			out.append(c)
			q.append(c)
	return out


## 后续遍历收集拓扑序，据此自底向上算子树叶子高
func _collect_high(roots: Array, child_map: Dictionary, high: Dictionary) -> void:
	var order := []
	var stack: Array = []
	for r in roots:
		stack.append(Array([r, false]))
	while stack.size() > 0:
		var pair: Array = stack.pop_back()
		var u: String = pair[0]
		var visited: bool = pair[1]
		if visited:
			order.append(u)
		else:
			stack.append(Array([u, true]))
			var ch: Array = child_map.get(u, [])
			var closed := {}
			for c in ch:
				if closed.has(c): continue
				closed[c] = true
				stack.append(Array([c, false]))
	for u in order:
		var ch2: Array = child_map.get(u, [])
		if ch2.is_empty(): continue
		var s: int = 0
		for c in ch2:
			s += high.get(c, 1)
		high[u] = s


## 子树所需垂直带长（递归）：父带 ≥ max(自身估高, Σ子带长 + Σ兄弟间距(_sib_gap))，保证后代不溢出、兄弟不交叠
func _subtree_span_est(u: String, child_map: Dictionary, est_h: Dictionary, memo: Dictionary) -> float:
	if memo.has(u):
		return memo[u]
	var ch: Array = child_map.get(u, [])
	var s: float = est_h.get(u, 140.0) as float
	if not ch.is_empty():
		var sub: float = 0.0
		var _gap_sum: float = 0.0
		for _c in ch:
			sub += _subtree_span_est(_c, child_map, est_h, memo)
			_gap_sum += _sib_gap(est_h.get(_c, 140.0) as float)
		s = maxf(s, sub + _gap_sum)
	memo[u] = s
	return s




## 递归布点：父居其子带中央；子带按各自子树带长精确切分（不足则居中留白），兄弟带间保证 ≥15px，绝不溢出交叠
func _assign_subtree(u: String, child_map: Dictionary, sp: Dictionary, est_h: Dictionary, out: Dictionary, top: float, bot: float, pxx: float, dirv: float, col_gap: float) -> void:
	var ch: Array = child_map.get(u, [])
	var totalSpan: float = 0.0
	for _c in ch:
		totalSpan += sp.get(_c, est_h.get(_c, 140.0) as float) as float
	totalSpan += 20.0 * maxf(float(ch.size()) - 1.0, 0.0)
	# 规则2（思傅 2026-09-02 最终裁定）：被玩家手动拖动的节点(人物/结论/推断)钉在手动位，
	# 且整条下游子树从手动位重新生长(向上不动)。关键：手动分支必须把下游 band 的 top/bot 重置为
	# 以「手动位.y」居中，而非沿用传入的(基于父=人物派生位)top/bot——否则下游只 x 跟着、y 仍锚定人物。
	# 效果：拖 1→2/3/4/5/6 随 1；拖 2→3/4/5/6 随 2；拖 3→4/5/6 随 3；拖 4(叶子)→仅 4 自己动。
	if u in owner._manual_nodes and owner._root_anchor_pos.has(u):
		out[u] = owner._root_anchor_pos[u]
		top = out[u].y - totalSpan * 0.5
		bot = out[u].y + totalSpan * 0.5
	elif out.has(u):
		out[u] = Vector2(out[u].x, (top + bot) * 0.5)
	else:
		out[u] = Vector2(pxx, (top + bot) * 0.5)
	var off: Vector2 = owner._node_offsets.get(u, Vector2.ZERO)
	out[u] += off
	if ch.is_empty():
		return
	var base_x: float = out[u].x
	var band_top: float = top + off.y
	var band_bot: float = bot + off.y
	var cur: float = band_top + maxf(0.0, ((band_bot - band_top) - totalSpan) * 0.5)
	for c in ch:
		var _h: float = sp.get(c, est_h.get(c, 140.0) as float) as float
		_assign_subtree(c, child_map, sp, est_h, out, cur, cur + _h, base_x + dirv * col_gap, dirv, col_gap)
		cur += _h + 20.0


# ===================== 一键自动排列（顶栏「自动排列」） =====================
## 严格按「BFS 深度」分列（人物列最右，结论/推断/线索逐列向左），同层 barycenter 排序
## 减少相邻列连线交叉，参考华生示范的横向层级推理图：整墙整洁、规范、尽量避免连线交叉。
func _auto_rank_layout(nodes: Array, center: Vector2, saved_pos: Dictionary, out: Dictionary) -> void:
	var kind := {}
	var ids: Array = []
	for nd in nodes:
		ids.append(nd.id)
		kind[nd.id] = nd.kind
	# 无向化邻接（rank/BFS 与 barycenter 都按无向连边处理，不依赖关系方向）
	var adj := owner._fold._build_adjacency()
	var undirected := {}
	for u in adj:
		if not undirected.has(u):
			undirected[u] = []
		for v in adj[u]:
			if not undirected[u].has(v):
				undirected[u].append(v)
			if not undirected.has(v):
				undirected[v] = []
			if not undirected[v].has(u):
				undirected[v].append(u)
	# rank：从全部人物出发 BFS，人物=最右列(0)。
	var rank := {}
	var qq: Array = []
	for id0 in ids:
		if kind.get(id0, "") == "person" and not rank.has(id0):
			rank[id0] = 0
			qq.append(id0)
	if qq.is_empty() and not ids.is_empty():
		rank[ids[0]] = 0
		qq.append(ids[0])
	var qi := 0
	while qi < qq.size():
		var u: String = qq[qi]
		qi += 1
		for v in undirected.get(u, []):
			if rank.has(v):
				continue
			rank[v] = rank[u] + 1
			qq.append(v)
	var graph_max := 0
	for id0 in rank:
		graph_max = maxi(graph_max, rank[id0])
	var ISOLATED: int = graph_max + 1   # 无线索/无关系的孤立节点统一放最左列，保持整洁
	for id0 in ids:
		if not rank.has(id0):
			rank[id0] = ISOLATED
		graph_max = maxi(graph_max, rank[id0])
	# 列 x：人物最右，向外逐列向左（参考示范「线索→推论→人物」由左及右汇聚）
	# 2026-09-08 修复：列间距必须按真实节点宽度定，不能只用 _node_width_for_kind 估算。
	# _make_node 实际宽常大于估算（hypo 140→238、conclusion 160→216），按估算 300px 列距会导致左右贴/重叠。
	var max_node_w: float = 0.0
	for id0 in ids:
		max_node_w = maxf(max_node_w, _view_width(id0))
	var h_gap: float = 120.0   # 相邻列节点边缘间最小水平间隙；与 logic_tree level_sep 对齐（2026-09-08 由 64→120）
	var col_gap := maxf(_clue_box_height(), max_node_w + h_gap)   # 需求3：列间距下限 ≥ 一个线索框高；宽度大时再加水平间隙
	var right_x: float = center.x + float(graph_max) * col_gap * 0.5
	# 同列按保存顺序/深度稳定初序
	var by_rank := {}
	for id0 in ids:
		var r: int = rank[id0]
		if not by_rank.has(r):
			by_rank[r] = []
		by_rank[r].append(id0)
	var byr_keys: Array = by_rank.keys()
	byr_keys.sort()
	for r in byr_keys:
		var arr: Array = by_rank[r]
		arr.sort_custom(func(a, b):
			var ya: Variant = saved_pos.get(a, null)
			var yb: Variant = saved_pos.get(b, null)
			var va: float = ya.y if ya is Vector2 else 0.0
			var vb: float = yb.y if yb is Vector2 else 0.0
			return va < vb)
	# barycenter 迭代（3 轮），按相邻列序数均值重排同列，降低连线交叉
	var nidx := {}
	for r in byr_keys:
		var arr: Array = by_rank[r]
		for i in arr.size():
			nidx[arr[i]] = i
	for _it in range(3):
		for r in byr_keys:
			var arr: Array = by_rank[r]
			if arr.size() < 2:
				continue
			var bc := {}
			for id0 in arr:
				var s: float = 0.0
				var c: int = 0
				for v in undirected.get(id0, []):
					if rank.get(v, -1) == r:
						continue
					s += float(nidx.get(v, arr.size()))
					c += 1
				bc[id0] = s / float(c) if c > 0 else float(arr.size()) * 0.5
			arr.sort_custom(func(a, b): return bc[a] < bc[b])
			for i in arr.size():
				nidx[arr[i]] = i
	# y 分配：每列按序堆叠、列内等距、整体居中（同列真实高度去重叠交给 _apply_column_overlap_fix）
	var ROW := 130.0
	for r in byr_keys:
		var arr: Array = by_rank[r]
		var n2: int = arr.size()
		var total: float = float(maxi(n2 - 1, 0)) * ROW
		var top: float = center.y - total * 0.5
		var xr: float = right_x - float(r) * col_gap
		for j in n2:
			out[arr[j]] = Vector2(xr, top + float(j) * ROW)
	# 收尾钳制
	for idf in out:
		out[idf] = _clamp_to_canvas(out[idf])




# ===================== 画布钳制 =====================
# 灵活布局辅助：仅把节点限制在画布内（XMind 式自由排布，允许任意位置）
func _clamp_to_canvas(p: Vector2) -> Vector2:
	# 跨场景累积改造（2026-08-29）：画布随内容自适应扩展，节点可向任意方向（含负坐标）自由铺开，
	# 不再把节点硬钳进固定/半固定视口矩形——早期的下限 60 会把超高墙（跨场景累积后节点极多）
	# 顶部压塌成一行，反而造成重叠。仅保留极端坐标兜底防 NaN/溢出；内容多少由 fit_view 缩放看全。
	if not is_finite(p.x) or not is_finite(p.y):
		return Vector2.ZERO
	var LIM := 100000.0
	return Vector2(clampf(p.x, -LIM, LIM), clampf(p.y, -LIM, LIM))


# ===================== 碰撞感知落点 =====================
## 螺旋/同心圆搜索：以 base 为圆心向外找与 existing 中所有节点 AABB 不相交的位置。
## nid 为新节点 id（排除自比）；kind 估算自身尺寸；clearance 为最小间隙。
## 找不到则返回扩大抖动后的兜底点（仍交给 _clamp_to_canvas 钳制）。
func _find_non_overlapping_position(base: Vector2, nid: String, kind: String, existing: Dictionary, clearance: float = 20.0) -> Vector2:
	var my_w: float = _node_width_for_kind(kind)
	# 高度兜底 110：headless 下 _node_data/视图尺寸不可靠，用保守下限避免真实高卡片仍重叠
	var my_h: float = maxf(_est_node_h(owner._node_data.get(nid, {})), 110.0)
	var my_rect := Rect2(base - Vector2(my_w, my_h) * 0.5, Vector2(my_w, my_h))
	if not _intersects_any(my_rect, existing, nid, clearance):
		return _clamp_to_canvas(base)
	var max_ring: int = 14
	for ring in range(1, max_ring + 1):
		var count: int = maxi(6, ring * 8)
		var r: float = 140.0 * (1.0 + ring * 0.42)
		for i in count:
			var angle: float = float(i) / float(count) * TAU + ring * 0.35
			var cand: Vector2 = base + Vector2(cos(angle), sin(angle)) * r
			var rect := Rect2(cand - Vector2(my_w, my_h) * 0.5, Vector2(my_w, my_h))
			if not _intersects_any(rect, existing, nid, clearance):
				return _clamp_to_canvas(cand)
	return _clamp_to_canvas(base + Vector2(randf_range(-140, 140), randf_range(-140, 140)))


## existing 中是否存在与 rect 相交（留 clearance 间隙）的节点；skip_id 用于排除自身
func _intersects_any(rect: Rect2, existing: Dictionary, skip_id: String, clearance: float) -> bool:
	for id in existing:
		if str(id) == str(skip_id):
			continue
		var c: Variant = existing[id]
		if not (c is Vector2):
			continue
		var k: String = str(owner._node_kind.get(id, "hypo"))
		var w: float = _node_width_for_kind(k)
		var h: float = maxf(_est_node_h(owner._node_data.get(str(id), {})), 110.0)
		var er := Rect2(c - Vector2(w, h) * 0.5, Vector2(w, h)).grow(clearance)
		if rect.intersects(er):
			return true
	return false


# 拖动自由摆放：放开范围限制（任务6）——允许节点中心拖到可视区之外较大范围，
# 配合画布平移（任务8）寻找；仅做极大值兜底避免坐标失控。
func _clamp_free(p: Vector2) -> Vector2:
	# 画布自由扩展（思傅 2026-09-20 需求2）：取消拖动范围限制，节点可拖到任意方向，
	# 画布随内容自由铺开；仅做 NaN/溢出兜底，避免坐标失控。
	if not is_finite(p.x) or not is_finite(p.y):
		return Vector2.ZERO
	var LIM := 100000.0
	return Vector2(clampf(p.x, -LIM, LIM), clampf(p.y, -LIM, LIM))


func _clamp_to_band(pos: Vector2, center: Vector2, kind: String) -> Vector2:
	var band: Dictionary = owner._RING_BANDS.get(kind, owner._RING_BANDS["clue"])
	var diff: Vector2 = pos - center
	var dist: float = diff.length()
	if dist < 0.01:
		# 落在中心点附近，给个默认方向（正上）以免角度无定义
		return center + Vector2(0.0, -band.default)
	if dist < band.min:
		return center + diff / dist * band.min
	if dist > band.max:
		return center + diff / dist * band.max
	return pos


# ===================== 位置持久化 =====================
## 第8节改造（A①+B①）：仅持久化「关系树根」锚点到 graph_root_anchors。
## 子节点全部由星形布局自动派生，不落盘——保证「手动排序只保留最顶端位置」。
func _persist_node_positions() -> void:
	if owner._state_store.is_empty(): return
	# 仅模式 C 写盘：模式 B 布局（或用户在模式 B 的拖动）不持久化，
	# 否则会覆盖模式 C 的存档位置 → 重进/切回星型时位置错乱（问题2）。
	if owner._mode != GraphViewController.ViewMode.MODE_C: return
	# 第8节改造（A①+B①）：仅持久化「关系树根」锚点到 graph_root_anchors；子节点全部自动派生不落盘
	var pos := {}
	for id in owner._root_anchor_pos:
		var p = owner._root_anchor_pos[id]
		if p is Vector2:
			pos[id] = p
	owner._state_store["graph_root_anchors"] = pos


# ===================== P0：布局诊断导出 + 不变量自检（2026-09-22） =====================
## 目的：把「截图反推」升级为「读数据」。导出内容 = 输入（节点尺寸/边/钉位）+ 输出（坐标）+ 违规清单，
## 该 JSON **可直接作为 tools/fixtures/ 的回归 fixture**（同一输入 → 断言不变量 + 坐标快照）。
## 只读，不改变任何布局行为。
func layout_diagnostic(extra: Dictionary = {}) -> Dictionary:
	var ids: Array = owner._node_center.keys()
	ids.sort()
	var nodes_out: Array = []
	for k in ids:
		var sid := str(k)
		var wh := Vector2.ZERO
		var v: Variant = owner._node_views.get(sid)
		if v != null and is_instance_valid(v):
			wh = v.size
		nodes_out.append({
			"id": sid,
			"kind": str(owner._node_kind.get(sid, "")),
			"label": str(owner._node_data.get(sid, {}).get("label", "")),
			"w": wh.x, "h": wh.y,
		})
	var rels: Array = []
	for r in owner._relations:
		rels.append({
			"from": str(r.get("from", "")), "to": str(r.get("to", "")),
			"kind": str(r.get("kind", "")), "color_key": str(r.get("color_key", "")),
		})
	var pins := {}
	for pk in owner._root_anchor_pos:
		var pv: Variant = owner._root_anchor_pos[pk]
		if pv is Vector2:
			pins[str(pk)] = [pv.x, pv.y]
	var comp_map: Dictionary = _relation_components()
	var groups := {}
	for k in comp_map:
		var cid: int = int(comp_map[k])
		if not groups.has(cid):
			groups[cid] = []
		groups[cid].append(str(k))
	var ckeys: Array = groups.keys()
	ckeys.sort()
	var comps: Array = []
	for c in ckeys:
		var arr: Array = groups[c]
		arr.sort()
		comps.append(arr)
	var centers := {}
	for k in owner._node_center:
		var cv: Vector2 = owner._node_center[k]
		centers[str(k)] = [cv.x, cv.y]
	var out := {
		"version": 1,
		"canvas": [owner._canvas.size.x, owner._canvas.size.y] if owner._canvas != null else [1920.0, 1080.0],
		"nodes": nodes_out,
		"relations": rels,
		"pins": pins,
		"manual": owner._manual_nodes.duplicate(),
		"components": comps,
		"computed": centers,
		"violations": check_invariants(),
	}
	for k in extra:
		out[k] = extra[k]
	return out


## 不变量自检（P0）：违规清单（空 = 合规）。用于 in-game 自检与 fixture 回归。
## ① 零重叠（硬）② 父居中于子 ③ 兄弟有序 ④ 同层共线（同组件+同深度，最多左右两列）
## 钉位节点（玩家落点）豁免 ②③④；孤立节点（无关系边）豁免 ④（其稳定不动是设计选择）。
## 依赖 owner._node_center / _node_views 已就绪（调用前请先写入布局结果）。
func check_invariants() -> Array:
	var bad: Array = []
	var ids: Array = owner._node_center.keys()
	ids.sort()
	if ids.size() < 2:
		return bad
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var ra: Rect2 = _node_rect(str(ids[i]))
			var rb: Rect2 = _node_rect(str(ids[j]))
			if ra.intersects(rb):
				bad.append("重叠: %s×%s" % [ids[i], ids[j]])
	var pf: Dictionary = _build_parent_of()
	var kids := {}
	for ch in pf:
		var p := str(pf[ch])
		if not kids.has(p):
			kids[p] = []
		kids[p].append(str(ch))
	var depth := {}
	var queue: Array = []
	for k in ids:
		var sid := str(k)
		if not pf.has(sid):
			depth[sid] = 0
			queue.append(sid)
	var guard := 0
	while queue.size() > 0 and guard < 100000:
		guard += 1
		var u: String = str(queue.pop_front())
		for c in kids.get(u, []):
			if depth.has(c):
				continue
			depth[c] = int(depth[u]) + 1
			queue.append(c)
	var pinned := {}
	for pk in owner._root_anchor_pos:
		pinned[str(pk)] = true
	# 兄弟序必须与布局同源口径（_ordered_children：链路亲和 → kind → id），否则「兄弟有序」会假阳性。
	var kids_ordered := {}
	for p in kids.keys():
		kids_ordered[str(p)] = _ordered_children(str(p), kids)
	for p in kids_ordered:
		if pinned.has(p):
			continue
		var cs: Array = kids_ordered[p]
		if cs.is_empty():
			continue
		var lo := 1e18
		var hi := -1e18
		var prev_y := -1e18
		var ordered := true
		for c in cs:
			var cy: float = owner._node_center.get(c, Vector2.ZERO).y
			lo = minf(lo, cy)
			hi = maxf(hi, cy)
			if cy < prev_y - 1.0:
				ordered = false
			prev_y = cy
		var mid := (lo + hi) * 0.5
		var py: float = owner._node_center.get(p, Vector2.ZERO).y
		if absf(py - mid) > 1.0:
			bad.append("父未居中: %s(父%.0f 子中点%.0f)" % [p, py, mid])
		if not ordered:
			bad.append("兄弟乱序: %s" % p)
	var comp_map: Dictionary = _relation_components()
	var by_group := {}
	for k in ids:
		var sid := str(k)
		if pinned.has(sid) or not comp_map.has(sid) or not depth.has(sid):
			continue
		var key := "%d|%d" % [int(comp_map[sid]), int(depth[sid])]
		if not by_group.has(key):
			by_group[key] = {}
		by_group[key][roundf(owner._node_center[sid].x)] = true
	for key in by_group:
		if by_group[key].size() > 2:
			bad.append("同层不共线: 组%s xs=%s" % [key, str(by_group[key].keys())])
	return bad
