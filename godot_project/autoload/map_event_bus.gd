extends Node

## MapEventBus - 地图事件总线
## 负责地图加载/地点标记/迷雾解锁等事件的发布与订阅

# 地点解锁事件（location_id: 被解锁的地点 ID）
signal location_unlocked(location_id: String)

func _ready() -> void:
	pass
