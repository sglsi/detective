extends SceneTree
## 难度管理器单测（对齐 B-11.2 / 03-6.4 模式差异表）
## 运行：godot --headless --script res://tools/test_difficulty.gd --path <godot_project>

func _initialize() -> void:
	await create_timer(0.05).timeout
	_run()
	quit()

func _run() -> void:
	var DScript = load("res://autoload/difficulty_manager.gd")
	var d = DScript.new()
	var ok := true
	var msg := ""

	# EASY
	d.set_difficulty(DScript.Difficulty.EASY)
	if d.get_difficulty_name() != "简单": ok = false; msg = "EASY 名称错误"
	elif not d.should_show_hint(): ok = false; msg = "EASY 应显示提示"
	elif d.auto_fill_notebook != true: ok = false; msg = "EASY 应自动填笔记"
	elif d.hardcore_manual != false: ok = false; msg = "EASY 不应 hardcore"
	elif d.hotspot_hint_level != 2: ok = false; msg = "EASY 热点提示级别应为 2"
	elif d.mislead_chance != 0.0: ok = false; msg = "EASY 误导概率应为 0"
	elif d.wall_assistance != "full": ok = false; msg = "EASY 推理墙辅助应为 full"
	elif d.branch_guidance != "full": ok = false; msg = "EASY 分支引导应为 full"
	elif d.time_strictness != "none": ok = false; msg = "EASY 时间严格度应为 none"
	elif d.get_score_multiplier() != 0.5: ok = false; msg = "EASY 分数倍率应为 0.5"
	elif d.get_help_max_attempts() != 3: ok = false; msg = "求助次数上限应为 3"

	# NORMAL
	if ok:
		d.set_difficulty(DScript.Difficulty.NORMAL)
		if d.get_difficulty_name() != "普通": ok = false; msg = "NORMAL 名称错误"
		elif d.hint_current_probability != 0.7: ok = false; msg = "NORMAL 基础提示概率应为 0.7"
		elif d.dynamic_hint_chance != true: ok = false; msg = "NORMAL 应开启动态概率"
		elif d.hotspot_hint_level != 1: ok = false; msg = "NORMAL 热点提示级别应为 1"
		elif d.mislead_chance != 0.3: ok = false; msg = "NORMAL 误导概率应为 0.3"
		elif d.wall_assistance != "standard": ok = false; msg = "NORMAL 推理墙辅助应为 standard"
		elif d.branch_guidance != "partial": ok = false; msg = "NORMAL 分支引导应为 partial"
		elif d.get_score_multiplier() != 1.0: ok = false; msg = "NORMAL 分数倍率应为 1.0"

	# HARD
	if ok:
		d.set_difficulty(DScript.Difficulty.HARD)
		if d.get_difficulty_name() != "困难": ok = false; msg = "HARD 名称错误"
		elif d.should_show_hint(): ok = false; msg = "HARD 不应显示提示"
		elif d.hardcore_manual != true: ok = false; msg = "HARD 应为 hardcore"
		elif d.hotspot_hint_level != 0: ok = false; msg = "HARD 热点提示级别应为 0"
		elif d.mislead_chance != 0.7: ok = false; msg = "HARD 误导概率应为 0.7"
		elif d.wall_assistance != "minimal": ok = false; msg = "HARD 推理墙辅助应为 minimal"
		elif d.branch_guidance != "none": ok = false; msg = "HARD 分支引导应为 none"
		elif d.get_score_multiplier() != 1.5: ok = false; msg = "HARD 分数倍率应为 1.5"
		elif d.get_difficulty_description() == "": ok = false; msg = "HARD 描述不应为空"

	# 误导过滤：简单模式剔除 is_correct=false / misleading=true，普通/困难按概率保留
	if ok:
		d.set_difficulty(DScript.Difficulty.EASY)
		var hotspots := [
			{"id":"hs1","is_correct":true},
			{"id":"hs2","is_correct":false},
			{"id":"hs3","misleading":true},
		]
		var filtered: Array = d.filter_hotspots_by_difficulty(hotspots)
		if filtered.size() != 1 or filtered[0].get("id") != "hs1":
			ok = false; msg = "EASY 应剔除所有误导线索"

	if ok:
		print("P1_RESULT: PASS — 难度管理器三模式差异配置正确")
	else:
		print("P1_RESULT: FAIL — " + msg)
