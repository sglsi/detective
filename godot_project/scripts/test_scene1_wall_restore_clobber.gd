extends Control
## 精确复现思傅报告的场景一推理墙存档 bug（2026-09-09）：
##   (a) 读档后进入墙正确；退出再进 → 初始页
##   (b) 读档后操作、再存档、再读档 → 初始页
## 根因：scene1._ready() 在 super._ready()（内含 _restore_saved_state，已恢复 _watson_wall_state
##   并据 WATSON_REASONING 阶段自动开墙）之后，又把 _watson_wall_state = {} 覆盖掉。
##   结果：已经打开的墙抓住旧引用（首次显示正确），但变量指向空字典——
##   之后退出再开墙用空字典 → 初始页；之后存档把空字典写进 save → 再读档也初始页。
##
## 本测试实例化【真实 scene1.tscn】，注入「已含关系」的存档（phase=WATSON_REASONING），验证：
##   (1) 读档自动开墙能展示恢复的关系（load→correct）；
##   (2) 退出墙（persist 写回）→ 再次开墙仍展示关系（reopen→correct，修复前会丢失→初始页）。
##
## 运行（沙箱外）：
##   godot --headless --path . "res://scenes/test_scene1_wall_restore_clobber.tscn"
## 退出码 0=PASS，1=FAIL。

var _ok := false

func _ready() -> void:
	await get_tree().process_frame

	# 1) 注入一份「已含关系」的存档状态（模拟读档）。
	#    phase=3 (WATSON_REASONING) 触发读档自动开墙；clue_ids 只给 3 条 watson 线索，
	#    使观察者 recorded=3 < needs(6)，退出墙时 _resume_observe 走「回观察」分支（不自动重开），
	#    从而我们可以在测试里手动再开墙来精确复现「退出→再进」这一用户报告路径。
	var restored_wall := {
		"relations": [{"from":"wrist","to":"W-A1","kind":"support","color_key":"green","dashed":false}],
		"graph_nodes": [{"id":"W-A1","x":120.0,"y":120.0}],
		"graph_derived_conclusions": [],
		"graph_placed_clues": ["wrist"],
		"verified": false,
		"verdict": -1
	}
	if GameManager == null:
		printerr("FATAL: GameManager 未就绪"); get_tree().quit(2); return
	GameManager.scene_state = {
		"scene_id": "scene1",
		"phase": 3,
		"clue_ids": ["wrist","arm","face_dark"],
		"wall_state_watson": restored_wall,
		"wall_state_messenger": {},
		"watson_recorded": 3,
		"messenger_recorded": 0
	}

	# 2) 实例化真实 scene1（触发 scene1._ready → super._ready → _restore_saved_state）
	var s1 = load("res://scenes/scene1.tscn").instantiate()
	add_child(s1)
	await get_tree().process_frame
	await get_tree().process_frame   # 给墙构建留两帧

	# (1) 读档自动开墙应展示关系（load→correct）
	var wall = s1.get("_wall_instance")
	if wall == null:
		printerr("RESULT: FAIL 读档未自动打开墙（无法验证）"); get_tree().quit(1); return
	var rels1 = wall.get("_relations")
	print("[LOAD_OPEN] relations=", rels1.size())
	if rels1.size() < 1:
		printerr("RESULT: FAIL 读档开墙未恢复关系(relations=0)")
		get_tree().quit(1); return

	# (2) 退出墙（persist 写回 _state_store；观察者未满 → _resume_observe 回观察、墙关闭）
	s1._wall_instance._on_back_pressed()
	await get_tree().process_frame
	await get_tree().process_frame
	var ws_after_close = s1.get("_watson_wall_state")
	print("[AFTER_CLOSE] _watson_wall_state.is_empty()=", ws_after_close.is_empty(),
		" relations=", ws_after_close.get("relations", []).size())

	# 等墙彻底释放
	var guard := 0
	while s1.get("_wall_instance") != null and guard < 30:
		await get_tree().process_frame
		guard += 1

	# (3) 退出后再开墙（reopen bug 路径）：以当前 _watson_wall_state 重新开墙
	s1._show_watson_reasoning_wall()
	await get_tree().process_frame
	await get_tree().process_frame
	var wall2 = s1.get("_wall_instance")
	if wall2 == null:
		printerr("RESULT: FAIL reopen 未打开墙"); get_tree().quit(1); return
	var rels2 = wall2.get("_relations")
	print("[REOPEN] relations=", rels2.size())
	if rels2.size() >= 1:
		_ok = true
		print("RESULT: PASS 读档开墙+退出再开墙，关系均保留（初始页 bug 已修复）")
	else:
		printerr("RESULT: FAIL reopen 后关系丢失（进入初始页）ws=", ws_after_close)
		_ok = false
	get_tree().quit(0 if _ok else 1)
