extends Node

## CaseEventBus - 案件事件总线
## 负责案件加载/切换/进度变更等事件的发布与订阅

# ============ 案件生命周期事件 ============
signal case_started(case_id: String)
signal case_loaded(case_id: String)

func _ready() -> void:
	pass
