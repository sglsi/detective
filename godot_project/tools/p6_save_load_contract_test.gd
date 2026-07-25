extends SceneTree

# P6 通用存/读档契约测试（--script 模式）
# 验证「存档/读档与场景解耦」的通用层：
#   - ClueSystem.collected_clues 作为单一真相源，随存档通用持久化
#   - SaveSystem.request_save / take_save_state 提供场景无关的快照存取
#   - SaveSystem.new_game 清空运行时进度
#
# 用法（godot_project 目录下，需本机 Godot）：
#   godot --headless --script res://tools/p6_save_load_contract_test.gd
# 成功哨兵：SAVE_SYSTEM_CONTRACT_OK

var started := false
var failures: Array = []

func _process(_delta: float) -> bool:
	if started:
		return false
	started = true
	await run_test()
	return false

func run_test() -> void:
	var ss = root.get_node_or_null("/root/SaveSystem")
	var cs = root.get_node_or_null("/root/ClueSystem")
	var gm = root.get_node_or_null("/root/GameManager")
	var sm = root.get_node_or_null("/root/SaveManager")

	if ss == null or cs == null or gm == null or sm == null:
		print("SAVE_SYSTEM_CONTRACT_FAIL: 缺少单例 SaveSystem/ClueSystem/GameManager/SaveManager")
		quit()
		return

	_clean_old_save()
	cs.clear_collected()
	gm.scene_state.clear()

	# 1. 收集线索（模拟场景1 华生 + 信使 两轮，以及场景2 花园）
	cs.collect_clue("wrist", "手腕肤色", "长期日晒", true, "watson")
	cs.collect_clue("arm", "左臂旧伤", "枪伤疤痕", true, "watson")
	cs.collect_clue("tattoo", "锚形文身", "海军标志", true, "messenger")
	cs.collect_clue("c201", "碾轧花草", "马车停靠痕迹", true, "garden")
	if cs.count_collected() != 4:
		failures.append("collect_clue 计数错误: %d" % cs.count_collected())
	if cs.count_collected("watson") != 2:
		failures.append("按 source 过滤(watson)错误: %d" % cs.count_collected("watson"))

	# 2. 通用保存（场景只提供 scene_id + phase + data，不碰内部状态）
	await ss.request_save("scene1", 4, {"clue_ids": cs.get_collected_ids()})
	if gm.current_scene_id != "scene1":
		failures.append("request_save 未设置 scene_id: %s" % gm.current_scene_id)

	# 3. 清空内存态（模拟进程重启）
	cs.clear_collected()
	gm.scene_state.clear()
	if cs.count_collected() != 0 or not gm.scene_state.is_empty():
		failures.append("清空内存态失败（仍有残留）")

	# 4. 读档（SaveManager 恢复 collected_clues + scene_state）
	var loaded: bool = await sm.load_game()
	if not loaded:
		failures.append("load_game 失败")

	# 5. 断言：ClueSystem 已恢复（单一真相源，推理墙据此展示）
	if cs.count_collected() != 4:
		failures.append("collected_clues 未恢复，数量=%d" % cs.count_collected())
	elif cs.count_collected("watson") != 2:
		failures.append("恢复后 watson 数量=%d" % cs.count_collected("watson"))
	elif not cs.has_collected("tattoo", "messenger"):
		failures.append("恢复后 messenger 线索缺失")

	# 6. 断言：SaveSystem 场景无关快照存取
	var st1 = ss.take_save_state("scene1")
	if st1.is_empty():
		failures.append("take_save_state(scene1) 应返回非空快照")
	elif int(st1.get("phase", -1)) != 4:
		failures.append("take_save_state phase 错误: %s" % st1.get("phase"))
	var st2 = ss.take_save_state("scene2")
	if not st2.is_empty():
		failures.append("take_save_state(scene2) 应返回空（非本场景存档）")

	# 7. 新游戏清空
	ss.new_game()
	if cs.count_collected() != 0 or not gm.scene_state.is_empty():
		failures.append("new_game 未清空 collected_clues / scene_state")

	if failures.is_empty():
		print("SAVE_SYSTEM_CONTRACT_OK — 通用存/读档层契约通过（collected_clues 单一真相源 + SaveSystem 场景无关）")
	else:
		print("SAVE_SYSTEM_CONTRACT_FAIL: " + str(failures))
	quit()

func _clean_old_save() -> void:
	var dir := DirAccess.open("user://")
	if dir != null and dir.file_exists("save_game.json"):
		dir.remove("save_game.json")
