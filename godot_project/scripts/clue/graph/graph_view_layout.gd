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
			var _ha: float = _view_height(arr[i - 1])
			var _hb: float = _view_height(arr[i])
			var _min_cy: float = owner._node_center[arr[i - 1]].y + (_ha + _hb) * 0.5 + 15.0
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


## 按节点 kind 估算渲染宽度（用于自适应半径防重叠；与 _make_node 卡片尺寸×2 同步）
func _node_width_for_kind(kind: String) -> float:
	# 2026-08-21：宽度整体减半（配合文本框自适应窄化，环径估算同步收紧）
	match kind:
		"clue":       return 160.0
		"hypo":       return 140.0
		"conclusion": return 160.0
		"chain":      return 125.0
		_: return 150.0


## 估算节点卡片高度（与 _make_node 尺寸逻辑一致）：行数=ceil(文本宽/420)，行数×行高＋副标题＋内边距
func _est_node_h(nd: Dictionary) -> float:
	var fs: float = 28.0
	var line_h: float = fs * 1.35
	var sub_h: float = 22.0 * 1.35
	var txt: String = str(nd.get("label", ""))
	var natural: float = maxf(float(txt.length()) * fs, 1.0)
	var nlines: float = maxf(1.0, ceil(natural / 420.0))
	return nlines * line_h + sub_h + 2.0 + 12.0


# ===================== 主布局入口 =====================
func _compute_layout(nodes: Array) -> Dictionary:
	var center := owner._canvas.size * 0.5
	if owner._canvas.size.x <= 0 or owner._canvas.size.y <= 0:
		# headless / 未布局时兜底（test_graph_view 会强制设 1280x720，但兜底仍必要）
		center = Vector2(960, 540)
	var out := {}

	# 加载已持久化位置
	var saved_pos: Dictionary = owner._state_store.get("graph_node_positions", {})

	if owner._mode == GraphViewController.ViewMode.MODE_C:
		# 按关系驱动的横向阶梯树（华生示范对齐）：人物→结论→推断→线索 逐列向左/右阶梯铺开，
		# 人物偏左树向右、偏右树向左（方向不硬性统一）；多人物各成一棵独立子树水平错开不交叉。
		_relation_tree_layout(nodes, center, saved_pos, out)
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
	var adj := owner._build_adjacency()
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
	# 节点估算高度（文字行数×行高 + 副标题 + 内边距），用于垂直带切分保证兄弟间 ≥15px
	var est_h := {}
	for nd in nodes:
		est_h[nd.id] = _est_node_h(nd)
	var memo := {}
	for _nd in nodes:
		_subtree_span_est(_nd.id, child_map, est_h, memo)
	# 人物定位：保存位优先（人物可自由拖动）；多人物水平错开
	var col_gap: float = 300.0
	var root_default_x: float = center.x
	var _rd: Variant = saved_pos.get(owner._focus_person, null) if owner._focus_person != "" else null
	if _rd is Vector2:
		root_default_x = _rd.x
	for r in roots:
		var _sv: Variant = saved_pos.get(r, null)
		var rx: float = _sv.x if (_sv is Vector2) else root_default_x
		var ry: float = _sv.y if (_sv is Vector2) else center.y
		out[r] = Vector2(rx, ry)
	# direction：人物偏右→向左生长，偏左→向右（方向不硬性统一）
	var dirv := 1.0
	if root_default_x >= owner._canvas.size.x * 0.5:
		dirv = -1.0
	for r in roots:
		var _sv2: Variant = saved_pos.get(r, null)
		var rx2: float = _sv2.x if (_sv2 is Vector2) else root_default_x
		var ry2: float = _sv2.y if (_sv2 is Vector2) else center.y
		var _half3: float = maxf(memo.get(r, 130.0) * 0.5, 60.0)
		var top2: float = ry2 - _half3
		var bot2: float = ry2 + _half3
		_assign_subtree(r, child_map, memo, est_h, out, top2, bot2, rx2, dirv, col_gap)
	# 孤立（未接入树）节点：外围散布（保存位优先），保持可见
	var spare_i := 0
	var out_keys := {}
	for k in out: out_keys[k] = true
	for nd in nodes:
		if out_keys.has(nd.id): continue
		var sv: Variant = saved_pos.get(nd.id, null)
		if sv is Vector2:
			out[nd.id] = sv
			continue
		out[nd.id] = Vector2(root_default_x + dirv * (5.0 + float(spare_i) * 0.6) * col_gap,
			center.y - 220.0 + float(spare_i) * 120.0)
		spare_i += 1
	# 手动拖动过的节点保持原位，不被自动布局覆盖（保证每个人物/结论/推断/线索都能自由移动）
	for mid2 in owner._manual_nodes:
		var _sv3: Variant = saved_pos.get(mid2, null)
		if _sv3 is Vector2 and out.has(mid2):
			out[mid2] = _sv3
	for idf in out:
		out[idf] = _clamp_to_canvas(out[idf])


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


## 子树所需垂直带长（递归）：父带 ≥ max(自身估高, Σ子带长 + 兄弟间隙15)，保证后代不溢出、兄弟不交叠
func _subtree_span_est(u: String, child_map: Dictionary, est_h: Dictionary, memo: Dictionary) -> float:
	if memo.has(u):
		return memo[u]
	var ch: Array = child_map.get(u, [])
	var s: float = est_h.get(u, 130.0) as float
	if not ch.is_empty():
		var sub: float = 0.0
		for _c in ch:
			sub += _subtree_span_est(_c, child_map, est_h, memo)
		s = maxf(s, sub + 15.0 * (float(ch.size()) - 1.0))
	memo[u] = s
	return s


## 递归布点：父居其子带中央；子带按各自子树带长精确切分（不足则居中留白），兄弟带间保证 ≥15px，绝不溢出交叠
func _assign_subtree(u: String, child_map: Dictionary, sp: Dictionary, est_h: Dictionary, out: Dictionary, top: float, bot: float, pxx: float, dirv: float, col_gap: float) -> void:
	var mid_y: float = (top + bot) * 0.5
	if out.has(u):
		out[u] = Vector2(out[u].x, mid_y)
	else:
		out[u] = Vector2(pxx, mid_y)
	var ch: Array = child_map.get(u, [])
	if ch.is_empty():
		return
	var totalSpan: float = 0.0
	for _c in ch:
		totalSpan += sp.get(_c, 130.0) as float
	totalSpan += 15.0 * (float(ch.size()) - 1.0)
	var cur: float = top + maxf(0.0, ((bot - top) - totalSpan) * 0.5)
	for c in ch:
		var _h: float = sp.get(c, 130.0) as float
		_assign_subtree(c, child_map, sp, est_h, out, cur, cur + _h, pxx + dirv * col_gap, dirv, col_gap)
		cur += _h + 15.0


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
	var m: float = 60.0
	var cv: Vector2 = owner._canvas.size
	var ox: float = clampf(p.x, m, maxf(cv.x - m, m))
	var oy: float = clampf(p.y, m, maxf(cv.y - m, m))
	return Vector2(ox, oy)


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
## 把当前所有节点位置写入 state_store（持久化手动布局，含隐藏节点——见设计 §6）
## 先用当前可见位置刷新缓存，再写入；隐藏节点位置由 _all_positions 保留（避免展开错位）。
func _persist_node_positions() -> void:
	if owner._state_store.is_empty(): return
	# 仅模式 C 写盘：模式 B 布局（或用户在模式 B 的拖动）不持久化，
	# 否则会覆盖模式 C 的存档位置 → 重进/切回星型时位置错乱（问题2）。
	if owner._mode != GraphViewController.ViewMode.MODE_C: return
	for id in owner._node_center:
		owner._all_positions[id] = owner._node_center[id]
	var pos: Dictionary = {}
	for id in owner._all_positions:
		var p = owner._all_positions[id]
		if id == owner._focus_person: continue   # 中心永远画布中央，不存
		if p is Vector2:
			pos[id] = p
	owner._state_store["graph_node_positions"] = pos
