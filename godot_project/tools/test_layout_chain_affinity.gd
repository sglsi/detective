extends SceneTree
## 推理墙布局「链路亲和」三原则回归（思傅 2026-09-17 截图反馈）：
##   A) 同链相邻：有连边的兄弟子树排序后必须相邻（_ordered_children 亲和重排）
##      ——右前蹄新换蹄铁链不被其他链隔离
##   B) 零亲和保持原序：无跨子树连边时与旧版 kind/id 序完全一致（行为不回归）
##   C) 分侧亲和：平衡布局下相关子树必须同侧（防跨中线深U，如血字链）
##   D) 自动平衡：默认右向树打包高度 > 1500 时自动左右分摊；小树仍纯右向

var _ok := true

func _chk(cond: bool, msg: String) -> void:
	if cond:
		print("[AFFINITY] " + msg)
	else:
		_ok = false
		print("FAIL " + msg)


## 人物 + n 条结论分支（每枝 branch_depth 级串行后代）；extra_rels 追加跨枝连边
func _make_case(gv, n: int, branch_depth: int, extra_rels: Array = []) -> Dictionary:
	var kind := {"P1": "person"}
	var label := {"P1": "凶手"}
	var rel := []
	for i in n:
		var cid := "C%d" % (i + 1)
		kind[cid] = "conclusion"
		label[cid] = "结论%d" % (i + 1)
		rel.append({"from": cid, "to": "P1", "kind": "support"})
		var prev: String = cid
		for j in branch_depth:
			var hid := "K%d_%d" % [i + 1, j + 1]
			kind[hid] = "clue"
			label[hid] = "线索%d-%d" % [i + 1, j + 1]
			rel.append({"from": hid, "to": prev, "kind": "support"})
			prev = hid
	for r in extra_rels:
		rel.append(r)
	gv._graph_nodes = []
	var nodes := []
	for id in kind:
		gv._graph_nodes.append({"id": id, "kind": kind[id], "label": label[id], "sub": "", "data": {}})
		nodes.append({"id": id, "kind": kind[id], "label": label[id]})
	gv._relations = rel.duplicate()
	return {"kind": kind, "label": label, "nodes": nodes}


func _child_map_of(gv) -> Dictionary:
	var parent_of: Dictionary = gv._layout._build_parent_of()
	var cm := {}
	for ch in parent_of:
		var p: String = parent_of[ch]
		if not cm.has(p):
			cm[p] = []
		if not (ch in cm[p]):
			cm[p].append(ch)
	return cm


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

	# ---------- A) 同链相邻：血字线索挂在 C1 枝，同时 support C4 枝的推断 ⇒ C1 与 C4 排序相邻 ----------
	var cA := _make_case(gv, 5, 1, [{"from": "K1_1", "to": "K4_1", "kind": "support"}])
	var cmA := _child_map_of(gv)
	gv._layout._aff_adj_dirty = true   # 布局外直调 _ordered_children：手动置脏邻接缓存（生产恒经布局入口）
	var orderA: Array = gv._layout._ordered_children("P1", cmA)
	var idxA := {}
	for i in orderA.size():
		idxA[str(orderA[i])] = i
	var d14: int = absi(int(idxA["C1"]) - int(idxA["C4"]))
	_chk(d14 == 1, "A1 同链相邻：C1↔C4 有共链线索（K1_1→K4_1），排序距离 %d == 1（序=%s）" % [d14, str(orderA)])
	# 同链子树在默认右向布局里 y 相邻（中间不隔其他链）
	var oA := {}
	gv._layout._logic_tree_layout(cA["nodes"], center, {}, oA)
	var yC := {}
	for i in range(1, 6):
		yC["C%d" % i] = float(oA["C%d" % i].y)
	var ys := [yC["C1"], yC["C2"], yC["C3"], yC["C4"], yC["C5"]]
	ys.sort()
	var i1: int = ys.find(yC["C1"])
	var i4: int = ys.find(yC["C4"])
	_chk(absi(i1 - i4) == 1, "A2 布局落位：C1 与 C4 在垂直序中相邻（C1 第 %d、C4 第 %d / 5）" % [i1 + 1, i4 + 1])

	# ---------- B) 零亲和保持原序：无跨枝连边 ⇒ kind/id 基础序 ----------
	_make_case(gv, 4, 1, [])
	var cmB := _child_map_of(gv)
	gv._layout._aff_adj_dirty = true
	var orderB: Array = gv._layout._ordered_children("P1", cmB)
	var expect := ["C1", "C2", "C3", "C4"]
	var same := true
	for i in expect.size():
		if str(orderB[i]) != expect[i]:
			same = false
	_chk(same, "B1 零亲和保持原序：%s" % str(orderB))

	# ---------- C) 分侧亲和：4 枝、C1↔C2 有跨枝连边 ⇒ 平衡分侧时 C1/C2 必须同侧 ----------
	var cC := _make_case(gv, 4, 2, [{"from": "K1_1", "to": "K2_1", "kind": "support"}])
	gv._subtree_sides = {}
	var oC := {}
	gv._layout._balanced_tree_layout(cC["nodes"], center, {}, oC)
	var sideC := {}
	for i in range(1, 5):
		var cid := "C%d" % i
		sideC[cid] = "L" if oC[cid].x < oC["P1"].x else "R"
	_chk(sideC["C1"] == sideC["C2"],
		"C1 分侧亲和：C1 与 C2 同侧（%s）——相关链不被拆到人物两侧成深U" % str(sideC))
	# 对照：同样 4 枝但零亲和时（旧行为）允许拆开配对平衡
	_make_case(gv, 4, 2, [])
	gv._subtree_sides = {}
	var oC2 := {}
	gv._layout._balanced_tree_layout(cC["nodes"], center, {}, oC2)
	var sc2 := {}
	for i in range(1, 5):
		var cid2 := "C%d" % i
		sc2[cid2] = "L" if oC2[cid2].x < oC2["P1"].x else "R"
	var nl: int = sc2.values().count("L")
	_chk(nl == 2, "C2 对照：零亲和 4 枝仍 2左2右平衡（%s）" % str(sc2))

	# ---------- D) 自动平衡：小树纯右向；大树自动左右分摊 ----------
	# 小树（3 枝 × 2 级）：默认分流仍走纯右向
	var cD1 := _make_case(gv, 3, 2, [])
	gv._subtree_sides = {}
	var oD1 := {}
	gv._layout._run_main_layout(cD1["nodes"], center, {}, oD1)
	var all_r := true
	for i in range(1, 4):
		if oD1["C%d" % i].x <= oD1["P1"].x:
			all_r = false
	_chk(all_r, "D1 小树（3 枝）默认仍纯右向，行为不变")
	# 大树（16 枝 × 1 级）：整树打包高度 ≈ 16×卡高+15×80 > 1500 ⇒ 自动平衡产生左侧分支
	var cD2 := _make_case(gv, 16, 1, [])
	gv._subtree_sides = {}
	var oD2 := {}
	gv._layout._run_main_layout(cD2["nodes"], center, {}, oD2)
	var n_l := 0
	for i in range(1, 17):
		if oD2["C%d" % i].x < oD2["P1"].x:
			n_l += 1
	_chk(n_l >= 4, "D2 大树（16 枝）自动左右分摊：左侧 %d 枝（≥4），不再单竖列越拉越长" % n_l)
	# 大树零重叠（自动平衡路径同样要过轮廓打包 + 真实高度）
	var rects := {}
	var ids2: Array = oD2.keys()
	for id in ids2:
		var k: String = str(cD2["kind"][id])
		var w: float = gv._layout._node_width_for_kind(k)
		var h: float = gv._layout._real_node_height(str(id), {"id": id, "kind": k, "label": cD2["label"][id]})
		rects[id] = Rect2(oD2[id] - Vector2(w, h) * 0.5, Vector2(w, h))
	var overlap := false
	for i in ids2.size():
		for j in range(i + 1, ids2.size()):
			if (rects[ids2[i]] as Rect2).grow(4.0).intersects((rects[ids2[j]] as Rect2).grow(4.0)):
				overlap = true
				_ok = false
				print("FAIL 重叠 %s↔%s" % [str(ids2[i]), str(ids2[j])])
	if not overlap:
		print("[AFFINITY] 大树自动平衡零重叠：34 节点 AABB 两两不相交 ✓")

	if _ok:
		print("AFFINITY_RESULT: PASS — 链路亲和三原则全部验证通过")
	else:
		print("AFFINITY_RESULT: FAIL")
	quit()
