extends SceneTree

## 单测：EndingSystem 四档结局判定（总星级占比口径）
## 哨兵：P1_RESULT: PASS

func _init() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var StarRatingSystem = root.get_node_or_null("/root/StarRatingSystem")
	var EndingSystem = root.get_node_or_null("/root/EndingSystem")
	if not StarRatingSystem or not EndingSystem:
		print("P1_RESULT: FAIL (autoload 未加载)"); quit(); return

	var ok := true
	var reason := ""

	# 传奇：满分 9 星
	StarRatingSystem.observation_score = StarRatingSystem.max_observation
	StarRatingSystem.reasoning_score = 14
	StarRatingSystem.insight_score = 7
	if EndingSystem.determine_ending("") != EndingSystem.LEGENDARY:
		ok = false; reason = "满分应传奇"

	# 杰出：7 星（obs3+reason3+ins1；ins=1→1星，总分 3+3+1=7，占比 0.778→杰出）
	StarRatingSystem.observation_score = StarRatingSystem.max_observation
	StarRatingSystem.reasoning_score = 14
	StarRatingSystem.insight_score = 1
	if EndingSystem.determine_ending("") != EndingSystem.OUTSTANDING:
		ok = false; reason = "7星应杰出"

	# 合格：5 星（obs3+reason2+ins0；reason 9/14≈0.64→2星）
	StarRatingSystem.observation_score = StarRatingSystem.max_observation
	StarRatingSystem.reasoning_score = 9
	StarRatingSystem.insight_score = 0
	if EndingSystem.determine_ending("") != EndingSystem.PASSING:
		ok = false; reason = "5星应合格"

	# 见习：3 星（obs3 其余 0）
	StarRatingSystem.observation_score = StarRatingSystem.max_observation
	StarRatingSystem.reasoning_score = 0
	StarRatingSystem.insight_score = 0
	if EndingSystem.determine_ending("") != EndingSystem.PROBATION:
		ok = false; reason = "3星应见习"

	# 跨案累积 + info
	StarRatingSystem.observation_score = StarRatingSystem.max_observation
	StarRatingSystem.reasoning_score = 14
	StarRatingSystem.insight_score = 7
	EndingSystem.determine_ending("case_alpha")
	if EndingSystem.get_ending_for_case("case_alpha") != EndingSystem.LEGENDARY:
		ok = false; reason = "case_alpha 应记录传奇"
	var info = EndingSystem.get_ending_info(EndingSystem.LEGENDARY)
	if info.get("name", "") != "传奇":
		ok = false; reason = "info.name 应传奇"

	if ok:
		print("P1_RESULT: PASS")
	else:
		print("P1_RESULT: FAIL - " + reason)
	quit()
