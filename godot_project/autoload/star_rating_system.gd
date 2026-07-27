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
var competitive_score: int = 0   # 竞技合成星级（原始总分 × 难度倍率），由 evaluate_badges 计算

# P3.1：观察力改为「线索分级加权」评分。满分基数 = scene4-8 可得线索权重合计（误导项0分）。
# 明细（关键10/重要5/一般2）：sc4=12 + sc5=24 + sc6=15 + sc7=34 + sc8=30 = 115。
# 注：scene1-3 目前不向 StarRatingSystem 计分（score_awarded 信号未接线，为既有缺口，
#     不在本次 P3.1 范围；见《P3.1_线索分级加权评分_改动设计》§遗留）。
var max_observation: int = 115  # scene4-8 可得线索权重合计（加权满分基数）
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
	# 3星（满星）门槛；观察之星在简单模式下降门槛（GDD §2.6.2：关键线索≥80%即可）
	var top_threshold: float = 0.9
	match dimension:
		RatingDimension.OBSERVATION:
			ratio = float(observation_score) / float(max_observation)
			if DifficultyManager != null \
			   and DifficultyManager.current_difficulty == DifficultyManager.Difficulty.EASY:
				top_threshold = 0.8
		RatingDimension.REASONING:
			ratio = float(reasoning_score) / float(max_reasoning)
		RatingDimension.INSIGHT:
			ratio = float(insight_score) / float(max_insight)
	
	if ratio >= top_threshold: return 3
	elif ratio >= 0.6: return 2
	elif ratio >= 0.3: return 1
	return 0

func get_total_stars() -> int:
	return get_stars(RatingDimension.OBSERVATION) + \
		   get_stars(RatingDimension.REASONING) + \
		   get_stars(RatingDimension.INSIGHT)

## 竞技分数倍率合成星级（设计 GDD §3 / 08 §3.9）：原始总分 × 难度倍率，四舍五入。
## 徽章仍基于原始星级（纯技巧），此值供结局/排行等竞技场景消费。
func get_adjusted_total_stars() -> int:
	var mult: float = 1.0
	if DifficultyManager != null:
		mult = DifficultyManager.get_score_multiplier()
	return roundi(float(get_total_stars()) * mult)

## 综合等级（GDD §2.6.5）：基于三星总数（满分 9，与难度无关）
##   名侦探  : 7-9 星 且 至少 2 个维度满 3 星（解锁《四签名》预告 + 开发者评论）
##   合格侦探: 4-6 星（福尔摩斯认可，正常结案）
##   继续推理: ≤3 星（推理仍有疏漏，可回溯重做，不强制结束）
func get_evaluation_grade() -> Dictionary:
	var total := get_total_stars()
	var three_star_dims := 0
	for dim in [RatingDimension.OBSERVATION, RatingDimension.REASONING, RatingDimension.INSIGHT]:
		if get_stars(dim) == 3:
			three_star_dims += 1
	if total >= 7 and three_star_dims >= 2:
		return {"grade": "master_detective", "name": "名侦探",
		        "description": "贝克街名侦探称号，解锁《四签名》预告 + 开发者评论。",
		        "can_replay": true}
	if total >= 4:
		return {"grade": "qualified_detective", "name": "合格侦探",
		        "description": "福尔摩斯认可，案件正常结案。", "can_replay": true}
	return {"grade": "keep_investigating", "name": "继续推理",
	        "description": "推理仍有疏漏，可回溯重新推理，不强制结束。", "can_replay": true}

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
	# 竞技分数倍率合成（设计 GDD §3）：难度调整合成星级，供结局/排行消费
	competitive_score = get_adjusted_total_stars()
