extends SceneTree

## P2-1 BadgeSystem 单测：验证通关时徽章评定 + 跨案累积（不触发持久化）
## 哨兵：P1_RESULT: PASS

func _init() -> void:
	call_deferred("run_test")

func run_test() -> void:
	if not StarRatingSystem or not BadgeSystem:
		print("P1_RESULT: FAIL (autoload 未加载)")
		quit()
		return

	# 干净起点
	StarRatingSystem.observation_score = 0
	StarRatingSystem.reasoning_score = 0
	StarRatingSystem.insight_score = 0
	BadgeSystem.reset()

	# 全满分 → 应解锁 KEEN_EYE / MASTER_DEDUCER / DEPTH_SEEKER / PERFECT_SCORE / FIRST_CASE_CLEAR
	StarRatingSystem.observation_score = StarRatingSystem.max_observation
	StarRatingSystem.reasoning_score = StarRatingSystem.max_reasoning
	StarRatingSystem.insight_score = StarRatingSystem.max_insight

	BadgeSystem._merge_badges("case_blood_letter")
	var expected = [
		StarRatingSystem.Badge.KEEN_EYE,
		StarRatingSystem.Badge.MASTER_DEDUCER,
		StarRatingSystem.Badge.DEPTH_SEEKER,
		StarRatingSystem.Badge.PERFECT_SCORE,
		StarRatingSystem.Badge.FIRST_CASE_CLEAR,
	]
	var ok = true
	for b in expected:
		if not BadgeSystem.has_badge(b):
			ok = false
			print("缺失徽章枚举值: ", b)
	if BadgeSystem.get_unlocked_count() != 5:
		ok = false
		print("累积数量异常: ", BadgeSystem.get_unlocked_count())

	# 二次通关：不应新增（累积集合，数量仍为 5）
	BadgeSystem._merge_badges("case_blood_letter_2")
	if BadgeSystem.get_unlocked_count() != 5:
		ok = false
		print("二次通关数量异常: ", BadgeSystem.get_unlocked_count())

	# 名称映射
	if BadgeSystem.get_badge_name(StarRatingSystem.Badge.KEEN_EYE) != "锐眼":
		ok = false

	if ok:
		print("P1_RESULT: PASS")
	else:
		print("P1_RESULT: FAIL")
	quit()
