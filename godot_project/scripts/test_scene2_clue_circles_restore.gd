extends Control
## 回归测试：思傅 2026-09-16 报 bug —— 场景二「推理链设计 → 存档 → 读档 → 退出推理墙」后，
## 线索收集提示圆圈（hl_ 高亮圈）重新出现、且可二次点击收集。
##
## 复现前提：简单模式（auto_reveal 会在 _create_observers 即 show 街道观察器、画出全部圆圈）。
## 验证点：
##   (1) 读档后(REASONING)：两套观察器均标记「已收集」、均处于非激活（隐藏/不可点）态、
##       世界层无任何 hl_ 提示圆圈；
##   (2) 关闭自动打开的推理墙（模拟用户「退出推理墙」）后，上述依旧成立。
##
## 运行：godot --headless --path . "res://scenes/test_scene2_clue_circles_restore.tscn"
## 退出码 0=PASS，1=FAIL。

var _failures: Array = []

func _assert(cond: bool, msg: String) -> void:
	if cond:
		print("[OK]   " + msg)
	else:
		printerr("[FAIL] " + msg)
		_failures.append(msg)

func _ready() -> void:
	await get_tree().process_frame
	if SaveManager == null or ClueSystem == null or GameManager == null or DifficultyManager == null:
		printerr("FATAL: 必要 autoload 未就绪"); get_tree().quit(2); return

	# 简单模式：触发 auto_reveal（_create_observers 即 show 街道观察器、画圆圈）——复现 bug 前提
	DifficultyManager.current_difficulty = DifficultyManager.Difficulty.EASY

	var all_ids := ["c201","c202","c203","c204","c205","c206"]

	GameManager.current_scene_id = "scene2"
	GameManager.current_case_id = "case1"
	GameManager.scene_state = {
		"scene_id": "scene2",
		"phase": 3,            # scene2 Phase.REASONING
		"clue_ids": all_ids,
		"slot": 0
	}
	# 走一次真实存档往返，确保 scene_state 被 SaveManager 正常打包/还原
	await SaveManager.save_to_slot(0)
	GameManager.scene_state = {}
	var ok := await SaveManager.load_slot(0)
	_assert(ok == true, "存档往返成功")

	var s2 = load("res://scenes/scene2.tscn").instantiate()
	add_child(s2)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	_verify_no_circles(s2, "读档后(REASONING)")

	# 模拟用户「退出推理墙」：关闭自动打开的墙
	var wall = s2.get("_wall_instance")
	_assert(wall != null, "REASONING 读档自动打开推理墙")
	if wall != null:
		wall.close_wall()
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		_verify_no_circles(s2, "退出推理墙后")

	if _failures.is_empty():
		print("RESULT: PASS 场景二读档后线索收集圆圈不再残留/可二次收集")
		get_tree().quit(0)
	else:
		printerr("RESULT: FAIL 共 %d 项失败" % _failures.size())
		get_tree().quit(1)

func _verify_no_circles(s2: Node, label: String) -> void:
	var street: Node = s2.get("_street_obs")
	var path: Node = s2.get("_path_obs")
	_assert(street != null and path != null, "%s: 两套观察器已创建" % label)
	if street == null or path == null:
		return
	# 两套观察器都应标记全部已收集
	_assert(street.get_recorded() >= 4, "%s: 街道观察器记录 4 条线索（实得 %d）" % [label, street.get_recorded()])
	_assert(path.get_recorded() >= 2, "%s: 通道观察器记录 2 条线索（实得 %d）" % [label, path.get_recorded()])
	# 都不应处于激活（可见/可点）态
	_assert(street.is_active() == false, "%s: 街道观察器未激活（不可再点）" % label)
	_assert(path.is_active() == false, "%s: 通道观察器未激活（不可再点）" % label)
	# 世界层不应有任何 hl_ 提示圆圈
	var ui: Node = s2.get("_ui")
	var world: Node = ui.get_world_layer() if (ui != null and ui.has_method("get_world_layer")) else null
	_assert(world != null, "%s: 取得世界层" % label)
	if world != null:
		var circles := 0
		for c in world.get_children():
			if String(c.name).begins_with("hl_"):
				circles += 1
		_assert(circles == 0, "%s: 世界层无线索提示圆圈（实得 %d）" % [label, circles])
