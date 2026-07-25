extends Control
## 自动验证存/读档链路（无需人工干预）
## 用法：Godot 编辑器 F5 启动本场景，自动跑完打印结果

func _ready() -> void:
	print("========== 存/读档自动验证 ==========")
	await get_tree().process_frame

	# 1. 检查 autoloads
	print("[Check] GameManager=", GameManager)
	print("[Check] SaveManager=", SaveManager)

	# 2. 模拟保存
	GameManager.current_case_id = "case_blood_letter"
	GameManager.current_scene_id = "scene1"
	var save_data := {"clue_ids": ["wrist", "arm", "pose"], "watson_recorded": 3}
	GameManager.scene_state = save_data.duplicate()
	GameManager.scene_state["phase"] = 2
	GameManager.scene_state["scene_id"] = "scene1"
	print("[Save] scene_state 写入 = ", GameManager.scene_state)

	# 3. 测试 get_saved_phase / get_saved_clue_ids
	var fw = SceneFramework.new()
	fw.name = "test_fw"; add_child(fw)
	var phase = fw.get_saved_phase("scene1")
	var ids = fw.get_saved_clue_ids()
	print("[Test] get_saved_phase('scene1') = ", phase, " (期望 2)")
	print("[Test] get_saved_clue_ids() = ", ids, " (期望 3 个 ID)")

	# 4. 测试 ClueObserver.mark_recorded
	var obs = ClueObserver.new()
	obs.name = "test_obs"
	obs.setup(self, null, null, [
		{"id":"wrist","label":"手腕","x":0,"y":0,"w":100,"h":40,"desc":""},
		{"id":"arm","label":"手臂","x":0,"y":0,"w":100,"h":40,"desc":""},
		{"id":"face","label":"面色","x":0,"y":0,"w":100,"h":40,"desc":""},
		{"id":"pose","label":"站姿","x":0,"y":0,"w":100,"h":40,"desc":""},
	], null)
	# 模拟恢复 3 条已收线索
	for cid in ["wrist","arm","pose"]:
		obs.mark_recorded(cid)
	print("[Test] mark_recorded x3 → recorded=", obs.get_recorded(), " (期望 3)")
	print("[Test] _recorded_ids=", obs._recorded_ids)
	print("[Test] _recorded=", obs._recorded, " (期望 3)")

	# 5. 测试 restore_observer
	fw.restore_observer(obs, ["wrist","arm","pose"], ["wrist","arm","face","pose"])
	print("[Test] restore_observer 后 recorded=", obs.get_recorded())

	# 6. 测试收集最后一个 → all_recorded 触发
	obs._recorded = 4
	obs._on_record("face", "面色黝黑")
	print("[Test] 全收后 recorded=", obs.get_recorded(), " 应触发 all_recorded")

	print("========== 验证完成 ==========")
	fw.queue_free(); obs.queue_free()
	await get_tree().create_timer(1.0).timeout
	get_tree().quit(0)
