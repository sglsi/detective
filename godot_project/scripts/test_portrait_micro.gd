extends Control

## 立绘微动组件自测：确认 PortraitMicroAnimator 真的会让立绘呼吸/浮动。
## 运行：godot --headless res://scenes/test_portrait_micro.tscn --quit
## 说明：headless --quit 下定时器 await 不可靠，故直接调用 _process(delta) 模拟时间推进。

const PortraitMicroAnimator = preload("res://scripts/ui/portrait_micro_animator.gd")

var _fails := 0
var _passes := 0

func _ready() -> void:
	await _run()
	queue_free()

func _chk(cond: bool, name: String) -> void:
	if cond:
		_passes += 1
		print("[OK] %s" % name)
	else:
		_fails += 1
		print("[FAIL] %s" % name)

func _run() -> void:
	# 准备一个纹理（复用已有半身像）
	var tex: Texture2D = null
	if ResourceLoader.exists("res://assets/characters/watson/watson_bust.png"):
		tex = load("res://assets/characters/watson/watson_bust.png")
	_chk(tex != null, "测试纹理可加载")

	var tr := TextureRect.new()
	tr.texture = tex
	tr.position = Vector2(100, 100)
	tr.size = Vector2(280, 340)
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(tr)

	var anim := PortraitMicroAnimator.new()
	add_child(anim)
	anim.setup(tr)
	# 站立角色模式：关浮动、开微旋转（验证 sway 不崩）
	anim.float_enabled = false
	anim.sway_enabled = true

	# 直接驱动 _process 模拟 1.2s，记录 scale.y / rotation 极值
	var min_scale_y := INF
	var max_scale_y := -INF
	var max_rot := 0.0
	for i in range(24):
		anim._process(0.05)
		min_scale_y = min(min_scale_y, tr.scale.y)
		max_scale_y = max(max_scale_y, tr.scale.y)
		max_rot = max(max_rot, abs(tr.rotation))

	_chk(max_scale_y - min_scale_y > 0.005, "呼吸：scale.y 随时间变化 (%.4f)" % (max_scale_y - min_scale_y))
	_chk(max_rot > 0.0001, "微旋转：rotation 随时间变化 (%.5f rad)" % max_rot)

	# 关 sway、开 float，验证浮动
	anim.sway_enabled = false
	anim.float_enabled = true
	var home_y: float = tr.position.y
	anim._process(0.05)
	var float_offset: float = abs(tr.position.y - home_y)
	_chk(float_offset > 0.5, "浮动：position.y 偏离基准 (%.2f px)" % float_offset)

	# set_talking 不报错且加大浮动
	anim.set_talking(true)
	anim._process(0.05)
	_chk(true, "set_talking(true) 调用不报错")

	# 隐藏时不应报错
	tr.hide()
	anim._process(0.05)
	_chk(true, "立绘隐藏时 _process 不报错")

	print("")
	print("PORTRAIT_MICRO: PASS=%d FAIL=%d" % [_passes, _fails])
