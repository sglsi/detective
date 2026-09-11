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
## UI 交互音效（按钮点击等）；资源由 tools/gen_placeholder_audio.py 生成
const UI_SFX := {
	"click": "ui_click.wav",
	"hover": "ui_hover.wav",
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
	# 1.5 秒后打印一次音频树诊断（播放状态 / 音量 / 总线 / 静音），便于远程定位无声
	get_tree().create_timer(1.5).timeout.connect(_print_audio_diag)
	if _pending_bgm != "":
		var p := _pending_bgm
		_pending_bgm = ""
		play_bgm(p, 1.5)

func _print_audio_diag() -> void:
	var music_idx := AudioServer.get_bus_index("Music")
	print("[Audio][diag] playing=", bgm_player.playing,
		" player_vol_db=", bgm_player.volume_db,
		" stream_ok=", bgm_player.stream != null,
		" music_bus_db=", AudioServer.get_bus_volume_db(music_idx) if music_idx >= 0 else -999.0,
		" music_mute=", AudioServer.is_bus_mute(music_idx) if music_idx >= 0 else true)

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
	set_process(true)
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

## Web 音频解锁轮询：GDScript 直接探测 AudioContext 状态，一旦 running 立即解锁并补播。
## 不依赖 _input（预览 iframe 下 _input 常收不到），根治"ctx 已 resume 但 BGM 没 play"的静音。
## Web 音频解锁轮询（v4）：GDScript 直接探测 AudioContext 状态，一旦 running 立即解锁并补播。
## 不依赖 _input（预览 iframe 下 _input 常收不到），根治"ctx 已 resume 但 BGM 没 play"的静音。
## 兜底：即便 JS 探测失效（返回 no-bridge），超时后也强制解锁并 play，避免永久静音死锁。
var _poll_accum := 0.0
var _since_ready := 0.0
const FORCE_UNLOCK_AFTER := 6.0
## 焦点感知：只有正在被操作的窗口/标签页才出声，后台实例自动静音。
## 解决同一游戏开多份（多标签页 / 预览面板 / 后台窗口）时声音叠加、且刷新当前页
## 也消不掉其他实例声音的问题。
var _focus_accum := 0.0
var _last_focus := true

func _set_app_focused(on: bool) -> void:
	if on == _last_focus:
		return
	_last_focus = on
	if bgm_player != null and bgm_player.playing:
		bgm_player.stream_paused = not on
	print("[Audio] 焦点变化 focused=", on, " -> BGM paused=", not on)

## 通用路径：引擎应用焦点通知（桌面端/导出版均生效）
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_set_app_focused(true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_set_app_focused(false)

## Web 兜底：iframe/预览面板下引擎通知未必可靠，直接问页面 document.hasFocus()
func _check_focus_pause(delta: float) -> void:
	_focus_accum += delta
	if _focus_accum < 0.4:
		return
	_focus_accum = 0.0
	var raw = JavaScriptBridge.eval("document.hasFocus()", true)
	_set_app_focused(bool(raw))

func _process(delta: float) -> void:
	if not OS.has_feature("web"):
		set_process(false)
		return
	_check_focus_pause(delta)
	if _audio_unlocked:
		return
	_poll_accum += delta
	_since_ready += delta
	if _poll_accum < 0.2:
		return
	_poll_accum = 0.0
	# head_include 注入的探针（页面层，不依赖 JavaScriptBridge 注入时机）
	# 返回形如 "C:running@48000x1" / "G:running@48000" / "no-ctx"
	var st = JavaScriptBridge.eval("window.__gdAudioState ? window.__gdAudioState() : 'no-bridge'", true)
	if typeof(st) == TYPE_STRING and str(st).contains("running"):
		print("[Audio] ctx running -> 解锁并补播: ", _pending_bgm, " (", st, ")")
		_unlock_audio()
	elif _since_ready > FORCE_UNLOCK_AFTER:
		print("[Audio] 超时兜底解锁（ctx=", st, "）-> 强制播放: ", _pending_bgm)
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
		# Godot 4.7：循环由流资源自身控制（AudioStreamPlayer 已无 loop 属性）。
		# ⚠️ 坑：AudioStreamWAV.loop_end 默认为 0，只设 loop_mode=LOOP_FORWARD 会让播放头
		# 立即循环回第 0 帧 → 声音卡死成静音（ctx running 却无声的元凶）。必须显式设 loop_end。
		if stream is AudioStreamWAV:
			var wav := stream as AudioStreamWAV
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			var bytes_per_frame := 2 * (2 if wav.stereo else 1)  # FORMAT_16_BITS
			wav.loop_end = wav.data.size() / bytes_per_frame
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

## 播放 UI 交互音效（如按钮点击）
func play_ui_sfx(id: String) -> void:
	if UI_SFX.has(id):
		play_sfx(UI_SFX[id])

## 播放一次性音效。用独立播放器而非共享 sfx_player：
## UI 连点不会互相打断/截断 stinger，短促音效得以完整播完。
func play_sfx(sfx_path: String) -> void:
	var path = "res://assets/audio/sfx/%s" % sfx_path
	if not ResourceLoader.exists(path):
		return
	var stream = load(path)
	if stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.bus = "SFX"
	p.stream = stream
	p.finished.connect(p.queue_free)
	add_child(p)
	p.play()

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
