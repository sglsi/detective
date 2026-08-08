extends SceneTree

## 验证场景四入场对话是否能在 e0→e8 间正常推进（不依赖鼠标，直接调 _dm.advance）
## 注意：场景 _ready 会自动调用 _enter_arrival（无存档时），本测试不重复调用。

func _initialize() -> void:
	await create_timer(0.3).timeout
	var s = load("res://scenes/scene4.tscn").instantiate()
	root.add_child(s)
	await create_timer(0.3).timeout

	var dm = s.get("_dm")
	if dm == null:
		print("[FAIL] DialogueManager 未初始化 (_dm == null)")
		quit(); return

	var cur = dm.current_node
	print("[INFO] 对话激活=", dm.is_active(), " 当前节点=", cur.node_id if cur else "null", " trigger=", dm.get_current_trigger() if dm.has_method("get_current_trigger") else cur.trigger)
	print("[INFO] _obs.is_active()=", s._obs.is_active(), " _phase=", s.get("_phase"))

	# 模拟玩家连续点击推进
	var guard := 0
	while dm.is_active() and guard < 30:
		cur = dm.current_node
		if cur == null:
			print("[INFO] 当前节点为空，停止")
			break
		print("[STEP] node=", cur.node_id, " trigger=", cur.trigger, " text=", cur.text.substr(0, 16))
		dm.advance()
		guard += 1
		await create_timer(0.05).timeout

	await create_timer(0.1).timeout
	var phase_after = s.get("_phase")
	var modal = s.get("_modal_panel")
	print("[RESULT] 对话结束后 _phase=", phase_after, " modal_panel有效=", (modal != null and is_instance_valid(modal)))
	if phase_after == 0 and modal != null:
		print("[OK] 入场对话已完整推进并触发 _on_arrival_ended → 追问面板已弹出")
	else:
		print("[FAIL] 入场对话未正常结束（phase=", phase_after, " modal=", modal, "）")
	quit()
