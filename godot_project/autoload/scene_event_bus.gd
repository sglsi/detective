extends Node

## SceneEventBus - 场景事件总线
## 负责场景切换/进入/离开/热点交互/工具使用等事件的发布与订阅

# ============ 场景生命周期 ============
signal scene_changed(scene_id: String)
signal scene_loaded(scene_id: String)
signal view_changed(view_name: String)

# ============ 热点与观察 ============
signal hotspot_clicked(hotspot_id: String)

# ============ 工具操作 ============
signal tool_requested(tool_name: String)
signal tool_used(tool_name: String)

# ============ 笔记 ============
signal note_recorded(note_text: String)

func _ready() -> void:
	pass
