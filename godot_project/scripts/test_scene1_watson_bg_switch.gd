extends Control
## 验证：切换到华生立绘（_show_opening_dialogue）时，背景图同步从「沙发客厅(sofa01)」
## 交叉淡化切换到「开门门廊(opendoor)」，而非等到进入观察阶段才切
## （修复：开场教程里华生已登场、背景却还是沙发客厅的观感不一致）。
## 退出码 0=PASS，1=FAIL。

var _ok := true
var _msg := []

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	var s1 = load("res://scenes/scene1.tscn").instantiate()
	add_child(s1)
	await get_tree().process_frame
	await get_tree().process_frame   # 给 _ready/_build_ui 留两帧

	var sofa_tex = load("res://assets/backgrounds/screen01-sofa01.jpg")
	var opendoor_tex = load("res://assets/backgrounds/screen01-opendoor.jpg")
	var ui = s1.get("_ui")
	if ui == null:
		_fail("scene1._ui 未创建"); s1.queue_free(); _finalize(); return
	var world = ui.get("_world")
	if world == null:
		_fail("scene1._ui._world 未创建"); s1.queue_free(); _finalize(); return

	# 初始（开场教程前）：背景应为沙发客厅
	var init_bg = world.find_child("scene_bg", true, false)
	if init_bg == null:
		_fail("初始场景未创建 scene_bg 背景节点"); s1.queue_free(); _finalize(); return
	if init_bg.texture != sofa_tex:
		_fail("初始背景应为沙发客厅(screen01-sofa01)，实际=%s" % (init_bg.texture.resource_path if init_bg.texture else "null"))

	# 执行：切换到华生立绘（同时应切背景）
	s1._show_opening_dialogue()
	await get_tree().process_frame
	await get_tree().process_frame

	# 切图是交叉淡化：旧 sofa 改名 scene_bg_old 淡出，新 opendoor 成为 scene_bg 淡入。
	var new_bg = world.find_child("scene_bg", true, false)
	if new_bg == null:
		_fail("切换后未创建新的 scene_bg 背景节点"); s1.queue_free(); _finalize(); return
	if new_bg.texture != opendoor_tex:
		_fail("华生立绘登场后背景应切到开门门廊(screen01-opendoor)，实际=%s" % (new_bg.texture.resource_path if new_bg.texture else "null"))

	# 立绘状态应同步：华生显示、福尔摩斯隐藏
	var wpc = s1.get("_portrait_ctrl")
	var hpc = s1.get("_holmes_portrait_ctrl")
	if wpc == null or not wpc.visible:
		_fail("华生立绘应在登场时显示")
	if hpc != null and hpc.visible:
		_fail("福尔摩斯立绘应在华生登场时隐藏")

	s1.queue_free()
	_finalize()

func _fail(m: String) -> void:
	_ok = false
	_msg.append(m)

func _finalize() -> void:
	if _ok:
		print("RESULT: PASS 华生立绘登场时背景同步切换至开门门廊")
	else:
		printerr("RESULT: FAIL " + " | ".join(_msg))
	get_tree().quit(0 if _ok else 1)
