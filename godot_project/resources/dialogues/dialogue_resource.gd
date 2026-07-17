class_name DialogueResource
extends Resource

## DialogueResource — 对话集合资源
## 包含一个完整场景/阶段的所有对话节点和条件分支
## 支持：三难度分支、四级验证分支、六步闭环触发

# ============ 元数据 ============

@export var scene_id: String = ""           # 场景标识，如 "scene_01"
@export var scene_name: String = ""         # 场景名称
@export var phase_id: String = ""           # 阶段标识，如 "phase1"
@export var phase_name: String = ""         # 阶段名称
@export var exploration_step: int = 0       # 六步闭环步骤 (1-6, 0=非六步闭环)

# ============ 难度分支入口 ============

## 三难度分别对应不同的起始节点
@export var easy_start_node: String = ""    # EASY 模式起始节点ID
@export var normal_start_node: String = ""  # NORMAL 模式起始节点ID
@export var hard_start_node: String = ""    # HARD 模式起始节点ID

# ============ 对话节点 ============

## 所有对话节点 (node_id → DialogueNodeResource)
@export var nodes: Array[Resource] = []

# ============ 元数据扩展 ============

## 本对话阶段涉及的知识库主题域（可选）
@export var knowledge_domains: Array[String] = []

## 本对话阶段完成后触发的里程碑（可选）
@export var milestone_name: String = ""

## 本对话阶段完成后的评分影响
@export var score_observation: int = 0
@export var score_reasoning: int = 0
@export var score_insight: int = 0

## 本对话阶段的徽章检查条件
@export var badge_check: String = ""        # 如 "NO_HINT_MASTER" / "FIRST_CASE_CLEAR"

## 本对话阶段后的场景事件（如 "open_reasoning_wall"）
@export var completion_event: String = ""


## 根据当前难度获取起始节点
func get_start_node(difficulty: int) -> String:
	match difficulty:
		0:  # EASY
			return easy_start_node if easy_start_node else _first_node()
		1:  # NORMAL
			return normal_start_node if normal_start_node else _first_node()
		2:  # HARD
			return hard_start_node if hard_start_node else _first_node()
	return _first_node()

func _first_node() -> String:
	if nodes.size() > 0:
		return nodes[0].node_id
	return ""


## 根据节点ID查找节点
func find_node(node_id: String) -> Resource:
	for node in nodes:
		if node.node_id == node_id:
			return node
	return null


## 获取六步闭环步骤名称
func get_step_name() -> String:
	match exploration_step:
		1: return "观察发现"
		2: return "工具操作"
		3: return "数据记录"
		4: return "知识检索"
		5: return "假设形成"
		6: return "验证修正"
	return ""
