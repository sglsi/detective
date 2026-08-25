extends Control
## 问题2验证：case_wide 下线索默认放左栏不进画布；人物仍分组平铺在画布。
## 人物来自 build 兜底（ClueSystem.get_collected("") 的 related_npcs）。

func _ready() -> void: _run()

func _run() -> void:
	var ClueSystem: Node = get_tree().root.get_node_or_null("/root/ClueSystem")
	if not ClueSystem:
		print("Q2_FAIL no ClueSystem"); get_tree().quit(0); return
	ClueSystem.clear_collected(); ClueSystem.case_wall_state = {}; ClueSystem.clear_source("q2")
	# 注入带 related_npcs 的线索（跨场景人物）
	ClueSystem.collect_clue_from_catalog("q2a", "车轮印", "窄轮距", true, "q2", 3, "", "", [], [], [], ["P_A"])
	ClueSystem.collect_clue_from_catalog("q2b", "身高特征", "凶手高大", true, "q2", 3, "", "", [], [], [], ["P_B"])
	var clues: Array = ClueSystem.get_collected("")
	var hypo := {"title": "核心", "battlefield": {"hypotheses": [{"id": "H1", "text": "某人作案", "correct": true}]}}
	var wall = load("res://scripts/clue/reasoning_wall.gd").new()
	wall.name = "Q2Wall"; add_child(wall)
	wall.setup(clues, hypo, Callable(), Callable(), 1, Callable(), {}, Callable(), false, -1, Callable(), true)
	await get_tree().create_timer(0.4).timeout
	if not wall._graph_view:
		print("Q2_FAIL no graph"); get_tree().quit(0)
	var gv = wall._graph_view
	print("[Q2] case_wide=%s" % gv._case_wide)
	var pnodes := []
	for id in gv._node_views:
		if gv._node_kind.get(id) == "person":
			pnodes.append(id)
	print("[Q2] 人物节点: ", str(pnodes))
	print("[Q2] 线索 q2a 在画布=%s, q2b 在画布=%s, _placed_clues=%s" % [
		gv._node_views.has("q2a"), gv._node_views.has("q2b"), str(gv._placed_clues)])
	var ok_person: bool = gv._node_views.has("P_A") or gv._node_views.has("P_B")
	var ok_left: bool = (not gv._node_views.has("q2a")) and (not gv._node_views.has("q2b"))
	print("[Q2] 人物平铺=%s, 线索默认左栏=%s" % [ok_person, ok_left])
	print(("Q2_OK" if ok_person and ok_left else ("Q2_FAIL person=%s left=%s" % [ok_person, ok_left])))
	get_tree().quit(0)