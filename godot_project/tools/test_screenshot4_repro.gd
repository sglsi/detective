extends SceneTree
## 复现思傅 2026-09-21 截图4（16 卡、4 列、全 support 边）：
## 由截图连线追踪还原的真实拓扑（from=子/更深层，to=父）：
##   A: b1→t1, g2→b1, g1→g2
##   B: t3→t2, b3→t2, b2→t3, g4→b3, g3→b2
##   C: t5→t4, b4→t5, b5→t5, g5→b4, g6→b5
## 截图实测（图像 px，×4.37=实尺）：t1=169 b1=188 g2=188 g1=58 | t2=299 t3=299 b2=299 g3=280 b3=411 g4=411
##   | t4=633 t5=633 b4=522 g5=522 b5=745 g6=745
## 疑点：tree B 中 t2 是 t3 与 b3 的父，父应居中于子（t3=299,b3=411 ⇒ 父应在 355），实测 299。

var _ok := true
func _chk(c: bool, m: String) -> void:
	if c: print("PASS " + m)
	else:
		_ok = false
		print("FAIL " + m)

func _initialize() -> void:
	await process_frame
	var GV = load("res://scripts/clue/graph_view_controller.gd")
	var gv = GV.new()
	var holder := Control.new(); holder.size = Vector2(1920, 1080); root.add_child(holder); holder.add_child(gv)
	await process_frame
	var canvas := Control.new(); canvas.size = Vector2(1920, 1080); holder.add_child(canvas); gv._canvas = canvas
	gv._mode = GV.ViewMode.MODE_C
	var SPEC := [
		["t1", "conclusion", "链A结论"], ["b1", "hypo", "链A推断"], ["g2", "clue", "链A线索甲"], ["g1", "clue", "链A线索乙"],
		["t2", "conclusion", "链B结论"], ["t3", "hypo", "链B推断甲"], ["b3", "hypo", "链B推断乙"], ["b2", "clue", "链B线索甲"], ["g4", "clue", "链B线索乙"], ["g3", "clue", "链B线索丙"],
		["t4", "conclusion", "链C结论"], ["t5", "hypo", "链C推断"], ["b4", "hypo", "链C推断甲"], ["b5", "hypo", "链C推断乙"], ["g5", "clue", "链C线索甲"], ["g6", "clue", "链C线索乙"],
	]
	var REL := [
		{"from": "b1", "to": "t1", "kind": "support"}, {"from": "g2", "to": "b1", "kind": "support"}, {"from": "g1", "to": "g2", "kind": "support"},
		{"from": "t3", "to": "t2", "kind": "support"}, {"from": "b3", "to": "t2", "kind": "support"},
		{"from": "b2", "to": "t3", "kind": "support"}, {"from": "g4", "to": "b3", "kind": "support"}, {"from": "g3", "to": "b2", "kind": "support"},
		{"from": "t5", "to": "t4", "kind": "support"}, {"from": "b4", "to": "t5", "kind": "support"}, {"from": "b5", "to": "t5", "kind": "support"},
		{"from": "g5", "to": "b4", "kind": "support"}, {"from": "g6", "to": "b5", "kind": "support"},
	]
	var nodes := []
	for s in SPEC:
		nodes.append({"id": s[0], "kind": s[1], "label": s[2], "sub": "", "data": {}})
		gv._node_kind[s[0]] = s[1]; gv._node_data[s[0]] = {}
		var v = gv._cards.make_node({"id": s[0], "kind": s[1], "label": s[2], "sub": "", "data": {}})
		canvas.add_child(v); gv._node_views[s[0]] = v
	await process_frame
	gv._relations = REL; gv._root_anchor_pos = {}; gv._manual_nodes = []; gv._node_center = {}
	var out: Dictionary = gv._layout._compute_layout(nodes, {})
	gv._node_center = out.duplicate()
	gv._layout._apply_global_overlap_fix()
	out = gv._node_center
	print("== 复现布局（实尺；截图换算是 实尺÷4.37=图像px，截图 t1=169px⇒739 实尺）==")
	var order := ["t1","b1","g2","g1","t2","t3","b3","b2","g3","g4","t4","t5","b4","b5","g5","g6"]
	for id in order:
		print("  %-3s x=%7.1f y=%7.1f  (截图 px≈%.0f)" % [id, out[id].x, out[id].y, out[id].y / 4.37])
	# 父居中于子（按 _build_parent_of 的真实父子）
	var pf: Dictionary = gv._layout._build_parent_of()
	var kids := {}
	for ch in pf:
		var p: String = pf[ch]
		if not kids.has(p): kids[p] = []
		kids[p].append(str(ch))
	print("== 父子关系 ==")
	for p in kids: print("  %s → %s" % [p, str(kids[p])])
	for p in kids:
		var mid: float = 0.0
		var lo := 1e18; var hi := -1e18
		for c in kids[p]:
			lo = minf(lo, out[c].y); hi = maxf(hi, out[c].y)
		mid = (lo + hi) * 0.5
		_chk(absf(out[p].y - mid) < 1.0, "父居中于子 %s: 父=%.0f 子中点=%.0f" % [p, out[p].y, mid])
	print("MULTI17_REPRO: " + ("PASS" if _ok else "FAIL"))
	quit()
