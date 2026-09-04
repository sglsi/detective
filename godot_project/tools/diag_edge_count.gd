extends SceneTree
## 验证：场景二推理墙「只渲染玩家选择(及 1:1 推导)的连线」，系统不再擅自补大量边。
## 打印：开墙初始 _edge_list 数、推导全部后 _edge_list 数、其中 target(金) 边数、support(绿) 边数。

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
	var bf: Dictionary = hypo.get("battlefield", {})
	for h in bf.get("hypotheses", []):
		var hid: String = h.get("id", ""); var gates: Array = h.get("gate_clue_ids", [])
		if hid == "" or gates.is_empty(): continue
		for c in gates:
			gv._derive_hypo(str(c), hid); await process_frame
	for c in bf.get("conclusions", []):
		var cid: String = c.get("id", ""); var gh: Array = c.get("gate_hypo_ids", [])
		if cid == "" or gh.is_empty(): continue
		gv._derive_conclusion(str(gh[0]), cid); await process_frame
	gv._rebuild_graph(); await process_frame

	var el: Array = gv._edge_list
	var target_n := 0; var support_n := 0; var other_n := 0
	for e in el:
		match e.get("kind", ""):
			"target": target_n += 1
			"support": support_n += 1
			_: other_n += 1
	print("[EDGE-COUNT] 渲染边总数=%d  target(金)=%d  support(绿)=%d  其他=%d" % [el.size(), target_n, support_n, other_n])
	print("[EDGE-COUNT] _relations(玩家边)数=%d" % gv._relations.size())
	# 期望：target(金) 应为 0（结论→人物金边不再自动派生）；support 仅 1:1 推导边，不应有大量
	if target_n == 0:
		print("[EDGE-COUNT] ✓ 无系统自动金边")
	else:
		print("[EDGE-COUNT] ✗ 仍有 %d 条系统金边" % target_n)
	quit()
