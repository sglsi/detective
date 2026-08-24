extends SceneTree
## 单元测试：顶栏「添文本框」add_text_node + 拖动放开区域（_clamp_free）
## 验证点：
##  1) add_text_node 生成唯一自定义节点（id=note_<kind>_<seq>），进 _node_list 且可 rebuild
##  2) 连续添加多次 id 不重复
##  3) 自定义节点写进 state_store["graph_nodes"] 可被再次 build 恢复
##  4) _clamp_free 允许节点中心略超出画布(±120) 而 _clamp_to_canvas 仍钳在画布内

func _initialize() -> void:
	await process_frame
	var ok := true
	var GV = load("res://scripts/clue/graph_view_controller.gd")
	var gv = GV.new()
	var root := get_root()
	root.add_child(gv)
	var sts: Dictionary = {}
	sts["graph_view_mode"] = 0   # 哨兵：模拟真实已使用的 state_store（非空）
	sts["graph_node_positions"] = {}
	# 手动构建画布容器（headless 不走 _build_ui）：_clip -> _canvas
	var clip := Control.new()
	clip.size = Vector2(1280, 800)
	root.add_child(clip)
	var cv := Control.new()
	cv.size = Vector2(1280, 800)
	cv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip.add_child(cv)
	gv._clip = clip
	gv._canvas = cv
	gv.build({
		"clues": [
			{"id": "c1", "name": "线索一", "correct": true, "relation_tags": []},
		],
		"hypo": {"title": "凶手是谁", "description": "", "battle": {"hypotheses": [{"id": "H1", "text": "推断一", "correct": true}], "contradictions": []}},
		"relations": [],
		"persons": [{"id": "P1", "name": "人物甲"}],
		"state_store": sts,
	})
	gv._state_store = sts

	# 1&2) 多次添加不同 kind / 同 kind，id 唯一
	gv.add_text_node("hypo")
	gv.add_text_node("hypo")
	gv.add_text_node("clue")
	gv.add_text_node("conclusion")
	gv.add_text_node("person")
	var nl: Array = gv._node_list()
	var nids := {}
	var found_hypo0 := false
	var found_person0 := false
	for nd in nl:
		var id: String = nd.get("id", "")
		if id.begins_with("note_"):
			if nids.has(id): ok = false; print("TXT_FAIL id重复: ", id)
			nids[id] = true
			if id == "note_hypo_0": found_hypo0 = true
			if id == "note_person_0": found_person0 = true
	if not found_hypo0: ok = false; print("TXT_FAIL 缺 note_hypo_0")
	if not found_person0: ok = false; print("TXT_FAIL 缺 note_person_0")
	print("[TXT] 已添加自定义节点: ", nids.keys())

	# 3) 持久化恢复
	var saved_nodes: Array = sts.get("graph_nodes", [])
	if saved_nodes.size() != 5: ok = false; print("TXT_FAIL state_store graph_nodes=%d (期望5)" % saved_nodes.size())
	var sts2: Dictionary = {"graph_nodes": saved_nodes.duplicate(true)}
	gv._state_store = sts2
	gv._graph_nodes = (Array(sts2.get("graph_nodes", [])) as Array).duplicate()
	var nl2: Array = gv._node_list()
	var c2 := 0
	for nd in nl2:
		if (nd.get("id", "") as String).begins_with("note_"): c2 += 1
	if c2 != 5: ok = false; print("TXT_FAIL 恢复后 note 节点=%d (期望5)" % c2)
	print("[TXT] 恢复后自定义节点数=", c2)

	# 4) clamp 放开: _clamp_free 允许 ±120 出界；_clamp_to_canvas 仍钳在画布内
	# 4) clamp 放开: _clamp_free 允许中心略超出画布(≤120)；_clamp_to_canvas 仍钳回画布内(margin 60)
	var sz: Vector2 = gv._canvas.size
	var p_in: Vector2 = gv._clamp_to_canvas(Vector2(sz.x * 0.5, sz.y * 0.5))
	if p_in != Vector2(sz.x * 0.5, sz.y * 0.5): ok = false; print("TXT_FAIL 画布内点被错误钳制: ", p_in)
	var out_p: Vector2 = Vector2(sz.x + 90, sz.y + 90)   # 超出画布 90px
	var p_free: Vector2 = gv._clamp_free(out_p)
	var p_clamp2: Vector2 = gv._clamp_to_canvas(out_p)
	# 自由拖动允许超越边缘(slack=120)，严格钳制应回到画布内(margin 60)
	if p_free.x <= sz.x: ok = false; print("TXT_FAIL _clamp_free 未放开到画布外: ", p_free, " size=", sz)
	if p_clamp2.x >= sz.x - 59.9: ok = false; print("TXT_FAIL _clamp_to_canvas 未收紧到画布内: ", p_clamp2, " size=", sz)
	print("[TXT] canvas.size=", sz, " clamp_free(out+90) -> ", p_free, " | clamp_to_canvas(out+90) -> ", p_clamp2)

	if ok:
		print("TXT_E2E: OK — 添文本框 + 拖动放开区域 全部通过")
	else:
		print("TXT_E2E: FAIL")
	quit()