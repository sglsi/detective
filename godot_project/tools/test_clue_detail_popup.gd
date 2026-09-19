extends SceneTree
# 聚焦验证：线索详情弹窗（统一 DetailCard PanelContainer）新增
#   ① 顶栏 ✕ 关闭按钮（CloseBtn）② 顶栏作为拖拽手柄（WindowDrag 已绑定 _wd_drag 元数据）③ 关闭后引用清空。
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
	await create_timer(0.1).timeout

	var popup = wall.get("_detail_popup")
	if popup == null:
		ok = false; msgs.append("D1_FAIL: _detail_popup 未创建")
	elif not (popup is PanelContainer):
		ok = false; msgs.append("D1b_FAIL: _detail_popup 应为 PanelContainer（统一详情卡框架），实际 %s" % popup.get_class())
	else:
		# 2) 顶栏（拖拽手柄）存在
		var title_bar: Control = null
		for c in popup.get_children():
			if c is HBoxContainer and c.name == "TitleBar":
				title_bar = c
		if title_bar == null:
			ok = false; msgs.append("D2_FAIL: 未找到 TitleBar 拖拽手柄")
		else:
			# 3) ✕ 关闭按钮存在
			var close_btn: Button = null
			for c in title_bar.get_children():
				if c is Button and c.name == "CloseBtn":
					close_btn = c
			if close_btn == null:
				ok = false; msgs.append("D3_FAIL: 未找到顶栏 ✕ 关闭按钮 CloseBtn")
			# 4) 拖拽已绑定（WindowDrag 在手柄写入 _wd_drag 元数据）
			if not title_bar.has_meta("_wd_drag"):
				ok = false; msgs.append("D4_FAIL: TitleBar 未绑定 WindowDrag（缺 _wd_drag 元数据）")
		# 5) 旧的 AcceptDialog 残留不应存在
		if popup.has_method("get_ok_button"):
			ok = false; msgs.append("D5_FAIL: 仍残留 AcceptDialog（不应有 get_ok_button）")

	# 6) 点击 ✕ 关闭后引用清空
	if ok:
		wall._clue_ctl._close_clue_detail()
		await create_timer(0.05).timeout
		if wall.get("_detail_popup") != null:
			ok = false; msgs.append("D6_FAIL: 关闭后 _detail_popup 引用未清空")

	if ok:
		print("DETAIL_RESULT: PASS  (PanelContainer + TitleBar拖拽手柄 + CloseBtn + 关闭清空引用 均通过)")
	else:
		for m in msgs: print(m)
		print("DETAIL_RESULT: FAIL")
	quit(0)
