extends Control
class_name DifficultySelect

## DifficultySelect — 难度选择界面
## 主菜单 → 选择难度 → 进入游戏场景

signal difficulty_selected(difficulty: int)

@onready var easy_btn: Button = $Panel/EasyBtn
@onready var normal_btn: Button = $Panel/NormalBtn
@onready var hard_btn: Button = $Panel/HardBtn

func _ready() -> void:
	easy_btn.pressed.connect(_on_easy_selected)
	normal_btn.pressed.connect(_on_normal_selected)
	hard_btn.pressed.connect(_on_hard_selected)
	
	_play_enter_animation()

func _play_enter_animation() -> void:
	modulate = Color(1, 1, 1, 0)
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.4)

func _on_easy_selected() -> void:
	_confirm_difficulty(DifficultyManager.Difficulty.EASY)

func _on_normal_selected() -> void:
	_confirm_difficulty(DifficultyManager.Difficulty.NORMAL)

func _on_hard_selected() -> void:
	_confirm_difficulty(DifficultyManager.Difficulty.HARD)

func _confirm_difficulty(difficulty: int) -> void:
	var names = ["简单", "普通", "困难"]
	print("[DifficultySelect] 选择难度: %s" % names[difficulty])
	
	# 设置难度
	DifficultyManager.set_difficulty(difficulty)
	
	# 发射信号
	difficulty_selected.emit(difficulty)
	
	# 进入游戏场景
	GameManager.start_case("case_01_study")
	get_tree().change_scene_to_file("res://scenes/game_scene.tscn")
