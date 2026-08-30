extends SceneTree
## 回归测试：拖动结论/推断时子树随移（需求3）+ 结论随人物移动（需求5）+ 孤立结论独立（需求2）+ 线索框加宽（需求6）
## 驱动真实 GraphViewController：build → 读 _node_center / _node_views，改锚点/偏移 → rebuild → 再读。

func _build_gv() -> Object:
	var gv = load("res://scripts/clue/graph_view_controller.gd").new()
	root.add_child(gv)
	await process_frame
	var persons := [{"id": "P", "name": "神秘嫌疑犯"}]
	var clues := [{"id": "C", "name": "线索C", "related_npcs": ["P"]}]
	var graph_nodes := [{"id": "H1", "kind": "hypo", "label": "推断H1", "sub": "自定义"}]
	var relations := [{"from": "H1", "to": "conclusion_K1", "kind": "support"}]
	var state_store := {
		"graph_placed_clues": ["C"],
		"graph_derived_conclusions": [
			{"id": "K1", "hid": "", "text": "结论K1", "target": "person:P"},
			{"id": "K2", "hid": "", "text": "孤立结论K2", "target": ""},
		],
		"graph_nodes": graph_nodes,
	}
	var data := {
		"clues": clues,
		"hypo": {"battlefield": {"conclusions": [
			{"id": "K1", "target": "person:P", "text": "结论K1"},
			{"id": "K2", "target": "", "text": "孤立结论K2"},
		]}},
		"relations": relations,
		"persons": persons,
		"focus_person": "P",
		"editable": true,
		"state_store": state_store,
	}
	gv.build(data)
	await process_frame
	return gv


func _rebuild(gv: Object) -> void:
	gv._rebuild_graph()
	await process_frame


func _initialize() -> void:
	await process_frame
	var pass_flag := true

	var gv = await _build_gv()
	await _rebuild(gv)

	# ---- 子树关系校验（需求3 前置）----
	var desc: Array = gv._layout._descendants("conclusion_K1")
	if not ("H1" in desc):
		print("FAIL: conclusion_K1 的子树应含 H1，实际=%s" % str(desc))
		pass_flag = false
	else:
		print("[drag_subtree] conclusion_K1 子树=%s" % str(desc))

	# ---- 需求5：结论/推断随人物移动 ----
	print("DEBUG derived=%d nodes=%s" % [gv._derived_conclusions.size(), str(gv._node_center.keys())])
	print("DEBUG parent_of=%s" % str(gv._layout._build_parent_of()))
	var p1: Vector2 = gv._node_center.get("P", Vector2.ZERO)
	var c1: Vector2 = gv._node_center.get("conclusion_K1", Vector2.ZERO)
	var h1: Vector2 = gv._node_center.get("H1", Vector2.ZERO)
	gv._root_anchor_pos["P"] = Vector2(400, 250)
	gv._node_center["P"] = Vector2(400, 250)
	await _rebuild(gv)
	var p2: Vector2 = gv._node_center.get("P", Vector2.ZERO)
	var c2: Vector2 = gv._node_center.get("conclusion_K1", Vector2.ZERO)
	var h2: Vector2 = gv._node_center.get("H1", Vector2.ZERO)
	var pd: Vector2 = p2 - p1
	if (c2 - c1).length() < pd.length() - 60.0:
		print("FAIL: 需求5 结论应随人物移动（位移 %.1f < %.1f）" % [(c2 - c1).length(), pd.length()])
		pass_flag = false
	else:
		print("[drag_subtree] 需求5 人物位移=%s 结论位移=%s 推断位移=%s" % [str(pd), str(c2 - c1), str(h2 - h1)])

	# ---- 需求3：手动拖动结论→其子树（推断H1）随之一并右移；偏移相对父派生位 ----
	gv._node_offsets["conclusion_K1"] = gv._node_offsets.get("conclusion_K1", Vector2.ZERO) + Vector2(120, 0)
	await _rebuild(gv)
	var c3: Vector2 = gv._node_center.get("conclusion_K1", Vector2.ZERO)
	var h3: Vector2 = gv._node_center.get("H1", Vector2.ZERO)
	if (c3 - c2).length() < 110.0:
		print("FAIL: 需求3 结论手动偏移后应右移≈120（实际 %.1f）" % (c3 - c2).length())
		pass_flag = false
	if (h3 - h2).length() < 110.0:
		print("FAIL: 需求3 推断H1应随结论一并右移≈120（实际 %.1f）" % (h3 - h2).length())
		pass_flag = false
	else:
		print("[drag_subtree] 需求3 结论偏移后 结论位移=%s 推断位移=%s" % [str(c3 - c2), str(h3 - h2)])

	# ---- 需求3+5：人物再移动→结论/推断仍跟随（偏移叠加在父派生位上）----
	var c_before: Vector2 = gv._node_center.get("conclusion_K1", Vector2.ZERO)
	var h_before: Vector2 = gv._node_center.get("H1", Vector2.ZERO)
	gv._root_anchor_pos["P"] = Vector2(550, 350)
	gv._node_center["P"] = Vector2(550, 350)
	await _rebuild(gv)
	var c_after: Vector2 = gv._node_center.get("conclusion_K1", Vector2.ZERO)
	var h_after: Vector2 = gv._node_center.get("H1", Vector2.ZERO)
	var follow: Vector2 = Vector2(150, 100)
	if (c_after - c_before - follow).length() > 20.0:
		print("FAIL: 需求3+5 人物再移动后结论仍应跟随（位移 %s 期望 %s）" % [str(c_after - c_before), str(follow)])
		pass_flag = false
	else:
		print("[drag_subtree] 需求3+5 人物再移动 结论位移=%s 推断位移=%s（均跟随）" % [str(c_after - c_before), str(h_after - h_before)])

	# ---- 需求2：孤立结论(K2,无关系)独立、不随人物移动 ----
	var k2_1: Vector2 = gv._node_center.get("conclusion_K2", Vector2.ZERO)
	if k2_1 == Vector2.ZERO:
		print("FAIL: 需求2 孤立结论 K2 应成为画布节点")
		pass_flag = false
	gv._root_anchor_pos["P"] = Vector2(700, 450)
	gv._node_center["P"] = Vector2(700, 450)
	await _rebuild(gv)
	var k2_2: Vector2 = gv._node_center.get("conclusion_K2", Vector2.ZERO)
	if k2_2 != Vector2.ZERO and (k2_2 - k2_1).length() > 5.0:
		print("FAIL: 需求2 孤立结论 K2 不应随人物移动（位移 %.1f）" % (k2_2 - k2_1).length())
		pass_flag = false
	else:
		print("[drag_subtree] 需求2 孤立结论 K2 位移=%.1f（应≈0，独立）" % (k2_2 - k2_1).length())

	# ---- 需求6：线索文本框宽度加倍（≥300）----
	var cv = gv._node_views.get("C")
	if cv == null or not is_instance_valid(cv):
		print("FAIL: 需求6 线索节点视图缺失")
		pass_flag = false
	else:
		var w: float = cv.size.x
		print("[drag_subtree] 需求6 线索卡宽度=%s（期望≥300）" % str(w))
		if w < 300.0:
			print("FAIL: 需求6 线索文本框宽度应≥300（实际 %.1f）" % w)
			pass_flag = false

	if pass_flag:
		print("DRAG_SUBTREE: PASS")
	else:
		print("DRAG_SUBTREE: FAIL")
	quit()
