extends SceneTree
## t_phase0_verdict_sync.gd — Phase 0.2 行为探针：图谱着色评分源切换验证。
##
## 验证四件事：
##   A. 墙 build 后 GraphViewController 收到 verdict_provider 且 _verdict 与 wall.get_verdict() 同源
##   B. 乱连 3 条 support 边后 _verdict 不再是旧口径的 3（旧口径 support≥3 即绿）
##   C. _compute_verdict() 返回 provider 结果（着色与提交判定同一评分源）
##   D. 摘掉 provider 后回落旧口径（-1 → 兜底推算），旧调用方不受影响
##
## 用法：GODOT --headless --path . -s res://tools/t_phase0_verdict_sync.gd

const RC := preload("res://data/reasoning_chains.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var rw = load("res://scripts/clue/reasoning_wall.gd")
	var wall = rw.new()
	wall.name = "Wall_phase0"
	root.add_child(wall)
	var hypo: Dictionary = RC.build_wall_dict("CH01M")
	wall.setup(_mk_clues(), hypo, Callable(), Callable(), 0, Callable(), {}, Callable(), false, -1, Callable(), false, [], false, true)
	await process_frame
	await process_frame
	var gv = wall._graph_view
	var fails := 0

	# A. provider 生效且同源
	if gv == null or not is_instance_valid(gv):
		print("P0_SYNC FAIL graph_view null")
		quit()
		return
	if not gv._cb_verdict_provider.is_valid():
		print("P0_SYNC FAIL provider missing")
		fails += 1
	var wv: int = wall.get_verdict()
	if gv._verdict != wv:
		print("P0_SYNC FAIL initial verdict mismatch gv=%d wall=%d" % [gv._verdict, wv])
		fails += 1
	else:
		print("P0_SYNC OK A: provider 同源 gv=%d wall=%d" % [gv._verdict, wv])

	# B+C. 乱连 3 条 support（tattoo 在 CH01M 链内 → 单端认领 → extra_edge 拉低 R）
	for i in range(3):
		gv._relations.append({"from": "tattoo", "to": "junk_%d" % i, "kind": "support"})
	gv._rebuild_graph()
	var wv2: int = wall.get_verdict()
	if gv._verdict == 3:
		print("P0_SYNC FAIL B: 乱连后仍 verdict=3（旧口径泄漏）")
		fails += 1
	elif gv._verdict != wv2:
		print("P0_SYNC FAIL B: 乱连后不同源 gv=%d wall=%d" % [gv._verdict, wv2])
		fails += 1
	else:
		print("P0_SYNC OK B: 乱连后 verdict=%d（旧口径会给 3）" % gv._verdict)
	if int(gv._data._compute_verdict()) != gv._verdict:
		print("P0_SYNC FAIL C: _compute_verdict 与 _verdict 不一致")
		fails += 1
	else:
		print("P0_SYNC OK C: 着色源=_verdict=%d" % gv._verdict)

	# D. 摘掉 provider → 回落旧口径
	gv._cb_verdict_provider = Callable()
	gv._rebuild_graph()
	if gv._verdict != -1:
		print("P0_SYNC FAIL D: 无 provider 时 _verdict 应为 -1")
		fails += 1
	else:
		print("P0_SYNC OK D: 无 provider 回落旧口径（_verdict=-1）")

	wall.queue_free()
	await process_frame
	print("P0_SYNC DONE fails=%d" % fails)
	quit()


func _mk_clues() -> Array:
	var out: Array = []
	for cid in ["tattoo", "beard", "posture", "manner", "sleeve", "limp"]:
		out.append({"id": cid, "name": cid, "description": "", "source": "messenger"})
	for cid in ["wrist", "arm", "face_dark", "face_haggard", "pose", "medical"]:
		out.append({"id": cid, "name": cid, "description": "", "source": "watson"})
	return out
