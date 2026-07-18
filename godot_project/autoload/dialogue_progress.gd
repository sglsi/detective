extends Node

## DialogueProgress — 对话进度聚合器（P5-1 新增）
## 由于 DialogueManager 是每场景实例、非全局 autoload，
## 这里提供一个全局聚合源，接收各场景对话节点访问记录，
## 供 SaveManager 收集/恢复对话进度，避免依赖具体场景实例生命周期。

# ============ 数据 ============

## scene_id -> 该场景已访问过的对话节点 ID 列表（去重后）
var progress: Dictionary = {}

# ============ 记录 ============

## 记录某场景访问了一个对话节点
func record_node(scene_id: String, node_id: String) -> void:
	if not progress.has(scene_id):
		progress[scene_id] = []
	if not progress[scene_id].has(node_id):
		progress[scene_id].append(node_id)

## 查询某场景已访问的节点列表
func get_scene_progress(scene_id: String) -> Array:
	if progress.has(scene_id):
		return progress[scene_id].duplicate()
	return []

## 查询某场景是否访问过某节点
func has_visited(scene_id: String, node_id: String) -> bool:
	return progress.has(scene_id) and progress[scene_id].has(node_id)

## 导出全部对话进度（供存档收集）
func get_dialogue_progress() -> Dictionary:
	var snapshot: Dictionary = {}
	for scene_id in progress.keys():
		snapshot[scene_id] = progress[scene_id].duplicate()
	return snapshot

## 从存档字典恢复对话进度（供读档恢复）
func restore_dialogue_progress(data: Dictionary) -> void:
	progress.clear()
	for scene_id in data.keys():
		var nodes = data[scene_id]
		if typeof(nodes) == TYPE_ARRAY:
			progress[scene_id] = nodes.duplicate()
