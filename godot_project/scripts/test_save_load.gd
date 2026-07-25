extends SceneTree
## Headless 验证：存/读档链路完整性（无需浏览器）
## 用 Godot headless 运行：Godot.exe --headless --path godot_project -s scripts/test_save_load.gd

func _init() -> void:
	print("=== 存/读档链路验证 ===")

	# 1. 检查关键 autoload 是否注册
	print("[Check] GameManager=", GameManager)
	print("[Check] SaveManager=", SaveManager)
	print("[Check] ClueObserver=", ClueObserver)
	print("[Check] SceneFramework=", SceneFramework)

	# 2. 模拟 GameManager 场景状态写入
	GameManager.current_case_id = "case_blood_letter"
	GameManager.current_scene_id = "scene1"
	GameManager.scene_state = {"phase": 2, "clue_ids": ["wrist", "arm", "pose"], "watson_recorded": 3}
	print("[Test] scene_state 已设置: ", GameManager.scene_state)

	# 3. 测试 get_saved_phase / get_saved_clue_ids（SceneFramework 辅助方法）
	var fw = SceneFramework.new()
	fw.name = "test_fw"
	var p = fw.get_saved_phase("scene1")
	var ids = fw.get_saved_clue_ids()
	print("[Test] get_saved_phase('scene1') = ", p, " (期望 2)")
	print("[Test] get_saved_clue_ids() = ", ids, " (期望 [wrist, arm, pose])")
	fw.queue_free()

	# 4. 测试 ClueObserver.mark_recorded
	var obs = ClueObserver.new()
	obs.name = "test_obs"
	obs.setup(null, null, null, [
		{"id":"wrist","label":"手腕","x":0,"y":0,"w":100,"h":40,"desc":""},
		{"id":"arm","label":"手臂","x":0,"y":0,"w":100,"h":40,"desc":""},
		{"id":"face","label":"面色","x":0,"y":0,"w":100,"h":40,"desc":""},
		{"id":"pose","label":"站姿","x":0,"y":0,"w":100,"h":40,"desc":""},
	], null)
	# 模拟恢复：3条已收
	for cid in ["wrist","arm","pose"]:
		obs.mark_recorded(cid)
	print("[Test] mark_recorded x3 → recorded=", obs.get_recorded(), " (期望 3)")
	print("[Test] _recorded_ids=", obs._recorded_ids, " (期望含 wrist, arm, pose)")
	obs.queue_free()

	# 5. 测试 do_save 数据格式
	GameManager.scene_state = {}
	var test_data := {"clue_ids": ["wrist", "arm", "pose"]}
	var phase := 2
	GameManager.do_save(phase, test_data)
	var ss = GameManager.scene_state
	print("[Test] do_save 后 scene_state = ", ss)
	print("[Test] ss.phase = ", ss.get("phase", -1), " (期望 2)")
	print("[Test] ss.scene_id = ", ss.get("scene_id", ""), " (期望 scene1)")

	# 6. 测试 do_load 恢复（是 coroutine，需要 await）
	await GameManager.do_load()
	print("[Test] do_load 返回 = ", GameManager.scene_state)

	print("=== 验证完成 ===")
	quit(0)
