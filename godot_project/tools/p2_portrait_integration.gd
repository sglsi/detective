extends Node
# P2 集成验证：SceneFramework.set_dialogue 经 PortraitLibrary 正确显示/隐藏立绘。
# 直接覆盖「立绘接入对话系统」这条运行时链路（单测只验 PortraitLibrary、走查不触发对话，均未覆盖）。
# 作为主场景运行：godot --headless --path . tools/p2_portrait_integration.tscn
# 哨兵：P2_RESULT: PORTRAIT_INTEGRATION_OK / PORTRAIT_INTEGRATION_FAIL

var _ok := true

func _fail(m: String) -> void:
	_ok = false
	printerr("FAIL " + m)

func _pass(m: String) -> void:
	print("OK   " + m)

func _ready() -> void:
	var sf := SceneFramework.new()
	add_child(sf)
	# 等一帧让 SceneFramework._ready 构建对话栏（含 _speaker_portrait）
	await get_tree().process_frame

	# 1. 福尔摩斯 + 思考 → 立绘显示且纹理非 null
	sf.set_dialogue("福尔摩斯", "测试文本", "思考")
	if sf._speaker_portrait.texture != null and sf._speaker_portrait.visible:
		_pass("福尔摩斯/思考 -> 立绘显示且纹理非空")
	else:
		_fail("福尔摩斯/思考 -> 立绘未显示 (tex=%s visible=%s)" % [sf._speaker_portrait.texture, sf._speaker_portrait.visible])

	# 2. 华生 + 赞同 → 立绘显示
	sf.set_dialogue("华生", "测试文本", "赞同")
	if sf._speaker_portrait.texture != null and sf._speaker_portrait.visible:
		_pass("华生/赞同 -> 立绘显示且纹理非空")
	else:
		_fail("华生/赞同 -> 立绘未显示")

	# 3. 提示(system，无立绘) → 立绘隐藏
	sf.set_dialogue("提示", "系统提示")
	if not sf._speaker_portrait.visible:
		_pass("提示(system) -> 立绘隐藏")
	else:
		_fail("提示(system) -> 立绘应隐藏却可见")

	# 4. NPC 单表情（葛莱森）也能显示
	sf.set_dialogue("葛莱森", "报告福尔摩斯", "从容")
	if sf._speaker_portrait.texture != null and sf._speaker_portrait.visible:
		_pass("葛莱森(NPC) -> 立绘显示")
	else:
		_fail("葛莱森(NPC) -> 立绘未显示")

	# 5. 不同 mood 命中不同纹理（自信 vs 思考）
	sf.set_dialogue("福尔摩斯", "x", "自信")
	var t1 = sf._speaker_portrait.texture
	sf.set_dialogue("福尔摩斯", "x", "思考")
	var t2 = sf._speaker_portrait.texture
	if t1 != null and t2 != null and t1 != t2:
		_pass("福尔摩斯 自信≠思考 -> 命中不同纹理")
	else:
		_fail("不同 mood 未命中不同纹理 (t1=%s t2=%s)" % [t1, t2])

	if _ok:
		print("P2_RESULT: PORTRAIT_INTEGRATION_OK")
	else:
		print("P2_RESULT: PORTRAIT_INTEGRATION_FAIL")
	get_tree().quit()
