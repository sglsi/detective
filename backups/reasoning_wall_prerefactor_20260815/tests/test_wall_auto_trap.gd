extends SceneTree

# 复现场景二「思考」按钮在 OBSERVE 阶段（收满线索但还没翻到 REASONING）提前开墙
# 导致 _wall_auto=false → 提交验证后不推进 的陷阱，并验证修复。
# 每个场景用全新 scene 实例，避免开/关墙实例互相污染。

var _pass := 0
var _fail := 0

func _chk(cond: bool, msg: String) -> void:
	if cond:
		_pass += 1
		print("[PASS] " + msg)
	else:
		_fail += 1
		print("[FAIL] " + msg)

func _new_scene() -> Node:
	var s2 = load("res://scripts/scene/scene2.gd").new()
	root.add_child(s2)
	return s2

func _collect_all(s2: Node) -> void:
	for h in s2.hotspots():
		s2._clues.append(h)

func _test_open(s2: Node, phase: int, expect_auto: bool, label: String) -> void:
	s2._phase = phase
	s2._open_wall()
	await create_timer(0.1).timeout
	_chk(s2._wall_auto == expect_auto, label + " （_wall_auto=%s）" % str(s2._wall_auto))

func _initialize() -> void:
	await create_timer(0.2).timeout

	# 场景 A：OBSERVE 阶段 + 收满线索 → 玩家提前点「思考」开墙（复现陷阱，应为 true）
	var a := _new_scene()
	_collect_all(a)
	await _test_open(a, 1, true, "收满线索后在 OBSERVE 阶段提前开墙：_wall_auto 应为 true")
	a.free()

	# 场景 B：OBSERVE 阶段 + 线索未收集 → 开墙应仍为预览（不推进，应为 false）
	var b := _new_scene()
	await _test_open(b, 1, false, "OBSERVE 阶段且线索未收集：_wall_auto 应为 false（预览）")
	b.free()

	# 场景 C：REASONING 阶段开墙（正常路径，应为 true）
	var c := _new_scene()
	_collect_all(c)
	await _test_open(c, 3, true, "REASONING 阶段开墙：_wall_auto 应为 true")
	c.free()

	print("\nWALL_AUTO_RESULT: " + ("PASS" if _fail == 0 else "FAIL") + "  (pass=%d fail=%d)" % [_pass, _fail])
	quit()
