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
				var ra: Rect2 = rects[id_a]
				var rb: Rect2 = rects[id_b]
				if not ra.intersects(rb):
					continue
				var a_fixed: bool = owner._manual_nodes.has(id_a) or _prot.has(id_a)
				var b_fixed: bool = owner._manual_nodes.has(id_b) or _prot.has(id_b)
				if a_fixed and b_fixed:
					# 双方都是玩家落点（刚性）：不挪动，避免拖动松手后被"自动排列"
					continue
				if b_fixed:
					# 下方刚性 → 上方可动节点上移：使 a 底边 ≤ b 顶边 − 24
					var push_up: float = ra.end.y - rb.position.y + 80.0
					owner._node_center[id_a] = Vector2(owner._node_center[id_a].x,
						owner._node_center[id_a].y - push_up)
					rects[id_a] = _node_rect(id_a)
					_sync_node_view(id_a)
				else:
					# 上方刚性，或双方皆可动 → 下方节点下移
					var push: float = ra.end.y - rb.position.y + 80.0
					owner._node_center[id_b] = Vector2(owner._node_center[id_b].x,
						owner._node_center[id_b].y + push)
					rects[id_b] = _node_rect(id_b)
					_sync_node_view(id_b)
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
			# 非拖动子树节点（上游/兄弟分支）保持拖前实际位、不重排——仅被拖子树平移，
			# 其余节点稳定不动（2026-09-05 修复「拖中下层节点导致上游/兄弟被重排错位移」）。
			var _prot2: Dictionary = _pinned_subtree_nodes()
			for nd in nodes:
				var nid := str(nd.id)
				if _prot2.has(nid): continue
				if prev_center.has(nid): out[nid] = prev_center[nid]
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
			var stack: Array = [pin_s]
			while stack.size() > 0:
				var u: String = stack.pop_back()
				for c in child_map.get(u, []):
					var cs := str(c)
					if saved_pos.has(cs): continue   # 后代若本身也被钉，交给其自身钉位处理
					if prev_center.has(cs):
						out[cs] = prev_center[cs]     # 保持拖拽末位（含拖拽平移）：刚性跟随根
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

	# BFS 真实树深（按 _build_parent_of 关系，非 kind）：串行结论沿链更深一层
	var depth_of := {}
	var q := []
	for r in roots:
		if depth_of.has(r):
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

	# Y = tidy 纵向 slot（2026-09-18 根治「加链重排深U」）：同 depth 列的兄弟按 tidy slot
	# 垂直铺开、父居中于子中点；取代原 BuchheimWalker 轮廓打包（按子树高堆叠会把同深度兄弟
	# 堆成一根长柱，连边被拉成长U）。slot 间距有界 → 任何连边纵向跨度有界 → 深U 物理消失。
	var max_h: float = 140.0
	for nd in nodes:
		max_h = maxf(max_h, est_h[nd.id])
	var ROW_STEP: float = max_h + _CONTOUR_SEP

	# 根排序：人物优先；其余按 kind 顺序聚类（同 kind 相邻成带，亲近分组）
	var kind_rank := {"person": 0, "event": 0, "conclusion": 1, "chain": 2, "hypo": 2, "clue": 3}
	roots.sort_custom(func(a, b):
		var ra: int = kind_rank.get(owner._fold._kind_of(a), 3)
		var rb: int = kind_rank.get(owner._fold._kind_of(b), 3)
		if ra != rb:
			return ra < rb
		return str(a) < str(b))

	# 各根水平带垂直堆叠（多人物各占一独立水平带）。先算每根 tidy-Y 跨度，再森林垂直居中、自上而下铺开。
	var subtree_sep: float = 40.0   # 根带间垂直间隙（亲近分组：异人物/异组留少量空）
	var root_tidy := {}
	var root_range := {}
	var total_h: float = 0.0
	_aff_adj_dirty = true   # 链路亲和邻接缓存：单次布局内复用，跨次布局重建（relations 可能已变）
	for r in roots:
		var ty: Dictionary = _tidy_y(str(r), child_map, ROW_STEP)
		root_tidy[r] = ty
		var gmin: float = 1e18
		var gmax: float = -1e18
		for nid in ty.keys():
			gmin = minf(gmin, ty[nid])
			gmax = maxf(gmax, ty[nid])
		root_range[r] = [gmin, gmax]
		total_h += (gmax - gmin) + subtree_sep
	total_h = maxf(0.0, total_h - subtree_sep)

	# 2026-09-19 思傅定案（叶子计数触发分散 · 取代旧 1200px 高度预算）：
	#   分散对象 = 全部无根链（结论-推断-线索 / 推断-线索，单枝或多枝的「无根森林」同属此类，不再因无树整类排除）。
	#   两分支：
	#     · 有树（person/event 根）且主列叶子(树叶+同列无根叶) > 6 → 无根链整体搬到**树右侧**新空区域（单列竖向、允许超高、不递归切分，B/C 定案）；
	#     · 纯无根森林（无任何人物/事件根）且叶子 > 6 → 无根链**自身多列铺开**（按叶子贪心切列、每列≤6叶、列间留 gap、整体水平居中）；
	#   整洁树（person/event 根）结构完全不动、永不镜像、始终主列垂直堆叠居中；
	#   不触发（≤6 叶）/ 无无根链 时，所有根单主列垂直堆叠（旧版行为，小案子不被打散）。
	var col_gap: float = 160.0   # 列间水平间隙
	# 根分类：人物根（整洁树） vs 无根链（零散链路）。kind 同 roots 排序口径（owner._fold._kind_of）。
	var person_roots: Array = []
	var loose_roots: Array = []
	for r in roots:
		var rk: String = owner._fold._kind_of(r)
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
	# 三分支判定：
	#   do_loose_forest = 纯无根森林（无人物/事件根）且叶子 > 6 → 自身多列铺开；
	#   do_relocate     = 有树 + 无根链 + 主列叶子 > 6 → 无根链整体搬树右侧单列（B/C 定案）；
	#   其余（≤6 叶 / 无无根链）→ 全部单主列（旧版行为，兜底 else）。
	var do_loose_forest: bool = person_roots.is_empty() and (not loose_roots.is_empty()) and (loose_leaf_count > 6)
	var do_relocate: bool = (not loose_roots.is_empty()) and (not person_roots.is_empty()) and (tree_leaf_count + loose_leaf_count > 6)

	if do_loose_forest:
		# ===== 纯无根森林：自身多列铺开（无树可搬，按叶子贪心切列、每列≤6叶、列间留 gap、整体水平居中）=====
		# 1. 按「每列 ≤6 叶」目标切成 ncols 列，顺序切块（同 kind 链路成块相邻，避免打散）
		var ncols: int = ceili(float(loose_leaf_count) / 6.0)
		ncols = maxi(2, ncols)
		var per: int = ceili(float(loose_roots.size()) / float(ncols))
		var lcols: Array = []
		for i in loose_roots.size():
			var ci: int = i / per
			if ci >= lcols.size():
				lcols.append([])
			lcols[ci].append(loose_roots[i])
		# 2. 每列横向占宽（含该列所有链最深偏移 + 半宽 + 根半宽）
		var col_widths: Array = []
		for col in lcols:
			var w: float = 0.0
			for r in col:
				var wmax: float = 0.0
				for nid in root_tidy[r].keys():
					var dw: int = int(depth_of.get(nid, 0))
					wmax = maxf(wmax, float(col_x.get(dw, col_x[0])) - float(col_x[0]) + max_w.get(dw, 150.0) * 0.5)
				w = maxf(w, wmax + max_w.get(0, 150.0) * 0.5)
			col_widths.append(w)
		# 3. 整体相对画布中心水平居中
		var total_w: float = 0.0
		for i in col_widths.size():
			total_w += col_widths[i]
			if i > 0:
				total_w += col_gap
		var cur_x: float = center.x - total_w * 0.5
		# 4. 逐列：列内每条链竖向堆叠（整体相对 center.y 垂直居中），列起点 cur_x；列间向右铺开
		for ci in lcols.size():
			var col: Array = lcols[ci]
			var ch_h: float = 0.0
			for r in col:
				ch_h += (root_range[r][1] - root_range[r][0]) + subtree_sep
			ch_h = maxf(0.0, ch_h - subtree_sep)
			var cury: float = center.y - ch_h * 0.5
			for r in col:
				var ty: Dictionary = root_tidy[r]
				var rg: Array = root_range[r]
				var sv: Variant = saved_pos.get(r, null)
				var rx: float = cur_x
				var ry: float = cury - rg[0]
				if sv is Vector2:
					rx = sv.x
					ry = sv.y
				var root_y0: float = ty.get(str(r), 0.0)
				out[r] = Vector2(rx, ry)
				for nid in ty.keys():
					if str(nid) == str(r):
						continue
					var _d := int(depth_of.get(nid, 0))
					out[nid] = Vector2(rx + (float(col_x.get(_d, col_x[0])) - float(col_x[0])), ry + (ty[nid] - root_y0))
				cury += (rg[1] - rg[0]) + subtree_sep
			cur_x += col_widths[ci] + col_gap
	elif do_relocate:
		# ===== 搬迁：人物整洁树独占主列；无根链整体搬到树右侧新空区域（单列竖向、允许超高）=====
		# 人物带：主列（col_x[0]）垂直堆叠、整体居中（根-干-枝-叶层展结构保持，永不镜像）
		var ph_total: float = 0.0
		for r in person_roots:
			ph_total += (root_range[r][1] - root_range[r][0]) + subtree_sep
		ph_total = maxf(0.0, ph_total - subtree_sep)
		var pcur_y: float = center.y - ph_total * 0.5
		for r in person_roots:
			var ty: Dictionary = root_tidy[r]
			var rg: Array = root_range[r]
			var sv: Variant = saved_pos.get(r, null)
			var rx: float = col_x[0]
			var ry: float = pcur_y - rg[0]
			if sv is Vector2:
				rx = sv.x
				ry = sv.y
			var root_y0: float = ty.get(str(r), 0.0)
			out[r] = Vector2(rx, ry)
			for nid in ty.keys():
				if str(nid) == str(r):
					continue
				var _d := int(depth_of.get(nid, 0))
				out[nid] = Vector2(rx + (float(col_x.get(_d, col_x[0])) - float(col_x[0])), ry + (ty[nid] - root_y0))
			pcur_y += (rg[1] - rg[0]) + subtree_sep
		# 无根链新区域：树最右沿 + 间隙 起点的单列竖向堆叠；整体相对画布中心垂直居中（允许超高，不递归切分）
		var maxd: int = 0
		for d in col_x.keys():
			maxd = maxi(maxd, int(d))
		var main_right: float = float(col_x.get(maxd, col_x[0])) - float(col_x[0]) + max_w.get(maxd, 150.0) * 0.5
		var band_x: float = col_x[0] + main_right + col_gap
		var loose_total_h: float = 0.0
		for r in loose_roots:
			loose_total_h += (root_range[r][1] - root_range[r][0]) + subtree_sep
		loose_total_h = maxf(0.0, loose_total_h - subtree_sep)
		var lcur_y: float = center.y - loose_total_h * 0.5
		for r in loose_roots:
			var ty: Dictionary = root_tidy[r]
			var rg: Array = root_range[r]
			var sv: Variant = saved_pos.get(r, null)
			var rx: float = band_x
			var ry: float = lcur_y - rg[0]
			if sv is Vector2:
				rx = sv.x
				ry = sv.y
			# 根置于 ry（带顶锚点）；子节点相对 y 减去根自身 tidy-y（美学3）
			var root_y0: float = ty.get(str(r), 0.0)
			out[r] = Vector2(rx, ry)
			for nid in ty.keys():
				if str(nid) == str(r):
					continue
				var _d := int(depth_of.get(nid, 0))
				out[nid] = Vector2(rx + (float(col_x.get(_d, col_x[0])) - float(col_x[0])), ry + (ty[nid] - root_y0))
			lcur_y += (rg[1] - rg[0]) + subtree_sep
	else:
		# ===== 旧版行为（≤6 叶 / 无无根链）：全部根单主列垂直堆叠、整体垂直居中 =====
		var start_y: float = center.y - total_h * 0.5
		var cur_y: float = start_y
		for r in roots:
			var ty: Dictionary = root_tidy[r]
			var rg: Array = root_range[r]
			var min_c: float = rg[0]
			var sv: Variant = saved_pos.get(r, null)
			var rx: float = col_x[0]
			var ry: float = cur_y - min_c
			if sv is Vector2:
				rx = sv.x
				ry = sv.y
			# 根置于 ry（带顶锚点）；子节点相对 y 减去根自身 tidy-y（ty[root] 为子群中点），
			# 使根居中于子群（XMind 局部对称 · 美学3），而非落在带顶。
			var root_y0: float = ty.get(str(r), 0.0)
			out[r] = Vector2(rx, ry)
			for nid in ty.keys():
				if str(nid) == str(r):
					continue
				# X 相对根（2026-09-18 修复）：根被钉位（rx=锚点.x）时子列必须相对根偏移，
				# 否则子树仍落在以画布中心为基准的 col_x 绝对列上——人物移走后推理链滞留原位。
				# 未钉位时 rx==col_x[0]，与旧绝对列完全等价。
				var _d := int(depth_of.get(nid, 0))
				out[nid] = Vector2(rx + (float(col_x.get(_d, col_x[0])) - float(col_x[0])), ry + (ty[nid] - root_y0))
			cur_y += (rg[1] - rg[0]) + subtree_sep
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

	# 真实高度（测量前置，与默认布局同口径）
	var est_h := {}
	var node_by_id := {}
	for nd in nodes:
		node_by_id[nd.id] = nd
		est_h[nd.id] = _real_node_height(nd.id, nd)

	# BFS 真实树深
	var depth_of := {}
	var q := []
	for r in roots:
		if depth_of.has(r):
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

	# 根排序（与默认布局同口径）
	var kind_rank := {"person": 0, "event": 0, "conclusion": 1, "chain": 2, "hypo": 2, "clue": 3}
	roots.sort_custom(func(a, b):
		var ra: int = kind_rank.get(owner._fold._kind_of(a), 3)
		var rb: int = kind_rank.get(owner._fold._kind_of(b), 3)
		if ra != rb:
			return ra < rb
		return str(a) < str(b))

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

	# ===== 无根链分流（与 _logic_tree_layout 同语义：叶子计数触发，2026-09-19 思傅定案）=====
	# 平衡布局（person 根左右分派）下，无根链（非 person/event 根的独立根）原本被等同堆叠到
	# center.x 同一竖列 → 与逻辑树布局一样挤成一条竖列。此处复用同样判定，把无根链从主堆叠中分流：
	#   do_relocate     = 有树 + 无根链 + 主列叶子(树叶+同列无根叶) > 6 → 无根链整体搬树右侧单列（允许超高、不递归切分）
	#   do_loose_forest = 纯无根森林（无人物/事件根）且叶子 > 6 → 自身多列铺开
	#   否则（≤6 叶 / 无无根链）→ 无根链并入主堆叠（旧版平衡行为，小案不打散）
	var person_roots: Array = []
	var loose_roots: Array = []
	for r in roots:
		var _rk: String = owner._fold._kind_of(r)
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
	var do_loose_forest: bool = person_roots.is_empty() and (not loose_roots.is_empty()) and (loose_leaf_count > 6)
	var do_relocate: bool = (not loose_roots.is_empty()) and (not person_roots.is_empty()) and (tree_leaf_count + loose_leaf_count > 6)
	var main_roots: Array = person_roots.duplicate()
	if not do_relocate and not do_loose_forest:
		main_roots.append_array(loose_roots)

	# 主堆叠（人物树；未触发时无根链并入）：仅对 main_roots 居中铺开
	var total_main_h: float = 0.0
	for r in main_roots:
		total_main_h += root_packed_h[r] + subtree_sep
	total_main_h = maxf(0.0, total_main_h - subtree_sep)
	var cur_y: float = center.y - total_main_h * 0.5
	for r in main_roots:
		var parts2: Dictionary = root_contours[r]
		var ph2: float = root_packed_h[r]
		var min_c: float = 0.0
		for sk in parts2.keys():
			var cont2: Dictionary = parts2[sk]["contour"]
			for rd in cont2.keys():
				min_c = minf(min_c, cont2[rd][0])
		var sv: Variant = saved_pos.get(r, null)
		var rx: float = center.x
		var ry: float = cur_y - min_c
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
		cur_y += ph2 + subtree_sep

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
		# 无根链整体搬到「树最右沿 + col_gap」起点的单列竖向；整体相对 center.y 垂直居中（允许超高，不递归切分）
		var col_gap: float = 160.0
		var band_x: float = center.x + tree_right_edge + col_gap
		var loose_total_h: float = 0.0
		for r in loose_roots:
			loose_total_h += root_packed_h[r] + subtree_sep
		loose_total_h = maxf(0.0, loose_total_h - subtree_sep)
		var lcur_y: float = center.y - loose_total_h * 0.5
		for r in loose_roots:
			var parts2: Dictionary = root_contours[r]
			var ph2: float = root_packed_h[r]
			var min_c: float = 0.0
			for sk in parts2.keys():
				var cont2: Dictionary = parts2[sk]["contour"]
				for rd in cont2.keys():
					min_c = minf(min_c, cont2[rd][0])
			var sv: Variant = saved_pos.get(r, null)
			var rx: float = band_x
			var ry: float = lcur_y - min_c
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
			lcur_y += ph2 + subtree_sep
	elif do_loose_forest:
		# 纯无根森林自身多列铺开（无树可搬）：按每列 ≤6 叶目标切 ncols 列、顺序切块、整体水平居中
		var col_gap: float = 160.0
		var ncols: int = maxi(2, ceili(float(loose_leaf_count) / 6.0))
		var per: int = ceili(float(loose_roots.size()) / float(ncols))
		var lcols: Array = []
		for i in loose_roots.size():
			var ci: int = i / per
			if ci >= lcols.size():
				lcols.append([])
			lcols[ci].append(loose_roots[i])
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
		var total_w: float = 0.0
		for i in col_widths.size():
			total_w += col_widths[i]
			if i > 0:
				total_w += col_gap
		var cur_x: float = center.x - total_w * 0.5
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
			cur_x += col_widths[ci] + col_gap

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



## tidy-tree 纵向 slot 定位（2026-09-18 配套 _logic_tree_layout 根治深U）：
## 与 _tidy_x 对称——叶子顺序占位、内部节点取子节点 Y 中点（父居中于子），
## 但沿 Y 轴铺开（而非 X）。配合 _logic_tree_layout 的 X=深度列（右向轴），
## 兄弟在同一 depth 列内按有界 slot 垂直铺开，取代原轮廓打包，根除深U。
func _tidy_y(root: String, child_map: Dictionary, slot: float) -> Dictionary:
	var res := {}
	var cursor := [0.0]
	_tidy_assign_y(str(root), child_map, slot, cursor, res)
	return res

func _tidy_assign_y(u: String, child_map: Dictionary, slot: float, cursor: Array, res: Dictionary) -> void:
	var kids: Array = child_map.get(u, [])
	if kids.is_empty():
		res[u] = cursor[0]
		cursor[0] += slot
		return
	var ys := []
	for c in kids:
		_tidy_assign_y(str(c), child_map, slot, cursor, res)
		ys.append(res.get(str(c), 0.0))
	res[u] = (ys[0] + ys[ys.size() - 1]) * 0.5



## ===================== 链路亲和排序（2026-09-17 · 思傅「同链相邻」原则） =====================
## 问题：兄弟基础序（kind/id）不管内容关联——新收线索 id 递增总排在末尾，
## 会把同一条推理链的节点与其他链隔开（用户截图：右前蹄新换蹄铁链被隔离很远、
## 血字链被拉成跨墙深U连线）。
## 方案：以「子树之间的真实连边数」为亲和度做贪心重排——有连边 ⇒ 属于同一条链，
## 排序时让彼此相邻，链上结论-推断-线索不被其他链隔离、连线短且不成深U。

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


## 后处理消重叠 + 父居中（已废弃 · 2026-09-07 G3 升级）。
## 原列式 2 趟收敛后处理已被 BuchheimWalker 轮廓打包（_pack_contour）取代：
## 轮廓法在布局阶段即保证零重叠 + 父居中于直接子首尾中点，无需事后修正。
## 函数保留为空壳仅为兼容潜在历史引用；正常布局路径不再调用。
func _resolve_and_recenter(out: Dictionary, child_map: Dictionary, depth_of: Dictionary, est_h: Dictionary) -> void:
	return


# ===================== 模式 C：XMind 星形布局（第8节改造 · A①+B① · 保留以备回退，默认已改逻辑图） =====================
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


## 兄弟子树轮廓间距（测量前置 · 2026-09-08）：线索兄弟按「半个线索文本框真实高度」分隔
## （思傅要求：上一线索下沿→下一线索上沿 = 半个框高），其余类型沿用 _CONTOUR_SEP 紧凑间隙。
func _sibling_sep(c_id: String, node_by_id: Dictionary = {}) -> float:
	# 2026-09-17：所有类型统一垂直间距（_CONTOUR_SEP = 80px）
	return _CONTOUR_SEP


## 兄弟节点垂直间距：约文本框高度的 1/4（XMind 式紧凑），下限 80（用户指定 80px）。
func _sib_gap(h: float) -> float:
	return maxf(h * 0.25, 80.0)


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
		else:
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
	# v→R→u→v 视觉环，保持原状。玩家钉位过的节点不吸收（尊重手动落点）。
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
		if owner._root_anchor_pos.has(rs):
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
