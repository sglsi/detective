extends SceneTree

## P1 对话资源冒烟测试（场景二/三）
## godot --headless --path . --script tools/p1_smoke_test.gd

func _fail(m: String) -> void:
	printerr("  ❌ FAIL: " + m)

func _pass(m: String) -> void:
	print("  ✅ " + m)

func _check_resource(path: String, expect_min_nodes: int, expect_step_entries: int) -> bool:
	print("=== 校验资源: %s ===" % path)
	var res = load(path)
	if res == null:
		_fail("无法加载资源 %s" % path)
		return false
	if not ("nodes" in res) or not res.has_method("get_start_node"):
		_fail("资源不是有效的 DialogueResource")
		return false

	var total = res.nodes.size()
	if total >= expect_min_nodes:
		_pass("节点总数 %d (>=%d)" % [total, expect_min_nodes])
	else:
		_fail("节点总数 %d < %d" % [total, expect_min_nodes])

	# 建立 id 集合
	var ids := {}
	for node in res.nodes:
		if node.node_id in ids:
			_fail("重复 node_id: %s" % node.node_id)
		ids[node.node_id] = node

	# 三难度起点有效
	for diff in [0, 1, 2]:
		var sid = res.get_start_node(diff)
		if sid == "" or not (sid in ids):
			_fail("难度 %d 起点无效: %s" % [diff, sid])
		else:
			_pass("难度 %d 起点: %s" % [diff, sid])

	# 所有 next_nodes 引用存在 或 为 end
	var dangling := 0
	for node in res.nodes:
		for nx in node.next_nodes:
			if nx != "end" and not (nx in ids):
				dangling += 1
				printerr("    悬空引用: %s -> %s" % [node.node_id, nx])
	if dangling == 0:
		_pass("无悬空 next_nodes 引用")
	else:
		_fail("悬空引用 %d 处" % dangling)

	# 六步入口节点计数
	var step_entries := 0
	for node in res.nodes:
		if node.is_step_entry and node.exploration_step > 0:
			step_entries += 1
	if step_entries == expect_step_entries:
		_pass("六步入口节点 %d (期望 %d)" % [step_entries, expect_step_entries])
	else:
		_fail("六步入口节点 %d != %d" % [step_entries, expect_step_entries])

	# 可达性 BFS（忽略难度/验证过滤，沿所有 next 分支）
	var visited := {}
	var queue := [res.get_start_node(0)]
	while queue.size() > 0:
		var cur = queue.pop_front()
		if cur == "end" or cur in visited:
			continue
		visited[cur] = true
		if not (cur in ids):
			continue
		for nx in ids[cur].next_nodes:
			if nx != "end" and not (nx in visited):
				queue.append(nx)
	if "end" in visited or _can_reach_end(ids, res.get_start_node(0)):
		_pass("从 EASY 起点可达 end")
	else:
		_fail("从 EASY 起点无法到达 end")

	return dangling == 0 and total >= expect_min_nodes and step_entries == expect_step_entries

func _can_reach_end(ids: Dictionary, start: String) -> bool:
	var visited := {}
	var queue := [start]
	while queue.size() > 0:
		var cur = queue.pop_front()
		if cur == "end":
			return true
		if cur in visited or not (cur in ids):
			continue
		visited[cur] = true
		for nx in ids[cur].next_nodes:
			queue.append(nx)
	return false

func _verify_branches(path: String, kinds: Array) -> void:
	print("=== 验证分支检查: %s ===" % path)
	var res = load(path)
	var found := {}
	for node in res.nodes:
		if node.verify_filter != "":
			found[node.verify_filter] = true
	for k in kinds:
		if k in found:
			_pass("存在验证分支: %s" % k)
		else:
			_fail("缺少验证分支: %s" % k)

func _check_choice_options(path: String, choice_ids: Array, expect_options: int) -> void:
	print("=== 选择题选项数检查: %s ===" % path)
	var res = load(path)
	var ids := {}
	for node in res.nodes:
		ids[node.node_id] = node
	for cid in choice_ids:
		if not (cid in ids):
			_fail("选择题节点不存在: %s" % cid)
			continue
		var n = ids[cid].next_nodes.size()
		if n == expect_options:
			_pass("选择题 %s 选项数 %d" % [cid, n])
		else:
			_fail("选择题 %s 选项数 %d != %d" % [cid, n, expect_options])

func _init() -> void:
	var ok := true
	ok = _check_resource("res://resources/dialogues/scene_02_garden.tres", 40, 7) and ok
	_verify_branches("res://resources/dialogues/scene_02_garden.tres",
		["VERIFIED", "SUPPORTED", "INSUFFICIENT", "CONTRADICTORY"])
	_check_choice_options("res://resources/dialogues/scene_02_garden.tres",
		["s2_hypothesis_choice", "s2_choice2_start"], 4)

	ok = _check_resource("res://resources/dialogues/scene_03_indoor.tres", 40, 0) and ok
	_check_choice_options("res://resources/dialogues/scene_03_indoor.tres",
		["s3_q1", "s3_q2", "s3_q3", "s3_q4", "s3_q5"], 4)

	if ok:
		print("\n🎉 P1 资源校验全部通过")
		quit(0)
	else:
		print("\n💥 P1 资源校验存在失败项")
		quit(1)
