class_name DialogueNodeResource
extends Resource

## DialogueNodeResource — 单个对话节点
## 包含：说话人、文本、表情、触发类型、下一个节点列表、条件分支

# ============ 基础字段 ============

@export var node_id: String = ""            # 唯一标识，如 "s1_p1_intro_01"
@export var speaker: String = ""            # 说话人：福尔摩斯/华生/system/信使/葛莱森/雷斯垂德/...
@export var text: String = ""               # 对话文本
@export var mood: String = "neutral"        # 表情/情绪：自信/吃惊/思考/微笑/严肃/...

# ============ 触发类型 ============

## auto: 自动推进到下一节点
## click: 等待玩家点击后推进
## choice: 等待玩家从选项中选择
## optional: 可选节点，玩家可跳过
## sfx: 触发音效后自动推进
## milestone: 触发里程碑动画后推进
## knowledge: 触发知识库打开后推进
## clue: 触发线索发现后推进
## guide: 触发引导提示后推进
## note: 触发笔记更新后推进
@export var trigger: String = "auto"

# ============ 下一个节点 ============

## 下一个节点ID列表（可多个，用于分支）
@export var next_nodes: Array[String] = []

## 下一个节点的选择文本（当 trigger = "choice" 时）
@export var choice_texts: Array[String] = []

# ============ 条件分支 ============

## 难度限定：仅在此难度下显示此节点
## 0=全难度, 1=EASY, 2=NORMAL, 3=HARD, 4=EASY+NORMAL, 5=NORMAL+HARD
@export var difficulty_filter: int = 0

## 验证结果分支：仅在此验证结果下显示此节点
## ""=无条件, "VERIFIED"/"SUPPORTED"/"INSUFFICIENT"/"CONTRADICTORY"
@export var verify_filter: String = ""

## 概率触发（仅 NORMAL 模式）
## 0.0 ~ 1.0，1.0=必定触发
@export var probability: float = 1.0

# ============ 六步闭环标记 ============

## 此节点属于六步闭环的哪一步 (0=不属于)
@export var exploration_step: int = 0

## 此节点是否为步骤入口（触发 step_X_enter 信号）
@export var is_step_entry: bool = false

# ============ 特效标记 ============

## 演出指示：特写/表情/UI/音效
@export var stage_direction: String = ""    # 如 "特写" / "音效:门铃" / "动画:里程碑"

## 笔记更新文本（trigger="note" 时使用）
@export var note_text: String = ""

## 系统提示文本
@export var system_hint: String = ""


## 获取下一个节点ID列表（运行时筛选后）
func get_available_next(difficulty: int, verify_result: String = "") -> Array[String]:
	var available: Array[String] = []
	
	for i in range(next_nodes.size()):
		var next_id = next_nodes[i] if i < next_nodes.size() else ""
		if next_id == "" or next_id == "end":
			available.append(next_id)
			continue
		
		# 概率检查（NORMAL 模式）
		if difficulty == 1 and probability < 1.0:
			if randf() > probability:
				continue
		
		available.append(next_id)
	
	return available


## 判断此节点是否应在当前条件下显示
func should_show(difficulty: int, verify_result: String = "") -> bool:
	# 难度过滤
	if difficulty_filter != 0:
		match difficulty_filter:
			1:  # 仅 EASY
				if difficulty != 0: return false
			2:  # 仅 NORMAL
				if difficulty != 1: return false
			3:  # 仅 HARD
				if difficulty != 2: return false
			4:  # EASY + NORMAL
				if difficulty == 2: return false
			5:  # NORMAL + HARD
				if difficulty == 0: return false
	
	# 验证结果过滤
	if verify_filter != "" and verify_filter != verify_result:
		return false
	
	return true
