extends RefCounted
class_name GraphViewLayout

## 图谱视图 · 布局层（拆自 graph_view_controller.gd，Request C 后架构分层）
##
## 职责：模式 C 关系树布局 / 模式 B 纵向分层 / XMind 自由布局（保留但当前未启用）/
## 节点尺寸估算（宽高）/ 画布钳制（clamp_free 放开范围=任务6）/ 位置持久化。
## 读取 owner（GraphViewController）的画布与状态；常量 _RING_BANDS 归控制器经 owner. 引用。

var owner: GraphViewController

# ===================== 节点尺寸估算 =====================
## 节点卡片真实高度：视图已测量用视图，否则回退字符估算
func _view_height(id: String) -> float:
	var v: Variant = owner._node_views.get(id)
	if v != null:
		var _sz: Vector2 = v.size
		if _sz.y > 1.0:
			return _sz.y
	return _est_node_h({})


## 同列纵向去重叠：同一列（x 相邻）节点按真实卡片高度，保证相邻卡片上下边距 ≥15px，
## 并把整列回居中避免整体下沉堆出画布
func _apply_column_overlap_fix() -> void:
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
			if owner._manual_nodes.has(str(arr[i])):
				continue
			var _ha: float = _view_height(arr[i - 1])
			var _hb: float = _view_height(arr[i])
			var _min_cy: float = owner._node_center[arr[i - 1]].y + (_ha + _hb) * 0.5 + 24.0
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


## 全局跨列去重叠（仅自动排列时调用）：AABB 相交检测 + 垂直推开，保持各列 x 结构不变
func _apply_global_overlap_fix() -> void:
	var ids: Array = owner._node_center.keys()
	if ids.size() < 2:
		return
	ids.sort_custom(func(a, b): return owner._node_center[a].y < owner._node_center[b].y)
	var rects := {}
	for id in ids:
		rects[id] = _node_rect(id)
	for i in ids.size():
		var id_a: String = ids[i]
		var ra: Rect2 = rects[id_a]
		for j in range(i + 1, ids.size()):
			var id_b: String = ids[j]
			var rb: Rect2 = rects[id_b]
			if ra.intersects(rb):
				# 钉位节点（玩家拖放落点）不被去重叠推走：推走=拖动松手后位置被改（回弹）
				if owner._manual_nodes.has(id_b):
					continue
				var push: float = ra.end.y - rb.position.y + 24.0
				owner._node_center[id_b] = Vector2(owner._node_center[id_b].x, owner._node_center[id_b].y + push)
				rects[id_b] = _node_rect(id_b)
				var vv: Variant = owner._node_views.get(id_b)
				if vv != null:
					vv.position = owner._node_center[id_b] - vv.size * 0.5
	for id in ids:
		owner._node_center[id] = _clamp_to_canvas(owner._node_center[id])


## 节点卡片 AABB（中心坐标 → Rect2；尺寸按 kind 估算宽 + 文本估算高）
func _node_rect(id: String) -> Rect2:
	var c: Vector2 = owner._node_center.get(id, Vector2.ZERO)
	var k: String = str(owner._node_kind.get(id, "hypo"))
	var w: float = _node_width_for_kind(k)
	# 与 _intersects_any / _find_non_overlapping_position 同一碰撞高度模型：用「标签估算高」而非实时视图高——
	# 去重叠在 _rebuild_graph 同步阶段执行，此时 Control 尚未由引擎完成布局，_view_height 不可靠（回退约 52）；
	# 用标签估算高（兜底 110）使去重叠与碰撞检测口径一致，彻底消除「修了仍重叠」的时序错配。
	var h: float = maxf(_est_node_h(owner._node_data.get(id, {})), 110.0)
	return Rect2(c - Vector2(w, h) * 0.5, Vector2(w, h))


## 按节点 kind 估算渲染宽度（用于自适应半径防重叠；与 _make_node 卡片尺寸×2 同步）
func _node_width_for_kind(kind: String) -> float:
	# 2026-08-21：宽度整体减半（配合文本框自适应窄化，环径估算同步收紧）
	match kind:
		"clue":       return 320.0   # 需求6：线索文本框宽度加倍（160→320），碰撞估算同步放宽避免重叠
		"hypo":       return 140.0
		"conclusion": return 160.0
		"chain":      return 125.0
		_: return 150.0


## 估算节点卡片高度（与 _make_node 尺寸逻辑一致）：行数=ceil(文本宽/420)，行数×行高＋副标题＋内边距
func _est_node_h(nd: Dictionary) -> float:
	var fs: float = 28.0
	var line_h: float = fs * 1.35
	var sub_h: float = 0.0   # 2026-08-28：取消状态副标题显示，副标题行高归零
	var txt: String = str(nd.get("label", ""))
	var natural: float = maxf(float(txt.length()) * fs, 1.0)
	var nlines: float = maxf(1.0, ceil(natural / 420.0))
	return nlines * line_h + sub_h + 2.0 + 12.0


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
func _compute_layout(nodes: Array) -> Dictionary:
	var center := owner._canvas.size * 0.5
	# 真实浏览器画布足够大；headless/极小画布时用虚拟中心兜底，避免布局把所有节点挤进一小块（生产不受影响）
	if owner._canvas.size.x < 800.0 or owner._canvas.size.y < 600.0:
		center = Vector2(960.0, 540.0)
	var out := {}

	# 加载已持久化「根锚点」（仅关系树根的位置；子节点全部自动派生）
	var saved_pos: Dictionary = owner._root_anchor_pos

	if owner._mode == GraphViewController.ViewMode.MODE_C:
		if owner._use_rank_layout:
			# 可选的严格 BFS 分列 + barycenter 减交叉模式（当前顶栏「自动排列」按钮走默认星形）
			_auto_rank_layout(nodes, center, saved_pos, out)
		else:
			# 默认自动布局（第8节 XMind 星形 · A①+B①）：以关系树根（人物/无人物的结论）为画布中心，
			# 直接子节点（结论）均分左右、子树向外放射生长（结论→推断→线索）；用玩家真实有向边
			# （support/target + 结论领域 target）构建树，正确处理「推断→推断」同层边，零重叠；
			# 仅根位置可被玩家手动锁定（_root_anchor_pos），子节点自动派生。
			_star_tree_layout(nodes, center, saved_pos, out)
		# 自由放置优先：玩家拖入落点 / 手动拖动过的节点（saved_pos 有记录）保持自身位置，
		# 不被阶梯树算法打回；未记录节点仍由算法排布。
		for _id2 in out:
			var _sp2: Variant = saved_pos.get(_id2, null)
			if _sp2 is Vector2:
				out[_id2] = _sp2
		# 钉位重派生（2026-09-04）：被手动钉住的节点（拖动后的根/树枝/分枝）以钉位为基准，
		# 整体平移其未钉子树——拖动松手后子树随上属走，不再回弹到放射布局位
		var parent_of := _build_parent_of()
		var child_map := {}
		for ch in parent_of:
			var pa := str(parent_of[ch])
			if not child_map.has(pa): child_map[pa] = []
			child_map[pa].append(str(ch))
		for pin_id in saved_pos:
			var pin_s := str(pin_id)
			var pv: Variant = saved_pos[pin_id]
			if not (pv is Vector2) or not out.has(pin_s): continue
			var delta: Vector2 = (pv as Vector2) - (out[pin_s] as Vector2)
			if delta.length() < 1.0: continue
			var stack: Array = [pin_s]
			while stack.size() > 0:
				var u: String = stack.pop_back()
				for c in child_map.get(u, []):
					var cs := str(c)
					if saved_pos.has(cs) or not out.has(cs): continue
					out[cs] = (out[cs] as Vector2) + delta
					stack.append(cs)
			out[pin_s] = pv
	else:
		# 模式 B：推理链纵向自上而下（人物在最上，结论→推断/链→线索依次向下逐行排开）
		out[owner._focus_person] = center
		var rows := {}
		for nd in nodes:
			if nd.id == owner._focus_person: continue
			var d: int = 4
			match nd.kind:
				"conclusion": d = 1
				"hypo", "chain": d = 2
				"clue": d = 3
			if not rows.has(d): rows[d] = []
			rows[d].append(nd.id)
		var depth_keys := rows.keys()
		depth_keys.sort()
		var span2: float = owner._canvas.size.x - 200.0 if owner._canvas.size.x > 200 else 1080.0
		var y0: float = center.y - 100.0
		var row_gap2 := 130.0
		var rr := 0
		for d in depth_keys:
			var arr: Array = rows[d]
			var n2: int = arr.size()
			var y: float = y0 + float(rr) * row_gap2
			for i in n2:
				var x: float = 100.0 + (float(i) / maxi(n2, 1)) * span2
				if n2 == 1: x = owner._canvas.size.x * 0.5 if owner._canvas.size.x > 0 else 540.0
				out[arr[i]] = Vector2(x, y)
			rr += 1
	return out


# ===================== 模式 C：按关系驱动的横向阶梯树（华生示范对齐） =====================
## 思想：不再按 kind 一次性横排，而是把「整条推理链」作为一棵以人物为根的关系树：
##   人物(col0) → 结论(col1) → 推断/推理链(col2) → 线索(col3) 逐列向右阶梯铺开。
##  - 排列起自人物为根的 BFS 树（邻居层更深者作子），同父子树归组、父居子带中央；
##  - 多结论/多推断/多线索同列垂直整齐堆叠，不出现跨侧分叉（避免连线交叉）；
##  - direction 不硬性统一：人物偏右则树向左生长、偏左则向右，人物可自由摆放（保存位优先）；
##  - 孤立（未接入树）线索在外围散布；多人物每人一棵独立子树、水平错开不交叉。
func _relation_tree_layout(nodes: Array, center: Vector2, saved_pos: Dictionary, out: Dictionary) -> void:
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


# ===================== 模式 C 默认：XMind 星形布局（第8节改造 · A①+B①） =====================
## 以「关系树根」（人物；或无人物的结论）为画布中心；根的直接子节点（结论）均分左/右两侧，
## 每侧子树向远离中心方向横向生长（结论→推断→线索），连线同侧不跨中心交叉。
## 仅根节点位置可被玩家手动锁定（持久化到 graph_root_anchors），其余全部自动派生。
##
## 树的构建：用玩家真实建立的有向边（_relations 中 support/target，以及结论领域 target 金边）
## 确定父子关系——from = 推导依据（子），to = 被推导对象（父）。即 父 = r.to，子 = r.from。
## 这能正确处理「推断→推断」同层级边（如 W-C1+W-C2→W-C3，W-C3 作为 W-C1/W-C2 的父），
## 而早先按「节点 kind 层级」下降的 BFS 会漏掉这类同层边、把节点丢成孤儿导致重叠。
## 每个子节点只取一个父：多个候选父时取 ring_depth 更大者（更靠近结论/人物的上层），保持链紧凑。
## 根的直接子节点按左右扇区分派，每子树按估算带长分配独立上下带，再递归向外放射；
## 同侧多分支不再共享同一垂直列，避免堆叠重叠。超出画布由 fit_view 缩放看全。
func _star_tree_layout(nodes: Array, center: Vector2, saved_root: Dictionary, out: Dictionary) -> void:
	# 收集「子 → 候选父」并解析唯一父（抽为 _build_parent_of，布局与拖拽子树计算共用口径）
	var parent_of := _build_parent_of()

	# 父子表 + 根集合（从未作为任何子出现的节点 = 根）
	var child_map := {}
	for ch in parent_of:
		var p: String = parent_of[ch]
		if not child_map.has(p): child_map[p] = []
		if not (ch in child_map[p]): child_map[p].append(ch)
	var has_parent := {}
	for ch in parent_of: has_parent[ch] = true
	var roots := []
	for nd in nodes:
		if not has_parent.has(nd.id):
			if not (nd.id in roots): roots.append(nd.id)
	if roots.is_empty() and not nodes.is_empty():
		roots = [nodes[0].id]

	# 放射根集合：优先人物根（多人物各成树、互不重叠）；其余「非人物孤立根」
	# （如删除某关系后变成根的推断/结论）并入首个放射根，统一左右放射，避免多根各自
	# 左右放射导致相邻子树带重叠（需求2：删除边后根节点不再与既有文本框叠加）。
	var person_roots := []
	for r in roots:
		if owner._fold._kind_of(r) == "person":
			person_roots.append(r)
	var emit_roots: Array = person_roots if person_roots.size() > 0 else (roots if roots.size() > 0 else [])
	var main_root: String = emit_roots[0] if emit_roots.size() > 0 else ""
	if main_root != "" and not child_map.has(main_root):
		child_map[main_root] = []
	for rt in roots:
		if rt == main_root: continue
		if owner._fold._kind_of(rt) == "person": continue   # 其它人物根各自独立放射
		# 需求：推断/结论/链类的孤立根（删除关系后变根、或本就无父）也不再并入主根，
		# 各自独立散布（碰撞感知落位），与孤立线索一致；避免「删除关系后变成根的推断/结论」
		# 被强行并入主根放射带，也避免它们随人物拖动而移动。
		continue

	# BFS：标记所有树内节点并求最大深度（用于自适应列间距）
	var assigned := {}
	var level_of := {}
	var max_level: int = 0
	var q := []
	for r in emit_roots:
		if assigned.has(r): continue
		assigned[r] = true
		level_of[r] = 0
		q.append(r)
	while q.size() > 0:
		var rest := []
		for u in q:
			for nb in child_map.get(u, []):
				if assigned.has(nb): continue
				assigned[nb] = true
				var lv: int = level_of.get(u, 0) + 1
				level_of[nb] = lv
				max_level = maxi(max_level, lv)
				rest.append(nb)
		q = rest
	# 估算高度（用于同列垂直堆叠留 20px 间隙，保证不重叠）
	var est_h := {}
	for nd in nodes: est_h[nd.id] = maxf(_est_node_h(nd), 140.0)
	# 估算每棵子树所需垂直带长（含间隙），用于把不同结论分支分配到独立上下扇区，避免同侧堆叠
	var memo := {}
	for _nd in nodes:
		_subtree_span_est(_nd.id, child_map, est_h, memo)

	# 列间距自适应画布宽度与树深：保证最深一列仍落在画布内
	var m: float = 60.0
	var half_avail: float = maxf(center.x - m - 90.0, 200.0)
	var col_gap: float = maxf(_clue_box_height(), clampf(half_avail / maxf(float(max_level), 1.0), 165.0, 300.0))   # 需求3：下限≥一个线索文本框高度

	# 放射根位置：仅 emit_roots 计 root_gap 均布；非人物孤立根已并入 main_root，不再单独定位
	var root_gap: float = 360.0
	var root_pos := {}
	for i in emit_roots.size():
		var rid: String = emit_roots[i]
		var rp := Vector2(center.x, center.y)
		if emit_roots.size() > 1:
			rp.x = center.x + (float(i) - float(emit_roots.size() - 1) * 0.5) * root_gap
		var sv: Variant = saved_root.get(rid, null)
		if sv is Vector2:
			rp = sv
		root_pos[rid] = rp
		out[rid] = rp

	# 按放射根的直接子节点分成左右扇区，每子树按带长分配独立上下带：结论星形分布于根四周，
	# 每条结论子树向同侧同带向外放射生长（推断→线索），避免不同分支垂直堆叠重叠。
	for r in emit_roots:
		var rx: float = root_pos[r].x
		var ry: float = root_pos[r].y
		var ch0: Array = child_map.get(r, []).duplicate()
		var half_n0: int = ceili(float(ch0.size()) / 2.0)
		var left_ch := []
		var right_ch := []
		for i in ch0.size():
			if i < half_n0:
				left_ch.append(ch0[i])
			else:
				right_ch.append(ch0[i])
		_place_side_children(left_ch, rx, ry, -1.0, col_gap, memo, est_h, child_map, out)
		_place_side_children(right_ch, rx, ry, 1.0, col_gap, memo, est_h, child_map, out)

	# 孤立（未接入树）节点：保存位优先；否则按 kind 分层垂直整齐排列（替代原随机螺旋），
	# 使默认星形布局下无关系节点也不乱飞，与「自动排列」视觉规则一致。
	var existing_spare := {}
	for _k in out:
		if out[_k] is Vector2:
			existing_spare[_k] = out[_k]
	# 先处理保存位/手动位
	for nd in nodes:
		if out.has(nd.id): continue
		var sv3: Variant = saved_root.get(nd.id, null)
		if sv3 is Vector2:
			out[nd.id] = sv3
			existing_spare[nd.id] = sv3
			continue
	# 剩余孤立节点按 kind 分组、分层排列
	var isolated_by_kind := {}
	for nd in nodes:
		if out.has(nd.id): continue
		var k: String = owner._fold._kind_of(nd.id)
		if not isolated_by_kind.has(k):
			isolated_by_kind[k] = []
		isolated_by_kind[k].append(nd.id)
	var kind_col := {"conclusion": 1.0, "hypo": 2.0, "chain": 2.0, "clue": 3.0, "person": 0.0, "event": 0.0}
	var ROW_H := 130.0
	for k in isolated_by_kind:
		var ids: Array = isolated_by_kind[k]
		if ids.is_empty(): continue
		var col_idx: float = kind_col.get(k, 3.0)
		var base_x: float = center.x + col_idx * col_gap
		var total_h: float = maxf(0.0, float(ids.size() - 1)) * ROW_H
		var top_y: float = center.y - total_h * 0.5
		for i in ids.size():
			var nid: String = ids[i]
			out[nid] = Vector2(base_x, top_y + float(i) * ROW_H)
			existing_spare[nid] = out[nid]

	# 软钳制：仅防 NaN / 极端值（保留列间距，不收缩到画布 margin，否则深树列会重叠）。超出画布由 fit_view 缩放看全。
	for idf in out:
		out[idf] = _clamp_to_canvas(out[idf])


## 兄弟节点垂直间距：取文本框高度的 0.35（折中：此前 20px 过窄贴在一起，0.5h 在节点多时又过于松散）。
## 下限 24 防止极矮节点间距过小。
func _sib_gap(h: float) -> float:
	return maxf(h * 0.35, 24.0)


## 把一组同侧子节点从 root 沿 dirv 方向逐列向外排布（复用 _assign_subtree 递归子树）
func _assign_side(root: String, group: Array, child_map: Dictionary, sp: Dictionary, est_h: Dictionary, out: Dictionary, dirv: float, col_gap: float) -> void:
	if group.is_empty(): return
	var rx: float = out.get(root, Vector2.ZERO).x
	var ry: float = out.get(root, Vector2.ZERO).y
	var total := 0.0
	var _gap_sum := 0.0
	for c in group:
		total += sp.get(c, 140.0) as float
		_gap_sum += _sib_gap(sp.get(c, 140.0))
	total += _gap_sum
	var top: float = ry - total * 0.5
	var cur: float = top
	for c in group:
		var h: float = sp.get(c, 140.0) as float
		_assign_subtree(c, child_map, sp, est_h, out, cur, cur + h, rx + dirv * col_gap, dirv, col_gap)
		cur += h + _sib_gap(h)


## 节点是否为「关系树根」（手动拖拽时仅根的位置被持久化）
## 与 _star_tree_layout 同口径：人物恒为根；结论若有领域 target（→人物）或作为 support/target 入边（有父）则为非根；
## 其余「从未作为有向边 from（即无父）」的节点即为根（如无人物的结论、孤立推断起点）。
func _is_tree_root(id: String) -> bool:
	if owner._fold._kind_of(id) == "person":
		return true
	# 作为任意 support/target 边的 from（推导依据方）⇒ 有父，非根
	for r in owner._relations:
		if r.get("kind", "") in ["support", "target"] and str(r.get("from", "")) == id:
			return false
	# 结论领域 target 金边（conclusion → person）→ 挂在人物下，非根
	if owner._fold._kind_of(id) == "conclusion":
		var _cid: String = str(id).replace("conclusion_", "")
		var _cdef: Dictionary = owner._conclusion_def(_cid)
		if _cdef.get("target", "") != "":
			return false
	return true


## 推理树「唯一父」映射（布局与拖拽子树计算共用口径）：from=子，to=父；
## 多个候选父取 ring_depth 更大者（更靠近结论/人物的上层），保持推断组合链紧凑。
func _build_parent_of() -> Dictionary:
	var RD := {"person": 0, "event": 0, "conclusion": 1, "hypo": 2, "chain": 2, "clue": 3}
	var rd_of := func(id: String) -> int:
		return RD.get(owner._fold._kind_of(id), 3)
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
		else:
			add_parent.call(_f, _t)
	# 结论领域 target 金边（conclusion → person:XXX）不在 _relations 中，单独补：结论作子、人物作父
	for _dc in owner._derived_conclusions:
		var _cid: String = str(_dc.get("id", ""))
		if _cid == "": continue
		var _nid: String = "conclusion_" + _cid
		var _cdef: Dictionary = owner._conclusion_def(_cid)
		var _tgt: String = _cdef.get("target", "")
		if _tgt == "": continue
		var _pid: String = _tgt.substr("person:".length()) if _tgt.begins_with("person:") else _tgt
		add_parent.call(_nid, _pid)
	# 人物↔其相关线索（related_npcs）结构边：与 _build_adjacency 同口径。
	# 使「把线索拖到人物上打标签」的线索归入对应人物子树；完全孤立线索此处无父→保持独立。
	for _rc in owner._clues:
		var _rcid: String = str(_rc.get("id", ""))
		if _rcid == "": continue
		for _p in _rc.get("related_npcs", []):
			if owner._fold._kind_of(_p) == "person":
				add_parent.call(_rcid, _p)
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
	var parent_of := {}
	for ch in parent_cand:
		var best: String = ""
		var best_rd: int = -1
		for p in parent_cand[ch]:
			var rd: int = rd_of.call(p)
			if rd > best_rd:
				best_rd = rd
				best = p
		parent_of[ch] = best
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


## 把根的直接子节点按子树带长分配到根的某一侧（dirv=-1 左 / +1 右），上下交替排布，
## 使各结论子树占据独立垂直扇区，避免同侧多分支堆叠重叠。
func _place_side_children(children: Array, root_x: float, root_y: float, dirv: float, col_gap: float, sp: Dictionary, est_h: Dictionary, child_map: Dictionary, out: Dictionary) -> void:
	if children.is_empty(): return
	var total: float = 0.0
	var _gap_sum: float = 0.0
	for c in children:
		total += sp.get(c, est_h.get(c, 140.0) as float)
		_gap_sum += _sib_gap(est_h.get(c, 140.0) as float)
	total += _gap_sum
	var top: float = root_y - total * 0.5
	var cur: float = top
	for c in children:
		var span: float = sp.get(c, est_h.get(c, 140.0) as float)
		_assign_subtree(c, child_map, sp, est_h, out, cur, cur + span, root_x + dirv * col_gap, dirv, col_gap)
		cur += span + _sib_gap(span)


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
	var col_gap := maxf(_clue_box_height(), 300.0)   # 需求3：列间距下限 = 一个线索文本框高度
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


# ===================== XMind 式自由布局（保留；当前模式 C 用关系树，此处未启用） =====================
func _xmind_layout(nodes: Array, center: Vector2, saved_pos: Dictionary, out: Dictionary) -> void:
	# 人物锚点：沿用已保存位置（人物可自由拖动/画布可有多个人物）；
	# 无保存时默认放在水平约 72% 处，给推理树留出向左铺开的空间。
	var person_pos: Vector2 = center
	var sp: Variant = saved_pos.get(owner._focus_person, null)
	if sp is Vector2:
		person_pos = sp
	else:
		person_pos = _clamp_to_canvas(Vector2(owner._canvas.size.x * 0.72, owner._canvas.size.y * 0.5))
	out[owner._focus_person] = person_pos
	# 层深：结论离人物最近(1)，推断/推理链中层(2)，线索最外层(3)
	var layer_of := {}
	for nd in nodes:
		match nd.kind:
			"conclusion":
				layer_of[nd.id] = 1
			"chain":
				layer_of[nd.id] = 2
			"hypo":
				layer_of[nd.id] = 2
			"clue":
				layer_of[nd.id] = 3
			_:
				layer_of[nd.id] = 4
	# 生长方向：人物偏右则向左铺开，偏左则向右铺开，避免树伸出画布
	var dirv := 1.0
	if person_pos.x >= owner._canvas.size.x * 0.5:
		dirv = -1.0
	var col_gap: float = 250.0
	# 按层分列；已保存位置直接沿用（尊重玩家拖动）
	var by_layer := {}
	var max_layer := 0
	for nd in nodes:
		if nd.id == owner._focus_person:
			continue
		var saved_v: Variant = saved_pos.get(nd.id, null)
		if saved_v is Vector2:
			out[nd.id] = saved_v
		else:
			var lv: int = layer_of.get(nd.id, 4)
			if not by_layer.has(lv):
				by_layer[lv] = []
			by_layer[lv].append(nd.id)
			if lv > max_layer:
				max_layer = lv
	# 同层同列：列 x 随层距人物递增，列内按高度均匀堆叠（多结论/多推断同侧时整齐排列）
	for lv in by_layer.keys():
		var ids: Array = by_layer[lv]
		var col_x: float = person_pos.x + dirv * (float(lv) * col_gap)
		var n := ids.size()
		var step: float = 92.0
		var total_h: float = float(maxi(n - 1, 0)) * step
		var top: float = clampf(person_pos.y - total_h * 0.5, 60.0, owner._canvas.size.y - 60.0)
		for j in n:
			out[ids[j]] = _clamp_to_canvas(Vector2(col_x, top + float(j) * step))
	# 布局收尾：全部钳制到画布内，防止默认布局把文本节点挤出可视区
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
	if not is_finite(p.x) or not is_finite(p.y):
		return Vector2.ZERO
	var cv: Vector2 = owner._canvas.size
	var slack: float = max(cv.x, cv.y, 3000.0)
	return Vector2(clampf(p.x, -slack, cv.x + slack),
		clampf(p.y, -slack, cv.y + slack))


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
