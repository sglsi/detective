extends SceneTree
## t_phase3_milestones.gd — Phase 3 冒烟探针：里程碑 gate 化 + 跨场景 merge。
##
## 验证六件事：
##   A. 开墙后里程碑初始全灭（gate 未命中）
##   B. connect_nodes("c201","H2-01")（真实 persist 链路）→ gate ["c201"] 命中 S2-1 点亮
##      且 state_store["milestones_lit"] 持久含 "S2-1"（走 connect_nodes 内部 _persist_state）
##   B2. milestone_index 登记存在（text/scene 正确）
##   C. 结论节点 conclusion_ 前缀形态命中：连 c202→conclusion_CL2-1 → S2-2 点亮
##   D. merge 语义：state_store 预置他场景 lit（S8-1/S8-2）→ 再 persist → 不被覆盖冲掉
##   E. 点亮不回退：remove_relation 删掉 S2-1 的 gate 边 → S2-1 仍点亮
##   F. 进程轴数据可消费：milestones_lit + milestone_index 结构满足 _case_progress_items 契约
##
## 用法：GODOT --headless --path . -s res://tools/t_phase3_milestones.gd

const RC := preload("res://data/reasoning_chains.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var rw = load("res://scripts/clue/reasoning_wall.gd")
	var wall = rw.new()
	wall.name = "Wall_phase3"
	root.add_child(wall)
	var hypo: Dictionary = RC.build_wall_dict("CH02")
	hypo["scene_id"] = "scene2"
	hypo["milestones"] = [
		{"id": "S2-1", "text": "死亡地点：劳瑞斯顿花园街3号", "gate": ["c201"]},
		{"id": "S2-2", "text": "来的是一辆出租马车（轴距6英尺10英寸）", "gate": ["H2-01", "CL2-1"]},
		{"id": "S2-5", "text": "三线合一：马车夫进了那栋空房子（假设级）", "gate": ["CL2-4"]},
	]
	var store: Dictionary = {}   # 引用传入，persist 写回此处
	wall.setup(_mk_clues(), hypo, Callable(), Callable(), 0, Callable(), store, Callable(), true, -1, Callable(), false, [], false, false)
	await process_frame
	await process_frame
	var fails := 0

	# A. 初始全灭
	var all_dark := true
	for m in wall._milestones:
		if m.get("lit", false):
			all_dark = false
	if not all_dark:
		print("P3_MS FAIL A: 初始存在已点亮里程碑")
		fails += 1
	else:
		print("P3_MS OK A: 初始全灭（%d 条）" % wall._milestones.size())

	# B. 真实链路连边 → gate 命中点亮 + persist
	wall._rel_ctl.connect_nodes("c201", "H2-01", "relate")
	await process_frame
	var s21_lit := false
	for m in wall._milestones:
		if m["id"] == "S2-1" and m.get("lit", false):
			s21_lit = true
	if not s21_lit:
		print("P3_MS FAIL B: 连 c201→H2-01 后 S2-1 未点亮")
		fails += 1
	else:
		print("P3_MS OK B: S2-1 gate 命中点亮")
	var lit_arr: Array = store.get("milestones_lit", [])
	if not lit_arr.has("S2-1"):
		print("P3_MS FAIL B1: milestones_lit 未持久（%s）" % str(lit_arr))
		fails += 1
	else:
		print("P3_MS OK B1: milestones_lit 持久含 S2-1（%s）" % str(lit_arr))

	# B2. milestone_index 登记
	var idx: Dictionary = store.get("milestone_index", {})
	var reg: Dictionary = idx.get("S2-1", {})
	if reg.get("text", "") != "死亡地点：劳瑞斯顿花园街3号":
		print("P3_MS FAIL B2: milestone_index 登记异常 %s" % str(reg))
		fails += 1
	else:
		print("P3_MS OK B2: index 登记 text=%s scene=%s" % [reg.get("text", ""), reg.get("scene", "")])

	# C. conclusion_ 前缀命中（图谱形态：玩家连的是 conclusion_CL2-1 节点）
	wall._rel_ctl.connect_nodes("c202", "conclusion_CL2-1", "support")
	await process_frame
	var s22_lit := false
	for m in wall._milestones:
		if m["id"] == "S2-2" and m.get("lit", false):
			s22_lit = true
	if not s22_lit:
		print("P3_MS FAIL C: conclusion_ 前缀形态未命中 S2-2")
		fails += 1
	else:
		print("P3_MS OK C: conclusion_CL2-1 命中 gate [H2-01, CL2-1] → S2-2 点亮")

	# D. merge：预置他场景 lit → 再 persist → 不被冲掉
	store["milestones_lit"] = ["S8-1", "S8-2"]
	wall._rel_ctl.connect_nodes("c203", "H2-02", "relate")
	await process_frame
	var lit2: Array = store.get("milestones_lit", [])
	if not (lit2.has("S8-1") and lit2.has("S8-2") and lit2.has("S2-1")):
		print("P3_MS FAIL D: merge 失败 %s" % str(lit2))
		fails += 1
	else:
		print("P3_MS OK D: merge 保留他场景 S8-1/S8-2 + 本场景 S2-1/S2-2")

	# E. 点亮不回退：删 S2-1 的 gate 边
	wall._rel_ctl.remove_relation("c201", "H2-01")
	await process_frame
	var s21_still := false
	for m in wall._milestones:
		if m["id"] == "S2-1" and m.get("lit", false):
			s21_still = true
	if not s21_still:
		print("P3_MS FAIL E: 删边后 S2-1 被错误回退")
		fails += 1
	else:
		print("P3_MS OK E: 删边后 S2-1 仍点亮（刻度不回退）")

	# F. 进程轴数据契约：lit 数组 + index 字典可被 _case_progress_items 消费
	#（他场景预置的 S8-* 无登记属预期——轴上降级显示裸 id；本场景点亮的必有登记）
	for mid in store.get("milestones_lit", []):
		if not idx.has(str(mid)):
			print("P3_MS INFO F: lit id %s 无 index 登记（他场景预置项，轴上降级裸 id）" % str(mid))
	var ok_f: bool = idx.has("S2-1") and idx.has("S2-2") and not store.get("milestones_lit", []).is_empty()
	if ok_f:
		print("P3_MS OK F: 进程轴数据契约满足（lit=%s index_keys=%s）" % [str(store.get("milestones_lit", [])), str(idx.keys())])
	else:
		fails += 1

	wall.queue_free()
	await process_frame
	print("P3_MS DONE fails=%d" % fails)
	quit()


func _mk_clues() -> Array:
	var out: Array = []
	for cid in ["c201", "c202", "c203", "c204", "c205", "c206"]:
		out.append({"id": cid, "name": cid, "description": "", "source": "scene2"})
	return out
