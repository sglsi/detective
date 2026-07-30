class_name PortraitMicroAnimator
extends Node

## PortraitMicroAnimator — 立绘微动组件（纯属性动画，无美术依赖）
##
## 让静态 PNG 立绘呈现"活人感"：
##   - 呼吸：scale.y 轻微正弦缩放（绕中心，pivot 已置中，不偏移）
##   - 浮动：position.y 正弦位移（说话时加大/加快）
##   - 微旋转：rotation 微小摆动（站立角色在金框内微摆，避免裁边）
##
## 用法：
##   var a := PortraitMicroAnimator.new()
##   add_child(a)
##   a.setup(texture_rect)            # 绑定目标，自动捕获 home 位置与随机相位
##   a.set_talking(true)              # 说话时调用，加大浮动
##   a.set_home(new_pos)              # 外部改了立绘位置后刷新基准
##
## 注意：目标必须是 TextureRect（或任何有 size/position/scale/rotation 的 CanvasItem）。
##       站立角色建议关 float_enabled、开 sway_enabled，避免浮动露出金框边。

# ============ 可调参数 ============

@export var enabled: bool = true
@export var breathe_amplitude: float = 0.02      # 呼吸缩放幅度（scale.y）
@export var breathe_speed: float = 1.6           # 呼吸频率（rad/s 量级）
@export var float_enabled: bool = true
@export var float_amplitude: float = 4.0         # 浮动位移（像素）
@export var float_speed: float = 0.8             # 浮动频率
@export var talk_bob_extra: float = 6.0          # 说话时额外浮动幅度
@export var talk_speed_mult: float = 1.8         # 说话时浮动频率倍率
@export var sway_enabled: bool = false
@export var sway_amplitude_deg: float = 0.6      # 微旋转幅度（度）
@export var sway_speed: float = 0.7              # 微旋转频率

# ============ 内部状态 ============

var _target: TextureRect = null
var _phase: float = 0.0
var _t: float = 0.0
var _talking: bool = false
var _home: Vector2 = Vector2.ZERO
var _last_size: Vector2 = Vector2.ZERO

# ============ 接口 ============

## 绑定目标立绘，捕获 home 位置并随机化相位（避免群体同呼吸）
func setup(target: TextureRect) -> void:
	_target = target
	_phase = randf() * TAU
	_home = target.position
	_recompute_pivot()

## 说话状态切换：加大/加快浮动
func set_talking(on: bool) -> void:
	_talking = on

## 外部改了立绘位置后刷新基准（如左下/右上切换）
func set_home(pos: Vector2) -> void:
	_home = pos

# ============ 运行 ============

func _recompute_pivot() -> void:
	if _target == null:
		return
	var s := _target.size
	if s != _last_size:
		_target.pivot_offset = s * 0.5
		_last_size = s

func _process(delta: float) -> void:
	if not enabled or _target == null or not _target.visible:
		return
	_recompute_pivot()
	_t += delta

	# 呼吸：scale.y 正弦，绕中心缩放（pivot 已置中）
	var breath := sin(_t * breathe_speed + _phase) * breathe_amplitude
	_target.scale = Vector2(1.0, 1.0 + breath)

	# 浮动：position.y 正弦偏移（说话时加大且加快）
	if float_enabled:
		var amp := float_amplitude + (talk_bob_extra if _talking else 0.0)
		var spd := float_speed * (talk_speed_mult if _talking else 1.0)
		_target.position.y = _home.y + sin(_t * spd + _phase) * amp

	# 微旋转：在金框内轻微摆动（站立角色用，避免裁边）
	if sway_enabled:
		_target.rotation = sin(_t * sway_speed + _phase * 1.3) * deg_to_rad(sway_amplitude_deg)
