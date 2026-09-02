extends SceneTree

## 验证 StarRatingSystem 的 case_branch_log 缓存回环（裁定4）：
## 推理墙提交验证写入明细 → 场景八 _show_scene_rating 读出来放结论。
func _initialize() -> void:
	print("===== 推理链报告缓存回环测试 =====")
	var srs = load("res://autoload/star_rating_system.gd").new()
	var ok := true

	# 模拟两条场景墙提交验证后写入的明细
	var scene2_detail := {
		"ratio": 0.875, "stars": 3, "summary": "推理链完整闭合", "hard_fail": false,
		"per_branch": [
			{"id":"CH02","name":"马车印迹","core":true,"active":true,"ratio":1.0,"stars":3,"hard_fail":false},
			{"id":"CH03","name":"凶手特征（多场景综合）","core":true,"active":true,"ratio":1.0,"stars":3,"hard_fail":false},
		],
	}
	var scene3_detail := {
		"ratio": 0.45, "stars": 2, "summary": "方向正确，尚有缺口", "hard_fail": false,
		"per_branch": [
			{"id":"CH04","name":"服毒判定","core":true,"active":true,"ratio":1.0,"stars":3,"hard_fail":false},
			{"id":"CH05","name":"RACHE 血字","core":true,"active":true,"ratio":0.5,"stars":2,"hard_fail":false},
		],
	}
	srs.record_branch_progress("scene2", scene2_detail)
	srs.record_branch_progress("scene3", scene3_detail)

	var log: Dictionary = srs.get_case_branch_log()
	_ok("缓存含 scene2", log.has("scene2"), str(log.keys()))
	_ok("缓存含 scene3", log.has("scene3"), str(log.keys()))

	# 场景八遍历 per_branch 放结论（复刻 _show_scene_rating 的读取逻辑）
	var total := 0
	var lines := []
	for sid in log.keys():
		for bp in log[sid].get("per_branch", []):
			total += 1
			lines.append("%s %d%%" % [str(bp.get("name","")), int(round(float(bp.get("ratio",0.0))*100.0))])
	_ok("场景八能列出每条链结论", total == 4, str(lines))

	# 练习墙不应写入（调用方判断，这里验证空值被忽略）
	srs.record_branch_progress("", {})
	srs.record_branch_progress("sceneX", {})
	_ok("空值/空 scene_id 被忽略", srs.get_case_branch_log().size() == 2, str(srs.get_case_branch_log().size()))

	# reset 清空
	srs.reset()
	_ok("reset 清空缓存", srs.get_case_branch_log().is_empty(), "size=%d" % srs.get_case_branch_log().size())

	if ok:
		print("===== 全部通过 ✅ =====")
	else:
		print("===== 存在失败 ❌ =====")
	quit()

func _ok(label: String, cond: bool, extra: String) -> void:
	if cond:
		print("  ✅ %s  (%s)" % [label, extra])
	else:
		print("  ❌ %s  (%s)" % [label, extra])
		quit(1)
