extends SceneTree

# PortraitLibrary 单元测试
# 用法: godot --headless --script res://tools/test_portrait_library.gd
# 输出: P1_RESULT: PORTRAIT_LIB_OK / PORTRAIT_LIB_FAIL: [...]

var failures: Array[String] = []

func _assert(cond: bool, msg: String) -> void:
	if cond:
		print("OK   " + msg)
	else:
		failures.append(msg)
		print("FAIL " + msg)

func _process(_delta: float) -> bool:
	# 1. 路径解析：主角按 mood 命中对应表情
	_assert(PortraitLibrary._resolve_path("福尔摩斯", "思考") == "res://assets/portraits/pixel/sherlock_思考.png", "sherlock 思考路径")
	_assert(PortraitLibrary._resolve_path("福尔摩斯", "从容") == "res://assets/portraits/pixel/sherlock_自信.png", "sherlock 别名 从容→自信")
	_assert(PortraitLibrary._resolve_path("福尔摩斯", "不存在的mood") == "res://assets/portraits/pixel/sherlock_思考.png", "sherlock 未知 mood 落默认")
	_assert(PortraitLibrary._resolve_path("华生", "敬佩") == "res://assets/characters/watson/watson_倾佩.jpg", "watson 别名 敬佩→倾佩")
	_assert(PortraitLibrary._resolve_path("华生", "") == "res://assets/characters/watson/watson_平静.jpg", "watson 空 mood 落默认")

	# 2. NPC：忽略 mood，返回固定立绘；无立绘说话人返回空
	_assert(PortraitLibrary._resolve_path("赫德森太太", "任意") == "res://assets/characters/mrs_hudson/mrs_hudson.png", "NPC 赫德森太太")
	_assert(PortraitLibrary._resolve_path("system", "guide") == "", "system 无立绘")
	_assert(PortraitLibrary._resolve_path("未知路人", "") == "", "未知说话人无立绘")

	# 3. has_portrait
	_assert(PortraitLibrary.has_portrait("福尔摩斯"), "has 福尔摩斯")
	_assert(PortraitLibrary.has_portrait("维金斯"), "has 维金斯")
	_assert(not PortraitLibrary.has_portrait("system"), "not has system")

	# 4. 映射到的所有资源文件必须真实存在（防止映射写错路径）
	var checked := {}
	for mood in PortraitLibrary.SHERLOCK_MOODS:
		var p: String = PortraitLibrary.SHERLOCK_DIR % PortraitLibrary.SHERLOCK_MOODS[mood]
		if not checked.has(p):
			checked[p] = true
			_assert(ResourceLoader.exists(p), "存在: " + p.get_file())
	for mood in PortraitLibrary.WATSON_MOODS:
		var p: String = PortraitLibrary.WATSON_DIR % PortraitLibrary.WATSON_MOODS[mood]
		if not checked.has(p):
			checked[p] = true
			_assert(ResourceLoader.exists(p), "存在: " + p.get_file())
	for spk in PortraitLibrary.NPC_PORTRAITS:
		var p: String = PortraitLibrary.NPC_PORTRAITS[spk]
		if not checked.has(p):
			checked[p] = true
			_assert(ResourceLoader.exists(p), "存在: " + p.get_file())

	# 5. 实际加载 + 缓存复用
	var t1 = PortraitLibrary.get_portrait("福尔摩斯", "思考")
	var t2 = PortraitLibrary.get_portrait("福尔摩斯", "思考")
	_assert(t1 != null, "sherlock 思考可加载")
	_assert(t1 == t2, "缓存复用同一实例")
	var t3 = PortraitLibrary.get_portrait("维金斯")
	_assert(t3 != null, "维金斯立绘可加载")
	_assert(PortraitLibrary.get_portrait("system", "guide") == null, "system 返回 null")

	if failures.is_empty():
		print("P1_RESULT: PORTRAIT_LIB_OK")
	else:
		print("P1_RESULT: PORTRAIT_LIB_FAIL: " + str(failures))
	quit()
	return false
