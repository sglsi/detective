extends Node

## StarRatingSystem - 三星评价系统
## 三维独立评定：观察力 / 推理能力 / 洞察力，各 1-3 星

# 评价维度
enum RatingDimension {
	OBSERVATION,   # 观察力：发现线索数量与质量
	REASONING,     # 推理能力：推理链完整度与正确率
	INSIGHT        # 洞察力：隐藏线索/深层关联的发现
}

# 徽章系统
enum Badge {
	NONE,
	KEEN_EYE,            # 观察力3星
	MASTER_DEDUCER,      # 推理能力3星
	DEPTH_SEEKER,        # 洞察力3星
	PERFECT_SCORE,       # 三满星
	SPEED_RUNNER,        # 快速通关
	NO_HINT_MASTER,      # 无提示通关（HARD限定）
	FIRST_CASE_CLEAR     # 首案通关
}

var observation_score: int = 0
var reasoning_score: int = 0
var insight_score: int = 0
var badges: Array = []

var max_observation: int = 45   # 总线索数
var max_reasoning: int = 14     # 总推理链数
var max_insight: int = 7        # 隐藏线索数

func _ready() -> void:
	pass

func add_observation(value: int = 1) -> void:
	observation_score = min(observation_score + value, max_observation)

func add_reasoning(value: int = 1) -> void:
	reasoning_score = min(reasoning_score + value, max_reasoning)

func add_insight(value: int = 1) -> void:
	insight_score = min(insight_score + value, max_insight)

func get_stars(dimension: RatingDimension) -> int:
	var ratio: float
	var max_val: int
	match dimension:
		RatingDimension.OBSERVATION:
			ratio = float(observation_score) / float(max_observation)
		RatingDimension.REASONING:
			ratio = float(reasoning_score) / float(max_reasoning)
		RatingDimension.INSIGHT:
			ratio = float(insight_score) / float(max_insight)
	
	if ratio >= 0.9: return 3
	elif ratio >= 0.6: return 2
	elif ratio >= 0.3: return 1
	return 0

func get_total_stars() -> int:
	return get_stars(RatingDimension.OBSERVATION) + \
		   get_stars(RatingDimension.REASONING) + \
		   get_stars(RatingDimension.INSIGHT)

func evaluate_badges() -> void:
	badges.clear()
	if get_stars(RatingDimension.OBSERVATION) == 3:
		badges.append(Badge.KEEN_EYE)
	if get_stars(RatingDimension.REASONING) == 3:
		badges.append(Badge.MASTER_DEDUCER)
	if get_stars(RatingDimension.INSIGHT) == 3:
		badges.append(Badge.DEPTH_SEEKER)
	if get_total_stars() == 9:
		badges.append(Badge.PERFECT_SCORE)
	if DifficultyManager.current_difficulty == DifficultyManager.Difficulty.HARD \
	   and not DifficultyManager.should_show_hint():
		badges.append(Badge.NO_HINT_MASTER)
	badges.append(Badge.FIRST_CASE_CLEAR)
