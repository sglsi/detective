extends SceneTree
## 存档/读档 + 线索状态一致性自测（对应需求：读档位置错乱 + 推理墙与进度「两层皮」）
##
## 覆盖：
##  A) 场景三「存档时只 3 条，但 ClueSystem 全局累计到 9 条」→ 读档后
##     场景内进度(_indoor_clues)、观察器已记录数、推理墙(_clue count)、ClueSystem 来源
##     必须全部收敛到 3，且恢复到存档阶段（不是从头开始）。
##  B) 场景三完成后自动存档（phase=TRANSITION）→ 读档恢复到 TRANSITION，而非开场。
##  C) 场景二同样的两层皮场景（garden）。
##  D) 场景一同样的两层皮场景（watson）。
##
## 每个场景用「准备 restore 输入（场景_state + 膨胀的 ClueSystem）→ 全新实例化触发 _ready→_restore_saved_state」
## 的方式，精确复现用户报的「存档 3 条 / 全局 9 条」错位输入，验证修复后收敛一致。
## 看门狗兜底，挂死强制退出。

func _initialize() -> void:
	await process_frame
	await process_frame
	var wd = create_timer(45.0)
	wd.timeout.connect(_watchdog_quit)

	var ClueSystem = root.get_node_or_null("/root/ClueSystem")
	var GameManager = root.get_node_or_null("/root/GameManager")
	var SaveSystem = root.get_node_or_null("/root/SaveSystem")
	if not (ClueSystem and GameManager and SaveSystem):
		print("P14_FAIL autoloads missing"); quit(); return

	var ok := true
	var log := []

	# 先抓各场景 Phase 枚举（避免硬编码，throwaway 实例即可）
	var s3p = load("res://scenes/scene3.tscn").instantiate()
	var PH3 = s3p.Phase
	var s2p = load("res://scenes/scene2.tscn").instantiate()
	var PH2 = s2p.Phase
	var s1p = load("res://scenes/scene1.tscn").instantiate()
	var PH1 = s1p.Phase
	s3p.queue_free(); s2p.queue_free(); s1p.queue_free()
	await process_frame; await process_frame

	# ============ A) 场景三：存档 3 条 / 全局 9 条 → 读档收敛一致 ============
	# 准备 restore 输入：scene_state 指向 3 条，ClueSystem 被「全局累计」撑到 9 条（复现用户现场）
	var three_ids = ["c301","c302","c303"]
	var all_indoor = ["c301","c302","c303","c304","c305","c306","c307","c308","c309"]
	GameManager.scene_state = {"scene_id":"scene3", "phase": PH3.INDOOR_OBSERVE, "clue_ids": three_ids.duplicate()}
	ClueSystem.clear_collected()
	ClueSystem.restore_collected_clues(_mk_snapshot(all_indoor, "indoor"))
	var s3 = _spawn("res://scenes/scene3.tscn")
	await process_frame; await process_frame
	var wall3 = s3.find_child("ReasoningWall", true, false)
	var cs_indoor = ClueSystem.get_collected("indoor").size()
	var rec3 = s3._indoor_obs.get_recorded()
	var local3 = s3._indoor_clues.size()
	log.append("[A 场景三] phase=%d 本地=%d 观察器=%d ClueSystem(indoor)=%d (期望 3/3/3)" % [s3._phase, local3, rec3, cs_indoor])
	if s3._phase != PH3.INDOOR_OBSERVE:
		ok = false; log.append("  ✗ 读档未恢复到 INDOOR_OBSERVE（bug1 复发）")
	if local3 != 3 or rec3 != 3 or cs_indoor != 3:
		ok = false; log.append("  ✗ 两层皮未修复：本地/观察器/ClueSystem 未全部收敛到 3")
	# 打开推理墙，核对墙上的线索数（必须与进度一致）
	s3._open_wall()
	await process_frame; await process_frame
	var w3 = s3.find_child("ReasoningWall", true, false)
	var wall_n3 = w3._clues.size() if w3 else -1
	log.append("  推理墙线索数=%d (期望 3)" % wall_n3)
	if wall_n3 != 3:
		ok = false; log.append("  ✗ 推理墙显示 %d 条 ≠ 场景进度 3（两层皮）" % wall_n3)
	if w3: w3.queue_free()
	s3.queue_free(); await process_frame; await process_frame

	# ============ B) 场景三完成自动存档 → 读档恢复到 TRANSITION（bug1 修复）============
	GameManager.scene_state = {"scene_id":"scene3", "phase": PH3.TRANSITION, "clue_ids": all_indoor.duplicate()}
	ClueSystem.clear_collected()
	ClueSystem.restore_collected_clues(_mk_snapshot(all_indoor, "indoor"))
	var s3b = _spawn("res://scenes/scene3.tscn")
	await process_frame; await process_frame
	log.append("[B 场景三完成] phase=%d (期望 %d=TRANSITION，绝非 0=ARRIVAL/开场)" % [s3b._phase, PH3.TRANSITION])
	if s3b._phase != PH3.TRANSITION:
		ok = false; log.append("  ✗ 读档后从头开始（bug1 复发）：phase=%d" % s3b._phase)
	var dm_active = (s3b._dm != null and s3b._dm.is_active())
	log.append("  过渡对话激活=%s (期望 true)" % str(dm_active))
	if not dm_active:
		ok = false; log.append("  ✗ 读档到 TRANSITION 但未进入过渡对话")
	s3b.queue_free(); await process_frame; await process_frame

	# ============ C) 场景二：存档 3 条 / 全局 6 条 → 读档收敛一致 ============
	var g_three = ["c201","c202","c203"]
	var all_garden = ["c201","c202","c203","c204","c205","c206"]
	GameManager.scene_state = {"scene_id":"scene2", "phase": PH2.GARDEN_OBSERVE, "clue_ids": g_three.duplicate()}
	ClueSystem.clear_collected()
	ClueSystem.restore_collected_clues(_mk_snapshot(all_garden, "garden"))
	var s2 = _spawn("res://scenes/scene2.tscn")
	await process_frame; await process_frame
	var cs_garden = ClueSystem.get_collected("garden").size()
	var rec2 = s2._garden_obs.get_recorded()
	var local2 = s2._garden_clues.size()
	log.append("[C 场景二] phase=%d 本地=%d 观察器=%d ClueSystem(garden)=%d (期望 3/3/3)" % [s2._phase, local2, rec2, cs_garden])
	if s2._phase != PH2.GARDEN_OBSERVE:
		ok = false; log.append("  ✗ 读档未恢复到 GARDEN_OBSERVE")
	if local2 != 3 or rec2 != 3 or cs_garden != 3:
		ok = false; log.append("  ✗ 两层皮未修复（场景二）")
	s2._open_wall()
	await process_frame; await process_frame
	var w2 = s2.find_child("ReasoningWall", true, false)
	var wall_n2 = w2._clues.size() if w2 else -1
	log.append("  推理墙线索数=%d (期望 3)" % wall_n2)
	if wall_n2 != 3:
		ok = false; log.append("  ✗ 推理墙显示 %d 条 ≠ 场景进度 3（场景二两层皮）" % wall_n2)
	if w2: w2.queue_free()
	s2.queue_free(); await process_frame; await process_frame

	# ============ D) 场景一：存档 2 条 watson / 全局 4 条 → 读档收敛一致 ============
	var w_two = ["wrist","arm"]
	var all_watson = ["wrist","arm","face","pose"]
	GameManager.scene_state = {"scene_id":"scene1", "phase": PH1.OBSERVE_WATSON, "clue_ids": w_two.duplicate()}
	ClueSystem.clear_collected()
	ClueSystem.restore_collected_clues(_mk_snapshot(all_watson, "watson"))
	var s1 = _spawn("res://scenes/scene1.tscn")
	await process_frame; await process_frame
	var cs_watson = ClueSystem.get_collected("watson").size()
	var rec1 = s1._watson_obs.get_recorded()
	log.append("[D 场景一] phase=%d 观察器=%d ClueSystem(watson)=%d (期望 2/2)" % [s1._phase, rec1, cs_watson])
	if s1._phase != PH1.OBSERVE_WATSON:
		ok = false; log.append("  ✗ 读档未恢复到 OBSERVE_WATSON")
	if rec1 != 2 or cs_watson != 2:
		ok = false; log.append("  ✗ 两层皮未修复（场景一）")
	# 场景一的推理墙直接读 ClueSystem.get_collected("watson")，核对其大小
	var w_clues = ClueSystem.get_collected("watson")
	log.append("  场景一推理墙数据源(watson)大小=%d (期望 2)" % w_clues.size())
	if w_clues.size() != 2:
		ok = false; log.append("  ✗ 场景一推理墙数据源=%d ≠ 2（两层皮）" % w_clues.size())
	s1.queue_free(); await process_frame; await process_frame

	# 汇总
	for l in log:
		print("[P14]", l)

	if ok:
		print("P14_SAVELOAD_OK 读档位置 + 推理墙/进度一致性 全部通过")
	else:
		print("P14_SAVELOAD_FAIL 存在不一致（两层皮或读档位置错乱）")
	quit()

func _mk_snapshot(ids: Array, source: String) -> Array:
	var snap := []
	for id in ids:
		snap.append({"id": id, "name": id, "desc": "d", "correct": true, "source": source})
	return snap

func _spawn(path: String) -> Node:
	var packed = load(path)
	var n = packed.instantiate()
	root.add_child(n)
	return n

func _wait(sec: float) -> void:
	await create_timer(sec).timeout

func _watchdog_quit() -> void:
	print("P14_WATCHDOG 超时强制退出（疑似挂死）")
	quit()
