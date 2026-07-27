extends Node

## TimelineSystem — 叙事时间线（P2-2 氛围层）
## 纯叙事表现层：按事件链记录案件进程里程碑（仅作沉浸，不参与玩法判定）。
## 设计基准：09审核报告 P0-5（叙事时间线与进度推进解耦，时间仅作氛围标签）

var timeline_entries: Dictionary = {}   # case_id -> Array[{time_label, text}]

func _ready() -> void:
	if CaseEventBus:
		CaseEventBus.case_started.connect(_on_case_started)
	if SystemEventBus:
		SystemEventBus.case_completed.connect(_on_case_completed)

func _on_case_started(case_id: String) -> void:
	add_entry(case_id, "案件开始调查", "09:00")

func _on_case_completed(case_id: String, _stars: Dictionary) -> void:
	add_entry(case_id, "案件侦破完成", "结案")

## 追加一条时间线条目（time_label 为游戏内小时制，仅氛围）
func add_entry(case_id: String, text: String, time_label: String = "") -> void:
	if not timeline_entries.has(case_id):
		timeline_entries[case_id] = []
	timeline_entries[case_id].append({"time_label": time_label, "text": text})
	if SystemEventBus:
		SystemEventBus.emit_signal("timeline_updated", case_id, get_entries(case_id))

func get_entries(case_id: String) -> Array:
	return timeline_entries.get(case_id, []).duplicate()

func get_all_entries() -> Dictionary:
	return timeline_entries.duplicate()

func restore_timeline(data: Dictionary) -> void:
	if typeof(data) == TYPE_DICTIONARY:
		timeline_entries = data.duplicate()
