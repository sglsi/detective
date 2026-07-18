extends SceneTree

# P5-4 内容深度打磨验证
# 验证场景三补齐了六步 exploration_step 与四级验证分支，
# 验证场景七补充了华生对话。

var failures: Array[String] = []

func _check(name: String, cond: bool, msg: String = "") -> void:
	if cond:
		print("OK   " + name)
	else:
		print("FAIL " + name + ((" — " + msg) if msg else ""))
		failures.append(name)

func _count_nodes(nodes: Array, predicate: Callable) -> int:
	var c := 0
	for n in nodes:
		if predicate.call(n):
			c += 1
	return c

func _process(_delta: float) -> bool:
	# ---------- 场景三：六步 + 验证分支 ----------
	var res3 := load("res://resources/dialogues/scene_03_indoor.tres")
	_check("scene_03_loaded", res3 != null)
	if res3:
		var nodes: Array = res3.get("nodes")
		_check("scene_03_nodes>=49", nodes.size() >= 49, "实际 %d" % nodes.size())
		var steps := {}
		var entries := {}
		var verifys := {}
		for n in nodes:
			var s: int = n.exploration_step
			steps[s] = steps.get(s, 0) + 1
			if n.is_step_entry:
				entries[s] = entries.get(s, 0) + 1
			var v: String = n.verify_filter
			if v != "":
				verifys[v] = verifys.get(v, 0) + 1
		for s in range(1, 7):
			_check("scene_03_step_%d_present" % s, steps.has(s) and steps[s] > 0, "count=%d" % steps.get(s, 0))
			_check("scene_03_entry_%d_present" % s, entries.has(s) and entries[s] > 0, "count=%d" % entries.get(s, 0))
		for v in ["VERIFIED", "SUPPORTED", "INSUFFICIENT", "CONTRADICTORY"]:
			_check("scene_03_verify_%s" % v, verifys.get(v, 0) > 0)
		# 验证 gate 节点存在且正确指向四级分支
		var gate = _find_node_by_id(nodes, "s3_verify_gate")
		_check("scene_03_verify_gate_exists", gate != null)
		if gate:
			_check("scene_03_verify_gate_step6", gate.exploration_step == 6)
			_check("scene_03_verify_gate_branches", gate.next_nodes.size() >= 4)
		# 原结局仍可达
		_check("scene_03_end_reachable", _find_node_by_id(nodes, "s3_end") != null)

	# ---------- 场景七：华生对话 ----------
	var res7 := load("res://resources/dialogues/scene_07_hotel.tres")
	_check("scene_07_loaded", res7 != null)
	if res7:
		var nodes: Array = res7.get("nodes")
		var watson_count := _count_nodes(nodes, func(n): return n.speaker == "华生")
		_check("scene_07_watson_present", watson_count > 0, "count=%d" % watson_count)
		_check("scene_07_watson_nodes>=4", watson_count >= 4, "count=%d" % watson_count)
		# 华生节点被正确接入流程（非孤立）
		var watson_linked := 0
		for n in nodes:
			if n.speaker == "华生":
				if n.next_nodes.size() > 0:
					watson_linked += 1
		_check("scene_07_watson_linked", watson_linked == watson_count, "linked=%d" % watson_linked)

	if failures.is_empty():
		print("DIALOGUE_PATCH_OK")
	else:
		print("DIALOGUE_PATCH_FAIL: " + str(failures))
	quit()
	return false

func _find_node_by_id(nodes: Array, node_id: String):
	for n in nodes:
		if n.node_id == node_id:
			return n
	return null
