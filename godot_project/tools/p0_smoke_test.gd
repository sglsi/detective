extends SceneTree

## P0-1b 对话资源冒烟测试
## 用 godot --headless --path . --script tools/p0_smoke_test.gd 运行
## 独立验证 scene_01_phase1_tutorial.tres 资源结构与六步闭环可达性。
## 注意：--script 模式下 preload/res:// 受限，故用 load() 运行时加载 + 鸭子类型检查。

var _failed: bool = false

func _fail(m: String) -> void:
	_failed = true
	printerr("  ❌ FAIL: " + m)

func _pass(m: String) -> void:
	print("  ✅ " + m)

func _init() -> void:
	print("=== P0-1b 对话资源冒烟测试 ===")
	print("资源: res://resources/dialogues/scene_01_phase1_tutorial.tres")

	var path = "res://resources/dialogues/scene_01_phase1_tutorial.tres"
	var res = load(path)
	if res == null:
		_fail("无法加载资源 %s" % path)
		quit(1)
		return
	# 鸭子类型检查：确认是 DialogueResource 实例（含 nodes / get_start_node）
	if not ("nodes" in res) or not res.has_method("get_start_node"):
		_fail("资源不是有效的 DialogueResource（缺少 nodes 或 get_start_node）")
		quit(1)

	# 1. 节点总数
	var total = res.nodes.size()
	if total >= 30:
		_pass("节点总数 %d (>=30)" % total)
	else:
		_fail("节点总数 %d < 30" % total)

	# 2. 六步入口节点（is_step_entry && exploration_step>0）
	var step_entries = 0
	for node in res.nodes:
		if node.is_step_entry and node.exploration_step > 0:
			step_entries += 1
	if step_entries == 7:
		_pass("六步入口节点 %d (期望 7)" % step_entries)
	else:
		_fail("六步入口节点 %d != 7" % step_entries)

	# 3. 三难度起点有效且存在
	for diff in [0, 1, 2]:
		var sid = res.get_start_node(diff)
		if sid == "":
			_fail("难度 %d 起始节点为空" % diff)
			continue
		var found = false
		for node in res.nodes:
			if node.node_id == sid:
				found = true
				break
		if found:
			_pass("难度 %d 起点 '%s' 存在" % [diff, sid])
		else:
			_fail("难度 %d 起点 '%s' 在节点表中不存在" % [diff, sid])

	# 4. 四级验证分支（s1_step6_*）
	var verify_count = 0
	for node in res.nodes:
		if node.node_id.begins_with("s1_step6_"):
			verify_count += 1
	if verify_count >= 4:
		_pass("四级验证分支节点 %d (>=4)" % verify_count)
	else:
		_fail("验证分支节点 %d < 4" % verify_count)

	# 5. 六步闭环可达性：从 NORMAL 起点沿 auto 链推进，验证能到达六步入口
	var start = res.get_start_node(1)
	var visited: Dictionary = {}
	var current = start
	var steps = 0
	var reached = false
	while current != "" and steps < 500:
		if visited.has(current):
			break
		visited[current] = true
		for node in res.nodes:
			if node.node_id == current and node.is_step_entry and node.exploration_step > 0:
				reached = true
		var nxt: Array = []
		for node in res.nodes:
			if node.node_id == current:
				nxt = node.get_available_next(1, "")
				break
		if nxt.is_empty():
			break
		current = nxt[0]
		steps += 1
		if reached:
			break
	if reached:
		_pass("六步闭环可达：从起点遍历 %d 步到达六步入口" % steps)
	else:
		_fail("从起点未到达任何六步入口节点（闭环不可达）")

	# 结果汇总
	if _failed:
		printerr("\n=== P0-1b 对话资源冒烟: 存在失败项 ===")
		quit(1)
	else:
		print("\n=== P0-1b 对话资源冒烟: 全部通过 ✅ ===")
		quit()
