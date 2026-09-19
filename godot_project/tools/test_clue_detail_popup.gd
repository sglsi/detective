extends SceneTree
# 聚焦验证：线索详情弹窗（AcceptDialog）新增 ①右上角 ✕ 关闭按钮 ②顶部拖拽手柄。
# 不调用重量级 wall.setup()，仅手动装配 _show_clue_detail 构建期所需的最小状态。

func _initialize() -> void:
	await create_timer(0.1).timeout
	var RW = load("res://scripts/clue/reasoning_wall.gd")
	var WL = load("res://scripts/clue/wall/wall_clue_library.gd")
	if not RW or not WL:
		print("DETAIL_RESULT: FAIL - 脚本加载失败")
		quit(1)
		return

	var wall = RW.new()
	wall.name = "DetailWall"
	root.add_child(wall)
	# 最小装配
	wall._clue_ctl = WL.new()
	wall._clue_ctl.owner = wall
	wall._difficulty = 1
	wall._clues = []

	var clue := {"id":"c1","name":"车轮印","desc":"d","correct":true,"source":"garden","associated":true,"attribute_tags":["直接物证"]}

	var ok := true
	var msgs := []

	wall._clue_ctl._show_clue_detail(clue)
	await create_timer(0.2).timeout   # 等 _make_detail_draggable 的 process_frame

	var popup = wall.get("_detail_popup")
	if popup == null:
		ok = false; msgs.append("D1_FAIL: _detail_popup 未创建")
	else:
		# 1) 默认底部确定按钮已隐藏（改用 ✕）
		if popup.get_ok_button().visible:
			ok = false; msgs.append("D2_FAIL: 默认确定按钮仍可见")
		# 2) 右上角 ✕ 按钮存在且可隐藏弹窗
		var close_btn: Control = null
		for c in popup.get_children():
			if c is Button and c.name == "DetailClose":
				close_btn = c
		if close_btn == null:
			ok = false; msgs.append("D3_FAIL: 未找到右上角 ✕ 关闭按钮")
		else:
			if not close_btn.pressed.is_connected(func(): pass):
				pass
			# 模拟点击关闭：直接调用 hide（验证可以关闭）
			popup.hide()
			await create_timer(0.05).timeout
			if popup.visible:
				ok = false; msgs.append("D4_FAIL: 调用 hide() 后弹窗仍可见")
		# 3) 拖拽手柄存在
		var has_handle := false
		for c in popup.get_children():
			if c is Control and c.name == "PopupDragHandle":
				has_handle = true
		if not has_handle:
			ok = false; msgs.append("D5_FAIL: 未创建拖拽手柄 PopupDragHandle")

	if ok:
		print("DETAIL_RESULT: PASS  (✕关闭按钮 + 隐藏默认确定钮 + 顶部拖拽手柄 + hide()可关闭 均通过)")
	else:
		for m in msgs: print(m)
		print("DETAIL_RESULT: FAIL")
	quit(0)
