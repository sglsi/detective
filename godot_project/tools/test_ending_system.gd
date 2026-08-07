extends SceneTree

## 单测：EndingSystem 四档结局判定（总星级占比口径）
## 哨兵：P1_RESULT: PASS
## 注：ending_system.gd 的 enum EndingTier 没有 class_name（项目约定），故本测试不通过
##     实例访问枚举，改以 determine_ending() 返回的档位 + get_ending_info() 的中文名做断言，
##     对 Godot 4.6 / 4.7 均兼容（避免实例.枚举 在旧版 Godot 报 Invalid access）。

func _init() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var srs = root.get_node_or_null("/root/StarRatingSystem")
	var es = root.get_node_or_null("/root/EndingSystem")
	if not srs or not es:
		print("P1_RESULT: FAIL (autoload 未加载)"); quit(); return

	var ok := true
	var reason := ""

	# 传奇：单链满星 9⭐（占比 100%）
	srs.chains = {}
	srs.submit_chain("t", 3, 3, 3)
	if not _is_tier(es, es.determine_ending(""), "传奇"):
		ok = false; reason = "满星应传奇"

	# 杰出：7 星（3+2+2，占比 0.778→杰出）
	srs.chains = {}
	srs.submit_chain("t", 3, 2, 2)
	if not _is_tier(es, es.determine_ending(""), "杰出"):
		ok = false; reason = "7星应杰出"

	# 合格：5 星（2+2+1，占比 0.556→合格）
	srs.chains = {}
	srs.submit_chain("t", 2, 2, 1)
	if not _is_tier(es, es.determine_ending(""), "合格"):
		ok = false; reason = "5星应合格"

	# 见习：3 星（1+1+1，占比 0.333→见习）
	srs.chains = {}
	srs.submit_chain("t", 1, 1, 1)
	if not _is_tier(es, es.determine_ending(""), "见习"):
		ok = false; reason = "3星应见习"

	# 跨案累积 + info
	srs.chains = {}
	srs.submit_chain("t", 3, 3, 3)
	es.determine_ending("case_alpha")
	var case_tier = es.get_ending_for_case("case_alpha")
	if not _is_tier(es, case_tier, "传奇"):
		ok = false; reason = "case_alpha 应记录传奇"
	var info = es.get_ending_info(case_tier)
	if info.get("name", "") != "传奇":
		ok = false; reason = "info.name 应传奇"

	if ok:
		print("P1_RESULT: PASS")
	else:
		print("P1_RESULT: FAIL - " + reason)
	quit()

## 辅助：用 determine_ending 的档位 int 查 get_ending_info()，比对中文名
func _is_tier(es, tier: int, expected_name: String) -> bool:
	var info = es.get_ending_info(tier)
	return info.get("name", "") == expected_name
