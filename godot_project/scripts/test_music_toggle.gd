extends Control
## 验证「界面常驻音乐开关（喇叭按钮）」：
##   T1 场景框架顶栏存在 music_toggle 按钮，且含 music_icon 子节点
##   T2 点击按钮 → AudioManager 音乐开关翻转为「关」，且 Music 总线静音，图标同步
##   T3 再点一次 → 恢复「开」，总线取消静音，图标同步
##
## 运行（沙箱外）：
##   godot --headless --path . "res://scenes/test_music_toggle.tscn"
## 退出码 0=PASS，1=FAIL。

func _ready() -> void:
	await get_tree().process_frame

	var ui = load("res://scripts/ui/scene_framework.gd").new()
	get_tree().root.add_child(ui)
	await get_tree().process_frame

	# T1：顶栏按钮 + 图标子节点
	var btn = ui.find_child("music_toggle", true, false)
	if btn == null or not (btn is Button):
		printerr("RESULT: FAIL T1 未找到顶栏 music_toggle 按钮")
		get_tree().quit(1); return
	var icon = btn.find_child("music_icon", true, false)
	print("[T1] 按钮存在，图标子节点=", icon != null)
	if icon == null:
		printerr("RESULT: FAIL T1 music_icon 子节点缺失")
		get_tree().quit(1); return

	var music_idx := AudioServer.get_bus_index("Music")
	if music_idx < 0:
		printerr("RESULT: FAIL Music 总线不存在")
		get_tree().quit(1); return

	var orig: bool = AudioManager.is_music_on()
	AudioManager.set_music_on(true)
	await get_tree().process_frame
	var on0: bool = AudioManager.is_music_on()
	var mute0: bool = AudioServer.is_bus_mute(music_idx)
	print("[SETUP] 初始 on=", on0, " mute=", mute0, " (记录原值=", orig, ")")
	if not on0 or mute0:
		printerr("RESULT: FAIL 置开后应不静音 on=", on0, " mute=", mute0)
		get_tree().quit(1); return

	# T2：点击 → 关（静音）
	(btn as Button).pressed.emit()
	await get_tree().process_frame
	var on1: bool = AudioManager.is_music_on()
	var mute1: bool = AudioServer.is_bus_mute(music_idx)
	var icon_off: bool = bool(icon.on)
	print("[T2] 点击后 on=", on1, " mute=", mute1, " icon.on=", icon_off)
	if on1 or not mute1 or icon_off:
		printerr("RESULT: FAIL T2 未正确关闭 on=", on1, " mute=", mute1, " icon.on=", icon_off)
		get_tree().quit(1); return

	# T3：再点 → 开（取消静音）
	(btn as Button).pressed.emit()
	await get_tree().process_frame
	var on2: bool = AudioManager.is_music_on()
	var mute2: bool = AudioServer.is_bus_mute(music_idx)
	var icon_on: bool = bool(icon.on)
	print("[T3] 再点后 on=", on2, " mute=", mute2, " icon.on=", icon_on)
	if not on2 or mute2 or not icon_on:
		printerr("RESULT: FAIL T3 未恢复 on=", on2, " mute=", mute2, " icon.on=", icon_on)
		get_tree().quit(1); return

	# 还原测试前的用户偏好，避免污染 settings.json
	AudioManager.set_music_on(orig)
	print("RESULT: PASS 音乐开关：顶栏按钮存在 / 点击静音 / 再点恢复 / 图标同步")
	get_tree().quit(0)
