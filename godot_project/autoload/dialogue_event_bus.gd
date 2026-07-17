extends Node

## DialogueEventBus - 对话事件总线
## 负责对话树推进/选项选择/NPC交互等事件的发布与订阅

signal dialogue_trigger(node_id: String)
signal dialogue_finished
signal node_entered(node_id: String)
signal step_entered(step: int)

func _ready() -> void:
	pass
