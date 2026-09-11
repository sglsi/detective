extends Node

## AudioManager - 音频管理器
## 管理 BGM、环境音、音效、语音的播放与控制

var current_bgm: String = ""
var bgm_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
var ambient_player: AudioStreamPlayer

## Web 音频自动播放策略：浏览器要求在用户手势后才能启动 AudioContext。
## 因此在首次手势前不真正 play，只记录"期望播放的 BGM"，待解锁后补播。
var _audio_unlocked := false
var _pending_bgm := ""

## 场景/流程节点 → BGM 文件名（位于 res://assets/audio/bgm/）
## 注：scene1 未覆盖 scene_id()，基类默认返回 "sceneX"，故以此键映射教学关 BGM。
const SCENE_BGM := {
	"menu": "menu.wav",
	"sceneX": "scene1.wav",
	"scene2": "scene2.wav",
	"scene3": "scene3.wav",
	"scene4": "scene4.wav",
	"scene5": "scene5.wav",
	"scene6": "scene6.wav",
	"scene7": "scene7.wav",
	"scene8": "scene8.wav",
}
## 事件 → stinger 文件名（位于 res://assets/audio/sfx/）
const STINGERS := {
	"clue_found": "clue_found.wav",
	"wall_conflict": "wall_conflict.wav",
	"reveal": "reveal.wav",
}

## 按场景/流程 id 播放对应 BGM（带淡入）；id 未知则忽略
func play_scene_bgm(id: String) -> void:
	if SCENE_BGM.has(id):
		play_bgm(SCENE_BGM[id], 1.5)

## 播放一次性事件音效（stinger）
func play_stinger(id: String) -> void:
	if STINGERS.has(id):
		play_sfx(STINGERS[id])

## 线索被正式记录 → 播放「发现线索」stinger
func _on_clue_recorded(_clue_id: String) -> void:
	play_stinger("clue_found")

## 首次用户手势 → 解锁音频上下文并补播待定 BGM（规避浏览器自动播放拦截）
func _input(event: InputEvent) -> void:
	if _audio_unlocked:
		return
	var gesture := false
	if event is InputEventMouseButton:
		gesture = (event as InputEventMouseButton).pressed
	elif event is InputEventKey:
		gesture = (event as InputEventKey).pressed
	if gesture:
		_unlock_audio()

func _unlock_audio() -> void:
	_audio_unlocked = true
	if _pending_bgm != "":
		var p := _pending_bgm
		_pending_bgm = ""
		play_bgm(p, 1.5)

func _ready() -> void:
	bgm_player = AudioStreamPlayer.new()
	sfx_player = AudioStreamPlayer.new()
	ambient_player = AudioStreamPlayer.new()
	add_child(bgm_player)
	add_child(sfx_player)
	add_child(ambient_player)
	
	# 设置音频总线
	bgm_player.bus = "Music"
	sfx_player.bus = "SFX"
	ambient_player.bus = "SFX"
	# 线索被正式记录 → 触发「发现线索」stinger
	if is_instance_valid(ClueEventBus):
		ClueEventBus.clue_recorded.connect(_on_clue_recorded)
	# 监听首次用户手势以解锁 Web 音频（规避浏览器自动播放拦截）
	set_process_input(true)

func play_bgm(bgm_path: String, fade_in: float = 1.0) -> void:
	# Web 自动播放策略：首次用户手势前不真正播放，仅记录期望 BGM，待解锁后补播
	if not _audio_unlocked:
		_pending_bgm = bgm_path
		return
	if current_bgm == bgm_path:
		return
	current_bgm = bgm_path
	var path = "res://assets/audio/bgm/%s" % bgm_path
	if not ResourceLoader.exists(path):
		return
	var stream = load(path)
	if stream:
		bgm_player.stream = stream
		# Godot 4.7：循环由流资源自身控制（AudioStreamPlayer 已无 loop 属性）
		if stream is AudioStreamWAV:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		if fade_in > 0.0:
			# 淡入：从静音(-80dB) tween 到满音量(0dB)
			bgm_player.volume_db = -80.0
			bgm_player.play()
			_fade_volume(bgm_player, 0.0, fade_in)
		else:
			bgm_player.volume_db = 0.0
			bgm_player.play()

func stop_bgm(fade_out: float = 1.0) -> void:
	if fade_out > 0.0 and bgm_player.playing:
		# 淡出：音量拉到静音后再停止并复位
		var tw := _fade_volume(bgm_player, -80.0, fade_out)
		tw.finished.connect(_stop_bgm_now)
	else:
		_stop_bgm_now()

func _stop_bgm_now() -> void:
	bgm_player.stop()
	bgm_player.volume_db = 0.0
	current_bgm = ""

## 通用音量淡变：把 player.volume_db 在 duration 秒内 tween 到 to_db，返回该 Tween 便于链式绑定 finished
func _fade_volume(player: AudioStreamPlayer, to_db: float, duration: float) -> Tween:
	var tw := create_tween()
	tw.tween_property(player, "volume_db", to_db, duration)
	return tw

func play_sfx(sfx_path: String) -> void:
	var path = "res://assets/audio/sfx/%s" % sfx_path
	if not ResourceLoader.exists(path):
		return
	var stream = load(path)
	if stream:
		sfx_player.stream = stream
		sfx_player.play()

func play_ambient(ambient_path: String) -> void:
	var path = "res://assets/audio/sfx/%s" % ambient_path
	if not ResourceLoader.exists(path):
		return
	var stream = load(path)
	if stream:
		ambient_player.stream = stream
		ambient_player.play()

func play_voice(voice_path: String) -> void:
	var path = "res://assets/audio/voice/%s" % voice_path
	if not ResourceLoader.exists(path):
		return
	var stream = load(path)
	if stream:
		# 语音使用独立的一次性播放器
		var voice_player = AudioStreamPlayer.new()
		voice_player.bus = "Voice"
		voice_player.stream = stream
		voice_player.finished.connect(voice_player.queue_free)
		add_child(voice_player)
		voice_player.play()
