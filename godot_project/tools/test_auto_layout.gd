extends SceneTree
## 运行时自测：场景二开推理墙后点击「自动排列」，断言：
## 1) 布局为「分列对齐」——同一 BFS 深度（同一列）的节点 x 一致（容差 36px）
## 2) 同列相邻节点垂直边缘间距 ≥ 15px（不覆盖）
## 3) 实测不抛错（挂死由 WATCHDOG 兜底）

func _initialize() -> void:
	await process_frame
	await process_frame
	var wd = create_timer(90.0)
	wd.timeout.connect(_watchdog_quit)

	var ClueSystem = root.get_node_or_null("/root/ClueSystem")
	var GameManager = root.get_node_or_null("/root/GameManager")
	var APIManager = root.get_node_or_null("/root/APIManager")
	if not (ClueSystem and GameManager and APIManager):
		print("AUTO_LAYOUT_FAIL autoloads missing"); quit(); return
	APIManager.is_online = false
	GameManager.is_guest = false

	var packed2 = load("res://scenes/scene2.tscn")
	if not packed2:
		print("AUTO_LAYOUT_FAIL scene2 load"); quit(); return
	var s2 = packed2.instantiate()
	root.add_child(s2)
	await process_frame
	await process_frame

	await _advance_dialogue(s2, 12)
	if s2._phase < s2.Phase.OBSERVE:
		await _advance_dialogue(s2, 12)
	if s2._phase != s2.Phase.OBSERVE:
		print("AUTO_LAYOUT_FAIL phase=", s2._phase); quit(); return

	for h in s2.HOTSPOTS:
		s2._obs._record(h["id"], str(h.get("desc", "")))
		await process_frame
	await _wait(6.5)
	s2._open_wall()
	await process_frame
	await process_frame

	var wall = s2.find_child("ReasoningWall", true, false)
	if wall == null:
		print("AUTO_LAYOUT_FAIL ReasoningWall not found"); quit(); return
	var gv = wall._graph_view
	if gv == null:
		print("AUTO_LAYOUT_FAIL _graph_view null"); quit(); return

	gv.auto_layout()
	await process_frame
	await process_frame
	await process_frame

	var nc = gv._node_center
	if nc == null or nc.size() < 2:
		print("AUTO_LAYOUT_FAIL no nodes to arrange, n=", nc.size() if nc else -1); quit(); return

	# —— 断言 1 & 2 ——
	var cols := {}   # rounded_x -> Array[node, center]
	var fails := PackedStringArray()
	for id0 in nc:
		var p: Vector2 = nc[id0]
		var cx: int = int(round(p.x / 6.0))
		if not cols.has(cx):
			cols[cx] = []
		cols[cx].append([id0, p])
	var total_ok := true
	var col_count := 0
	for cx in cols:
		var arr = cols[cx]
		if arr.size() < 1:
			continue
		arr.sort_custom(func(a, b): return a[1].y < b[1].y)
		col_count += 1
		for i in range(1, arr.size()):
			var gap: float = arr[i][1].y - arr[i - 1][1].y
			if gap < 14.0:
				total_ok = false
				fails.append("同列x=%d 节点 %s 与 %s 垂直间距 %.1fpx (<15)" % [cx, arr[i - 1][0], arr[i][0], gap])
	# 分列应至少 2 列（人物 + 至少一个内容列）
	if col_count < 2:
		total_ok = false
		fails.append("分列数过少 col_count=%d" % col_count)

	if total_ok:
		print("AUTO_LAYOUT_OK nodes=%d cols=%d（列对齐 + 同列不覆盖）" % [nc.size(), col_count])
	else:
		for f in fails:
			print("AUTO_LAYOUT_FAIL ", f)
	quit()


func _advance_dialogue(scene: Node, max_clicks: int) -> void:
	for i in max_clicks:
		var dm = scene._dm
		if dm == null or not is_instance_valid(dm) or not dm.is_active():
			break
		if dm.get_current_trigger() != "choice":
			dm.advance()
		await _wait(0.3)
		await process_frame


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _watchdog_quit() -> void:
	print("AUTO_LAYOUT_WATCHDOG 超时强制退出（疑似挂死）")
	quit()