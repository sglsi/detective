extends Node

## AudioManager - 音频管理器
## 管理 BGM、环境音、音效、语音的播放与控制

var current_bgm: String = ""
var bgm_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
var ambient_player: AudioStreamPlayer

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

func play_bgm(bgm_path: String, fade_in: float = 1.0) -> void:
	if current_bgm == bgm_path:
		return
	current_bgm = bgm_path
	var stream = load("res://assets/audio/bgm/%s" % bgm_path)
	if stream:
		bgm_player.stream = stream
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
	var stream = load("res://assets/audio/sfx/%s" % sfx_path)
	if stream:
		sfx_player.stream = stream
		sfx_player.play()

func play_ambient(ambient_path: String) -> void:
	var stream = load("res://assets/audio/sfx/%s" % ambient_path)
	if stream:
		ambient_player.stream = stream
		ambient_player.play()

func play_voice(voice_path: String) -> void:
	var stream = load("res://assets/audio/voice/%s" % voice_path)
	if stream:
		# 语音使用独立的一次性播放器
		var voice_player = AudioStreamPlayer.new()
		voice_player.bus = "Voice"
		voice_player.stream = stream
		voice_player.finished.connect(voice_player.queue_free)
		add_child(voice_player)
		voice_player.play()
