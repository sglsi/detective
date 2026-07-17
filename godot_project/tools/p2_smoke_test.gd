extends SceneTree

## P2 对话资源冒烟测试（场景 4-8 自主探索）
## godot --headless --path . --script tools/p2_smoke_test.gd

func _fail(m: String) -> void:
	printerr("  ❌ FAIL: " + m)

func _pass(m: String) -> void:
	print("  ✅ " + m)

func _check_resource(path: String, expect_min_nodes: int, expect_step_entries: int, hypo_choice: String) -> bool:
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

	var ids := {}
	for node in res.nodes:
		if node.node_id in ids:
			_fail("重复 node_id: %s" % node.node_id)
		ids[node.node_id] = node

	for diff in [0, 1, 2]:
		var sid = res.get_start_node(diff)
		if sid == "" or not (sid in ids):
			_fail("难度 %d 起点无效: %s" % [diff, sid])
		else:
			_pass("难度 %d 起点: %s" % [diff, sid])

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

	var step_entries := 0
	for node in res.nodes:
		if node.is_step_entry and node.exploration_step > 0:
			step_entries += 1
	if step_entries == expect_step_entries:
		_pass("六步入口节点 %d (期望 %d)" % [step_entries, expect_step_entries])
	else:
		_fail("六步入口节点 %d != %d" % [step_entries, expect_step_entries])

	# 四级验证分支齐全
	var found_verify := {}
	for node in res.nodes:
		if node.verify_filter != "":
			found_verify[node.verify_filter] = true
	for k in ["VERIFIED", "SUPPORTED", "INSUFFICIENT", "CONTRADICTORY"]:
		if k in found_verify:
			_pass("存在验证分支: %s" % k)
		else:
			_fail("缺少验证分支: %s" % k)

	# 关键推理选择题 4 选项
	if hypo_choice in ids:
		var n = ids[hypo_choice].next_nodes.size()
		if n == 4:
			_pass("推理选择题 %s 选项数 %d" % [hypo_choice, n])
		else:
			_fail("推理选择题 %s 选项数 %d != 4" % [hypo_choice, n])
	else:
		_fail("推理选择题节点不存在: %s" % hypo_choice)

	# 可达 end（忽略难度/验证过滤，沿所有 next 分支）
	if _can_reach_end(ids, res.get_start_node(0)):
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

func _init() -> void:
	var ok := true
	var cfg = [
		["res://resources/dialogues/scene_04_police.tres", 43, "s4_hypo_choice"],
		["res://resources/dialogues/scene_05_parlor.tres", 40, "s5_hypo_choice"],
		["res://resources/dialogues/scene_06_apartment.tres", 40, "s6_hypo_choice"],
		["res://resources/dialogues/scene_07_hotel.tres", 40, "s7_hypo_choice"],
		["res://resources/dialogues/scene_08_finale.tres", 39, "s8_hypo_choice"],
	]
	for c in cfg:
		ok = _check_resource(c[0], c[1], 7, c[2]) and ok

	if ok:
		print("\n🎉 P2 资源校验全部通过（场景 4-8）")
		quit(0)
	else:
		print("\n💥 P2 资源校验存在失败项")
		quit(1)
