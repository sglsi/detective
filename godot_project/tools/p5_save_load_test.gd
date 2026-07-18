extends SceneTree

# P5-1 端到端存读档测试（--script 模式）
# --script 模式不会自动加载 project.godot 中的 autoload，
# 因此本脚本手动实例化并用 Engine.register_singleton 注册所需单例，
# 之后即可像正常运行那样通过全局名访问它们，验证 SaveManager 的收集/恢复。
#
# 四类被验证的状态：
#   - ClueSystem 线索状态
#   - GameManager 里程碑
#   - MapManager 解锁地点
#   - DialogueProgress 对话进度
# 流程：注入状态 → save_game() → 清空内存态 → load_game() → 断言恢复一致
#
# 用法（godot_project 目录下）：
#   godot --headless --script res://tools/p5_save_load_test.gd
# 成功哨兵：SAVE_LOAD_E2E_OK

# 与 ClueSystem.ClueState.DISCOVERED 对齐（UNDISCOVERED=0, DISCOVERED=1, ...）
const DISCOVERED := 1
const SEED_CLUES := ["clue_a", "clue_b", "clue_c"]

var started := false
var failures: Array[String] = []


func _process(_delta: float) -> bool:
	if started:
		return false
	started = true
	await run_test()
	return false


# ---------- 测试主流程 ----------

func run_test() -> void:
	# --script 模式下 Godot 会自动加载 project.godot 中的 autoload 作为全局单例，
	# 通过 Engine.get_singleton 取到的是与 SaveManager 内部引用相同的实例。
	var gm = root.get_node_or_null("/root/GameManager")
	var cs = root.get_node_or_null("/root/ClueSystem")
	var mm = root.get_node_or_null("/root/MapManager")
	var dp = root.get_node_or_null("/root/DialogueProgress")
	var sm = root.get_node_or_null("/root/SaveManager")

	_clean_old_save()

	# 1. 注入状态
	gm.is_guest = true
	gm.current_case_id = "case_blood"
	gm.current_scene_id = "scene_02"

	var seed_states := {}
	for cid in SEED_CLUES:
		seed_states[cid] = DISCOVERED
	cs.restore_clue_states(seed_states)

	gm.add_milestone("m1")
	gm.add_milestone("m2")
	gm.add_milestone("m2")  # 重复，验证去重

	mm.unlock_location("loc_a")
	mm.unlock_location("loc_b")

	dp.record_node("scene_02", "node_1")
	dp.record_node("scene_02", "node_2")

	print("▶ 注入状态完成：clues=%d milestones=%d locs=%d dlg_scenes=%d"
		% [cs.discovered_clues.size(), gm.completed_milestones.size(),
		   mm.unlocked_locations.size(), dp.get_dialogue_progress().size()])

	# 2. 保存
	var save_res = await sm.save_game()
	if save_res.get("error", true):
		failures.append("save_game 返回错误: " + str(save_res))
	else:
		print("▶ save_game 完成: " + str(save_res))

	# 3. 清空内存态
	cs.discovered_clues.clear()
	cs.clue_count = 0
	gm.restore_milestones([])
	mm.restore_unlocked_locations([])
	dp.restore_dialogue_progress({})
	gm.current_case_id = ""

	if cs.discovered_clues.size() != 0 or gm.completed_milestones.size() != 0 \
			or mm.unlocked_locations.size() != 0 \
			or dp.get_dialogue_progress().size() != 0 or gm.current_case_id != "":
		failures.append("清空内存态失败，仍残留数据")
	else:
		print("▶ 内存态已清空，准备读档")

	# 4. 读档
	var loaded: bool = await sm.load_game()
	if not loaded:
		failures.append("load_game 返回 false（读档失败）")
	else:
		print("▶ load_game 完成")

	# 5. 断言恢复一致
	if gm.current_case_id != "case_blood":
		failures.append("case_id 未恢复 (得到 '%s')" % gm.current_case_id)

	if cs.discovered_clues.size() != SEED_CLUES.size():
		failures.append("线索数量未恢复 (得到 %d, 期望 %d)"
			% [cs.discovered_clues.size(), SEED_CLUES.size()])
	else:
		for cid in SEED_CLUES:
			if not cs.discovered_clues.has(cid):
				failures.append("线索缺失: " + cid)
			elif cs.discovered_clues[cid].state != DISCOVERED:
				failures.append("线索状态未恢复: " + cid)

	if gm.completed_milestones.size() != 2:
		failures.append("里程碑数量未恢复 (得到 %d, 期望 2)"
			% gm.completed_milestones.size())
	elif not (gm.completed_milestones.has("m1") and gm.completed_milestones.has("m2")):
		failures.append("里程碑内容未恢复: " + str(gm.completed_milestones))

	if mm.unlocked_locations.size() != 2:
		failures.append("解锁地点数量未恢复 (得到 %d, 期望 2)"
			% mm.unlocked_locations.size())
	elif not (mm.is_location_unlocked("loc_a") and mm.is_location_unlocked("loc_b")):
		failures.append("解锁地点内容未恢复: " + str(mm.unlocked_locations))

	var dlg = dp.get_dialogue_progress()
	if not dlg.has("scene_02") or dlg["scene_02"].size() != 2:
		failures.append("对话进度未恢复: " + str(dlg))
	elif not (dlg["scene_02"].has("node_1") and dlg["scene_02"].has("node_2")):
		failures.append("对话进度节点未恢复: " + str(dlg))

	# 6. 汇总
	if failures.is_empty():
		print("SAVE_LOAD_E2E_OK — 存读档四类状态收集/恢复一致")
	else:
		print("SAVE_LOAD_E2E_FAIL: " + str(failures))
	quit()


func _clean_old_save() -> void:
	var dir := DirAccess.open("user://")
	if dir != null and dir.file_exists("save_game.json"):
		dir.remove("save_game.json")
