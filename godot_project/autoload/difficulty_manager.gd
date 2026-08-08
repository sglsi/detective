extends Node

## DifficultyManager - 难度管理器
## 管理三种难度模式：EASY（引导式）/ NORMAL（概率提示+动态调整）/ HARD（硬核推理）
##
## 设计基线：08_系统框架设计 §3.5 / 00_核心设计思路 §2.3 / GDD §3 /
##          02_标准化开发目录 B-11《模式与难度》/ 03_关卡设计稿 6.4《模式差异表》。
##
## 模式差异总览（按文档 B-11.2 / 03-6.4）：
##   | 维度                 | 简单              | 普通              | 困难              |
##   |----------------------|-------------------|-------------------|-------------------|
##   | 场景线索提示         | 高亮所有可交互点  | 微光标记关键交互点| 无任何提示标记    |
##   | 对话细节补充         | 全部              | 概率              | 严格证据          |
##   | 可信度展示           | 等级+详细来源     | 高/中/低三档      | 不显示            |
##   | 假设引导             | 自动高亮优先方向  | 弱提示推荐方向    | 无引导            |
##   | 推理墙辅助           | 全开              | 标准              | 极简              |
##   | 矛盾被动提示         | 默认开启          | 默认关闭/可手动开 | 强制关闭          |
##   | 求助（全局扫描）     | 单案件3次         | 单案件3次         | 单案件3次         |
##   | 误导线索             | 不出现            | 30% 概率          | 70% 概率          |
##   | 时间时效规则         | 无线索失效        | 软时效            | 严格时序可失效    |
##   | 自动填写笔记         | 是                | 否                | 否                |
##   | 分数倍率             | 0.5×              | 1.0×              | 1.5×              |

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

# ── 模式差异配置（由 set_difficulty 统一设置）──
# 提示与引导
var auto_fill_notebook: bool = false       # EASY: 自动填写推理笔记
var show_guidance: bool = false            # EASY: 显示引导
var dynamic_hint_chance: bool = false      # NORMAL: 动态提示概率
var hardcore_manual: bool = false          # HARD: 完全手动，无提示

# 场景交互点提示级别（B-11.2「场景线索提示」）
# 0=无提示  1=关键高亮  2=全部高亮
var hotspot_hint_level: int = 0

# 对话细节补充级别（B-11.2「对话细节补充」）
var dialogue_detail_level: String = "strict_evidence"   # "full" / "probability" / "strict_evidence"

# 可信度展示级别（B-11.2「可信度展示」）
var credibility_display: String = "none"   # "detailed" / "tier" / "none"

# 假设引导级别（B-11.2「假设引导」）
var hypothesis_guidance: String = "none"   # "full" / "partial" / "none"

# 推理墙辅助级别（B-11.2「推理墙辅助」）
var wall_assistance: String = "standard"   # "full" / "standard" / "minimal"

# 矛盾被动提示（B-11.2）
var contradiction_passive: bool = false

# 误导线索出现概率（B-11.2 / 00 §H-01）
var mislead_chance: float = 0.0

# 时间时效严格度（B-11.2）
var time_strictness: String = "soft"   # "none" / "soft" / "strict"

# 分支选择引导（03-6.4）
var branch_guidance: String = "none"   # "full" / "partial" / "none"

# 线索自动呈现：简单模式直接展示所有可交互点；普通/困难需玩家主动操作
var auto_reveal_clues: bool = false


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
			hotspot_hint_level = 2
			dialogue_detail_level = "full"
			credibility_display = "detailed"
			hypothesis_guidance = "full"
			wall_assistance = "full"
			contradiction_passive = true
			mislead_chance = 0.0
			time_strictness = "none"
			branch_guidance = "full"
			auto_reveal_clues = true
		Difficulty.NORMAL:
			auto_fill_notebook = false
			show_guidance = false
			dynamic_hint_chance = true
			hardcore_manual = false
			hint_current_probability = HINT_BASE_PROBABILITY
			hotspot_hint_level = 1
			dialogue_detail_level = "probability"
			credibility_display = "tier"
			hypothesis_guidance = "partial"
			wall_assistance = "standard"
			contradiction_passive = false
			mislead_chance = 0.3
			time_strictness = "soft"
			branch_guidance = "partial"
			auto_reveal_clues = false
		Difficulty.HARD:
			auto_fill_notebook = false
			show_guidance = false
			dynamic_hint_chance = false
			hardcore_manual = true
			hint_current_probability = 0.0
			hotspot_hint_level = 0
			dialogue_detail_level = "strict_evidence"
			credibility_display = "none"
			hypothesis_guidance = "none"
			wall_assistance = "minimal"
			contradiction_passive = false
			mislead_chance = 0.7
			time_strictness = "strict"
			branch_guidance = "none"
			auto_reveal_clues = false
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


## 单案件求助（全局扫描）次数上限（B-10.4.7 / B-11.2）：三模式统一 3 次
func get_help_max_attempts() -> int:
	return 3


## 返回当前难度中文名
func get_difficulty_name() -> String:
	match current_difficulty:
		Difficulty.EASY: return "简单"
		Difficulty.NORMAL: return "普通"
		Difficulty.HARD: return "困难"
	return "未知"


## 返回指定难度的玩家可读描述（难度选择界面用）
func get_difficulty_description(difficulty: Difficulty = current_difficulty) -> String:
	match difficulty:
		Difficulty.EASY:
			return "助手模式：高亮所有可交互点、自动呈现线索、详细引导、无误导。适合体验剧情。"
		Difficulty.NORMAL:
			return "平衡体验：关键交互点微光提示、动态概率提示、30% 误导线索、标准推理墙。"
		Difficulty.HARD:
			return "硬核推理：无提示标记、无引导、70% 误导线索、极简辅助、严格时序。"
		_:
			return ""


## ── 模式差异便捷判定（供各系统消费）──

## 是否应在场景中持续高亮可交互热点（不依赖点击 LOOK）
func should_highlight_hotspots() -> bool:
	return hotspot_hint_level >= 1

## 是否应显示全部热点（简单模式），还是仅关键热点（普通）
func should_show_all_hotspots() -> bool:
	return hotspot_hint_level >= 2

## 当前难度下某条热点是否应显示提示标记
## 用于 ClueObserver.show() 等：根据 hotspot_hint_level 与热点重要性决定是否可见
func is_hotspot_hint_visible(hs: Dictionary) -> bool:
	if hotspot_hint_level >= 2:
		return true
	if hotspot_hint_level == 1:
		# 普通模式仅标记「关键/重要」交互点
		var importance: String = hs.get("importance", hs.get("type", ""))
		return importance == "key" or importance == "important" or importance == "critical"
	return false


## ── 误导线索过滤（B-11.2 / 00 §H-01）──
## 输入：原始热点数组（元素可含 is_correct=false / misleading=true / difficulty_visibility 字段）
## 输出：按当前难度保留下来的热点数组。简单模式剔除所有误导；普通模式按概率保留部分；困难模式保留大部分。
## 采用确定性种子（由各热点 id 生成 hash），保证同一存档下结果稳定。
func filter_hotspots_by_difficulty(hotspots: Array) -> Array:
	var out: Array = []
	for hs in hotspots:
		var is_misleading := false
		if hs is Dictionary:
			# 场景 hotspots() 数据用 "correct"，运行时归一化后用 "is_correct"，两者都要兼容
			var correct_val = hs.get("is_correct", hs.get("correct", true))
			is_misleading = correct_val == false or hs.get("misleading", false) == true
		elif hs is HotspotData:
			is_misleading = not hs.is_correct
		if not is_misleading:
			out.append(hs)
			continue
		# 误导线索按概率出现
		var chance: float = mislead_chance
		var deterministic := _hash_float(str(hs.get("id", "")))
		if deterministic < chance:
			out.append(hs)
	return out


## 将 0~1 的确定性 hash 从热点 id 生成
func _hash_float(id_str: String) -> float:
	var h: int = 5381
	for i in range(id_str.length()):
		h = ((h << 5) + h) + id_str.unicode_at(i)
		# 防止 int 溢出 Godot 自动变负，强制保持正数
		h = h & 0xFFFFFFFF
	return float(h) / float(0xFFFFFFFF)
