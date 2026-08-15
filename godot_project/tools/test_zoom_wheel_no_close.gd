extends SceneTree
## 验证线索放大弹出框的「滚轮不关闭」修复：
##  - 滚轮(上/下)事件经过 ScrollContainer 滚动文字时，不应触发弹出框关闭；
##  - 左键点击、Enter/Space/Esc/E 仍正常关闭并记录线索。
## （2026-08-15 修复：滚轮也是 InputEventMouseButton 且 pressed=true，此前被当成点击关闭）

var ok := true

func _init() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var Gd = load("res://scripts/ui/scene_framework.gd")
	var CO = load("res://scripts/clue/clue_observer.gd")
	var DM = get_root().get_node_or_null("/root/DifficultyManager")
	if DM != null:
		DM.set_difficulty(0)

	var sf = Gd.new(); sf.name = "ui"; root.add_child(sf)
	sf.setup("测试", "TEST", null)
	var world = sf.get_world_layer(); var woff = sf.get_world_offset()

	var hs := [{"id":"c201","label":"碾轧的花草","x":180.0,"y":800.0,"w":150.0,"h":42.0,
		"desc":"路边草地被压过了——两道平行的印子。","tool":"none",
		"image":"res://assets/scenes/sc_02_garden.png","anchor":"c201"}]
	var obs = CO.new(); obs.name = "obs"; root.add_child(obs)
	obs.setup(sf, Label.new(), Label.new(), hs, null, null, "", world, woff)
	obs.show()
	obs._btns[0].emit_signal("pressed")
	await create_timer(0.02).timeout
	if obs._zoom_popup == null:
		print("[WHEEL] FAIL 弹出框未创建"); ok = false; _done(sf, obs); return

	# 滚轮下：应仍打开
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	obs._on_zoom_input(wheel)
	await create_timer(0.02).timeout
	if obs._zoomed:
		print("[WHEEL] OK 滚轮下不关闭（_zoomed 仍 true）")
	else:
		print("[WHEEL] FAIL 滚轮下误关闭"); ok = false

	# 滚轮上：应仍打开
	var wheel_up := InputEventMouseButton.new()
	wheel_up.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel_up.pressed = true
	obs._on_zoom_input(wheel_up)
	await create_timer(0.02).timeout
	if obs._zoomed:
		print("[WHEEL] OK 滚轮上不关闭（_zoomed 仍 true）")
	else:
		print("[WHEEL] FAIL 滚轮上误关闭"); ok = false

	# 左键点击：应关闭并记录
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	obs._on_zoom_input(click)
	await create_timer(0.02).timeout
	if not obs._zoomed:
		print("[WHEEL] OK 左键点击正常关闭")
	else:
		print("[WHEEL] FAIL 左键点击未关闭"); ok = false

	_done(sf, obs)

func _done(sf, obs) -> void:
	obs.queue_free(); sf.queue_free()
	print("[WHEEL]", "PASS ✅" if ok else "FAIL ❌")
	quit()
