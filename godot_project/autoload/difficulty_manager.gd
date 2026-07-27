extends Node

## DifficultyManager - 难度管理器
## 管理三种难度模式：EASY（引导式）/ NORMAL（概率提示+动态调整）/ HARD（硬核推理）
##
## 设计基线：08_系统框架设计 §3.5 / 00_核心设计思路 §2.3 / GDD §3 / 02_标准化开发目录 H-02。
## 本次落地（P3.1.x 高优先三项）：
##   1) 动态概率调整（NORMAL：停滞+10% / 错误推理+5% / 正常-5%，上限 0.95，基础 0.7）
##   2) 困难模式隐藏纯提示选项（filter_choices + DialogueNodeResource.is_hint_only）
##   3) 竞技分数倍率（get_score_multiplier：EASY 0.5 / NORMAL 1.0 / HARD 1.5）

enum Difficulty {
	EASY,
	NORMAL,
	HARD
}

var current_difficulty: Difficulty = Difficulty.NORMAL

# ── 提示概率（仅 NORMAL 使用动态概率）──
const HINT_BASE_PROBABILITY: float = 0.7     # 普通模式基础提示概率（02文档 H-02：70%）
const HINT_MAX_PROBABILITY: float = 0.95     # 动态调整天花板（08 §3.5）
const HINT_MIN_PROBABILITY: float = 0.1      # 概率下限护栏，避免彻底无提示
var hint_current_probability: float = HINT_BASE_PROBABILITY  # 当前动态概率

# ── 停滞检测（连续交互未发现线索视为停滞，提高提示概率）──
const STALL_INTERACTION_THRESHOLD: int = 15  # 连续 15 次交互未发现线索
var _interactions_since_last_clue: int = 0

# ── 错误推理计数（连续错误推理提高提示概率）──
const WRONG_INFERENCE_THRESHOLD: int = 3     # 连续 3 次错误推理
var _wrong_inference_count: int = 0

# 各模式特性
var auto_fill_notebook: bool = false      # EASY: 自动填写推理笔记
var show_guidance: bool = false           # EASY: 显示引导
var dynamic_hint_chance: bool = false     # NORMAL: 动态提示概率
var hardcore_manual: bool = false         # HARD: 完全手动，无提示


func _ready() -> void:
	pass


func set_difficulty(difficulty: Difficulty) -> void:
	current_difficulty = difficulty
	# 重置动态状态，避免跨难度污染
	_interactions_since_last_clue = 0
	_wrong_inference_count = 0
	match difficulty:
		Difficulty.EASY:
			auto_fill_notebook = true
			show_guidance = true
			dynamic_hint_chance = false
			hardcore_manual = false
			hint_current_probability = 1.0
		Difficulty.NORMAL:
			auto_fill_notebook = false
			show_guidance = false
			dynamic_hint_chance = true
			hardcore_manual = false
			hint_current_probability = HINT_BASE_PROBABILITY
		Difficulty.HARD:
			auto_fill_notebook = false
			show_guidance = false
			dynamic_hint_chance = false
			hardcore_manual = true
			hint_current_probability = 0.0
	SystemEventBus.emit_signal("difficulty_changed", difficulty)


## 被动提示判定（被 scene_controller / star_rating 等消费）
func should_show_hint() -> bool:
	if hardcore_manual:
		return false
	if auto_fill_notebook:
		return true
	if dynamic_hint_chance:
		return randf() < hint_current_probability
	return false


## 当前提示概率（UI/测试读取）
func get_current_hint_probability() -> float:
	return hint_current_probability


## ── 动态概率调整（普通模式核心机制，08 §3.5 on_progress_check）──
## 调整规则：停滞 +10% / 错误推理 +5% / 正常进展 -5%（上限 HINT_MAX，下限 HINT_BASE）。
## 由游戏在「进度检查点」调用（如对话结束、场景切换）；普通模式之外无效。
func on_progress_check() -> void:
	if current_difficulty != Difficulty.NORMAL:
		return
	var reason: StringName = &"normal_progress"
	if _interactions_since_last_clue >= STALL_INTERACTION_THRESHOLD:
		hint_current_probability = min(HINT_MAX_PROBABILITY, hint_current_probability + 0.1)
		reason = &"stall_detected"
	elif _wrong_inference_count >= WRONG_INFERENCE_THRESHOLD:
		hint_current_probability = min(HINT_MAX_PROBABILITY, hint_current_probability + 0.05)
		reason = &"wrong_inference"
	else:
		hint_current_probability = max(HINT_BASE_PROBABILITY, hint_current_probability - 0.05)
		reason = &"normal_progress"
	UIEventBus.hint_probability_adjusted.emit(hint_current_probability, reason)


## 记录一次玩家交互（停滞计数 +1）。由各系统在玩家操作时调用（如对话推进、热点点击）。
func record_interaction() -> void:
	_interactions_since_last_clue += 1


## 重置停滞计数（线索发现时由 ClueSystem.collect_clue 调用）。
func reset_stall_counter() -> void:
	_interactions_since_last_clue = 0


## 记录一次错误推理（连续错误 +5%）。由推理墙判定错误时调用。
func record_wrong_inference() -> void:
	_wrong_inference_count += 1


## 重置错误计数（推理正确时调用）。
func reset_wrong_inference() -> void:
	_wrong_inference_count = 0


## ── 困难模式：过滤纯提示选项（08 §3.5 filter_choices）──
## nodes: Array[DialogueNodeResource]；HARD 下剔除 is_hint_only 节点，其余模式原样返回。
func filter_choices(nodes: Array) -> Array:
	if current_difficulty != Difficulty.HARD:
		return nodes
	return nodes.filter(func(c): return not (c is DialogueNodeResource and c.is_hint_only))


## ── 竞技分数倍率（GDD §3 / 08 §3.9 ActionSystem.get_action_difficulty）──
## EASY 0.5× / NORMAL 1.0× / HARD 1.5×；供 StarRatingSystem 合成评分与结局/排行使用。
func get_score_multiplier() -> float:
	match current_difficulty:
		Difficulty.EASY: return 0.5
		Difficulty.HARD: return 1.5
		_: return 1.0


func get_difficulty_name() -> String:
	match current_difficulty:
		Difficulty.EASY: return "简单"
		Difficulty.NORMAL: return "普通"
		Difficulty.HARD: return "困难"
	return "未知"
