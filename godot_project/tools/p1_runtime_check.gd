extends Node

## P1 运行时校验（真实引擎上下文）
## 作为主场景运行：godot --headless --path . tools/p1_runtime_check.tscn
## 此时 autoload 已全部初始化，可真实解析 game_scene 派生脚本中的
## autoload 全局引用与 class_name 交叉引用。

var _failed: bool = false

func _fail(m: String) -> void:
	_failed = true
	printerr("  ❌ FAIL: " + m)

func _pass(m: String) -> void:
	print("  ✅ " + m)

func _check_packed(path: String, expect_class: String) -> bool:
	print("=== 校验场景: %s ===" % path)
	var scn = load(path)
	if scn == null:
		_fail("无法加载场景 %s" % path)
		return false
	if not (scn is PackedScene):
		_fail("不是 PackedScene: %s" % path)
		return false
	var inst = scn.instantiate()
	if inst == null:
		_fail("实例化失败 %s" % path)
		return false
	if not (inst is Node):
		_fail("实例不是 Node: %s" % path)
		inst.free()
		return false
	# 注意：get_class() 返回基类（Control），需用脚本的 class_name 判定
	var script = inst.get_script()
	var gname: String = script.get_global_name() if script != null else ""
	if gname != expect_class:
		_fail("实例类不匹配：期望 %s，实际 %s" % [expect_class, gname])
		inst.free()
		return false
	_pass("场景加载并实例化成功: %s (class=%s)" % [path, gname])
	inst.free()
	return true

func _check_tres(path: String, scene_id: String, expect_nodes: int) -> bool:
	print("=== 校验对话资源: %s ===" % path)
	var res = load(path)
	if res == null:
		_fail("无法加载资源 %s" % path)
		return false
	if not ("nodes" in res) or not res.has_method("get_start_node"):
		_fail("不是有效的 DialogueResource: %s" % path)
		return false
	var total: int = res.nodes.size()
	if total < expect_nodes:
		_fail("节点数 %d < 期望 %d" % [total, expect_nodes])
		return false
	_pass("节点总数 %d (>=%d)" % [total, expect_nodes])
	# 三难度起点有效
	for diff in [0, 1, 2]:
		var sid: String = res.get_start_node(diff)
		var found: bool = false
		for node in res.nodes:
			if node.node_id == sid:
				found = true
				break
		if found:
			_pass("难度 %d 起点 '%s' 存在" % [diff, sid])
		else:
			_fail("难度 %d 起点 '%s' 不存在" % [diff, sid])
	# 无悬空 next_nodes
	var ids: Dictionary = {}
	for node in res.nodes:
		ids[node.node_id] = true
	var dangling: int = 0
	for node in res.nodes:
		for nx in node.next_nodes:
			# "end" 为对话终止伪节点，由 dialogue_manager 特殊处理，不算悬空
			if nx == "end":
				continue
			if not ids.has(nx):
				dangling += 1
				printerr("    悬空引用: %s -> %s" % [node.node_id, nx])
	if dangling > 0:
		_fail("存在 %d 处悬空 next_nodes" % dangling)
		return false
	_pass("无悬空 next_nodes 引用")
	return true

func _ready() -> void:
	print("=== P1 运行时校验（真实引擎上下文）===")
	var ok := true

	# 1. 场景 2 实例化（半引导）
	ok = _check_packed("res://scenes/scene_02.tscn", "Scene02Game") and ok
	# 2. 场景 3 实例化（轻引导）
	ok = _check_packed("res://scenes/scene_03.tscn", "Scene03Game") and ok

	# 3. 对话资源结构
	ok = _check_tres("res://resources/dialogues/scene_02_garden.tres", "scene_02", 40) and ok
	ok = _check_tres("res://resources/dialogues/scene_03_indoor.tres", "scene_03", 40) and ok

	if ok:
		print("\n🎉 P1 运行时校验全部通过")
		get_tree().quit(0)
	else:
		print("\n💥 P1 运行时校验存在失败项")
		get_tree().quit(1)
