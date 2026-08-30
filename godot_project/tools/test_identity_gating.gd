extends SceneTree
## 回归测试：场景二人物身份门控
## 断言：场景二进入推理墙时，NPC_HOP 显示「神秘嫌疑犯」、NPC_DRE 显示「死者」，
## 不提前暴露「霍普」「德雷伯」真名。

func _initialize() -> void:
	await process_frame
	var ReasoningWall = load("res://scripts/clue/reasoning_wall.gd")
	var wall = ReasoningWall.new()
	root.add_child(wall)
	await process_frame

	# 构造场景二已收集线索（c201-c206），均关联 NPC_HOP 与 NPC_DRE
	var clues := []
	for cid in ["c201", "c202", "c203", "c204", "c205", "c206"]:
		var c = load("res://data/clues/clue_%s.tres" % cid)
		if c and c is Resource:
			clues.append({
				"id": cid,
				"name": c.get("name"),
				"correct": true,
				"associated": false,
				"related_npcs": c.get("related_npcs"),
			})
	# 构造 hypothesis（含 extra persons 以覆盖配置路径）
	var hypo := {
		"persons": ["NPC_HOP", "NPC_DRE"],
		"battlefield": {},
		"chain_id": "scene2",
		"expected_clues": 6,
	}
	wall.setup(clues, hypo, Callable(), Callable(), ReasoningWall.Diff.NORMAL, Callable(), {}, Callable(), true, 6, Callable(), false, [], false)
	await process_frame

	# 直接调用状态层派生人物（与真实 wall.build 同源）
	var persons: Array = wall._state_ctl._derive_persons()
	print("[identity_gating] persons=%s" % str(persons))
	var pass_flag := true
	var hop_name := ""
	var dre_name := ""
	for p in persons:
		var pid: String = p.get("id", "")
		if pid == "NPC_HOP": hop_name = p.get("name", "")
		if pid == "NPC_DRE": dre_name = p.get("name", "")
	if hop_name != "神秘嫌疑犯":
		print("FAIL: NPC_HOP 应为「神秘嫌疑犯」，实际 '%s'" % hop_name)
		pass_flag = false
	if dre_name != "死者":
		print("FAIL: NPC_DRE 应为「死者」，实际 '%s'" % dre_name)
		pass_flag = false
	var has_hop := false
	var has_dre := false
	for p in persons:
		if str(p.get("name", "")) == "霍普": has_hop = true
		if str(p.get("name", "")) == "德雷伯": has_dre = true
	if has_hop:
		print("FAIL: 场景二不应出现真名「霍普」")
		pass_flag = false
	if has_dre:
		print("FAIL: 场景二不应出现真名「德雷伯」")
		pass_flag = false
	if pass_flag:
		print("IDENTITY_GATING: PASS")
	else:
		print("IDENTITY_GATING: FAIL")
	quit()
