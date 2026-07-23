extends Control
class_name MainMenuV2

## MainMenuV2 - 维多利亚风格主菜单
## 基于设计文档 06_主界面设计方案.md 实现
## 7层图层结构：纸张底图 → 城市背景 → 暗角 → 标题 → 按钮 → 装饰

@onready var continue_btn: Button = $Layer5_ButtonContainer/ContinueBtn
@onready var new_case_btn: Button = $Layer5_ButtonContainer/NewCaseBtn
@onready var casebook_btn: Button = $Layer5_ButtonContainer/CasebookBtn
@onready var options_btn: Button = $Layer5_ButtonContainer/HBoxContainer/OptionsBtn
@onready var quit_btn: Button = $Layer5_ButtonContainer/HBoxContainer/QuitBtn
@onready var register_btn: Button = $AuthContainer/RegisterBtn
@onready var login_btn: Button = $AuthContainer/LoginBtn
@onready var version_label: Label = $VersionLabel
@onready var title_en: Label = $Layer4_TitleContainer/TitleEN
@onready var subtitle_en: Label = $Layer4_TitleContainer/SubtitleEN
@onready var subtitle_cn: Label = $Layer4_TitleContainer/SubtitleCN
@onready var anim_player: AnimationPlayer = $AnimationPlayer

var has_save: bool = false

func _ready() -> void:
	_setup_ui()
	_connect_buttons()
	_check_save()
	_play_enter_animation()

func _setup_ui() -> void:
	# 版本号
	var version = ProjectSettings.get_setting("application/config/version", "0.1")
	version_label.text = "v" + version + " Alpha"

func _connect_buttons() -> void:
	continue_btn.pressed.connect(_on_continue_pressed)
	new_case_btn.pressed.connect(_on_new_case_pressed)
	casebook_btn.pressed.connect(_on_casebook_pressed)
	options_btn.pressed.connect(_on_options_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)
	register_btn.pressed.connect(_on_register_pressed)
	login_btn.pressed.connect(_on_login_pressed)

func _check_save() -> void:
	# 检查是否有存档
	if GameManager and GameManager.has_method("is_guest"):
		has_save = FileAccess.file_exists("user://save_game.json")
	else:
		has_save = FileAccess.file_exists("user://save_game.json")
	
	# 根据存档状态显示/隐藏继续按钮
	continue_btn.visible = has_save
	if has_save:
		# 有存档时，继续调查按钮显示在最上方
		continue_btn.show()

func _play_enter_animation() -> void:
	# 简单的淡入动画
	if anim_player:
		var anim = Animation.new()
		anim.length = 1.0
		
		# 创建淡入轨道
		var track_idx = anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(track_idx, ".:modulate")
		anim.track_insert_key(track_idx, 0.0, Color(1, 1, 1, 0))
		anim.track_insert_key(track_idx, 1.0, Color(1, 1, 1, 1))
		
		var anim_lib = AnimationLibrary.new()
		anim_lib.add_animation("fade_in", anim)
		anim_player.add_animation_library("", anim_lib)
		anim_player.play("fade_in")

# === 按钮回调 ===

func _on_continue_pressed() -> void:
	AudioManager.play_sfx("ui_click.wav") if AudioManager else null
	# 读取存档并继续游戏
	_load_game()

func _on_new_case_pressed() -> void:
	AudioManager.play_sfx("ui_click.wav") if AudioManager else null
	# 进入难度选择或案件选择
	get_tree().change_scene_to_file("res://scenes/difficulty_select.tscn")

func _on_casebook_pressed() -> void:
	AudioManager.play_sfx("ui_click.wav") if AudioManager else null
	# 打开案件档案（TODO: 实现案件档案界面）
	print("打开案件档案")

func _on_options_pressed() -> void:
	AudioManager.play_sfx("ui_click.wav") if AudioManager else null
	# 打开设置界面（TODO: 实现设置界面）
	print("打开设置")

func _on_quit_pressed() -> void:
	AudioManager.play_sfx("ui_click.wav") if AudioManager else null
	if OS.has_feature("web") or OS.get_name() == "Web":
		# Web 导出无真正进程退出，直接重载页面回到标题
		JavaScriptBridge.eval("window.location.reload()")
	else:
		get_tree().quit()

func _on_register_pressed() -> void:
	AudioManager.play_sfx("ui_click.wav") if AudioManager else null
	_open_auth("register")

func _on_login_pressed() -> void:
	AudioManager.play_sfx("ui_click.wav") if AudioManager else null
	_open_auth("login")

func _open_auth(mode: String) -> void:
	# 打开认证面板
	if AuthPanel:
		var panel = AuthPanel.new()
		if mode == "login":
			panel.set_mode("login")
		else:
			panel.set_mode("register")
		get_tree().root.add_child(panel)

func _load_game() -> void:
	# 加载存档
	if SaveManager:
		var save_data = SaveManager.load_local_save()
		if save_data:
			# 根据存档数据加载对应场景
			var scene_path = save_data.get("current_scene", "res://scenes/game_scene.tscn")
			get_tree().change_scene_to_file(scene_path)
		else:
			# 存档加载失败，进入新游戏
			get_tree().change_scene_to_file("res://scenes/difficulty_select.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/difficulty_select.tscn")

# === 输入处理 ===

func _input(event: InputEvent) -> void:
	# ESC 键返回（主菜单无上级，可忽略或退出）
	if event.is_action_pressed("ui_cancel"):
		# 可选：弹出确认退出对话框
		pass
