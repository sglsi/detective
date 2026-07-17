class_name HotspotData
extends Resource

## HotspotData - 热点数据资源
## 场景中可交互的观察/对话/检查区域

@export var id: String = ""
@export var label: String = ""
@export var description: String = ""
@export var position: Vector2 = Vector2.ZERO
@export var size: Vector2 = Vector2(100, 50)
@export var is_visible: bool = true
@export var is_correct: bool = true      # true=正确线索, false=干扰项
@export var hotspot_type: String = "observe"  # observe/talk/examine
@export var required_tool: String = "magnifier"  # magnifier/tape/none
