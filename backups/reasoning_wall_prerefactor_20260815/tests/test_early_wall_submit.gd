extends SceneTree
## 复现场景二真实卡死：OBSERVE 阶段、仅部分线索时点「思考」开墙（守卫要求 ≥1 条，
## 故用 1 条开墙，_wall_auto=false 钉死在该墙实例上），之后线索收满并进入推理阶段、
## 在同一个墙实例内提交验证 —— 必须能推进过渡，否则卡死（旧逻辑依赖开墙时 _wall_auto）。

var _container: Node
var _pass := 0
var _fail := 0

func _initialize() -> void:
	await create_timer(0.1).timeout
	_container = Node.new()
	get_root().add_child(_container)

	var Cls = load("res://scripts/scene/scene2.gd")

	# ---- 场景 A：部分线索时提前开墙，之后收满+进推理，同实例提交 ----
	var s2 = Cls.new()
	_container.add_child(s2)
	await create_timer(0.1).timeout
	s2._enter_arrival(); await create_timer(0.05).timeout
	s2._on_arrival_ended(); await create_timer(0.05).timeout
	s2._on_detective_ended(); await create_timer(0.05).timeout
	_chk(s2._phase == 2, "A：已进入 OBSERVE 阶段(phase=2)")

	# 先记录 1 条线索（绕过「0 线索不能开墙」守卫）
	var hs0 = s2.hotspots()[0]
	s2._on_clue_recorded(hs0["id"], {"id":hs0["id"],"name":hs0["label"],"desc":hs0.get("desc",""),"correct":true})
	await create_timer(0.05).timeout
	s2._open_wall(); await create_timer(0.05).timeout
	var wall_a = s2._wall_instance
	_chk(wall_a != null, "A：部分线索时开墙成功")
	_chk(s2._wall_auto == false, "A：开墙时仅 1 条线索 → _wall_auto=false（旧逻辑会卡死）")

	# 收满剩余线索 + 进入推理阶段（模拟自动流程，但不重新开墙）
	for hs in s2.hotspots().slice(1):
		s2._on_clue_recorded(hs["id"], {"id":hs["id"],"name":hs["label"],"desc":hs.get("desc",""),"correct":true})
	await create_timer(0.05).timeout
	s2._phase = 3   # Phase.REASONING
	_chk(s2._clues.size() >= s2.hotspots().size(), "A：全部线索已收满")

	# 同实例提交验证（模拟点「确定」）
	wall_a._on_verify_confirm(3); await create_timer(0.1).timeout
	_chk(s2._phase == 4, "A：提前开的墙、收满+进推理后提交 → 进入 TRANSITION(phase=4)")
	_chk(s2._dm != null and s2._dm.is_active(), "A：过渡对话已激活")

	# ---- 对照组：OBSERVE、1 条线索预览提交，不应推进 ----
	var s3 = Cls.new()
	_container.add_child(s3)
	await create_timer(0.05).timeout
	s3._enter_arrival(); await create_timer(0.03).timeout
	s3._on_arrival_ended(); await create_timer(0.03).timeout
	s3._on_detective_ended(); await create_timer(0.05).timeout
	var h0 = s3.hotspots()[0]
	s3._on_clue_recorded(h0["id"], {"id":h0["id"],"name":h0["label"],"desc":h0.get("desc",""),"correct":true})
	s3._open_wall(); await create_timer(0.05).timeout
	var wall_c = s3._wall_instance
	wall_c._on_verify_confirm(1); await create_timer(0.1).timeout
	_chk(s3._phase == 2, "对照：OBSERVE 且 1 条线索预览提交 → 不推进(仍 phase=2)")

	print("EARLY_WALL_RESULT: PASS=%d FAIL=%d" % [_pass, _fail])
	await create_timer(0.1).timeout
	quit()

func _chk(cond: bool, msg: String) -> void:
	if cond:
		_pass += 1
		print("  [PASS] %s" % msg)
	else:
		_fail += 1
		print("  [FAIL] %s" % msg)
