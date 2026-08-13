extends SceneTree
## 摄像机复位回归测试（对应场景一华生→信使「推近后卡放大态」bug）
## 验证：观察推近 focus_world_point 使 _world 缩放→2.2（tween 跑完后），
##       阶段切换 reset_camera() 使 _world 缩放回到 1.0、position 回到 (0,0)（tween 跑完后）。
## 哨兵：CAM_RESET_RESULT: PASS / FAIL
##
## 运行：godot --headless --script res://tools/test_camera_reset.gd

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var sf = load("res://scripts/ui/scene_framework.gd").new()
	root.add_child(sf)
	sf._ready()                       # --script 无帧推进，手动触发构建世界子树
	sf.setup("摄像机复位测试", "t", null)
	sf.set_camera_enabled(true)

	var ok := true
	var step := ""

	# 1) 模拟「记录线索时推近到华生立绘部位」：tween 异步，需等其跑完再断言
	step = "focus"
	sf.focus_world_point(Vector2(500, 400), 2.2)
	await create_timer(0.55).timeout
	var focus_scale: float = sf._world.scale.x
	if abs(focus_scale - 2.2) > 0.1:
		ok = false; step = "推近后 scale=%.3f 期望≈2.2" % focus_scale

	# 2) 模拟「华生→信使 阶段切换」：reset_camera 归位，同样等 tween 跑完
	step = "reset"
	sf.reset_camera()
	await create_timer(0.6).timeout
	var reset_scale: float = sf._world.scale.x
	var reset_pos: Vector2 = sf._world.position
	if abs(reset_scale - 1.0) > 0.05:
		ok = false; step = "复位后 scale=%.3f 期望≈1.0" % reset_scale
	if not reset_pos.is_equal_approx(Vector2.ZERO):
		ok = false; step = "复位后 position=%s 期望(0,0)" % reset_pos

	# 3) 二次推近（信使观察记录线索）再复位，确认复位幂等
	step = "refocus"
	sf.focus_world_point(Vector2(900, 300), 2.5)
	await create_timer(0.55).timeout
	step = "rereset"
	sf.reset_camera()
	await create_timer(0.6).timeout
	var s2: float = sf._world.scale.x
	var p2: Vector2 = sf._world.position
	if abs(s2 - 1.0) > 0.05 or not p2.is_equal_approx(Vector2.ZERO):
		ok = false; step = "二次复位后 scale=%.3f pos=%s" % [s2, p2]

	print("CAM_RESET focus=%.3f reset=%.3f rereset=%.3f" % [focus_scale, reset_scale, s2])

	if ok:
		print("CAM_RESET_RESULT: PASS")
	else:
		print("CAM_RESET_RESULT: FAIL - " + step)
	quit(0 if ok else 1)
