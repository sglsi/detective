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

## 首次用户手势 → 解锁音频上下文并补播待定 BGM（作为 JS 轮询之外的兜底路径）
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
	# Web 音频根治（v3 健壮方案）：
	# 浏览器要求用户手势后才能 resume AudioContext；Godot 4.7 的 index.js 自身不注册任何输入监听
	# 来 resume，完全靠我们注入 DOM 级手势监听。但旧方案里 GDScript 仅靠 _input 翻转 _audio_unlocked，
	# 在预览 iframe 下 _input 常收不到 → ctx 已被 resume、BGM 却从未 play() → 全程静音。
	# 故改用：①JS 在真实手势调用栈内 resume ctx；②GDScript 每帧轮询 ctx.state，一旦 running 立即
	# 解锁并补播（不再依赖 _input）。两条路径并存，互不冲突。
	set_process_input(true)
	if OS.has_feature("web"):
		var js := """
(function(){
  function __godotResume(){
    try {
      if (window.GodotAudio && GodotAudio.ctx && GodotAudio.ctx.state !== 'running') {
        GodotAudio.ctx.resume();
        console.log('[Audio] GodotAudio.ctx.resume() ->', GodotAudio.ctx.state);
      }
    } catch(e){ console.log('[Audio] resume error', e); }
  }
  ['pointerdown','mousedown','keydown','touchstart'].forEach(function(ev){
    window.addEventListener(ev, __godotResume, {capture:true});
  });
  window.__godotAudioState = function(){
    try {
      if (window.GodotAudio && GodotAudio.ctx) return GodotAudio.ctx.state;
    } catch(e){}
    return 'no-ctx';
  };
  console.log('[Audio] Web audio unlock injected');
})();
"""
		JavaScriptBridge.eval(js)
		set_process(true)

## Web 音频解锁轮询：GDScript 直接探测 AudioContext 状态，一旦 running 立即解锁并补播。
## 不依赖 _input（预览 iframe 下 _input 常收不到），根治"ctx 已 resume 但 BGM 没 play"的静音。
var _poll_accum := 0.0
func _process(delta: float) -> void:
	if _audio_unlocked or not OS.has_feature("web"):
		return
	_poll_accum += delta
	if _poll_accum < 0.2:
		return
	_poll_accum = 0.0
	var st = JavaScriptBridge.eval("window.__godotAudioState ? window.__godotAudioState() : 'no-bridge'", true)
	if st == "running":
		print("[Audio] ctx running detected -> unlock & play pending: ", _pending_bgm)
		_unlock_audio()
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
		push_warning("[Audio] BGM 资源缺失: " + path)
		return
	var stream = load(path)
	if stream == null:
		push_warning("[Audio] BGM 加载失败: " + path)
		return
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
