extends Control
## 验证华生 shake 动画（场景一开场教程对话阶段，按对话逐句推进动作）：
##  (1) 复用福尔摩斯动画控制器 + 三张 watson_shake 帧可正常单次播放并触发 cycle_finished（兜底路径）；
##  (1b) 对话驱动模式（实际用法）：start_dialogue_driven 后保持第0帧，之后每句对话 advance 一帧，
##       3 句后定格末帧 shake03，与开场教程对话「逐句变换动作、结束定格」完全对应；
##  (2) 场景一已把该控制器挂到华生立绘的 img 节点，节奏 fps=4 / loop=false（与福尔摩斯一致），
##      且 _show_opening_dialogue 中以对话驱动方式启动、_on_line 中逐句推进。
## 退出码 0=PASS，1=FAIL。

var _ok := true
var _msg := []
var _fired := false   # 用成员变量捕获 cycle_finished（lambda 对值类型按值捕获不可靠）

func _ready() -> void:
	await get_tree().process_frame

	# ---- (1) 动画器单元：用华生三帧跑一遍单次播放 ----
	var f0 = load("res://assets/characters/watson/watson_shake01.png")
	var f1 = load("res://assets/characters/watson/watson_shake02.png")
	var f2 = load("res://assets/characters/watson/watson_shake03.png")
	if not (f0 and f1 and f2):
		_fail("shake 帧未全部加载（watson_shake01/02/03.png）")
	var img = TextureRect.new(); add_child(img)
	var anim = Node.new()
	anim.set_script(load("res://scripts/characters/holmes_smoke_animator.gd"))
	anim.set("target", img)
	var frames: Array[Texture2D] = []   # 必须与 holmes_smoke_animator 的 Array[Texture2D] 同类型，否则 set 静默丢弃
	frames.append(f0); frames.append(f1); frames.append(f2)
	anim.set("frames", frames)
	anim.set("fps", 4.0)
	anim.set("loop", false)
	anim.set("auto_play", false)
	img.add_child(anim)
	var fired := false
	anim.cycle_finished.connect(_mark_fired)
	print("[DBG] frames.size=", anim.get("frames").size(), " target!=null=", anim.get("target") != null, " img.tex_set=", img.texture != null)
	anim.play(true)
	var ticks := 0
	while ticks < 90:   # ≈1.5s @60fps，绕过 create_timer 不确定性
		await get_tree().process_frame
		ticks += 1
	print("[DBG] after wait: fired=", _fired, " img.tex_is_f2=", img.texture == f2)
	if not _fired:
		_fail("cycle_finished 未触发（单次播放未正常结束）")
	if img.texture != f2:
		_fail("末帧应停在 shake03（单次播放结束保持末帧）")

	# ---- (1b) 动画器单元：对话驱动模式（场景一实际用法，与福尔摩斯同款）----
	await _test_dialogue_driven()

	# ---- (2) 场景一集成：确认控制器已挂到华生立绘并接线 ----
	await _check_scene1_wiring()
	_finalize()

func _check_scene1_wiring() -> void:
	var s1 = load("res://scenes/scene1.tscn").instantiate()
	add_child(s1)
	await get_tree().process_frame
	await get_tree().process_frame   # 给 _ready/_build_ui 留两帧
	var wa = s1.get("_watson_anim")
	if wa == null:
		_fail("scene1._watson_anim 未创建")
		s1.queue_free()
		return
	var fr = wa.get("frames")
	if fr == null or fr.size() != 3:
		_fail("scene1._watson_anim frames 数量 != 3（实际 %s）" % (fr.size() if fr else "null"))
	if abs(wa.get("fps") - 4.0) > 0.001:
		_fail("scene1._watson_anim fps != 4（与福尔摩斯节奏不一致）")
	if wa.get("loop") != false:
		_fail("scene1._watson_anim loop 应为 false（单次播放后落定）")
	s1.queue_free()

func _mark_fired() -> void:
	_fired = true

## 对话驱动模式（场景一实际用法）：start_dialogue_driven 后保持第0帧，之后每句对话 advance 一帧，
## 3 句后定格末帧 shake03（与开场教程对话「逐句变换动作」完全对应）。
func _test_dialogue_driven() -> void:
	var f0 = load("res://assets/characters/watson/watson_shake01.png")
	var f1 = load("res://assets/characters/watson/watson_shake02.png")
	var f2 = load("res://assets/characters/watson/watson_shake03.png")
	var img = TextureRect.new(); add_child(img)
	var anim = Node.new()
	anim.set_script(load("res://scripts/characters/holmes_smoke_animator.gd"))
	anim.set("target", img)
	var frames: Array[Texture2D] = []
	frames.append(f0); frames.append(f1); frames.append(f2)
	anim.set("frames", frames)
	anim.set("fps", 4.0)
	anim.set("loop", false)
	anim.set("auto_play", false)
	img.add_child(anim)
	anim.start_dialogue_driven()
	await get_tree().process_frame
	if img.texture != f0:
		_fail("对话驱动首帧应为 shake01（start_dialogue_driven 后保持第0帧）")
	# 模拟开场教程的 3 句对话逐句推进（首句仅消费标记，保持第0帧）
	anim.advance_frame()
	if img.texture != f0:
		_fail("对话驱动首句应保持 shake01（首句不跳变）")
	anim.advance_frame()
	if img.texture != f1:
		_fail("对话驱动第2句应变为 shake02")
	anim.advance_frame()
	if img.texture != f2:
		_fail("对话驱动第3句应变为 shake03（末帧，对应对话结束定格）")
	anim.queue_free(); img.queue_free()

func _fail(m: String) -> void:
	_ok = false
	_msg.append(m)

func _finalize() -> void:
	if _ok:
		print("RESULT: PASS 华生 shake 动画：帧加载/单次播放/场景接线均正常")
	else:
		printerr("RESULT: FAIL " + " | ".join(_msg))
	get_tree().quit(0 if _ok else 1)
