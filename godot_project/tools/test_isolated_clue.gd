extends SceneTree
## 回归测试：孤立线索独立性（放置画布但未与人物建立关系的线索，拖动人时跟着移动）
## 驱动真实 GraphViewController：build → 读 _node_center，模拟移动人物锚点 → rebuild → 再读 _node_center。
##   A. 完全孤立线索（无 support/target 边、related_npcs 空）→ 不随人物移动（保持独立）
##   B. 已打标签线索（related_npcs 含人物）→ 挂在人物下、随人物移动（功能保留）

func _build_gv(clues: Array, related_for_c: Array, relations: Array) -> Object:
	var gv = load("res://scripts/clue/graph_view_controller.gd").new()
	root.add_child(gv)
	await process_frame
	var cdict := {}
	for c in clues:
		cdict[c.get("id", "")] = c
	# 注入 related_npcs（按参数覆盖，便于 A/B 切换）
	var final_clues := []
	for c in clues:
		var cc: Dictionary = c.duplicate()
		cc["related_npcs"] = related_for_c if str(c.get("id", "")) == "C" else c.get("related_npcs", [])
		final_clues.append(cc)
	var data := {
		"clues": final_clues,
		"hypo": {},
		"relations": relations,
		"persons": [{"id": "P", "name": "神秘嫌疑犯"}],
		"focus_person": "P",
		"editable": true,
		"state_store": {"graph_placed_clues": ["C"]},
	}
	gv.build(data)
	await process_frame
	return gv


func _move_person_and_rebuild(gv: Object, target: Vector2) -> void:
	gv._root_anchor_pos["P"] = target
	gv._node_center["P"] = target
	gv._rebuild_graph()
	await process_frame


func _initialize() -> void:
	await process_frame
	var pass_flag := true

	var clue := {"id": "C", "name": "孤立线索", "related_npcs": []}

	# ===================== 场景 A：完全孤立线索 =====================
	var gv_a = await _build_gv([clue], [], [])
	var p1_a: Vector2 = gv_a._node_center.get("P", Vector2.ZERO)
	var c1_a: Vector2 = gv_a._node_center.get("C", Vector2.ZERO)
	await _move_person_and_rebuild(gv_a, Vector2(300, 200))
	var p2_a: Vector2 = gv_a._node_center.get("P", Vector2.ZERO)
	var c2_a: Vector2 = gv_a._node_center.get("C", Vector2.ZERO)
	var person_delta_a := p2_a - p1_a
	var clue_delta_a := c2_a - c1_a
	print("[isolated_clue] A 人物位移=%s 孤立线索位移=%s" % [str(person_delta_a), str(clue_delta_a)])
	if not gv_a._node_center.has("C"):
		print("FAIL: A 孤立线索未成为画布节点")
		pass_flag = false
	elif clue_delta_a.length() > 5.0:
		print("FAIL: A 完全孤立线索应不随人物移动（位移 %.1f）" % clue_delta_a.length())
		pass_flag = false

	# ===================== 场景 B：已打标签线索（挂人物） =====================
	var gv_b = await _build_gv([clue], ["P"], [])
	var p1_b: Vector2 = gv_b._node_center.get("P", Vector2.ZERO)
	var c1_b: Vector2 = gv_b._node_center.get("C", Vector2.ZERO)
	await _move_person_and_rebuild(gv_b, Vector2(300, 200))
	var p2_b: Vector2 = gv_b._node_center.get("P", Vector2.ZERO)
	var c2_b: Vector2 = gv_b._node_center.get("C", Vector2.ZERO)
	var person_delta_b := p2_b - p1_b
	var clue_delta_b := c2_b - c1_b
	print("[isolated_clue] B 人物位移=%s 已打标签线索位移=%s" % [str(person_delta_b), str(clue_delta_b)])
	if not gv_b._node_center.has("C"):
		print("FAIL: B 已打标签线索未成为画布节点")
		pass_flag = false
	elif clue_delta_b.length() < person_delta_b.length() - 60.0:
		print("FAIL: B 已打标签线索应挂在人物下、随人物移动（位移 %.1f 过小，期望≈%.1f）" % [clue_delta_b.length(), person_delta_b.length()])
		pass_flag = false

	if pass_flag:
		print("ISOLATED_CLUE: PASS")
	else:
		print("ISOLATED_CLUE: FAIL")
	quit()
