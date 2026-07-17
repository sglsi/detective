extends Control
class_name TopBar

## TopBar - 顶部状态栏
## 显示场景名称、游戏内时间、设置按钮

@onready var scene_label: Label = $SceneLabel
@onready var time_label: Label = $TimeLabel
@onready var menu_btn: Button = $MenuBtn
@onready var difficulty_label: Label = $DifficultyLabel

func _ready() -> void:
	SceneEventBus.connect("scene_changed", _on_scene_changed)
	SystemEventBus.connect("difficulty_changed", _on_difficulty_changed)
	menu_btn.pressed.connect(_on_menu_pressed)

func set_scene_name(name: String) -> void:
	scene_label.text = name

func set_time(time_str: String) -> void:
	time_label.text = time_str

func set_difficulty(diff: int) -> void:
	var names = ["🔰 简单", "⚖️ 普通", "💀 困难"]
	if diff < names.size():
		difficulty_label.text = names[diff]

func _on_scene_changed(scene_id: String) -> void:
	# 根据场景 ID 更新显示
	var scene_names = {
		"sc_01_lab": "贝克街221B — 实验室",
		"sc_02_lauriston": "劳瑞斯顿花园街 — 室外",
		"sc_03_lauriston_in": "劳瑞斯顿花园街 — 室内",
		"sc_04_audley": "奥德利大院",
		"sc_05_parlor": "贝克街221B — 会客厅",
	}
	if scene_names.has(scene_id):
		scene_label.text = scene_names[scene_id]

func _on_difficulty_changed(diff: int) -> void:
	set_difficulty(diff)

func _on_menu_pressed() -> void:
	UIManager.open_screen(UIManager.UIScreen.SETTINGS)
