extends SceneTree

# P8 复现「继续游戏中不存档直接读档」回归测试（--script 模式）
# 精准对应 bug：
#   旧实现 _do_load() 只是 change_scene 回主菜单，主菜单继续依赖 load_game() 重读；
#   而场景 _ready 用 take_save_state(consume=true) 把内存 scene_state 清空后，
#   若重读失败（游客无本地档 / 登录态网络不稳）就落新游戏。
# 修复后 _do_load() = SaveManager.load_game()（每次从磁盘/云端重读）+ reload_current_scene()。
#
# 本测试在通用层验证修复前提：
#   继续(load1) → 场景消费 scene_state(consume) → 不存档再次 load2 → 必须仍能从磁盘恢复。
#
# 用法（godot_project 目录下）：
#   godot --headless --script res://tools/p8_reload_without_save_test.gd
# 成功哨兵：RELOAD_WITHOUT_SAVE_OK

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
		print("RELOAD_WITHOUT_SAVE_FAIL: 缺少单例")
		quit()
		return

	_clean_old_save()
	cs.clear_collected()
	gm.scene_state.clear()

	# 1. 先有一次有效存档（模拟用户之前保存过）
	cs.collect_clue("wrist", "手腕肤色", "长期日晒", true, "watson")
	cs.collect_clue("arm", "左臂旧伤", "枪伤疤痕", true, "watson")
	cs.collect_clue("tattoo", "锚形文身", "海军标志", true, "messenger")
	cs.collect_clue("c201", "碾轧花草", "马车停靠", true, "garden")
	await ss.request_save("scene1", 4, {"clue_ids": cs.get_collected_ids()})

	# 2. 模拟「继续游戏」：主菜单 load_game() 从磁盘恢复
	cs.clear_collected()
	gm.scene_state.clear()
	var ok1 = await sm.load_game()
	if not ok1:
		failures.append("继续(load1) 失败")
	# 3. 模拟场景 _ready 消费 scene_state（take_save_state 默认 consume=true 会清空内存态）
	var st1 = ss.take_save_state("scene1")
	if st1.is_empty():
		failures.append("继续后 take_save_state 为空")
	elif int(st1.get("phase", -1)) != 4:
		failures.append("继续后 phase 错误: %s" % st1.get("phase"))
	if cs.count_collected() != 4:
		failures.append("继续后 collected_clues 未恢复: %d" % cs.count_collected())
	# 关键点：此时内存 scene_state 已被 consume 清空
	if not gm.scene_state.is_empty():
		failures.append("consume 后 scene_state 应被清空（修复前提）")

	# 4. 模拟「继续游戏中，不存档直接读档」→ 修复后 _do_load 先 load_game() 再 reload
	#    验证：即使内存态已空，load_game() 仍能从磁盘重读并恢复
	var ok2 = await sm.load_game()
	if not ok2:
		failures.append("再次读档(load2) 失败 —— 这正是旧 bug：重读失败→落新游戏")
	# 5. 再次 take_save_state（对应 reload 后的 _restore_saved_state）
	var st2 = ss.take_save_state("scene1")
	if st2.is_empty():
		failures.append("再次读档后 take_save_state 为空 —— 会重新开始游戏")
	elif int(st2.get("phase", -1)) != 4:
		failures.append("再次读档后 phase 错误: %s" % st2.get("phase"))
	if cs.count_collected() != 4:
		failures.append("再次读档后 collected_clues 未恢复: %d" % cs.count_collected())

	# 6. 反向确认：若磁盘无存档，load_game 应返回 false（_do_load 据此提示「没有可用的存档」而非重开）
	_clean_old_save()
	cs.clear_collected()
	gm.scene_state.clear()
	var ok3 = await sm.load_game()
	if ok3:
		failures.append("无存档时 load_game 应返回 false（否则会误恢复）")

	if failures.is_empty():
		print("RELOAD_WITHOUT_SAVE_OK — 继续中「不存档直接读档」可正确从磁盘恢复；无存档时安全返回 false")
	else:
		print("RELOAD_WITHOUT_SAVE_FAIL: " + str(failures))
	quit()

func _clean_old_save() -> void:
	var dir := DirAccess.open("user://")
	if dir != null and dir.file_exists("save_game.json"):
		dir.remove("save_game.json")
