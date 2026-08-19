extends Node

## ClueEventBus - 线索事件总线
## 负责线索发现/记录/关联/验证等事件的发布与订阅

signal clue_discovered(clue_id: String)
signal clue_recorded(clue_id: String)
signal clues_linked(clue_a: String, clue_b: String)
signal verification_complete(result: int)

func _ready() -> void:
	pass
