extends Node

## BadgeSystem — 徽章系统（P2-6，接 StarRatingSystem）
##
## 职责（遵循「单一机制」原则）：
##   * 评分 / 判定逻辑只在 StarRatingSystem（其 evaluate_badges() + Badge 枚举）；
##   * 本系统只做：跨案累积的「已解锁徽章」集合、持久化（经 SaveManager 存档流）、
##     广播（SystemEventBus.badges_updated）供 UI 展示。
##
## 接入点：监听 SystemEventBus.case_completed（由 GameManager.end_case 发出）。
##
## 偏差说明（重要）：运行时徽章定义采用 StarRatingSystem.Badge 枚举
##（KEEN_EYE / MASTER_DEDUCER / DEPTH_SEEKER / PERFECT_SCORE / SPEED_RUNNER /
## NO_HINT_MASTER / FIRST_CASE_CLEAR 共 7 枚，已编译验证运行）。
## 这与 08_系统框架设计.md B-11.2 另列的 7 枚命名（初出茅庐/神枪手/博闻强识…）
## 不重合。本系统**不另起一套**，以免违反「单一机制」；两套命名统一属后续事项。

# 内存态：badge 枚举值(int) -> {"case_id":String, "time":int}
var unlocked: Dictionary = {}

func _ready() -> void:
	if SystemEventBus:
		SystemEventBus.case_completed.connect(_on_case_completed)

# 案件通关：消费 StarRatingSystem 评定，合并到累积集合，广播 + 持久化
func _on_case_completed(case_id: String, _stars: Dictionary) -> void:
	var newly = _merge_badges(case_id)
	if not newly.is_empty() and SystemEventBus:
		SystemEventBus.emit_signal("badges_updated", unlocked)
	_persist()

# 纯逻辑：把当前评定的徽章并入累积集合，返回本次新解锁的徽章
# （抽成独立方法，便于单测在不触发持久化的情况下验证评定/累积）
func _merge_badges(case_id: String) -> Array:
	if not StarRatingSystem:
		return []
	StarRatingSystem.evaluate_badges()
	var newly: Array = []
	for b in StarRatingSystem.badges:
		if not unlocked.has(b):
			unlocked[b] = {"case_id": case_id, "time": Time.get_unix_time_from_system()}
			newly.append(b)
	return newly

func _persist() -> void:
	if SaveManager:
		SaveManager.save_game()

# ---- 查询 API ----
func get_unlocked_badges() -> Dictionary:
	return unlocked.duplicate()

func get_current_badges() -> Array:
	if StarRatingSystem:
		return StarRatingSystem.badges.duplicate()
	return []

func has_badge(b: int) -> bool:
	return unlocked.has(b)

func get_unlocked_count() -> int:
	return unlocked.size()

func get_badge_name(b: int) -> String:
	if not StarRatingSystem:
		return "Badge_%d" % b
	match b:
		StarRatingSystem.Badge.NONE: return "无"
		StarRatingSystem.Badge.KEEN_EYE: return "锐眼"
		StarRatingSystem.Badge.MASTER_DEDUCER: return "推理大师"
		StarRatingSystem.Badge.DEPTH_SEEKER: return "深掘者"
		StarRatingSystem.Badge.PERFECT_SCORE: return "完美通关"
		StarRatingSystem.Badge.SPEED_RUNNER: return "速通者"
		StarRatingSystem.Badge.NO_HINT_MASTER: return "无提示大师"
		StarRatingSystem.Badge.FIRST_CASE_CLEAR: return "首案告破"
		_: return "Badge_%d" % b

# ---- 恢复 / 重置（存档流调用） ----
func restore_badges(data: Dictionary) -> void:
	if data.is_empty():
		return
	unlocked = data.duplicate()

func reset() -> void:
	unlocked = {}
