extends SceneTree
## 验证（2026-09-05 修订）：推理墙连线规则
##  A) 开墙即「仅玩家连线」——不推导任何节点时渲染边必须为 0（系统不再擅自补任何边）。
##  B) 玩家选择推导（线索→推断 / 推断→结论）时，对应 support 绿边应出现（属玩家连线）。
##  C) 结论→人物金边 NOT 自动派生（玩家须显式拖结论到人物才建 target 边）。

func _count(el: Array) -> Dictionary:
	var d := {"total": el.size(), "target": 0, "support": 0, "other": 0}
	for e in el:
		match e.get("kind", ""):
			"target": d["target"] += 1
			"support": d["support"] += 1
			_: d["other"] += 1
	return d

func _initialize() -> void:
	await process_frame
	root.size = Vector2(1920, 1080)
	var GV = load("res://scripts/clue/graph_view_controller.gd")
	var sc = load("res://scripts/scene/scene2.gd")
	var hypo: Dictionary = sc.new().reasoning_hypothesis()
	var gv = GV.new()
	var holder = Control.new(); root.add_child(holder); holder.add_child(gv)
	await process_frame
	var clues := [
		{"id":"c201","name":"车轮印","correct":true},{"id":"c202","name":"轴距","correct":true},
		{"id":"c203","name":"蹄铁","correct":true},{"id":"c204","name":"蹄印零乱","correct":true},
		{"id":"c205","name":"脚印","correct":true},{"id":"c206","name":"步幅","correct":true}]
	gv.build({"clues":clues, "hypo":hypo, "persons":[{"id":"KILLER","name":"马车夫"}],
		"difficulty":gv.Diff.NORMAL, "editable":true, "state_store":{}, "auto_fold":false, "case_wide":true})
	await process_frame

	# ---- A) 开墙未推导：渲染边必须为 0 ----
	var a := _count(gv._edge_list)
	print("[EDGE-COUNT-A] 开墙未推导 渲染边总数=%d target=%d support=%d" % [a["total"], a["target"], a["support"]])
	var ok := true
	if a["total"] != 0:
		ok = false
		print("[EDGE-COUNT-A] ✗ 系统仍擅自补了 %d 条边" % a["total"])
	else:
		print("[EDGE-COUNT-A] ✓ 开墙即零系统边（仅玩家连线）")

	# ---- B) 玩家推导全部 线索→推断 / 推断→结论 ----
	var bf: Dictionary = hypo.get("battlefield", {})
	var derive_calls := 0
	for h in bf.get("hypotheses", []):
		var hid: String = h.get("id", ""); var gates: Array = h.get("gate_clue_ids", [])
		if hid == "" or gates.is_empty(): continue
		for c in gates:
			gv._derive_hypo(str(c), hid); await process_frame; derive_calls += 1
	for c in bf.get("conclusions", []):
		var cid: String = c.get("id", ""); var gh: Array = c.get("gate_hypo_ids", [])
		if cid == "" or gh.is_empty(): continue
		gv._derive_conclusion(str(gh[0]), cid); await process_frame; derive_calls += 1
	gv._rebuild_graph(); await process_frame

	var b := _count(gv._edge_list)
	print("[EDGE-COUNT-B] 推导全部后 渲染边总数=%d target=%d support=%d  (玩家推导调用=%d)" % [b["total"], b["target"], b["support"], derive_calls])
	if b["support"] != b["total"]:
		ok = false
		print("[EDGE-COUNT-B] ✗ 出现非 support 的边（%d 条 other）" % b["other"])
	else:
		print("[EDGE-COUNT-B] ✓ 全部为玩家推导的 support 绿边")
	if b["target"] != 0:
		ok = false
		print("[EDGE-COUNT-B] ✗ 结论→人物金边被自动派生（%d 条）" % b["target"])
	else:
		print("[EDGE-COUNT-B] ✓ 无自动金边（须玩家显式拖结论到人物）")

	# ---- C) 玩家显式建结论→人物金边后，target 边应出现 ----
	gv._edge._add_edge("conclusion_CL2-6", "KILLER", "target", "gold", false)
	gv._rebuild_graph(); await process_frame
	var c := _count(gv._edge_list)
	print("[EDGE-COUNT-C] 玩家建金边后 target=%d（期望≥1）" % c["target"])
	if c["target"] < 1:
		ok = false
		print("[EDGE-COUNT-C] ✗ 玩家显式金边未渲染")
	else:
		print("[EDGE-COUNT-C] ✓ 玩家显式金边正常渲染")

	print("[EDGE-COUNT] %s" % ("RESULT: PASS" if ok else "RESULT: FAIL"))
	quit()
