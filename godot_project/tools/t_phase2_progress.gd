extends SceneTree
## t_phase2_progress.gd — Phase 2 冒烟探针：推理进程条（顶栏第三行）。
##
## 验证四件事：
##   A. 开墙后进程条初始态：fill 节点在、ΣR 显示 0%、_last_branch 已有实时评估值
##   B. 程序化连一条真相边（走 _gv_relations_changed 真实回调）→ ΣR 增长、UI 与 _last_branch 一致
##   C. 色块数 == _last_branch.per_branch 中 core 链数
##   D. _open_verify_result（判定重算）后进程条与 _last_branch 严格一致（同一数据源）+ 验证窗口创建
##
## 用法：GODOT --headless --path . -s res://tools/t_phase2_progress.gd

const RC := preload("res://data/reasoning_chains.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var rw = load("res://scripts/clue/reasoning_wall.gd")
	var wall = rw.new()
	wall.name = "Wall_phase2"
	root.add_child(wall)
	var hypo: Dictionary = RC.build_wall_dict("CH02")
	hypo["scene_id"] = "scene2"      # 评分 scope = scene2 的 core 链（CH02+CH03）
	wall.setup(_mk_clues(), hypo, Callable(), Callable(), 0, Callable(), {}, Callable(), false, -1, Callable(), false, [], false, false)
	await process_frame
	await process_frame
	var gv = wall._graph_view
	var fails := 0

	# A. 初始态
	if gv == null or not is_instance_valid(gv):
		print("P2_PROG FAIL A: graph_view null")
		quit()
		return
	if wall._progress_fill == null or not is_instance_valid(wall._progress_fill):
		print("P2_PROG FAIL A0: 进程条未创建")
		quit()
		return
	if wall._progress_pct_lbl.text != "0%":
		print("P2_PROG FAIL A1: 初始 ΣR 应为 0%%，实际 %s" % wall._progress_pct_lbl.text)
		fails += 1
	else:
		print("P2_PROG OK A: 初始 ΣR=0%%  fill=%s" % str(wall._progress_fill.size))
	var lb0: Dictionary = wall._last_branch
	if lb0.is_empty():
		print("P2_PROG FAIL A2: _last_branch 空（初始评估未跑）")
		fails += 1
	else:
		print("P2_PROG OK A2: _last_branch 就绪 ratio=%.4f" % float(lb0.get("ratio", 0.0)))

	# B. 连一条真相边 c201→H2-01（CH02 真相边）——走真实回调路径
	var before: float = float(lb0.get("ratio", 0.0))
	gv._relations.append({"from": "c201", "to": "H2-01", "kind": "support"})
	wall._gv_relations_changed(gv._relations.duplicate())
	await process_frame
	var lb1: Dictionary = wall._last_branch
	var r1: float = float(lb1.get("ratio", 0.0))
	if r1 <= before:
		print("P2_PROG FAIL B: 连边后 ΣR 未增长 before=%.4f after=%.4f" % [before, r1])
		fails += 1
	else:
		print("P2_PROG OK B: 连真相边后 ΣR %.4f→%.4f  UI=%s" % [before, r1, wall._progress_pct_lbl.text])
	if wall._progress_pct_lbl.text != "%d%%" % int(round(r1 * 100.0)):
		print("P2_PROG FAIL B2: UI 百分比(%s)与 _last_branch(%.2f%%) 不一致" % [wall._progress_pct_lbl.text, r1 * 100.0])
		fails += 1
	else:
		print("P2_PROG OK B2: UI 与 _last_branch 一致")

	# C. 色块数 == per_branch core 数（queue_free 旧块仍在树上，过滤）
	var core_n := 0
	for b in lb1.get("per_branch", []):
		if bool(b.get("core", false)):
			core_n += 1
	var live := 0
	for c in wall._progress_blocks.get_children():
		if not c.is_queued_for_deletion():
			live += 1
	if live != core_n:
		print("P2_PROG FAIL C: 活色块 %d != core 链 %d" % [live, core_n])
		fails += 1
	else:
		print("P2_PROG OK C: 色块=%d == core 链=%d" % [live, core_n])

	# D. 判定重算后一致（_open_verify_result 内部 force 刷新）+ 验证窗口创建
	wall._verify_ctl._open_verify_result()
	await process_frame
	var lb2: Dictionary = wall._last_branch
	if wall._progress_pct_lbl.text != "%d%%" % int(round(float(lb2.get("ratio", 0.0)) * 100.0)):
		print("P2_PROG FAIL D: 提交判定后进程条与 _last_branch 不一致")
		fails += 1
	else:
		print("P2_PROG OK D: 提交后 UI=%s == _last_branch ratio" % wall._progress_pct_lbl.text)
	if wall._verify_win == null:
		print("P2_PROG FAIL D2: 验证窗口未创建")
		fails += 1
	else:
		print("P2_PROG OK D2: 验证窗口已创建")

	wall.queue_free()
	await process_frame
	print("P2_PROG DONE fails=%d" % fails)
	quit()


func _mk_clues() -> Array:
	var out: Array = []
	for cid in ["c201", "c202", "c203", "c204", "c205", "c206"]:
		out.append({"id": cid, "name": cid, "description": "", "source": "scene2"})
	return out
