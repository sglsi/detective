extends Node
# 回归测试：验证 DialogueManager 不会因三类数据缺陷而卡死/崩溃
#   (1) 自环自动推进（A→A）：advance 会无限重入同一节点
#   (2) 不可见节点成环（should_show 全 false 互相指向）：_go_to_node 跳过递归会无限递归 → 栈溢出
#   (3) choice 节点所有选项被条件过滤：呈现空选项面板后玩家无任何可点项 → 冻结
# 哨兵：P1_RESULT: PASS / FAIL
#   若缺陷未修，(2) 会无限递归令进程崩溃（CI 超时失败），(1)(3) 会令对话始终 active → FAIL。
#
# ⚠️ 运行方式（关键）：必须作为「主场景」运行，不能用 --script！
#   godot --headless --path . tools/test_dialogue_no_hang.tscn
# 原因：本测试依赖 DialogueManager，而 DialogueManager._ready() 引用 autoload 单例
#   DialogueEventBus。--script 模式下 autoload 在编译期尚未注册，会导致
#   "Identifier not found: DialogueEventBus" 编译失败（进而 DialogueManager.new() 失败、
#   测试逻辑空跑、虚假 PASS）。作为主场景运行时 autoload 已全部初始化，可真实解析。
#
# 注：DialogueNodeResource.next_nodes 为强类型 Array[String]、DialogueResource.nodes 为
#   强类型 Array[Resource]，构造时必须用强类型数组赋值，否则 Godot 4 运行时拒绝赋值。

var _ok := true

func _process(_delta: float) -> void:
	_run_case_self_loop()
	_run_case_invisible_cycle()
	_run_case_empty_choice()
	if _ok:
		print("P1_RESULT: PASS")
	else:
		print("P1_RESULT: FAIL")
	get_tree().quit()

func _new_manager() -> DialogueManager:
	var dm := DialogueManager.new()
	add_child(dm)
	return dm

func _mk(nid: String, trigger: String, nexts: Array[String], diff_filter: int = 0, verify: String = "") -> DialogueNodeResource:
	var n := DialogueNodeResource.new()
	n.node_id = nid
	n.speaker = "system"
	n.text = nid
	n.trigger = trigger
	n.next_nodes = nexts
	n.difficulty_filter = diff_filter
	n.verify_filter = verify
	return n

func _run_case_self_loop() -> void:
	var dm := _new_manager()
	var res := DialogueResource.new()
	var nodes: Array[Resource] = [_mk("a", "auto", ["a"])]
	res.nodes = nodes
	res.easy_start_node = "a"; res.normal_start_node = "a"; res.hard_start_node = "a"
	dm.dialogue_resource = res
	dm.start_dialogue()
	for i in 30:
		if not dm.is_active(): break
		dm.advance()
	if dm.is_active():
		_ok = false
		push_error("[dialogue] 自环节点未被安全结束（仍 active）")
	dm.queue_free()

func _run_case_invisible_cycle() -> void:
	var dm := _new_manager()
	var res := DialogueResource.new()
	# 三节点互相指向，但全部 difficulty_filter=3(HARD)，NORMAL 下均不可见 → 跳过成环
	var nodes: Array[Resource] = [
		_mk("x", "auto", ["y"], 3),
		_mk("y", "auto", ["z"], 3),
		_mk("z", "auto", ["x"], 3),
	]
	res.nodes = nodes
	res.normal_start_node = "x"
	dm.dialogue_resource = res
	dm.set_difficulty(1)   # NORMAL
	dm.start_dialogue()
	for i in 30:
		if not dm.is_active(): break
		dm.advance()
	if dm.is_active():
		_ok = false
		push_error("[dialogue] 不可见节点成环未被 visited 守卫安全结束（仍 active）")
	dm.queue_free()

func _run_case_empty_choice() -> void:
	var dm := _new_manager()
	var res := DialogueResource.new()
	var nodes: Array[Resource] = [
		_mk("c", "choice", ["o1", "o2"]),
		_mk("o1", "auto", ["end"], 0, "VERIFIED"),
		_mk("o2", "auto", ["end"], 0, "SUPPORTED"),
	]
	res.nodes = nodes
	res.normal_start_node = "c"
	dm.dialogue_resource = res
	dm.start_dialogue()
	for i in 30:
		if not dm.is_active(): break
		dm.advance()
	if dm.is_active():
		_ok = false
		push_error("[dialogue] 空选项节点未被安全结束（仍 active）")
	dm.queue_free()
