extends Node

## P2 运行时校验（真实引擎上下文）
## 作为主场景运行：godot --headless --path . tools/p2_runtime_check.tscn
## autoload 已全部初始化，可真实解析 GameScene 派生脚本中的全局引用与 class_name。

var _failed: bool = false

func _fail(m: String) -> void:
	_failed = true
	printerr("  ❌ FAIL: " + m)

func _pass(m: String) -> void:
	print("  ✅ " + m)

func _check_packed(path: String, expect_class: String) -> void:
	print("=== 校验场景: %s ===" % path)
	var scn = load(path)
	if scn == null:
		_fail("无法加载场景 %s" % path)
		return
	if not (scn is PackedScene):
		_fail("不是 PackedScene: %s" % path)
		return
	var inst = scn.instantiate()
	if inst == null:
		_fail("实例化失败 %s" % path)
		return
	var script = inst.get_script()
	var gname: String = script.get_global_name() if script != null else ""
	if gname != expect_class:
		_fail("实例类不匹配：期望 %s，实际 %s" % [expect_class, gname])
		inst.free()
		return
	_pass("场景加载并实例化成功: %s (class=%s)" % [path, gname])
	# 释放（不进入 _ready 后的交互循环）
	inst.free()

func _check_tres(path: String, expect_nodes: int) -> void:
	print("=== 校验对话资源: %s ===" % path)
	var res = load(path)
	if res == null:
		_fail("无法加载资源 %s" % path)
		return
	if not ("nodes" in res) or not res.has_method("get_start_node"):
		_fail("不是有效的 DialogueResource: %s" % path)
		return
	var total: int = res.nodes.size()
	if total < expect_nodes:
		_fail("节点数 %d < 期望 %d" % [total, expect_nodes])
		return
	_pass("节点总数 %d (>=%d)" % [total, expect_nodes])
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
	var ids: Dictionary = {}
	for node in res.nodes:
		ids[node.node_id] = true
	var dangling: int = 0
	for node in res.nodes:
		for nx in node.next_nodes:
			if nx == "end":
				continue
			if not ids.has(nx):
				dangling += 1
				printerr("    悬空引用: %s -> %s" % [node.node_id, nx])
	if dangling > 0:
		_fail("存在 %d 处悬空 next_nodes" % dangling)
		return
	_pass("无悬空 next_nodes 引用")

func _ready() -> void:
	print("=== P2 运行时校验（场景 4-8 实例化 + 资源结构）===")
	var scenes = [
		["res://scenes/scene_04.tscn", "Scene04Game", "res://resources/dialogues/scene_04_police.tres", 43],
		["res://scenes/scene_05.tscn", "Scene05Game", "res://resources/dialogues/scene_05_parlor.tres", 40],
		["res://scenes/scene_06.tscn", "Scene06Game", "res://resources/dialogues/scene_06_apartment.tres", 40],
		["res://scenes/scene_07.tscn", "Scene07Game", "res://resources/dialogues/scene_07_hotel.tres", 40],
		["res://scenes/scene_08.tscn", "Scene08Game", "res://resources/dialogues/scene_08_finale.tres", 39],
	]
	for s in scenes:
		_check_packed(s[0], s[1])
		_check_tres(s[2], s[3])

	if _failed:
		print("\n💥 P2 运行时校验存在失败项")
		get_tree().quit(1)
	else:
		print("\n🎉 P2 运行时校验全部通过")
		get_tree().quit(0)
