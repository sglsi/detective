extends SceneTree
## 回归测试：ClueObserver 防重复/防叠层守卫（真实玩家乱点路径）
## 1) 重复 _on_record 同一线索不重复计数、all_recorded 不重复触发
## 2) 全部记录后 show() 不把已记录热点重新显示
## 3) 放大层打开时点其他热点被忽略（防叠层残留 obs_dim 挡死全屏）
## 4) 读档死局防御：scene3 恢复到勘查阶段但线索已 9/9 → 自动进入推理

func _initialize() -> void:
	await process_frame
	await process_frame
	var wd = create_timer(40.0)
	wd.timeout.connect(_watchdog_quit)

	var ClueSystem = root.get_node_or_null("/root/ClueSystem")
	var GameManager = root.get_node_or_null("/root/GameManager")
	if not (ClueSystem and GameManager):
		print("P13_FAIL autoloads missing"); quit(); return

	var packed = load("res://scenes/scene3.tscn")
	var s3 = packed.instantiate()
	root.add_child(s3)
	await process_frame
	await process_frame

	var ok = true
	var obs = s3._indoor_obs
	var all_count := [0]
	obs.all_recorded.connect(func(_c): all_count[0] += 1)

	s3._phase = s3.Phase.INDOOR_OBSERVE
	obs.show()

	# ---- 1) 重复记录守卫 ----
	obs._on_record("c301", "d")
	obs._on_record("c301", "d")  # 玩家重复记录同一线索
	obs._on_record("c301", "d")
	await process_frame
	if obs.get_recorded() != 1:
		ok = false; print("P13_FAIL 重复记录被计数：recorded=", obs.get_recorded())
	else:
		print("[P13] 重复记录守卫 OK（3 次 _on_record 只计 1）")

	# ---- 3) 叠层守卫：打开一个放大层后，点其他热点应被忽略 ----
	obs._on_hotspot("c302", "desc302")
	await process_frame
	var dims_before = _count_named(s3, "obs_dim")
	obs._on_hotspot("c303", "desc303")  # 放大层未关时点另一个热点
	await process_frame
	var dims_after = _count_named(s3, "obs_dim")
	if dims_after > dims_before:
		ok = false; print("P13_FAIL 放大层叠加：dim %d→%d" % [dims_before, dims_after])
	else:
		print("[P13] 叠层守卫 OK（dim 保持 %d）" % dims_after)
	# 记录 c302 关闭放大层
	obs._on_record("c302", "desc302")
	await process_frame
	await process_frame
	if _count_named(s3, "obs_dim") != 0:
		ok = false; print("P13_FAIL 放大层未清干净")

	# ---- 2) show() 不复活已记录热点 ----
	for h in s3.HOTSPOTS:
		obs._on_record(h["id"], "d")  # 补齐剩余（重复的会被守卫忽略）
	await process_frame
	if obs.get_recorded() != 9:
		ok = false; print("P13_FAIL 补齐后 recorded=", obs.get_recorded())
	if all_count[0] != 1:
		ok = false; print("P13_FAIL all_recorded 触发次数=", all_count[0], "（期望 1）")
	else:
		print("[P13] all_recorded 恰好触发 1 次 OK")
	obs.show()
	var visible_btns = 0
	for b in obs._btns:
		if b.visible: visible_btns += 1
	if visible_btns != 0:
		ok = false; print("P13_FAIL show() 复活了已记录热点：可见=", visible_btns)
	else:
		print("[P13] show() 不复活已记录热点 OK")

	# ---- 4) 读档死局防御：勘查阶段 + 线索 9/9（clue_ids 已满）→ 自动进推理 ----
	# 注意：以存档 clue_ids 为权威（已收满 9 条），而非依赖全局 ClueSystem 累计，
	# 这样「clue_ids 空但 ClueSystem 满」这类不一致存档不会再被误判为「已集齐」。
	var all_ids = []
	for h in s3.HOTSPOTS: all_ids.append(h["id"])
	GameManager.scene_state = {"scene_id":"scene3", "phase": s3.Phase.INDOOR_OBSERVE, "clue_ids": all_ids}
	var s3b = packed.instantiate()
	root.add_child(s3b)
	await process_frame
	await process_frame
	# _enter_reasoning 有 2.5s 计时器再开墙
	await create_timer(3.5).timeout
	await process_frame
	if s3b._phase != s3b.Phase.REASONING:
		ok = false; print("P13_FAIL 读档死局未解除：phase=", s3b._phase)
	elif s3b.find_child("ReasoningWall", true, false) == null:
		ok = false; print("P13_FAIL 读档死局：推理墙未自动打开")
	else:
		print("[P13] 读档死局防御 OK（勘查+9/9 → 自动进推理墙）")

	if ok: print("P13_GUARD_OK 观察器守卫与读档死局防御全部通过")
	else: print("P13_GUARD_FAIL 存在未通过项")
	quit()

func _count_named(node: Node, target: String) -> int:
	var cnt = 0
	if node.name == target: cnt += 1
	for c in node.get_children():
		cnt += _count_named(c, target)
	return cnt

func _watchdog_quit() -> void:
	print("P13_WATCHDOG 超时强制退出")
	quit()
