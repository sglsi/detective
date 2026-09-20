extends Control
## 复现场景四「兰斯警士：好，那我从头开讲」卡死。
## 走真实玩家路径：入场对话 → 三选一初始追问 → ia0 → ia1 → end → _start_step1。
## 同时用「真实 _input 鼠标点击」与「直接 _dm.advance()」两种方式推进，
## 以区分「点击被 _advance_blocked 吞掉」与「_start_step1 抛错」两类根因。

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var s4 = load("res://scenes/scene4.tscn").instantiate()
	add_child(s4)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	# 进入 ARRIVAL 阶段（等价于从场景三切到场景四）
	s4._enter_arrival()
	await get_tree().process_frame

	var dbg := func(tag: String):
		var d = s4.get("_dm")
		if d and d.is_active():
			print("[%s] node=%s speaker=%s trig=%s | advance_blocked(mouse)=%s" % [
				tag, d.get_current_speaker(), d.current_node.node_id if d.current_node else "?",
				d.get_current_trigger(), str(s4._advance_blocked(true))])
		else:
			print("[%s] dialogue INACTIVE" % tag)

	# ---- 1) 用真实 _input 鼠标点击推进「入场对话」e0..e8 ----
	print("===== 阶段一：入场对话（真实 _input 点击）=====")
	var guard := 0
	while s4.get("_dm") and s4._dm.is_active() and guard < 40:
		dbg.call("arrival")
		# 构造一次左键按下事件
		var ev = InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = true
		ev.position = Vector2(960, 1000)   # 对话栏中央偏下，避开顶部回看按钮
		s4._input(ev)
		await get_tree().process_frame
		guard += 1
	print("[INFO] 入场对话结束？dm.active=", s4._dm.is_active() if s4.get("_dm") else "n/a")

	# 入场结束应弹三选一面板（_on_arrival_ended → _show_initial_choice）。
	# 模拟玩家选「案发经过」→ _init_dir_case
	if s4.has_method("_init_dir_case"):
		print("===== 阶段二：玩家选「案发经过」→ _init_dir_case =====")
		# 忠实模拟：真实游戏里选项按钮的 pressed 回调先 _close_modal() 再调 cb
		if s4.has_method("_close_modal"):
			s4._close_modal()
		s4._init_dir_case()
		await get_tree().process_frame
	else:
		printerr("[FAIL] scene4 无 _init_dir_case 方法")
		get_tree().quit(1)
		return

	# ---- 2) ia0 → ia1 用真实 _input 点击 ----
	print("===== 阶段三：ia0/ia1（真实 _input 点击）=====")
	guard = 0
	var reached_ia1 := false
	var entered_step1 := false
	while s4.get("_dm") and s4._dm.is_active() and guard < 20:
		dbg.call("ia")
		var sp = s4._dm.get_current_speaker()
		var nid = s4._dm.current_node.node_id if s4._dm.current_node else "?"
		if nid == "ia1":
			reached_ia1 = true
		if nid == "s00":
			entered_step1 = true
		var ev = InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = true
		ev.position = Vector2(960, 1000)
		s4._input(ev)
		await get_tree().process_frame
		# 若点击因 blocked 无效，节点会停在原地——检测是否卡住
		var nid2 = s4._dm.current_node.node_id if (s4.get("_dm") and s4._dm.current_node) else "?"
		if nid2 == nid and reached_ia1 and guard > 0:
			printerr("[STALL] ia1 点击后被 _advance_blocked 吞掉，未推进到 end")
			break
		guard += 1

	# ---- 3) 判定是否进入 _start_step1（新对话 s00 即视为成功）----
	# _loop 已在推进 s00..s5，只要曾进入 _start_step1 的对话即证明 ia1→end→_start_step1 通畅。
	await get_tree().process_frame
	await get_tree().process_frame
	var d = s4.get("_dm")
	if entered_step1:
		print("RESULT: PASS ia1 → end → _start_step1 通畅（已推进至 Step1 对话 s00..s5）")
		get_tree().quit(0)
	else:
		var nid = d.current_node.node_id if (d and d.current_node) else "inactive"
		printerr("RESULT: FAIL 卡在 ia1，未进入 _start_step1。当前 node=%s" % nid)
		get_tree().quit(1)
