extends Node
## 福尔摩斯全身立绘抽烟动画控制器
## 将 smoke00-07 序列按指定帧率循环切换目标 TextureRect 的 texture。
## 设计为挂到立绘 Control 下的子节点，由 scene1.gd 在开场对话阶段启停。

@export var target: TextureRect
@export var frames: Array[Texture2D] = []
@export var fps: float = 4.0
@export var loop: bool = true
@export var auto_play: bool = false

var _timer: Timer = null
var _idx: int = 0
var _playing: bool = false

signal cycle_finished

func _ready() -> void:
	if target == null and get_parent() is TextureRect:
		target = get_parent()
	_timer = Timer.new()
	_timer.name = "FrameTimer"
	_timer.one_shot = false
	_timer.wait_time = 1.0 / maxf(fps, 0.001)
	_timer.timeout.connect(_on_tick)
	add_child(_timer)
	if auto_play:
		play()

func play(reset: bool = false) -> void:
	if frames.is_empty() or target == null:
		return
	if reset:
		_idx = 0
		_update_frame()
	_playing = true
	_timer.start()

func pause() -> void:
	_playing = false
	if _timer:
		_timer.stop()

func stop(reset_frame: bool = true) -> void:
	_playing = false
	if _timer:
		_timer.stop()
	if reset_frame:
		_idx = 0
		_update_frame()

func set_fps(value: float) -> void:
	fps = value
	if _timer:
		_timer.wait_time = 1.0 / maxf(fps, 0.001)

func _update_frame() -> void:
	if target and not frames.is_empty():
		target.texture = frames[_idx]

func _on_tick() -> void:
	if frames.is_empty():
		return
	_idx += 1
	if _idx >= frames.size():
		if loop:
			_idx = 0
		else:
			_idx = frames.size() - 1
			pause()
			cycle_finished.emit()
			return
	_update_frame()
