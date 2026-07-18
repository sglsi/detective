extends Node

## MapManager — 地图/地点状态管理器（P5-1 新增）
## 跟踪玩家已解锁的地点，供存档收集/恢复使用。
## 设计为与前端的 MapEventBus 解耦的轻量全局状态源，避免依赖尚未实现的地图场景。

# ============ 数据 ============

var unlocked_locations: Array = []  # 已解锁地点 ID 列表

# ============ 生命周期 ============

func _ready() -> void:
	# 初始默认解锁起点地点（若存在 MapEventBus 则发布事件）
	if MapEventBus:
		pass

# ============ 解锁逻辑 ============

## 解锁一个地点（去重）；返回是否本次新解锁
func unlock_location(location_id: String) -> bool:
	if unlocked_locations.has(location_id):
		return false
	unlocked_locations.append(location_id)
	if MapEventBus:
		MapEventBus.emit_signal("location_unlocked", location_id)
	return true

## 查询某地点是否已解锁
func is_location_unlocked(location_id: String) -> bool:
	return unlocked_locations.has(location_id)

## 获取全部已解锁地点（供存档收集）
func get_unlocked_locations() -> Array:
	return unlocked_locations.duplicate()

## 从存档数组恢复已解锁地点（供读档恢复）
func restore_unlocked_locations(locations: Array) -> void:
	unlocked_locations.clear()
	for loc in locations:
		if not unlocked_locations.has(loc):
			unlocked_locations.append(loc)
