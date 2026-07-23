extends CharacterBody2D
## 像素风格福尔摩斯角色控制器
## 基于像素艺术精灵表，支持多种动画状态

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# 移动速度
@export var move_speed: float = 100.0
# 当前状态
var current_state: String = "idle"

func _ready() -> void:
	# 初始化动画
	play_animation("idle")

func _physics_process(delta: float) -> void:
	# 获取输入
	var direction: Vector2 = Vector2.ZERO
	
	if Input.is_action_pressed("ui_right"):
		direction.x += 1
	elif Input.is_action_pressed("ui_left"):
		direction.x -= 1
	
	if Input.is_action_pressed("ui_down"):
		direction.y += 1
	elif Input.is_action_pressed("ui_up"):
		direction.y -= 1
	
	# 移动
	if direction != Vector2.ZERO:
		direction = direction.normalized()
		velocity = direction * move_speed
		play_animation("walk")
	else:
		velocity = velocity.move_toward(Vector2.ZERO, move_speed)
		if current_state == "walk":
			play_animation("idle")
	
	move_and_slide()

## 播放指定动画
func play_animation(anim_name: String) -> void:
	if current_state == anim_name:
		return
	
	current_state = anim_name
	
	if animated_sprite.has_animation(anim_name):
		animated_sprite.play(anim_name)

## 播放思考动画
func play_think() -> void:
	play_animation("think")

## 播放检查动画
func play_inspect() -> void:
	play_animation("inspect")

## 播放指向动画
func play_point() -> void:
	play_animation("point")

## 设置角色朝向
func set_facing_right(facing_right: bool) -> void:
	animated_sprite.flip_h = not facing_right
