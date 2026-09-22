extends SceneTree
## P4 A/B：弱连通分量统一的两种语义（运行期开关 _unify_component_as_branch_tree）
##   甲（默认 false，= 既有语义 + test_wrap_layout G1）：悬空根按**真实连线**挂到目标节点下 →
##     同一条视觉链的节点**同行**（relate 相连的 结论/推断/线索 成一条水平链）。
##   乙（true）：整分量挂**虚拟根**，各结构树根成为其**兄弟** → 各占一行（"一个树的多分支"）。
## 两者都满足「组件 = 一棵视觉树」（不变量全合规），差别只在"视觉链是否同行"。
var _ok := true
func _chk(c: bool, m: String) -> void:
	if c: print("PASS " + m)
	else:
		_ok = false
		print("FAIL " + m)

func _run_mode(gv, GV, canvas, nodes: Array, rel: Array, flag: bool, tag: String) -> Dictionary:
	for ch in canvas.get_children(): ch.queue_free()
	gv._node_views = {}; gv._node_center = {}; gv._node_kind = {}; gv._node_data = {}
	gv._relations = []; gv._root_anchor_pos = {}; gv._manual_nodes = []
	gv._balanced_layout = false; gv._use_rank_layout = false; gv._state_store = {}
	gv._layout._row_step_scale = 1.0
	gv._layout._unify_component_as_branch_tree = flag
	for nd in nodes:
		gv._node_kind[nd.id] = nd.kind; gv._node_data[nd.id] = {}
		var v = gv._cards.make_node(nd); canvas.add_child(v); gv._node_views[nd.id] = v
	await process_frame
	gv._relations = rel.duplicate()
	var out: Dictionary = gv._layout._compute_layout(nodes, {})
	gv._node_center = out.duplicate()
	gv._layout._apply_global_overlap_fix()
	if gv._layout._has_overlap():
		out = gv._layout._resolve_residual_overlaps(nodes, {})
		gv._node_center = out.duplicate()
	out = gv._node_center
	print("== [%s] ==" % tag)
	for id in ["GR", "GH", "GC"]:
		if out.has(id): print("  %-3s x=%7.1f y=%7.1f" % [id, out[id].x, out[id].y])
	var viol: Array = gv._layout.check_invariants()
	_chk(viol.is_empty(), "[%s] 不变量合规%s" % [tag, "" if viol.is_empty() else "；" + str(viol)])
	return out

func _initialize() -> void:
	await process_frame
	var GV = load("res://scripts/clue/graph_view_controller.gd")
	var gv = GV.new()
	var holder := Control.new(); holder.size = Vector2(1920, 1080); root.add_child(holder); holder.add_child(gv)
	await process_frame
	var canvas := Control.new(); canvas.size = Vector2(1920, 1080); holder.add_child(canvas); gv._canvas = canvas
	gv._mode = GV.ViewMode.MODE_C
	gv._layout._relayout_on_edge = false
	# 与 test_wrap_layout 段G 同构：线索 -support-> 推断；推断 -relate-> 结论
	var SPEC := [
		["GH", "hypo", "推断"], ["GC", "clue", "线索"], ["GR", "conclusion", "结论"],
	]
	var nodes := []
	for s in SPEC: nodes.append({"id": s[0], "kind": s[1], "label": s[2], "sub": "", "data": {}})
	var REL := [
		{"from": "GC", "to": "GH", "kind": "support"},
		{"from": "GH", "to": "GR", "kind": "relate"},
	]
	gv._relations = REL.duplicate()
	var comp: Dictionary = gv._layout._relation_components()
	var cids := {}
	for k in comp: cids[int(comp[k])] = true
	_chk(cids.size() == 1, "relate 串起的两条链属同一分量（分量数=%d）" % cids.size())

	# 甲：默认（连线式吸收）→ 应成"一条水平链"（全部同行）
	var a: Dictionary = await _run_mode(gv, GV, canvas, nodes, REL, false, "甲 连线式吸收(默认)")
	var ys := {}
	for id in ["GR", "GH", "GC"]:
		if a.has(id): ys[roundf(a[id].y)] = true
	_chk(ys.size() == 1, "甲：三节点同行（行数=%d，期望 1）" % ys.size())

	# 乙：虚拟根（分支式）→ 两链各占一行
	var b: Dictionary = await _run_mode(gv, GV, canvas, nodes, REL, true, "乙 虚拟根分支")
	var ys2 := {}
	for id in ["GR", "GH", "GC"]:
		if b.has(id): ys2[roundf(b[id].y)] = true
	_chk(ys2.size() == 2, "乙：结论独立一行 + 推断/线索一行（行数=%d，期望 2）" % ys2.size())
	_chk(absf(b["GR"].x - b["GH"].x) < 1.0, "乙：结论与推断同列（同组件第 0 层）")

	gv._layout._unify_component_as_branch_tree = false   # 复原默认
	print("P4_AB: " + ("PASS" if _ok else "FAIL"))
	quit()
