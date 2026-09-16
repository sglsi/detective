extends Control
## 验证思傅报告的「读档后场景一评价体系显示内容不正确」：
##   根因：墙验证三维星（=推理链信息）_watson_stars/_messenger_stars 仅在 COMPLETE 存档写入，
##   而「验证后推进一两步再存档」的 MESSENGER_REASONING 存盘点不写它们 →
##   读档重放裁定 → _calc_stars 读默认空字典 → 三星全错。
##   修复：墙验证回调把 stars/verdict 写进 _watson_wall_state/_messenger_wall_state，
##   该 dict 随 wall_state_watson/messenger 在 *每个* 存盘点持久化，读档分支再恢复。
##
## 本测试实例化真实 scene1.tscn，注入一份 MESSENGER_REASONING 存档
## （wall_state_watson/messenger 含 stars），断言读档后 _watson_stars/_messenger_stars 被恢复，
## 且 _calc_stars() 聚合出正确三星。
##
## 运行：godot --headless --path . "res://scenes/test_scene1_rating_restore.tscn"
## 退出码 0=PASS，1=FAIL。基线（无本修复）下 _watson_stars/_messenger_stars 仍为 {} → FAIL。

var _failures: Array[String] = []

func _assert(cond: bool, msg: String) -> void:
	if cond:
		print("[OK]   " + msg)
	else:
		printerr("[FAIL] " + msg)
		_failures.append(msg)

func _safe_get(d: Dictionary, key: String, default = null):
	# 兼容 dict[key] 缺省值（Godot4 dict 无默认参数），手写安全取值
	if d.has(key):
		return d[key]
	return default

func _ready() -> void:
	await get_tree().process_frame

	if GameManager == null:
		printerr("FATAL: GameManager 未就绪"); get_tree().quit(2); return

	# 注入「验证后推进一两步」的存档：MESSENGER_REASONING(5)，双墙均已验证且含三维星。
	var stars_full := {"observation": 3, "reasoning": 3, "insight": 3}
	var ws := {"verified": true, "verdict": 3, "stars": stars_full.duplicate(true)}
	var ms := {"verified": true, "verdict": 3, "stars": stars_full.duplicate(true)}
	GameManager.scene_state = {
		"scene_id": "scene1",
		"phase": 5,                       # Phase.MESSENGER_REASONING
		"clue_ids": ["wrist","arm","tattoo","beard"],
		"wall_state_watson": ws,
		"wall_state_messenger": ms,
		"watson_recorded": 2,
		"messenger_recorded": 2
	}

	# 实例化真实 scene1（触发 super._ready → _restore_saved_state → MESSENGER_REASONING 分支）
	var s1 = load("res://scenes/scene1.tscn").instantiate()
	add_child(s1)
	await get_tree().process_frame
	await get_tree().process_frame

	# (1) 读档分支须把墙_state 里的 stars 恢复到 _watson_stars/_messenger_stars
	var wstars: Dictionary = s1.get("_watson_stars")
	var mstars: Dictionary = s1.get("_messenger_stars")
	print("[RESTORE] _watson_stars=", wstars, " _messenger_stars=", mstars)
	_assert(int(_safe_get(wstars, "observation", 0)) == 3, "读档恢复：华生墙三星 observation 恢复为 3")
	_assert(int(_safe_get(wstars, "reasoning", 0)) == 3, "读档恢复：华生墙三星 reasoning 恢复为 3")
	_assert(int(_safe_get(wstars, "insight", 0)) == 3, "读档恢复：华生墙三星 insight 恢复为 3")
	_assert(int(_safe_get(mstars, "observation", 0)) == 3, "读档恢复：信使墙三星 observation 恢复为 3")
	_assert(int(_safe_get(mstars, "reasoning", 0)) == 3, "读档恢复：信使墙三星 reasoning 恢复为 3")
	_assert(int(_safe_get(mstars, "insight", 0)) == 3, "读档恢复：信使墙三星 insight 恢复为 3")

	# (2) 重放裁定对话结束 → _on_messenger_verdict_end → _calc_stars 须聚合出正确三星
	s1._calc_stars()
	print("[CALC] _stars_observe=", s1.get("_stars_observe"),
		" _stars_reason=", s1.get("_stars_reason"),
		" _stars_insight=", s1.get("_stars_insight"))
	_assert(int(s1.get("_stars_observe")) == 3, "聚合：观察之星 = 3（两墙均值）")
	_assert(int(s1.get("_stars_reason")) == 3, "聚合：推理之星 = 3（两墙均值）")
	_assert(int(s1.get("_stars_insight")) == 3, "聚合：洞察之星 = 3（两墙均值）")

	if _failures.is_empty():
		print("RESULT: PASS 读档后场景一评级三星正确（推理链信息已提供给评价体系）")
		get_tree().quit(0)
	else:
		printerr("RESULT: FAIL 读档后评级三星丢失，共 %d 项" % _failures.size())
		get_tree().quit(1)
