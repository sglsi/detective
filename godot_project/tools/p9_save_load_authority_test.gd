extends SceneTree

# P9 回归测试：「存档成功、读档失败」根因修复
# 验证本地缓存成为权威来源后，注册用户 save -> 清内存 -> load 闭环成立
# 对应 bug：注册用户在线时存档只写云端、读档只从云端读，云端返回空则读档失败。
#
# 用法（godot_project 目录下）：
#   godot --headless --script res://tools/p9_save_load_authority_test.gd
# 成功哨兵：SAVE_LOAD_AUTHORITY_OK

var started := false

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
		print("P9_SETUP_FAIL"); quit(); return

	# 模拟注册用户（正是触发 bug 的身份）
	gm.is_guest = false
	gm.current_case_id = "case_blood_letter"
	gm.current_scene_id = "scene1"

	# 1) 收集线索并存档（走完整 request_save 链路，写入本地缓存）
	cs.collect_clue("wrist", "手腕肤色分界", "长期日晒", true, "watson")
	cs.collect_clue("arm", "左臂旧伤", "枪伤疤痕", true, "watson")
	cs.collect_clue("face", "面色憔悴", "久病初愈", true, "watson")
	cs.collect_clue("pose", "军人站姿", "军事训练", true, "watson")
	await ss.request_save("scene1", 4, {"clue_ids": cs.get_collected_ids(), "watson_recorded": 4, "messenger_recorded": 0})

	# 2) 清空内存态，模拟「关闭后重开」
	gm.scene_state.clear()
	cs.clear_collected()

	# 3) 读档（注册用户路径：本地缓存权威）
	var ok = await sm.load_game()
	var phase = gm.scene_state.get("phase", -1)
	var scene_id = gm.scene_state.get("scene_id", "")
	var ids: Array = gm.scene_state.get("clue_ids", [])
	var cc = cs.count_collected()

	print("[p9] ok=", ok, " phase=", phase, " scene_id=", scene_id, " ids.size=", ids.size(), " collected=", cc)

	if ok and phase == 4 and scene_id == "scene1" and ids.size() == 4 and cc == 4:
		print("SAVE_LOAD_AUTHORITY_OK")
	else:
		print("SAVE_LOAD_AUTHORITY_FAIL ok=", ok, " phase=", phase, " scene_id=", scene_id, " ids=", ids.size(), " cc=", cc)
	quit()
