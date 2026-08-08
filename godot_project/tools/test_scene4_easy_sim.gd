extends SceneTree

## 模拟【简单模式】根因：手动 _obs.show() 让观察器在非观察阶段保持激活，
## 验证 _advance_blocked 的 _in_observe_phase() 护栏是否放行对话推进。
## 修复前：_obs.is_active() 无条件拦截 → e0「马车上」点不动、卡死。
## 修复后：非观察阶段不拦截 → 对话正常推进到 e8。

func _initialize() -> void:
	await create_timer(0.3).timeout
	var s = load("res://scenes/scene4.tscn").instantiate()
	root.add_child(s)
	await create_timer(0.3).timeout

	var dm = s.get("_dm")
	if dm == null:
		print("[FAIL] DialogueManager 未初始化")
		quit(); return

	# 模拟简单模式：强制激活空观察器（基类 _create_observers 在 EASY + 有热点时会做）
	s._obs.show()
	print("[SIM] 已手动 _obs.show() → _obs.is_active()=", s._obs.is_active(), " _in_observe_phase()=", s._in_observe_phase())

	var cur = dm.current_node
	print("[INFO] 对话激活=", dm.is_active(), " 当前节点=", cur.node_id if cur else "null")

	# 模拟玩家点击推进
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
		print("[OK] 模拟EASY：观察器激活但非观察阶段，对话仍正常推进（卡死已修复）")
	else:
		print("[FAIL] 模拟EASY：对话被观察器拦截，仍卡死（phase=", phase_after, "）")
	quit()
