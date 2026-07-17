extends Node

## CaseManager - 案件管理器
## 负责案件数据的加载、进度跟踪、场景切换

var current_case: Dictionary = {}
var case_progress: Dictionary = {}
var unlocked_locations: Array = []
var completed_milestones: Array = []

func _ready() -> void:
	pass

func load_case(case_id: String) -> Dictionary:
	var case_data = load("res://data/cases/%s.tres" % case_id)
	current_case = {
		"id": case_id,
		"title": "",
		"scenes": [],
		"clues": [],
		"npcs": [],
	}
	CaseEventBus.emit_signal("case_loaded", case_id)
	return current_case

func get_case_list() -> Array:
	var cases: Array = []
	# TODO: 扫描 data/cases/ 目录获取可用案件列表
	return cases

func set_scene(scene_id: String) -> void:
	GameManager.current_scene_id = scene_id
	SceneEventBus.emit_signal("scene_changed", scene_id)

func get_available_locations() -> Array:
	return unlocked_locations
