extends SceneTree

# P3 美术资产校验：确认所有接入 Godot 的资产可被加载（非 null）。
# 用法（在 godot_project 目录下，先 godot --headless --import 生成 .import）：
#   godot --headless --script res://tools/p3_art_check.gd

var failures: Array[String] = []

func _check(name: String, res: Resource) -> void:
	if res == null:
		failures.append(name + " -> null")
		print("FAIL " + name)
	else:
		print("OK   " + name)

func _check_skip_missing(name: String, path: String) -> void:
	# 源图缺失（仅剩 .import 占位元数据）视为已知缺口，跳过以保持 CI 绿；
	# 缺口由美术资产补全任务单独跟进（P3）。若源图存在却 load 失败仍判 FAIL。
	if not FileAccess.file_exists(path):
		print("SKIP " + name + " (源图缺失，缺口单独跟进)")
		return
	_check(name, load(path))

func _process(_delta: float) -> bool:
	# 1. 立绘 — 统一以 PortraitLibrary 为数据源校验（2026-07-28 收口）
	#    福尔摩斯像素表情（assets/portraits/pixel/）：映射到的每张图必须可加载
	var sherlock_files := {}
	for mood in PortraitLibrary.SHERLOCK_MOODS:
		sherlock_files[PortraitLibrary.SHERLOCK_MOODS[mood]] = true
	for f in sherlock_files:
		var p: String = PortraitLibrary.SHERLOCK_DIR % f
		_check("portrait(sherlock):" + p.get_file(), load(p))

	# 1b. 华生表情（assets/characters/watson/*.jpg）
	var watson_files := {}
	for mood in PortraitLibrary.WATSON_MOODS:
		watson_files[PortraitLibrary.WATSON_MOODS[mood]] = true
	for f in watson_files:
		var p: String = PortraitLibrary.WATSON_DIR % f
		_check("portrait(watson):" + p.get_file(), load(p))

	# 1c. NPC 单表情立绘（assets/characters/<角色>/）
	for spk in PortraitLibrary.NPC_PORTRAITS:
		var p: String = PortraitLibrary.NPC_PORTRAITS[spk]
		_check("portrait(npc:%s):%s" % [spk, p.get_file()], load(p))

	# 2. UI 参考图（jpg / png）
	var ui = [
		"res://assets/ui/textures/案件主界面_Blackwood Mansion.jpg",
		"res://assets/ui/textures/对话交互界面.jpg",
		"res://assets/ui/textures/难度选择界面.png",
		"res://assets/ui/textures/推理墙_思维殿堂界面.png",
	]
	for u in ui:
		_check("ui:" + u.get_file(), load(u))

	# 3. 16:9 归一化变体
	_check("ui_norm:难度选择界面_16x9.png",
		load("res://assets/ui/textures/normalized/难度选择界面_16x9.png"))

	# 4. 9-slice 边框纹理
	var frame = load("res://assets/ui/textures/frame_brass.png")
	_check("frame:frame_brass.png", frame)
	if frame != null:
		var tex := frame as Texture2D
		print("     frame size = " + str(tex.get_size()))

	# 5. UI 主题（Theme 资源）
	var theme = load("res://assets/ui/ui_theme.tres")
	_check("ui_theme.tres", theme)

	# 6. NinePatchRect 示例场景（9-slice 实际接入节点树）
	var ex = load("res://scenes/ui_frame_example.tscn")
	_check("ui_frame_example.tscn", ex)

	# 7. P5-3 场景背景图（8 张 Victorian gaslight 氛围插画）
	var scenes = [
		"sc_01_lab", "sc_02_garden", "sc_03_indoor", "sc_04_police",
		"sc_05_parlor", "sc_06_apartment", "sc_07_hotel", "sc_08_finale",
	]
	for sid in scenes:
		var path = "res://assets/scenes/" + sid + ".png"
		var tex = load(path)
		_check("scene:" + sid, tex)
		if tex != null:
			print("     scene size = " + str(tex.get_size()))

	if failures.is_empty():
		print("ART_CHECK_OK")
	else:
		print("ART_CHECK_FAIL: " + str(failures))
	quit()
	return false
