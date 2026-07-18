extends Node

## ClueSystem - 线索系统
## 管理线索的发现、记录、关联和15字段标准化数据结构

# 线索状态枚举
enum ClueState {
	UNDISCOVERED,
	DISCOVERED,
	RECORDED,
	ANALYZED,
	LINKED
}

# 15字段线索数据结构
class ClueData:
	var id: String
	var name: String
	var description: String
	var category: String           # 物证/证言/文件/痕迹
	var location: String           # 发现地点
	var discovery_condition: String # 发现条件
	var observation: String        # 观察记录
	var analysis: String           # 分析结果
	var related_clues: Array       # 关联线索ID列表
	var related_npcs: Array        # 关联NPC列表
	var timeline_position: float   # 时间线位置
	var importance: int            # 重要度 1-5
	var is_key_evidence: bool      # 是否关键证据
	var state: ClueState
	var discovery_time: String

var discovered_clues: Dictionary = {}  # clue_id -> ClueData
var clue_count: int = 0

func _ready() -> void:
	pass

func load_clue(clue_id: String) -> ClueData:
	if discovered_clues.has(clue_id):
		return discovered_clues[clue_id]
	var clue_data = load("res://data/clues/%s.tres" % clue_id)
	# TODO: 从 .tres 资源中解析 ClueData
	return null

func discover_clue(clue_id: String) -> void:
	if discovered_clues.has(clue_id):
		return
	var clue = load_clue(clue_id)
	if clue:
		clue.state = ClueState.DISCOVERED
		discovered_clues[clue_id] = clue
		clue_count += 1
		ClueEventBus.emit_signal("clue_discovered", clue_id)

func record_clue(clue_id: String) -> void:
	if not discovered_clues.has(clue_id):
		return
	discovered_clues[clue_id].state = ClueState.RECORDED
	ClueEventBus.emit_signal("clue_recorded", clue_id)

func link_clues(clue_a: String, clue_b: String) -> void:
	if discovered_clues.has(clue_a) and discovered_clues.has(clue_b):
		discovered_clues[clue_a].related_clues.append(clue_b)
		discovered_clues[clue_b].related_clues.append(clue_a)
		discovered_clues[clue_a].state = ClueState.LINKED
		discovered_clues[clue_b].state = ClueState.LINKED
		ClueEventBus.emit_signal("clues_linked", clue_a, clue_b)

func get_discovered_count() -> int:
	return clue_count

func get_total_clues() -> int:
	# TODO: 从案件数据中获取总线索数
	return 45  # 血字的研究：45条线索

## 存档：导出所有已发现线索的状态（clue_id -> ClueState 整数）
func get_clue_states() -> Dictionary:
	var states: Dictionary = {}
	for clue_id in discovered_clues.keys():
		states[clue_id] = discovered_clues[clue_id].state
	return states

## 存档：从字典恢复线索状态（不依赖 .tres 解析，直接重建内存态）
func restore_clue_states(states: Dictionary) -> void:
	discovered_clues.clear()
	for clue_id in states.keys():
		var cd = ClueData.new()
		cd.id = clue_id
		cd.state = int(states[clue_id])
		discovered_clues[clue_id] = cd
	clue_count = discovered_clues.size()
