extends Node

## StarRatingSystem — 三星评价系统（v4.0 离散制）
##
## 设计基准：00_标准化开发目录.md §B-11.5 三星评价公式 / §B-11.2 徽章等级 /
##           §B-11.4 调查方向选择与洞察之星 / §B-10.4.3 提示对洞察之星影响。
## 02_血字的研究_场景设计与流程 §4.5 / §7 / 附录C（v4.0 三星+徽章版）。
##
## 核心规则（v4.0）：
##   * 每条推理链独立评定 观察🔍 / 推理🧠 / 洞察💡 三维，各 1-3⭐（无 0⭐）。
##   * 单链最高 9⭐；案件总评 = 所有链星级汇总。以《血字的研究》为例 14 链 × 9 = 126⭐。
##   * 观察之星：按缺失条数（缺≥3→1⭐ / 缺1-2→2⭐ / 缺0→3⭐），不区分线索重要性。
##   * 推理之星：按正确比例（4/4→3⭐ / 3/4→2⭐ / ≤2/4→1⭐）。
##   * 洞察之星：按调查方向质量 + 隐藏信息发现（绕路→1⭐ / 重要方向→2⭐ / 最优顺序→3⭐）；
##               提示降级（B-10.4.3）：L2 上限 2⭐ / L3 上限 1⭐ / L4 固定 1⭐。
##   * 错误无惩罚：错误不扣分、不衰减、不关闭推理链，仅影响推理之星正确比例。
##   * 徽章：铜(单链 3-5⭐) / 银(6-8⭐) / 金(9⭐)，与难度无关。
##   * 结局档位（EndingSystem）：传奇≥90% / 杰出 70-89% / 合格 50-69% / 见习<50%。
##
## 调用方：推理墙在每次评星时调用 submit_chain() 提交当前链三维星级；
##         BadgeSystem / EndingSystem / GameManager 在结案时读取聚合结果。

# 评价维度
enum RatingDimension {
	OBSERVATION,   # 观察力：证据收集完整度
	REASONING,     # 推理能力：推理正确性与逻辑性
	INSIGHT,       # 洞察力：调查方向与隐藏信息发现
}

# 徽章（v4.0：等级徽章由单链星级决定，与难度无关；专项/历程徽章另列）
enum Badge {
	NONE,
	COPPER,           # 铜徽章：单链 3-5⭐（初出茅庐）
	SILVER,           # 银徽章：单链 6-8⭐（渐入佳境）
	GOLD,             # 金徽章：单链满星 9⭐（侦探本色）
	FIRST_CASE_CLEAR, # 首案告破
	NO_HINT_MASTER,   # 无提示大师（HARD 且全程未用提示）
}

const MAX_STARS_PER_CHAIN: int = 9   # 三维 × 3⭐
const MAX_STARS_PER_DIM: int = 3

# 每条推理链三维星级（各 1-3）
var chains: Dictionary = {}   # chain_id -> {"observation":int,"reasoning":int,"insight":int}

# 案件推理链明细缓存（裁定4：侦查中验证窗口不暴露错在哪，场景八一次性放全案结论）
# scene_id -> {"ratio":float,"stars":int,"summary":String,"per_branch":Array}
# 由推理墙提交验证时写入；仅正式墙（非练习墙）计入。
var case_branch_log: Dictionary = {}

# 跨链聚合（供 GameManager 进度展示 / 存档兼容；= 各维所有链之和）
var observation_score: int = 0
var reasoning_score: int = 0
var insight_score: int = 0

var badges: Array = []
var competitive_score: int = 0   # 竞技合成星级（原始总分 × 难度倍率），由 evaluate_badges 计算

func _ready() -> void:
	pass

## 提交/覆盖一条推理链的三维星级（各 1-3⭐）。
## hint_cap：洞察之星上限修正（B-10.4.3）。-1=不限；2=L2 华生提示上限2⭐；
## 1=L3 福尔摩斯模糊提示上限1⭐；0=L4 失败保护固定1⭐。
func submit_chain(chain_id: String, observation: int, reasoning: int, insight: int, hint_cap: int = -1) -> void:
	if chain_id == "" or chain_id == "reasoning_chain":
		return  # 未声明 chain_id 的墙（如场景一·华生/信使墙）不参与计分，避免相互覆盖
	var ins := clampi(insight, 1, MAX_STARS_PER_DIM)
	if hint_cap >= 0:
		ins = mini(ins, hint_cap)
		if hint_cap == 0:
			ins = 1
	chains[chain_id] = {
		"observation": clampi(observation, 1, MAX_STARS_PER_DIM),
		"reasoning": clampi(reasoning, 1, MAX_STARS_PER_DIM),
		"insight": ins,
	}
	_recalculate_aggregates()

func _recalculate_aggregates() -> void:
	observation_score = 0
	reasoning_score = 0
	insight_score = 0
	for cr in chains.values():
		observation_score += cr["observation"]
		reasoning_score += cr["reasoning"]
		insight_score += cr["insight"]

func has_chain(chain_id: String) -> bool:
	return chains.has(chain_id)

## 缓存某场景提交验证时的推理链明细（裁定4）：供场景八「结局全案总结」放出结论。
## detail 应为推理墙 owner._last_branch（含 ratio/stars/summary/per_branch）。
## scene_id 为空或 detail 为空则忽略；练习墙由调用方自行判断不调用本函数。
func record_branch_progress(scene_id: String, detail: Dictionary) -> void:
	if scene_id == "" or detail.is_empty():
		return
	case_branch_log[scene_id] = {
		"ratio": float(detail.get("ratio", 0.0)),
		"stars": int(detail.get("stars", 0)),
		"summary": str(detail.get("summary", "")),
		"hard_fail": bool(detail.get("hard_fail", false)),
		"per_branch": detail.get("per_branch", []),
	}

func get_case_branch_log() -> Dictionary:
	return case_branch_log

func get_chain_stars(chain_id: String) -> Dictionary:
	if chains.has(chain_id):
		return chains[chain_id].duplicate()
	return {"observation": 0, "reasoning": 0, "insight": 0}

func get_chain_total(chain_id: String) -> int:
	if chains.has(chain_id):
		var c: Dictionary = chains[chain_id]
		return int(c["observation"]) + int(c["reasoning"]) + int(c["insight"])
	return 0

func get_chain_count() -> int:
	return chains.size()

## 案件总星级 = 所有推理链星级之和（例：6 链满星 = 54⭐；完整 14 链 = 126⭐）
func get_total_stars() -> int:
	var t := 0
	for cr in chains.values():
		t += int(cr["observation"]) + int(cr["reasoning"]) + int(cr["insight"])
	return t

## 案件满星 = 已提交链数 × 9（支持任意链数，默认 14 链 => 126⭐）
func get_max_total_stars() -> int:
	return chains.size() * MAX_STARS_PER_CHAIN

## 单维聚合星（跨链求和；供兼容接口 / UI 展示，可能 >3）
func get_stars(dimension: RatingDimension) -> int:
	match dimension:
		RatingDimension.OBSERVATION: return observation_score
		RatingDimension.REASONING: return reasoning_score
		RatingDimension.INSIGHT: return insight_score
	return 0

## 竞技分数倍率合成星级（设计 GDD §3）：原始总分 × 难度倍率，四舍五入。
## 徽章仍基于原始星级（纯技巧），此值供结局/排行等竞技场景消费。
func get_adjusted_total_stars() -> int:
	var mult: float = 1.0
	if DifficultyManager != null:
		mult = DifficultyManager.get_score_multiplier()
	return roundi(float(get_total_stars()) * mult)

## 徽章评定（v4.0：铜/银/金按单链最高总星，与难度无关；历程徽章另计）
func evaluate_badges() -> void:
	badges.clear()
	# 单链最高总星 -> 决定最高等级徽章
	var best := 0
	for cid in chains.keys():
		best = maxi(best, get_chain_total(cid))
	if best >= MAX_STARS_PER_CHAIN:
		badges.append(Badge.GOLD)
	elif best >= 6:
		badges.append(Badge.SILVER)
	elif best >= 3:
		badges.append(Badge.COPPER)
	# 首案告破
	badges.append(Badge.FIRST_CASE_CLEAR)
	# 无提示大师：HARD 且全程未用提示
	if DifficultyManager != null \
	   and DifficultyManager.current_difficulty == DifficultyManager.Difficulty.HARD \
	   and (DifficultyManager.should_show_hint() == false):
		badges.append(Badge.NO_HINT_MASTER)
	# 竞技分数倍率合成（设计 GDD §3）：难度调整合成星级，供结局/排行消费
	competitive_score = get_adjusted_total_stars()

## 重置（新游戏时调用）
func reset() -> void:
	chains.clear()
	observation_score = 0
	reasoning_score = 0
	insight_score = 0
	badges.clear()
	competitive_score = 0
	case_branch_log.clear()
