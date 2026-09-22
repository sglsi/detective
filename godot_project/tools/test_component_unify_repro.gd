extends SceneTree
## 组件内统一语义回归（P4 定稿 · 思傅 2026-09-22 定案：**甲**）
##   甲 = 悬空根按**真实连线**吸收进链（relate 相连的 结论/推断/线索 **同行**成一条水平链）；
##   实质性支撑树各自独立水平带。
## 曾评估的「乙：整分量挂虚拟根、各结构树根成兄弟（各占一行）」已删除（回溯见提交 8933424）。
## 本测试同时**锁死该决策**：若将来有人重新引入虚拟根路径，第 ① 条断言会立刻 FAIL。
var _ok := true
func _chk(c: bool, m: String) -> void:
	if c: print("PASS " + m)
	else:
		_ok = false
		print("FAIL " + m)

func _run(gv, canvas, nodes: Array, rel: Array) -> Dictionary:
	for ch in canvas.get_children(): ch.queue_free()
	gv._node_views = {}; gv._node_center = {}; gv._node_kind = {}; gv._node_data = {}
	gv._relations = []; gv._root_anchor_pos = {}; gv._manual_nodes = []
	gv._balanced_layout = false; gv._use_rank_layout = false; gv._state_store = {}
	gv._layout._row_step_scale = 1.0
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
	return gv._node_center

func _initialize() -> void:
	await process_frame
	var GV = load("res://scripts/clue/graph_view_controller.gd")
	var gv = GV.new()
	var holder := Control.new(); holder.size = Vector2(1920, 1080); root.add_child(holder); holder.add_child(gv)
	await process_frame
	var canvas := Control.new(); canvas.size = Vector2(1920, 1080); holder.add_child(canvas); gv._canvas = canvas
	gv._mode = GV.ViewMode.MODE_C
	gv._layout._relayout_on_edge = false

	# ① 决策锁定：乙（虚拟根）路径必须不存在
	_chk(not gv._layout.has_method("_build_virtual_roots"), "乙（虚拟根）路径已删除，定案甲")
	_chk(not gv._layout.has_method("_is_virtual_root"), "无 _is_virtual_root 残留")

	# ② 拓扑（与 test_wrap_layout 段G 同构）：线索 -support-> 推断；推断 -relate-> 结论
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
	_chk(cids.size() == 1, "relate 串起的两链属同一分量（分量数=%d，期望 1）" % cids.size())

	var out: Dictionary = await _run(gv, canvas, nodes, REL)
	print("== 甲：连线式吸收 ==")
	for id in ["GR", "GH", "GC"]:
		if out.has(id): print("  %-3s x=%7.1f y=%7.1f" % [id, out[id].x, out[id].y])

	var ys := {}
	for id in ["GR", "GH", "GC"]:
		if out.has(id): ys[roundf(out[id].y)] = true
	_chk(ys.size() == 1, "弱关联节点与链同行：三节点同一行（行数=%d，期望 1）" % ys.size())
	_chk(out.has("GR") and out.has("GH") and out.has("GC")
		and out["GR"].x < out["GH"].x and out["GH"].x < out["GC"].x,
		"深度列右向递增（结论 → 推断 → 线索）")
	_chk(absf(out["GH"].x - out["GR"].x - 380.0) < 1.0 and absf(out["GC"].x - out["GH"].x - 380.0) < 1.0,
		"列距 = 380（整洁树列网格）")
	var viol: Array = gv._layout.check_invariants()
	_chk(viol.is_empty(), "不变量合规%s" % ("" if viol.is_empty() else "；" + str(viol)))
	_chk(not gv._layout._has_overlap(), "零重叠")

	# ③ 反例护栏：若有人改成「各根独立带（乙）」，行数会变 2 —— 上式已能捕获
	print("COMPONENT_UNIFY_REPRO: " + ("PASS" if _ok else "FAIL"))
	quit()
