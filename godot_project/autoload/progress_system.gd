extends Node

## ProgressSystem — 调查进度系统（P2-2）
## 事件驱动：场景登记进度节点，完成节点推进计数；同时自动从 ClueSystem 统计线索发现率。
## 不采用硬性时间计量（时间仅作沉浸表现层，由 TimelineSystem 负责）。
## 设计基准：00_核心设计思路 B-5 / 09审核报告 P0-5（TimelineSystem→ProgressSystem）

var case_nodes: Dictionary = {}   # case_id -> {"total":int, "done":Dictionary(node_id->true)}

func _ready() -> void:
	if CaseEventBus:
		CaseEventBus.case_started.connect(_on_case_started)
	if ClueEventBus:
		ClueEventBus.clue_discovered.connect(_on_clue_discovered)

func _on_case_started(case_id: String) -> void:
	if not case_nodes.has(case_id):
		var total := 8
		if ClueSystem and ClueSystem.get_total_clues() > 0:
			total = ClueSystem.get_total_clues()
		register_case(case_id, total)

func _on_clue_discovered(_clue_id: String) -> void:
	var cid := GameManager.current_case_id if GameManager else ""
	if cid == "":
		return
	_emit_progress(cid)

## 登记案件进度节点总数（场景调用，覆盖默认）
func register_case(case_id: String, total_nodes: int) -> void:
	if not case_nodes.has(case_id):
		case_nodes[case_id] = {"total": total_nodes, "done": {}}
	else:
		case_nodes[case_id]["total"] = total_nodes
	_emit_progress(case_id)

## 完成一个进度节点
func complete_node(case_id: String, node_id: String) -> void:
	if not case_nodes.has(case_id):
		case_nodes[case_id] = {"total": 8, "done": {}}
	case_nodes[case_id]["done"][node_id] = true
	_emit_progress(case_id)

func get_progress(case_id: String) -> Dictionary:
	var entry = case_nodes.get(case_id, {"total": 0, "done": {}})
	var total: int = entry["total"]
	var current: int = entry["done"].size()
	var node_ratio: float = float(current) / float(total) if total > 0 else 0.0
	var clue_ratio: float = _clue_ratio()
	var overall: float = (node_ratio + clue_ratio) * 0.5
	node_ratio = clampf(node_ratio, 0.0, 1.0)
	overall = clampf(overall, 0.0, 1.0)
	return {"current": current, "total": total, "node_ratio": node_ratio, "clue_ratio": clue_ratio, "ratio": overall}

func get_all_progress() -> Dictionary:
	var out := {}
	for cid in case_nodes.keys():
		out[cid] = get_progress(cid)
	return out

func restore_progress(data: Dictionary) -> void:
	if typeof(data) == TYPE_DICTIONARY:
		case_nodes = data.duplicate()

func _clue_ratio() -> float:
	if not ClueSystem:
		return 0.0
	var total := ClueSystem.get_total_clues()
	if total <= 0:
		return 0.0
	return clampf(float(ClueSystem.count_collected()) / float(total), 0.0, 1.0)

func _emit_progress(case_id: String) -> void:
	if SystemEventBus:
		var p := get_progress(case_id)
		SystemEventBus.emit_signal("progress_updated", case_id, p["current"], p["total"], p["ratio"])
