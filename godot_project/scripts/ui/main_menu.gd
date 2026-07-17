extends Control
class_name MainMenu

## MainMenu - 游戏主菜单
## 标题界面、开始/继续/设置/退出

@onready var title_label: Label = $TitleContainer/TitleLabel
@onready var subtitle_label: Label = $TitleContainer/SubtitleLabel
@onready var start_btn: Button = $MenuContainer/StartBtn
@onready var continue_btn: Button = $MenuContainer/ContinueBtn
@onready var settings_btn: Button = $MenuContainer/SettingsBtn
@onready var quit_btn: Button = $MenuContainer/QuitBtn
@onready var version_label: Label = $VersionLabel
@onready var bg_panel: Panel = $BackgroundPanel
@onready var anim_player: AnimationPlayer = $AnimationPlayer

var has_save: bool = false

func _ready() -> void:
	_setup_ui()
	_connect_buttons()
	_check_save()
	_play_enter_animation()

func _setup_ui() -> void:
	# 标题
	title_label.text = "维多利亚伦敦探案"
	subtitle_label.text = "SHERLOCK HOLMES: THE CASE OF THE CRIMSON LETTER"
	
	# 按钮文本
	start_btn.text = "开始游戏"
	continue_btn.text = "继续游戏"
	settings_btn.text = "设置"
	quit_btn.text = "退出游戏"
	
	# 版本号
	version_label.text = "v" + ProjectSettings.get_setting("application/config/version")

func _connect_buttons() -> void:
	start_btn.pressed.connect(_on_start_pressed)
	continue_btn.pressed.connect(_on_continue_pressed)
	settings_btn.pressed.connect(_on_settings_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)

func _check_save() -> void:
	# 检查是否有存档
	if GameManager.is_guest:
		has_save = FileAccess.file_exists("user://save_game.json")
	else:
		has_save = false  # TODO: 检查云端存档
	
	continue_btn.visible = has_save
	continue_btn.disabled = not has_save

func _play_enter_animation() -> void:
	if anim_player and anim_player.has_animation("fade_in"):
		anim_player.play("fade_in")

func _on_start_pressed() -> void:
	AudioManager.play_sfx("ui_confirm.wav")
	
	# 游客模式直接开始
	if GameManager.is_guest:
		_start_new_game()
	else:
		_start_new_game()

func _on_continue_pressed() -> void:
	AudioManager.play_sfx("ui_confirm.wav")
	
	var loaded = await SaveManager.load_game()
	if loaded:
		# 加载存档后跳转到对应场景
		if GameManager.current_case_id != "":
			GameManager.start_case(GameManager.current_case_id)
		else:
			get_tree().change_scene_to_file("res://scenes/game_scene.tscn")
	else:
		UIManager.show_notification("没有找到存档文件")

func _on_settings_pressed() -> void:
	AudioManager.play_sfx("ui_click.wav")
	UIManager.open_screen(UIManager.UIScreen.SETTINGS)
	# TODO: 打开设置界面

func _on_quit_pressed() -> void:
	AudioManager.play_sfx("ui_click.wav")
	get_tree().quit()

func _start_new_game() -> void:
	# 显示难度选择界面
	var difficulty_scene = load("res://scenes/difficulty_select.tscn")
	if difficulty_scene:
		var diff_select = difficulty_scene.instantiate()
		get_tree().root.add_child(diff_select)
		
		# 连接难度选择信号
		diff_select.difficulty_selected.connect(func(_d):
			diff_select.queue_free()
		)
	else:
		# 回退：直接开始
		GameManager.start_case("case_01_study")
		get_tree().change_scene_to_file("res://scenes/game_scene.tscn")
