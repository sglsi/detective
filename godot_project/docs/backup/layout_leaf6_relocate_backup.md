# 备份：「竖列叶数 > 6 → 无根链搬右侧分列」机制（已退役）

> 归档日期：2026-09-22（思傅指示：移动并存储到备份文件）
> 状态：**已从 `scripts/clue/graph/graph_view_layout.gd` 摘除**，全文保存于本文件。

## 1. 它是什么
基于**叶数阈值（硬编码 6）的根分流规则**：

- 「有人物/事件树 + 存在无根链 + 主列叶子数 > 6」：把**无根链整体搬到人物树右侧**新空区域；
- 无根链再按「每列 ≤ 6 叶」切成 ncols 列（`_split_roots_into_columns`：以弱连通分量为最小单位，同一棵视觉树不被拆到两列）；
- 意图：屏幕多为宽 > 高，向右铺开符合**左右阅读习惯**，避免单列越拉越长。

## 2. 为何退役（2026-09-22）
1. **单点启发式**：阈值 6 是魔法数字，且只对「有树 + 有无根链」生效；链路/卡片数量组合一变就不适用。
2. **不是真正的二维装箱**：只把无根链竖着堆成一列放在树右侧，两列高度极不平衡（实测思傅真实墙：左 3280 高 vs 右 1720 高，包围盒 4100×3280，卡片填充率 29.4%）。
3. **已被 R3 组件矩形装箱取代**（`09e5745` / `650a3b8`）：R3 以弱连通分量为最小装箱单位做货架装箱，
   目标 = **最小化整墙适配屏幕所需缩放 `max(W/屏宽, H/屏高)`** —— 宽屏自动横向、窄屏自动竖排，
   与链路/卡片数量无关，可泛化到任意组合。
4. 两套规则并存会抢位：装箱给出的位置直接覆盖 do_relocate 算出的“右列”坐标（后者只是装箱前临时位）。

## 3. 退役后行为
所有根（人物树 + 无根链）**并入单主列垂直堆叠** = 原「未触发 do_relocate」路径（行为不变）；
宽屏横向由 **R3 装箱目标函数** 自然完成。

---

## 4. 被移除的代码（verbatim）

### 4.1 `_logic_tree_layout` · 根分流注释块 + `if do_relocate:` 整支（末行 `else:` 为保留部分的分支头）

```gdscript
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
		var rk: String = owner._fold._kind_of(str(r))
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
```

### 4.2 `_split_roots_into_columns`（仅供上述分列使用）

```gdscript
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
```

### 4.3 `_balanced_tree_layout` · 无根链分流 + 分类/叶统计 + `if do_relocate:` 整支（含 `tree_right_edge`）

```gdscript
	# ===== 无根链分流（与 _logic_tree_layout 同语义；2026-09-21 修订：纯无根森林永不拆列）=====
	# 平衡布局（person 根左右分派）下，无根链（非 person/event 根的独立根）与逻辑树布局同口径分流：
	#   do_relocate = 有树 + 无根链 + 主列叶子(树叶+同列无根叶) > 6 → 无根链整体搬树右侧单列（允许超高、不递归切分）
	#   否则（含纯无根森林任意叶数——多列铺开已删，2026-09-21 思傅 图1/图3）→ 无根链并入主堆叠
	var person_roots: Array = []
	var loose_roots: Array = []
	for r in roots:
		var _rk: String = owner._fold._kind_of(str(r))
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

```

### 4.4 `_balanced_tree_layout` · 叶数统计（仅供分列）

```gdscript

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
```

### 4.5 诊断脚本（已从 tools/ 移除）

#### `tools/diag_balanced_loose.gd`

```gdscript
extends SceneTree
## 诊断：平衡布局（_balanced_tree_layout）下无根链是否从主列竖列分流到树右侧并按 >6 叶分列
## 场景：人物 P1（2 条结论链：结论→推断→线索）+ 8 条无根链（结论→线索，无父）
## 预期：主列叶子(2 线索+8 无根叶=10 >6) 触发 do_relocate → 无根链搬到树右侧、按 >6 叶分列、与树留清晰间隔

var _ok := true
func _chk(cond: bool, msg: String) -> void:
	if cond: print("PASS " + msg)
	else: _ok = false; print("FAIL " + msg)

func _overlap_check(gv, out: Dictionary, KIND: Dictionary, LABEL: Dictionary) -> void:
	var ids := out.keys()
	var rects := {}
	for id in ids:
		var k: String = KIND[id]
		var w: float = gv._layout._node_width_for_kind(k)
		var h: float = gv._layout._real_node_height(id, {"id": id, "kind": k, "label": LABEL[id]})
		rects[id] = Rect2(out[id] - Vector2(w, h) * 0.5, Vector2(w, h))
	var overlap := false
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			if rects[ids[i]].grow(2.0).intersects(rects[ids[j]].grow(2.0)):
				overlap = true
				print("FAIL 重叠 %s↔%s" % [ids[i], ids[j]])
	_chk(not overlap, "零重叠：%d 节点 AABB 两两不相交" % ids.size())

func _initialize() -> void:
	await process_frame
	var GV = load("res://scripts/clue/graph_view_controller.gd")
	var gv = GV.new()
	var holder = Control.new()
	root.add_child(holder)
	holder.add_child(gv)
	await process_frame
	if gv._canvas != null:
		gv._canvas.size = Vector2(5000.0, 4000.0)
	var center := Vector2(960.0, 540.0)

	var KIND := {}
	var LABEL := {}
	var REL := []
	KIND["P1"] = "person"; LABEL["P1"] = "人物：张三"
	for i in 2:
		var c := "C%d" % i
		KIND[c] = "conclusion"; LABEL[c] = "结论%d" % i
		REL.append({"from": c, "to": "P1", "kind": "support"})
		var h := "H%d" % i
		KIND[h] = "hypo"; LABEL[h] = "推断%d" % i
		REL.append({"from": h, "to": c, "kind": "support"})
		var cl := "CL%d" % i
		KIND[cl] = "clue"; LABEL[cl] = "线索%d" % i
		REL.append({"from": cl, "to": h, "kind": "support"})
	for i in 8:
		var rc := "LC%d" % i
		KIND[rc] = "conclusion"; LABEL[rc] = "无根结论%d" % i
		var lc := "LCL%d" % i
		KIND[lc] = "clue"; LABEL[lc] = "无根线索%d" % i
		REL.append({"from": lc, "to": rc, "kind": "support"})

	gv._graph_nodes = []
	for id in KIND:
		gv._graph_nodes.append({"id": id, "kind": KIND[id], "label": LABEL[id], "sub": "", "data": {}})
	gv._relations = REL.duplicate()
	var nodes := []
	for id in KIND:
		nodes.append({"id": id, "kind": KIND[id], "label": LABEL[id]})

	var out := {}
	gv._layout._balanced_tree_layout(nodes, center, {}, out)

	# 1. 人物居中于 center.x
	_chk(absf(out["P1"].x - center.x) < 60.0, "人物 P1 居中于 center.x (x=%.0f)" % out["P1"].x)
	# 2. 无根链根搬到树右侧（x 明显 > center.x）
	var loose_roots := []
	for i in 8:
		loose_roots.append("LC%d" % i)
	var min_loose_x := 1e18
	for id in loose_roots:
		min_loose_x = minf(min_loose_x, out[id].x)
	_chk(min_loose_x > center.x + 150.0, "无根链整体搬到树右侧（最左无根根 x=%.0f > center+150，非主列竖列）" % min_loose_x)
	# 2b. 无根链按 >6 叶分列 → 结论根应占 ≥2 个 x 列
	var lcols := {}
	for id in loose_roots:
		lcols[out[id].x] = true
	_chk(lcols.size() >= 2, "无根链 8 叶 >6 → 分 ≥2 列（占 %d 个 x 列）" % lcols.size())
	# 2c. 与整洁树留清晰间隔：树最右沿（人物各节点 x 最大值）到无根链最左 > 120
	var tree_right := -1e18
	for id in ["P1", "C0", "C1", "H0", "H1", "CL0", "CL1"]:
		tree_right = maxf(tree_right, out[id].x)
	_chk(min_loose_x > tree_right + 120.0, "无根链与整洁树留清晰间隔（min_x=%.0f > 树最右沿 %.0f + 120）" % [min_loose_x, tree_right])
	# 3. 无根链内部仍右向流（结论.x < 线索.x）
	var flow := true
	for i in 8:
		if out["LCL%d" % i].x <= out["LC%d" % i].x:
			flow = false
	_chk(flow, "无根链内部右向流（结论.x < 线索.x）")
	# 4. 零重叠
	_overlap_check(gv, out, KIND, LABEL)
	# 5. 主列（center.x ± 120）上不应再堆叠无根链根（验证确实被分流）
	var on_main_col := 0
	for i in 8:
		if absf(out["LC%d" % i].x - center.x) < 120.0:
			on_main_col += 1
	_chk(on_main_col == 0, "无根链根未留在主列竖列（留在主列数=%d，应为 0）" % on_main_col)

	print("RESULT " + ("ALL_PASS" if _ok else "HAS_FAIL"))
	quit()
```


#### `tools/diag_relocate_gap.gd`

```gdscript
extends SceneTree
## 诊断：do_relocate（树 + 无根链分 2 列）时，两列无根链之间的可见水平间隔
## 应等于「160 + 无根链半宽」规则下的可见间隔（= col_gap = 160），而非旧版的 160 - 半宽。

var _ok := true
func _chk(cond: bool, msg: String) -> void:
	if cond: print("PASS " + msg)
	else: _ok = false; print("FAIL " + msg)

func _initialize() -> void:
	await process_frame
	var GV = load("res://scripts/clue/graph_view_controller.gd")
	var gv = GV.new()
	var holder = Control.new()
	root.add_child(holder)
	holder.add_child(gv)
	await process_frame
	if gv._canvas != null:
		gv._canvas.size = Vector2(5000.0, 4000.0)
	var center := Vector2(960.0, 540.0)

	var KIND := {}
	var LABEL := {}
	var REL := []
	KIND["P1"] = "person"; LABEL["P1"] = "人物：张三"
	for i in 2:
		var c := "C%d" % i
		KIND[c] = "conclusion"; LABEL[c] = "结论%d" % i
		REL.append({"from": c, "to": "P1", "kind": "support"})
		var h := "H%d" % i
		KIND[h] = "hypo"; LABEL[h] = "推断%d" % i
		REL.append({"from": h, "to": c, "kind": "support"})
		var cl := "CL%d" % i
		KIND[cl] = "clue"; LABEL[cl] = "线索%d" % i
		REL.append({"from": cl, "to": h, "kind": "support"})
	for i in 8:
		var rc := "LC%d" % i
		KIND[rc] = "conclusion"; LABEL[rc] = "无根结论%d" % i
		var lc := "LCL%d" % i
		KIND[lc] = "clue"; LABEL[lc] = "无根线索%d" % i
		REL.append({"from": lc, "to": rc, "kind": "support"})

	gv._graph_nodes = []
	for id in KIND:
		gv._graph_nodes.append({"id": id, "kind": KIND[id], "label": LABEL[id], "sub": "", "data": {}})
	gv._relations = REL.duplicate()
	var nodes := []
	for id in KIND:
		nodes.append({"id": id, "kind": KIND[id], "label": LABEL[id]})

	var out := {}
	gv._layout._balanced_tree_layout(nodes, center, {}, out)

	# 把每条无根链（结论根 + 其线索子）归到同一列；按根索引进列
	var per: int = ceili(8.0 / maxf(1.0, ceili(8.0 / 6.0)))   # 与布局口径一致：ncols=ceili(8/6)=2 → per=4
	var col_members: Array = []
	for i in 8:
		var ci: int = i / per
		while col_members.size() <= ci:
			col_members.append([])
		col_members[ci].append("LC%d" % i)
		col_members[ci].append("LCL%d" % i)
	var col_xs: Array = []
	for c in col_members:
		col_xs.append(out[c[0]].x)
	_chk(col_members.size() >= 2, "无根链 ≥2 列（实际 %d 列）" % col_members.size())

	# 树最右沿（人物各节点 x 最大值 + 半宽）与首列无根链最左节点左沿的可见间隔
	var tree_right := -1e18
	for id in ["P1", "C0", "C1", "H0", "H1", "CL0", "CL1"]:
		tree_right = maxf(tree_right, out[id].x + gv._layout._node_width_for_kind(KIND[id]) * 0.5)
	var first_col_left := 1e18
	for id in col_members[0]:
		first_col_left = minf(first_col_left, out[id].x - gv._layout._node_width_for_kind(KIND[id]) * 0.5)
	var tree_to_first_gap: float = first_col_left - tree_right
	print("INFO 树→首列可见间隔 = %.1f" % tree_to_first_gap)

	# 计算相邻两列（含线索子节点）的可见水平间隔（左列最右节点右沿 → 右列最左节点左沿）
	var min_gap := 1e18
	for k in range(col_members.size() - 1):
		var left_ids: Array = col_members[k]
		var right_ids: Array = col_members[k + 1]
		var left_right_edge := -1e18
		for id in left_ids:
			left_right_edge = maxf(left_right_edge, out[id].x + gv._layout._node_width_for_kind(KIND[id]) * 0.5)
		var right_left_edge := 1e18
		for id in right_ids:
			right_left_edge = minf(right_left_edge, out[id].x - gv._layout._node_width_for_kind(KIND[id]) * 0.5)
		var gap := right_left_edge - left_right_edge
		min_gap = minf(min_gap, gap)
		print("INFO 列%d→列%d 可见间隔 = %.1f" % [k, k + 1, gap])
	_chk(min_gap >= 150.0, "相邻两列无根链可见间隔 ≥ 150（=col_gap=160，旧版仅 160-半宽≈70）：实测 %.1f" % min_gap)
	_chk(absf(tree_to_first_gap - min_gap) < 5.0, "树→首列间隔(%.1f) 与 列间间隔(%.1f) 一致（同规则）" % [tree_to_first_gap, min_gap])

	print("RESULT " + ("ALL_PASS" if _ok else "HAS_FAIL"))
	quit()
```


---

## 5. 恢复指南
1. `_split_roots_into_columns`（4.2）放回 `graph_view_layout.gd`。
2. `_logic_tree_layout`：4.1 放回 `total_h = maxf(0.0, total_h - subtree_sep)` 之后，
   并把当前「单主列堆叠」代码**缩进一级套回 `else:`**（只缩 `else` 体；函数尾部的钉位收尾与钳制循环保持 1 级）。
3. `_balanced_tree_layout`：
   - 4.4 放回 `owner._last_layout_sides = sides.duplicate()` 之后；
   - 4.3 中「分流注释 + 分类/叶统计 + do_relocate + main_roots」放回 `var main_roots` 位置，
     「tree_right_edge + if do_relocate 整支」放在**主堆叠循环之后**（原位置）。
   ⚠️ 当时摘除时曾误删主堆叠循环（导致输出为空、测试卡死），故此备份按“两段删除”口径编写。
4. 真要让它生效，还需决定：R3 `_pack_components` 是否**跳过被它分列的无根链**（否则装箱会覆盖其位置）。
5. 验证：`--check-only` → `tools/test_wrap_layout.gd` → `tools/test_layout_fixtures.gd`
   （若回归，多个 fixture 金标准需重新固化）→ 两面真实墙 `test_wall_real_hop*.gd`。

## 6. 相关历史
- **2026-09-19**：引入「叶子计数触发分散」与 `_split_roots_into_columns`（思傅定案：宽屏左右阅读）。
- **2026-09-21**：修订「纯无根森林永不拆列」（思傅图1/图3 根治）。
- **2026-09-22**：R3 组件矩形装箱 + 屏幕适配目标（`09e5745` / `650a3b8`）取代本机制；本文件存档。
