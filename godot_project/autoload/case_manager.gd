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
	var path = "res://data/cases/%s.tres" % case_id
	if not ResourceLoader.exists(path):
		return {}
	var c = load(path)
	if c == null:
		return {}
	current_case = {
		"id": case_id,
		"title": c.title if c is CaseData else "",
		"scenes": c.scenes if c is CaseData else [],
		"clues": c.clues if c is CaseData else [],
		"npcs": c.npcs if c is CaseData else [],
	}
	CaseEventBus.emit_signal("case_loaded", case_id)
	return current_case

func get_case_list() -> Array:
	var cases: Array = []
	var dir = DirAccess.open("res://data/cases/")
	if dir == null:
		return cases
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if fname.ends_with(".tres") and not fname.begins_with("."):
			var c = load("res://data/cases/" + fname)
			if c != null:
				cases.append({
					"id": c.id if c is CaseData else fname.get_basename(),
					"title": c.title if (c is CaseData and c.title != "") else fname.get_basename(),
				})
		fname = dir.get_next()
	dir.list_dir_end()
	return cases

func set_scene(scene_id: String) -> void:
	GameManager.current_scene_id = scene_id
	SceneEventBus.emit_signal("scene_changed", scene_id)

func get_available_locations() -> Array:
	return unlocked_locations
