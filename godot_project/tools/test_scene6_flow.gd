extends SceneTree
## 头less 流程冒烟测试：直接调用 scene6 的各流程函数，确保对话节点构建与各回调不抛异常。
## 不模拟点击（headless 点击不可靠），只验证函数体可安全执行。

func _initialize() -> void:
	await create_timer(0.15).timeout
	var scen = load("res://scenes/scene6.tscn")
	if not scen:
		print("SCENE6_FLOW_FAIL: cannot load scene6.tscn")
		quit(); return
	var node = scen.instantiate()
	root.add_child(node)
	await create_timer(0.15).timeout

	for d in [0, 1, 2]:
		node._difficulty = d
		node._investigated = {"landlady": true, "alice": true}
		node._gregson_conclusion()      # 构建三难度变体对话
		await create_timer(0.05).timeout

	node._investigated = {"landlady": true, "alice": true, "room": true}
	node._arrest_interrogation()
	await create_timer(0.05).timeout
	node._harper_choice()
	await create_timer(0.05).timeout
	node._talk_harper()
	await create_timer(0.05).timeout
	node._gregson_flip()
	await create_timer(0.05).timeout
	node._enter_reasoning()
	await create_timer(0.05).timeout
	node._enter_transition()
	await create_timer(0.05).timeout
	# _go_scene5 会真正切场景，headless 下跳过
	print("SCENE6_FLOW_OK")
	quit()
