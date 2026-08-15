extends SceneTree
# 回归：点击线索记录后，摄像机必须回到统览原场景（zoom=1, position=0），
# 否则其余未记录线索会被推近镜头推出视口外，导致流程卡死。
# 本测试模拟基类 _on_clue_recorded 的 reset_camera() 行为。

func _initialize() -> void:
	var sf = load("res://scripts/ui/scene_framework.gd").new()
	sf.name = "ui"
	root.add_child(sf)
	sf._ready()

	var world: Control = sf.get_world_layer()
	var off: Vector2 = sf.get_world_offset()
	if world == null:
		print("CAM_RETURN: FAIL (world_layer missing)"); quit()

	var hotspots: Array = [
		{"id":"a","label":"线索A","x":300,"y":300,"w":100,"h":40,"desc":"描述A"},
		{"id":"b","label":"线索B","x":600,"y":300,"w":100,"h":40,"desc":"描述B"},
		{"id":"c","label":"线索C","x":900,"y":300,"w":100,"h":40,"desc":"描述C"},
	]
	var txt := Label.new(); var spk := Label.new()
	var obs = load("res://scripts/clue/clue_observer.gd").new()
	obs.name = "observer"
	sf.add_child(obs)
	obs.setup(sf, txt, spk, hotspots, null, null, "", world, off)

	# 模拟基类 _on_clue_recorded：记录线索后回到统览态
	obs.clue_recorded.connect(func(_id: String, _data: Dictionary) -> void:
		sf.reset_camera()
	)

	obs.show()
	await create_timer(0.05).timeout

	# 初始应为统览态
	if not world.scale.is_equal_approx(Vector2.ONE):
		print("CAM_RETURN: FAIL (initial scale not overview): ", world.scale); quit()

	# 点击线索 A → 打开放大图
	obs._btns[0].emit_signal("pressed")
	if not obs._zoomed:
		print("CAM_RETURN: FAIL (zoom popup did not open)"); quit()

	# 关闭放大图 → 触发记录 → reset_camera 回到统览
	obs._close_zoom()
	if obs._btns[1].visible == false or obs._btns[2].visible == false:
		print("CAM_RETURN: FAIL (other clues hidden after record)"); quit()

	# 等待 tween 完成（reset_camera 0.35s）
	await create_timer(0.5).timeout

	var ok := true
	if not world.scale.is_equal_approx(Vector2.ONE):
		print("CAM_RETURN: FAIL (scale not reset): ", world.scale); ok = false
	if not world.position.is_equal_approx(Vector2.ZERO):
		print("CAM_RETURN: FAIL (position not reset): ", world.position); ok = false
	if not obs._btns[1].visible or not obs._btns[2].visible:
		print("CAM_RETURN: FAIL (other clues not visible after return)"); ok = false

	print("CAM_RETURN: PASS" if ok else "CAM_RETURN: FAIL")
	quit()
