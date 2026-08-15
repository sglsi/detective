extends SceneTree
# 回归：场景一信使时序（思傅 2026-08-15 修复）
#   验证「赫德森太太/福尔摩斯对话期间信使与线索不提前出现」：
#     1) _start_messenger_phase 开始时：信使立绘隐藏、观察器未激活（点击未开放）
#     2) 对话推进到 m1（福尔摩斯：让他进来吧）→ 信使立绘出现（入场）
#     3) 推进到 m3（福尔摩斯：您曾经是海军陆战队军士吧）→ 线索提示圈点亮，
#        但观察器【仍未激活】（reveal_hints 不开放点击，防对话中误点）
#     4) 对话结束 → 观察器激活（开放点击），进入正式观察
#   用对话节点钩子 dialogue_node_entered 驱动，与真实游玩一致。
#   注意：autoload 在 _init 延迟帧才挂到 /root，故用 _init + call_deferred 与 test_tool_system 同模式。

func _init() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var ok := true
	var path := "res://scenes/scene1.tscn"
	if not ResourceLoader.exists(path):
		print("SC1_MSG: FAIL (packed scene not found)"); quit(); return
	var packed = load(path)
	var inst = packed.instantiate()

	# 手动构建 UI + 两组观察器（绕过开场对话自动启动，聚焦信使时序）
	inst._build_ui()
	# 难度设为简单，确保 hint_level=2 以验证「点亮提示圈」确实画出 6 个。
	# ⚠️ --script 入口脚本编译期解析不到 autoload 裸全局名，须用 /root 节点路径取实例；
	#    且须延迟到此帧（autoload 才挂到 root）。
	var dm_node = root.get_node_or_null("/root/DifficultyManager")
	if dm_node == null:
		print("SC1_MSG: FAIL (autoload DifficultyManager 未加载)"); quit(); return
	dm_node.set_difficulty(0)   # 0 = EASY → hotspot_hint_level=2
	inst._create_observers()

	# 进入信使阶段（此时不应有任何信使/线索提前出现）
	inst._start_messenger_phase()
	await create_timer(0.05).timeout

	# (1) 对话开始前：信使立绘隐藏 + 观察器未激活
	var a0: bool = (not inst._messenger_portrait_ctrl.visible) and (not inst._messenger_obs.is_active())
	if not a0:
		print("SC1_MSG: FAIL (1) 信使/线索在对话前就出现了 (portrait=", inst._messenger_portrait_ctrl.visible, " active=", inst._messenger_obs.is_active(), ")")
		ok = false

	# (2) 推进到 m1：福尔摩斯同意让信使进来 → 信使入场
	inst._dm.advance(); await create_timer(0.02).timeout
	var a1: bool = inst._messenger_portrait_ctrl.visible
	if not a1:
		print("SC1_MSG: FAIL (2) m1 后信使立绘未显示")
		ok = false

	# (3) 推进到 m2、m3；m3 福尔摩斯介绍其为海军军士 → 点亮提示圈（但不激活点击）
	inst._dm.advance(); await create_timer(0.02).timeout   # m2
	inst._dm.advance(); await create_timer(0.02).timeout   # m3 -> reveal_hints
	var lvl: int = dm_node.hotspot_hint_level
	var a3_active: bool = not inst._messenger_obs.is_active()   # reveal 绝不可激活点击
	var hl_count: int = _count_hl(inst._messenger_obs._portrait_ctrl)
	# 期望点亮数 = 观察器经难度过滤后的真实热点数（EASY 剔除非误导线索→4 条；HARD 含误导→6 条）
	var expected_hl: int = inst._messenger_obs._hotspots.size()
	var a3_hints: bool = (lvl > 0 and hl_count == expected_hl) or (lvl == 0 and hl_count == 0)
	if not a3_active:
		print("SC1_MSG: FAIL (3) m3 reveal_hints 错误地激活了观察器（对话中可点）")
		ok = false
	if a3_hints == false:
		print("SC1_MSG: FAIL (3) m3 后提示圈未点亮 (hint_level=", lvl, " hl_count=", hl_count, " expected=", expected_hl, ")")
		ok = false

	# (4) 推进直到对话结束 → 观察器激活（正式观察）
	for i in range(12):
		if not is_instance_valid(inst._dm) or not inst._dm.dialogue_active:
			break
		inst._dm.advance(); await create_timer(0.02).timeout
	await create_timer(0.1).timeout
	var a_end: bool = inst._messenger_obs.is_active()
	if not a_end:
		print("SC1_MSG: FAIL (4) 对话结束后观察器未激活（信使线索仍点不到）")
		ok = false

	print("[SC1_MSG] a0(premature_hidden)=", a0, " a1(m1_portrait)=", a1,
		  " a3_active_still_false=", a3_active, " a3_hints(lvl=", lvl, " hl=", hl_count, ")=", a3_hints,
		  " a_end(active)=", a_end)
	print("SC1_MSG: ", "PASS ✅" if ok else "FAIL ❌")
	quit()

func _count_hl(ctrl: Control) -> int:
	var n := 0
	for c in ctrl.get_children():
		if c.name.begins_with("hl_"):
			n += 1
	return n
