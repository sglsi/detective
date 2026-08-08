extends SceneTree

## 验证场景四在【简单模式】下入场对话能否正常推进（复现卡死根因）
## 用法：--script tools/test_scene4_easy.gd   （默认 EASY）
##       改 difficulty 变量可切 NORMAL/HARD

func _initialize() -> void:
	await create_timer(0.2).timeout
	# 设为简单模式：auto_reveal_clues=true → 基类 _create_observers 会 _obs.show()
	var DM = Engine.get_singleton("DifficultyManager")
	if DM:
		DM.set_difficulty(0)  # 0 = EASY
		print("[INFO] 难度设为 EASY (auto_reveal_clues=", DM.auto_reveal_clues, ")")

	var s = load("res://scenes/scene4.tscn").instantiate()
	root.add_child(s)
	await create_timer(0.3).timeout

	var dm = s.get("_dm")
	if dm == null:
		print("[FAIL] DialogueManager 未初始化 (_dm == null)")
		quit(); return

	var cur = dm.current_node
	print("[INFO] 对话激活=", dm.is_active(), " 当前节点=", cur.node_id if cur else "null", " trigger=", cur.trigger)
	print("[INFO] _obs.is_active()=", s._obs.is_active(), " _in_observe_phase()=", s._in_observe_phase(), " _phase=", s.get("_phase"))

	# 模拟玩家连续点击推进
	var guard := 0
	while dm.is_active() and guard < 30:
		cur = dm.current_node
		if cur == null:
			break
		print("[STEP] node=", cur.node_id, " trigger=", cur.trigger)
		dm.advance()
		guard += 1
		await create_timer(0.05).timeout

	await create_timer(0.1).timeout
	var phase_after = s.get("_phase")
	var modal = s.get("_modal_panel")
	print("[RESULT] 对话结束后 _phase=", phase_after, " modal_panel有效=", (modal != null and is_instance_valid(modal)))
	if phase_after == 0 and modal != null:
		print("[OK] EASY 模式：入场对话已完整推进并弹出追问面板（卡死已修复）")
	else:
		print("[FAIL] EASY 模式：入场对话未正常结束（phase=", phase_after, "）")
	quit()
