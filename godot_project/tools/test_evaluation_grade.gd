extends SceneTree
## v4.0 评价体系回归单测（替代旧「综合等级」）：
##   1) 结局档位（传奇≥90% / 杰出 70-89% / 合格 50-69% / 见习<50%）基于逐链总星占比
##   2) 难度不影响原始总星（get_total_stars 与难度无关；倍率仅作用于 get_adjusted_total_stars）
## 哨兵：P1_RESULT: PASS
## 运行：godot --headless --script res://tools/test_evaluation_grade.gd --path <godot_project>

var StarRatingSystem
var EndingSystem
var DifficultyManager

func _init() -> void:
	call_deferred("run_test")

## 设定单链三星组合并返回结局档位中文名（清空其它链，保证占比精确）
func _tier_name(obs: int, rea: int, ins: int) -> String:
	StarRatingSystem.chains = {}
	StarRatingSystem.submit_chain("t", obs, rea, ins)
	var tier = EndingSystem.determine_ending("")
	return EndingSystem.get_ending_info(tier).get("name", "")

func run_test() -> void:
	var ok := true
	var msg := ""
	StarRatingSystem = root.get_node_or_null("/root/StarRatingSystem")
	EndingSystem = root.get_node_or_null("/root/EndingSystem")
	DifficultyManager = root.get_node_or_null("/root/DifficultyManager")
	if not StarRatingSystem or not EndingSystem:
		print("P1_RESULT: FAIL (autoload 未加载)"); quit(); return

	# 传奇：单链满星 9⭐（占比 100%）
	if _tier_name(3, 3, 3) != "传奇":
		ok = false; msg = "满星应传奇"
	# 杰出：7⭐（3+2+2，占比 0.778）
	if _tier_name(3, 2, 2) != "杰出":
		ok = false; msg = "7星应杰出"
	# 合格：5⭐（2+2+1，占比 0.556）
	if _tier_name(2, 2, 1) != "合格":
		ok = false; msg = "5星应合格"
	# 见习：3⭐（1+1+1，占比 0.333）
	if _tier_name(1, 1, 1) != "见习":
		ok = false; msg = "3星应见习"

	# 难度不影响原始总星
	if DifficultyManager != null:
		StarRatingSystem.chains = {}
		StarRatingSystem.submit_chain("t", 3, 3, 3)
		DifficultyManager.set_difficulty(DifficultyManager.Difficulty.HARD)
		var hard_total = StarRatingSystem.get_total_stars()
		DifficultyManager.set_difficulty(DifficultyManager.Difficulty.NORMAL)
		var normal_total = StarRatingSystem.get_total_stars()
		if hard_total != 9 or normal_total != 9:
			ok = false; msg = "原始总星应恒为 9（与难度无关），实得 HARD=%d NORMAL=%d" % [hard_total, normal_total]

	if ok:
		print("P1_RESULT: PASS — v4.0 结局档位/难度无关性通过")
	else:
		print("P1_RESULT: FAIL — " + msg)
	quit()
