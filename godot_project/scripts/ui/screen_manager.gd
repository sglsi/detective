extends Control
class_name ScreenManager

## ScreenManager - 屏幕管理器
## 管理场景加载、转场动画、加载画面

@onready var transition_rect: ColorRect = $TransitionRect
@onready var loading_label: Label = $LoadingLabel
@onready var anim_player: AnimationPlayer = $AnimationPlayer

var current_scene: String = ""
var is_transitioning: bool = false

func _ready() -> void:
	transition_rect.color = Color(0, 0, 0, 0)
	loading_label.hide()

func change_scene(scene_path: String, fade_duration: float = 0.5) -> void:
	if is_transitioning:
		return
	
	is_transitioning = true
	current_scene = scene_path
	
	# 淡出
	await _fade_out(fade_duration)
	
	# 显示加载提示
	loading_label.show()
	loading_label.text = "正在加载..."
	
	# 切换场景
	var err = get_tree().change_scene_to_file(scene_path)
	if err != OK:
		push_error("场景切换失败: %s (error: %d)" % [scene_path, err])
		loading_label.text = "加载失败"
		await get_tree().create_timer(2.0).timeout
	
	# 淡入
	await get_tree().create_timer(0.3).timeout
	loading_label.hide()
	await _fade_in(fade_duration)
	
	is_transitioning = false

func change_scene_with_loading(scene_path: String, message: String = "正在加载...") -> void:
	if is_transitioning:
		return
	
	is_transitioning = true
	current_scene = scene_path
	
	# 淡出
	await _fade_out(0.3)
	
	# 显示加载画面
	loading_label.text = message
	loading_label.show()
	
	# 模拟加载过程（实际项目中用 ResourceLoader.load_interactive）
	await get_tree().create_timer(1.0).timeout
	
	# 切换
	get_tree().change_scene_to_file(scene_path)
	
	# 淡入
	await get_tree().create_timer(0.2).timeout
	loading_label.hide()
	await _fade_in(0.5)
	
	is_transitioning = false

func _fade_out(duration: float) -> void:
	if anim_player and anim_player.has_animation("fade_out"):
		anim_player.play("fade_out")
		await anim_player.animation_finished
	else:
		var tween = create_tween()
		tween.tween_property(transition_rect, "color", Color(0, 0, 0, 1), duration)

func _fade_in(duration: float) -> void:
	if anim_player and anim_player.has_animation("fade_in"):
		anim_player.play("fade_in")
		await anim_player.animation_finished
	else:
		var tween = create_tween()
		tween.tween_property(transition_rect, "color", Color(0, 0, 0, 0), duration)
