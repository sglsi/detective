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

	easy_btn.mouse_entered.connect(_show_desc.bind(DifficultyManager.Difficulty.EASY))
	normal_btn.mouse_entered.connect(_show_desc.bind(DifficultyManager.Difficulty.NORMAL))
	hard_btn.mouse_entered.connect(_show_desc.bind(DifficultyManager.Difficulty.HARD))

	_play_enter_animation()
	_show_desc(DifficultyManager.Difficulty.NORMAL)


func _show_desc(difficulty: int) -> void:
	var desc := DifficultyManager.get_difficulty_description(difficulty)
	var label = get_node_or_null("Panel/DescriptionLabel")
	if label == null:
		label = Label.new()
		label.name = "DescriptionLabel"
		label.position = Vector2(610, 700)
		label.size = Vector2(700, 120)
		label.horizontal_alignment = 1
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", Color(0.85, 0.72, 0.50))
		$Panel.add_child(label)
	label.text = desc

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
	# 首次进入困难模式：先弹一次性提醒（干扰项需甄别），确认后再进入
	if difficulty == DifficultyManager.Difficulty.HARD and not DifficultyManager.is_hard_mode_warned():
		_show_hard_mode_warning(difficulty)
		return
	_apply_difficulty(difficulty)

func _apply_difficulty(difficulty: int) -> void:
	var names = ["简单", "普通", "困难"]
	print("[DifficultySelect] 选择难度: %s" % names[difficulty])
	DifficultyManager.set_difficulty(difficulty)
	difficulty_selected.emit(difficulty)
	GameManager.start_case("case_blood_letter")
	SceneLoader.transition_to("res://scenes/scene1.tscn")

## 困难模式首次提醒弹窗：说明线索含干扰项、需甄别判断（不扣分但走弯路）。
## 仅在「首次」通过 ConfigFile 持久化标记，之后不再弹出。
func _show_hard_mode_warning(difficulty: int) -> void:
	var warn := Control.new()
	warn.name = "HardModeWarning"
	warn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	warn.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(warn)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	warn.add_child(dim)
	var f := Panel.new()
	f.size = Vector2(680, 380)
	f.position = Vector2((1920 - 680) / 2.0, (1080 - 380) / 2.0)
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = Color(0.13, 0.10, 0.07, 0.98)
	fsb.border_color = Color(0.82, 0.62, 0.28, 1)
	fsb.border_width_left = 3; fsb.border_width_right = 3; fsb.border_width_top = 3; fsb.border_width_bottom = 3
	fsb.set_corner_radius_all(10)
	f.add_theme_stylebox_override("panel", fsb)
	warn.add_child(f)
	var t := Label.new()
	t.text = "⚠  困难模式提示"
	t.add_theme_font_size_override("font_size", 30)
	t.add_theme_color_override("font_color", Color(0.95, 0.78, 0.30))
	t.position = Vector2(40, 30); t.size = Vector2(600, 44)
	f.add_child(t)
	var body := Label.new()
	body.text = "困难模式下，线索中会混入干扰项（约 70% 的线索可能为误导），需要你自行甄别、判断真伪。\n\n错误推理不会扣分，但会多走一段弯路。祝你推理顺利！"
	body.add_theme_font_size_override("font_size", 19)
	body.add_theme_color_override("font_color", Color(0.86, 0.80, 0.66))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.position = Vector2(40, 96); body.size = Vector2(600, 180)
	f.add_child(body)
	var ok := Button.new()
	ok.text = "我明白了，开始挑战"
	ok.icon = load("res://assets/ui/icons/deerstalker.png")
	ok.add_theme_constant_override("icon_max_width", 30)
	ok.position = Vector2(190, 300); ok.size = Vector2(300, 52)
	ok.add_theme_font_size_override("font_size", 22)
	ok.add_theme_color_override("font_color", Color(0.92, 0.84, 0.55))
	var ob := StyleBoxFlat.new()
	ob.bg_color = Color(0.30, 0.10, 0.10, 0.95)
	ob.border_color = Color(0.85, 0.65, 0.25, 1)
	ob.border_width_left = 2; ob.border_width_right = 2; ob.border_width_top = 2; ob.border_width_bottom = 2
	ob.set_corner_radius_all(4)
	ok.add_theme_stylebox_override("normal", ob)
	ok.pressed.connect(func():
		DifficultyManager.mark_hard_mode_warned()
		warn.queue_free()
		_apply_difficulty(difficulty)
	)
	f.add_child(ok)
