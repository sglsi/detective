extends Node

## DifficultyManager - 难度管理器
## 管理三种难度模式：EASY（引导式）/ NORMAL（概率提示）/ HARD（硬核推理）

enum Difficulty {
	EASY,
	NORMAL,
	HARD
}

var current_difficulty: Difficulty = Difficulty.NORMAL

# 提示概率（仅 NORMAL 模式使用，0.0 ~ 1.0）
var hint_probability: float = 0.5

# 各模式特性
var auto_fill_notebook: bool = false      # EASY: 自动填写推理笔记
var show_guidance: bool = false           # EASY: 显示引导
var dynamic_hint_chance: bool = true      # NORMAL: 动态提示概率
var hardcore_manual: bool = false         # HARD: 完全手动，无提示

func _ready() -> void:
	pass

func set_difficulty(difficulty: Difficulty) -> void:
	current_difficulty = difficulty
	match difficulty:
		Difficulty.EASY:
			auto_fill_notebook = true
			show_guidance = true
			dynamic_hint_chance = false
			hardcore_manual = false
			hint_probability = 1.0
		Difficulty.NORMAL:
			auto_fill_notebook = false
			show_guidance = false
			dynamic_hint_chance = true
			hardcore_manual = false
			hint_probability = 0.5
		Difficulty.HARD:
			auto_fill_notebook = false
			show_guidance = false
			dynamic_hint_chance = false
			hardcore_manual = true
			hint_probability = 0.0
	SystemEventBus.emit_signal("difficulty_changed", difficulty)

func should_show_hint() -> bool:
	if hardcore_manual:
		return false
	if auto_fill_notebook:
		return true
	if dynamic_hint_chance:
		return randf() < hint_probability
	return false

func get_difficulty_name() -> String:
	match current_difficulty:
		Difficulty.EASY: return "简单"
		Difficulty.NORMAL: return "普通"
		Difficulty.HARD: return "困难"
	return "未知"
