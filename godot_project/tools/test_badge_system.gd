extends SceneTree

## v4.0 BadgeSystem 单测：验证通关时徽章评定（铜/银/金按单链总星）+ 跨案累积（不触发持久化）
## 哨兵：P1_RESULT: PASS

func _init() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var StarRatingSystem = root.get_node_or_null("/root/StarRatingSystem")
	var BadgeSystem = root.get_node_or_null("/root/BadgeSystem")
	if not StarRatingSystem or not BadgeSystem:
		print("P1_RESULT: FAIL (autoload 未加载)")
		quit()
		return

	var ok := true

	# 金徽章：单链满星 9⭐ → GOLD + FIRST_CASE_CLEAR（2 枚）
	StarRatingSystem.chains = {}
	StarRatingSystem.submit_chain("scene8", 3, 3, 3)
	BadgeSystem.reset()
	BadgeSystem._merge_badges("case_blood_letter")
	if not BadgeSystem.has_badge(StarRatingSystem.Badge.GOLD):
		ok = false; print("金徽章缺失")
	if not BadgeSystem.has_badge(StarRatingSystem.Badge.FIRST_CASE_CLEAR):
		ok = false; print("首案告破缺失")
	if BadgeSystem.get_unlocked_count() != 2:
		ok = false; print("金徽章累积数量异常: ", BadgeSystem.get_unlocked_count())

	# 银徽章：单链 6⭐（2,2,2）→ SILVER
	StarRatingSystem.chains = {}
	StarRatingSystem.submit_chain("scene6", 2, 2, 2)
	BadgeSystem.reset()
	BadgeSystem._merge_badges("case2")
	if not BadgeSystem.has_badge(StarRatingSystem.Badge.SILVER):
		ok = false; print("银徽章缺失")

	# 铜徽章：单链 3⭐（1,1,1）→ COPPER
	StarRatingSystem.chains = {}
	StarRatingSystem.submit_chain("scene4", 1, 1, 1)
	BadgeSystem.reset()
	BadgeSystem._merge_badges("case3")
	if not BadgeSystem.has_badge(StarRatingSystem.Badge.COPPER):
		ok = false; print("铜徽章缺失")

	# 名称映射
	if BadgeSystem.get_badge_name(StarRatingSystem.Badge.GOLD) != "侦探本色（金）":
		ok = false; print("金徽章名称错误")
	if BadgeSystem.get_badge_name(StarRatingSystem.Badge.COPPER) != "初出茅庐（铜）":
		ok = false; print("铜徽章名称错误")

	if ok:
		print("P1_RESULT: PASS")
	else:
		print("P1_RESULT: FAIL")
	quit()
