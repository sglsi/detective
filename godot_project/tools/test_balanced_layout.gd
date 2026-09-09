extends SceneTree
## 左右平衡整洁树（顶栏「自动排列」· 思傅 2026-09-09 需求）布局验证：
##   A) 分派规则：n=1 全右；n=2 1左1右；n=3 最茂盛者独占一侧+另2个另一侧；n=4 2左2右且重量配对
##   B) 严格镜像：同深度左右列相对人物根的水平偏移绝对值相等（美学4）
##   C) 左侧「叶-枝-干-根」：深度越大 x 越小；右侧「根-干-枝-叶」：深度越大 x 越大
##   D) 两侧都垂直居中于人物根（美学3），且整墙零重叠
##   E) 玩家手动换侧（_subtree_sides）覆盖自动分派
##   F) 默认模式（_balanced_layout=false）仍是纯右向，未被本次改动影响

var _ok := true
var _log := []

func _chk(cond: bool, msg: String) -> void:
	if cond:
		_log.append(msg)
	else:
		_ok = false
		print("FAIL " + msg)


## 造一棵「人物 + n 条结论分支」的树：branch_sizes[i] = 第 i 条分支除结论自身外再挂几个后代（推断链）
func _make_case(gv, branch_sizes: Array) -> Dictionary:
	var kind := {"P1": "person"}
	var label := {"P1": "凶手"}
	var rel := []
	for i in branch_sizes.size():
		var cid: String = "C%d" % (i + 1)
		kind[cid] = "conclusion"
		label[cid] = "结论%d：分支主干" % (i + 1)
		rel.append({"from": cid, "to": "P1", "kind": "support"})
		var prev: String = cid
		for j in int(branch_sizes[i]):
			var hid: String = "H%d_%d" % [i + 1, j + 1]
			kind[hid] = "hypo" if j % 2 == 0 else "clue"
			label[hid] = "分支%d 第%d 级依据" % [i + 1, j + 1]
			rel.append({"from": hid, "to": prev, "kind": "support"})
			prev = hid
	gv._graph_nodes = []
	var nodes := []
	for id in kind:
		gv._graph_nodes.append({"id": id, "kind": kind[id], "label": label[id], "sub": "", "data": {}})
		nodes.append({"id": id, "kind": kind[id], "label": label[id]})
	gv._relations = rel.duplicate()
	return {"kind": kind, "label": label, "nodes": nodes}


func _sides_of(gv, out: Dictionary, n: int) -> Array:
	var arr := []
	for i in n:
		var cid: String = "C%d" % (i + 1)
		arr.append("L" if out[cid].x < out["P1"].x else "R")
	return arr


func _initialize() -> void:
	await process_frame
	var GV = load("res://scripts/clue/graph_view_controller.gd")
	if GV == null:
		print("FAIL 无法加载 graph_view_controller.gd")
		quit(); return
	var gv = GV.new()
	var holder = Control.new()
	root.add_child(holder)
	holder.add_child(gv)
	await process_frame
	var center := Vector2(960.0, 540.0)

	# ---------- A) 分派规则 ----------
	# n=1：单枝全右
	var c1 := _make_case(gv, [2])
	gv._subtree_sides = {}
	var o1 := {}
	gv._layout._balanced_tree_layout(c1["nodes"], center, {}, o1)
	_chk(o1["C1"].x > o1["P1"].x, "n=1 单枝默认在右：C1.x(%.0f) > P1.x(%.0f)" % [o1["C1"].x, o1["P1"].x])

	# n=2：1 左 1 右
	var c2 := _make_case(gv, [2, 2])
	gv._subtree_sides = {}
	var o2 := {}
	gv._layout._balanced_tree_layout(c2["nodes"], center, {}, o2)
	var s2 := _sides_of(gv, o2, 2)
	_chk(s2.count("L") == 1 and s2.count("R") == 1, "n=2 一左一右：%s" % str(s2))

	# n=3：最茂盛（分支2 挂 6 个后代）独占一侧，另 2 个在另一侧
	var c3 := _make_case(gv, [1, 6, 1])
	gv._subtree_sides = {}
	var o3 := {}
	gv._layout._balanced_tree_layout(c3["nodes"], center, {}, o3)
	var s3 := _sides_of(gv, o3, 3)
	var lone_side: String = s3[1]
	_chk(s3.count(lone_side) == 1, "n=3 最茂盛分支独占一侧（C2 在 %s 侧，该侧仅它一枝）：%s" % [lone_side, str(s3)])
	_chk(s3[0] == s3[2] and s3[0] != lone_side, "n=3 另 2 条稀疏分支同在另一侧：%s" % str(s3))

	# n=4：2 左 2 右，且「茂盛+稀疏」配对（两侧总节点数差 ≤1）
	var c4 := _make_case(gv, [8, 1, 6, 2])
	gv._subtree_sides = {}
	var o4 := {}
	gv._layout._balanced_tree_layout(c4["nodes"], center, {}, o4)
	var s4 := _sides_of(gv, o4, 4)
	_chk(s4.count("L") == 2 and s4.count("R") == 2, "n=4 两侧各 2 枝：%s" % str(s4))
	var wsum := {"L": 0, "R": 0}
	var wt := [9, 2, 7, 3]   # 各分支子树节点数 = 1(结论) + 后代数
	for i in 4:
		wsum[s4[i]] += int(wt[i])
	_chk(absi(int(wsum["L"]) - int(wsum["R"])) <= 1,
		"n=4 重量配对平衡：左%d vs 右%d（差≤1）" % [int(wsum["L"]), int(wsum["R"])])

	# ---------- B/C/D) 用 n=4 这盘验镜像/方向/居中/零重叠 ----------
	var depth := {"P1": 0}
	for i in 4:
		depth["C%d" % (i + 1)] = 1
		for j in int(wt[i]) - 1:
			depth["H%d_%d" % [i + 1, j + 1]] = 2 + j
	# B) 同深度左右偏移镜像相等
	var off_by_side := {}      # "L2" -> 偏移绝对值
	for id in o4:
		if str(id) == "P1": continue
		var d: int = int(depth.get(str(id), 0))
		var side: String = "L" if o4[id].x < o4["P1"].x else "R"
		var off: float = absf(o4[id].x - o4["P1"].x)
		var key: String = "%s%d" % [side, d]
		if off_by_side.has(key):
			_chk(absf(float(off_by_side[key]) - off) < 0.5,
				"同侧同深度共线 %s：%.0f≈%.0f" % [key, float(off_by_side[key]), off])
		off_by_side[key] = off
	var mirror_ok := true
	for key in off_by_side:
		var ks: String = str(key)
		if not ks.begins_with("L"): continue
		var rkey: String = "R" + ks.substr(1)
		if off_by_side.has(rkey):
			if absf(float(off_by_side[ks]) - float(off_by_side[rkey])) > 0.5:
				mirror_ok = false
				print("FAIL 镜像不等 %s(%.0f) vs %s(%.0f)" % [ks, float(off_by_side[ks]), rkey, float(off_by_side[rkey])])
	_chk(mirror_ok, "左右列严格镜像：各深度 |Δx| 左右相等（美学4）")

	# C) 左侧叶-枝-干-根（深度↑ → x↓）；右侧根-干-枝-叶（深度↑ → x↑）
	var dir_ok := true
	for i in 4:
		var cid: String = "C%d" % (i + 1)
		var side: String = s4[i]
		var prev_x: float = o4[cid].x
		for j in int(wt[i]) - 1:
			var hid: String = "H%d_%d" % [i + 1, j + 1]
			if not o4.has(hid): continue
			if side == "L":
				if not (o4[hid].x < prev_x - 1.0): dir_ok = false
			else:
				if not (o4[hid].x > prev_x + 1.0): dir_ok = false
			prev_x = o4[hid].x
	_chk(dir_ok, "左侧「叶-枝-干-根」/ 右侧「根-干-枝-叶」：每级沿各自方向单调外扩")
	# 人物在左右两侧节点之间（中心节点）
	var lmax: float = -1e18
	var rmin: float = 1e18
	for id in o4:
		if str(id) == "P1": continue
		if o4[id].x < o4["P1"].x:
			lmax = maxf(lmax, o4[id].x)
		else:
			rmin = minf(rmin, o4[id].x)
	_chk(lmax < o4["P1"].x and rmin > o4["P1"].x,
		"人物为中心节点：左侧最右(%.0f) < P1.x(%.0f) < 右侧最左(%.0f)" % [lmax, o4["P1"].x, rmin])

	# D) 两侧直接子（结论）都垂直居中于人物 + 零重叠
	var lys := []
	var rys := []
	for i in 4:
		var cid: String = "C%d" % (i + 1)
		if s4[i] == "L": lys.append(o4[cid].y)
		else: rys.append(o4[cid].y)
	for grp in [["左", lys], ["右", rys]]:
		var arr: Array = grp[1]
		if arr.size() < 2: continue
		var mn: float = 1e18
		var mx: float = -1e18
		for y in arr:
			mn = minf(mn, float(y)); mx = maxf(mx, float(y))
		_chk(o4["P1"].y > mn - 1.0 and o4["P1"].y < mx + 1.0,
			"%s侧结论群垂直居中于人物：P1.y(%.0f)∈[%.0f,%.0f]" % [str(grp[0]), o4["P1"].y, mn, mx])
	var ids: Array = o4.keys()
	var rects := {}
	for id in ids:
		var k: String = str(c4["kind"][id])
		var w: float = gv._layout._node_width_for_kind(k)
		var h: float = gv._layout._real_node_height(str(id), {"id": id, "kind": k, "label": c4["label"][id]})
		rects[id] = Rect2(o4[id] - Vector2(w, h) * 0.5, Vector2(w, h))
	var overlap := false
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			if (rects[ids[i]] as Rect2).grow(4.0).intersects((rects[ids[j]] as Rect2).grow(4.0)):
				overlap = true
				_ok = false
				print("FAIL 重叠 %s↔%s" % [str(ids[i]), str(ids[j])])
	if not overlap:
		_log.append("零重叠：%d 节点 AABB 两两不相交 ✓" % ids.size())

	# ---------- E) 玩家手动换侧覆盖 ----------
	# 默认 n=1 在右；显式指定 L 后必须到左侧
	var c5 := _make_case(gv, [3])
	gv._subtree_sides = {"C1": "L"}
	var o5 := {}
	gv._layout._balanced_tree_layout(c5["nodes"], center, {}, o5)
	_chk(o5["C1"].x < o5["P1"].x, "玩家换侧覆盖：指定 C1=L 后 C1.x(%.0f) < P1.x(%.0f)" % [o5["C1"].x, o5["P1"].x])
	_chk(o5["H1_1"].x < o5["C1"].x, "换侧带整棵子树：H1_1.x(%.0f) < C1.x(%.0f)（同在左侧、继续向左延伸）" % [o5["H1_1"].x, o5["C1"].x])
	# 三枝中把两枝强制到右：左侧只剩 1 枝
	var c6 := _make_case(gv, [2, 2, 2])
	gv._subtree_sides = {"C1": "R", "C2": "R"}
	var o6 := {}
	gv._layout._balanced_tree_layout(c6["nodes"], center, {}, o6)
	var s6 := _sides_of(gv, o6, 3)
	_chk(s6[0] == "R" and s6[1] == "R", "多枝换侧覆盖生效：C1/C2 均在右 %s" % str(s6))

	# ---------- F) 默认模式仍纯右向 ----------
	gv._subtree_sides = {}
	var c7 := _make_case(gv, [2, 2, 2, 2])
	var o7 := {}
	gv._layout._logic_tree_layout(c7["nodes"], center, {}, o7)
	var all_right := true
	for i in 4:
		if o7["C%d" % (i + 1)].x <= o7["P1"].x: all_right = false
	_chk(all_right, "默认布局未受影响：4 条分支仍全部在人物右侧（纯右向）")

	# ---------- G) 分流开关：_balanced_layout 决定走哪套 ----------
	gv._balanced_layout = true
	var o8 := {}
	gv._layout._run_main_layout(c7["nodes"], center, {}, o8)
	var has_left := false
	for i in 4:
		if o8["C%d" % (i + 1)].x < o8["P1"].x: has_left = true
	_chk(has_left, "_run_main_layout 分流：_balanced_layout=true 时确实产生左侧分支")
	gv._balanced_layout = false
	var o9 := {}
	gv._layout._run_main_layout(c7["nodes"], center, {}, o9)
	var none_left := true
	for i in 4:
		if o9["C%d" % (i + 1)].x < o9["P1"].x: none_left = false
	_chk(none_left, "_run_main_layout 分流：_balanced_layout=false 时全部在右（默认不变）")

	for l in _log:
		print("[BALANCED]", l)
	if _ok:
		print("BALANCED_RESULT: PASS — 左右平衡布局全部性质验证通过")
	else:
		print("BALANCED_RESULT: FAIL")
	quit()
