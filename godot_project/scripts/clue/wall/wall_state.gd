extends RefCounted
class_name WallState

## 推理墙 · 状态层（拆自 reasoning_wall.gd，Request C 后架构分层）
##
## 职责：身份揭示门控（NPC 中文名）、verdict 信号（contradiction/support 实时计数）、
## 跨重开持久化（关联/关系/战场/里程碑/verified）、人物派生（含 ClueSystem 兜底）、
## 里程碑初始化与点亮 UI、三星评价（观察/推理/洞察 + StarRatingSystem 提交）。
## 读取/回写 owner（ReasoningWall）状态；常量归墙经 owner. 引用；
## get_verdict / get_milestone_state 为公开 API 留在墙内（内部改调本层信号方法）。

var owner: ReasoningWall

# ===================== 人物显示名 / 身份揭示门控 =====================
func _npc_display_name(id: String) -> String:
	return owner._NPC_DISPLAY_NAMES.get(id, id)


## 身份揭示门控（需求2）：判定某 NPC 是否应以"已知人物"出现。live 为当前已收集线索。
func _identity_revealed(pid: String, live: Array) -> bool:
	var gates: Array = owner._IDENTITY_REVEAL_GATES.get(pid, [])
	if gates.is_empty():
		return true
	for g in gates:
		for c in live:
			if c.get("id", "") == g:
				return true
	return false


# ===================== verdict 信号 =====================
## 关系信号：把「拖拽相互关系」接入验证判定（原判定只看 _associated/_contradicting 计数）
func _contradiction_signals() -> int:
	var n := owner._contradicting
	for r in owner._relations:
		# 虚线（存疑）只显示、不计入判定，防止玩家乱连误判结案
		if r.get("dashed", false):
			continue
		if r.kind == "contradict" or r.kind == "oppose":
			n += 1
	return n


func _support_signals() -> int:
	var n := owner._associated
	# 修复（问题2）：支撑目标若是误导型派生节点（推断/结论 kind=false），该支撑边不计入判定强度——
	# 给错误推导（误导推断/伪结论）建支撑边，不该让案件「倾向成立/已证实」。
	# 结论落盘时会生成 推断→结论 的 support 边（to=conclusion_X），故此处一并覆盖结论正确性。
	var gv = owner._graph_view
	for r in owner._relations:
		if r.get("dashed", false):
			continue
		if r.get("kind", "") == "support":
			var to_id: String = str(r.get("to", ""))
			if gv != null and gv.has_method("_derived_node_correct") and not gv._derived_node_correct(to_id):
				continue
			n += 1
	return n


# ===================== 跨重开持久化（#场景二卡死修复） =====================
## 推理墙为瞬时节点，重建即丢失进度。状态由场景持有的 _state_store 引用保存：
## 关联线索 id、战场假设/矛盾状态、里程碑点亮、verified 标记与最近判定。
func _restore_state() -> void:
	if not owner._persist_enabled: return
	if owner._state_store.is_empty(): return
	var saved_assoc: Array = owner._state_store.get("associated", [])
	var assoc_set := {}
	for s in saved_assoc: assoc_set[s] = true
	owner._associated = 0; owner._contradicting = 0
	owner._doubt_book = owner._state_store.get("doubt_book", [])
	owner._relations = []
	for r in owner._state_store.get("relations", []):
		owner._relations.append({"from": r.get("from", ""), "to": r.get("to", ""), "kind": r.get("kind", "relate"),
			"color_key": r.get("color_key", owner._rel_ctl._kind_to_key(r.get("kind", "relate"))), "dashed": r.get("dashed", false)})
	for c in owner._clues:
		if assoc_set.has(c.get("id", "")):
			c["associated"] = true
			owner._associated += 1
			if not c.get("correct", true): owner._contradicting += 1
		else:
			c["associated"] = false
	var bf: Dictionary = owner._state_store.get("battlefield", {})
	owner._battle_hypo_states = {}
	owner._battle_contra_states = {}
	for h in owner._battle.get("hypotheses", []):
		var hid: String = h.get("id", "")
		if bf.has(hid): owner._battle_hypo_states[hid] = int(bf[hid])
	for c in owner._battle.get("contradictions", []):
		var cid: String = c.get("id", "")
		if bf.has(cid): owner._battle_contra_states[cid] = bool(bf[cid])
	for m in owner._milestones:
		m["lit"] = (m["id"] in owner._state_store.get("milestones_lit", []))
	owner._verified = owner._state_store.get("verified", false)
	owner._verified_verdict = owner._state_store.get("verdict", -1)


func _persist_state() -> void:
	if not owner._persist_enabled: return   # 调用方未开启持久化则不写（兼容旧调用方）
	var assoc := []
	for c in owner._clues:
		if c.get("associated", false): assoc.append(c.get("id", ""))
	var m_lit := []
	for m in owner._milestones:
		if m["lit"]: m_lit.append(m["id"])
	var bf := {}
	for h in owner._battle.get("hypotheses", []):
		bf[h.get("id", "")] = owner._battle_hypo_states.get(h.get("id", ""), 0)
	for c in owner._battle.get("contradictions", []):
		bf[c.get("id", "")] = owner._battle_contra_states.get(c.get("id", ""), false)
	# ⚠️ 不要 _state_store.clear()！（Bug1）图谱视图把节点位置/模式/焦点也写进同一份
	# state_store 引用，clear() 会把它们一起抹掉。这里只覆盖推理墙自身关心的键。
	owner._state_store["associated"] = assoc
	owner._state_store["milestones_lit"] = m_lit
	owner._state_store["battlefield"] = bf
	owner._state_store["verified"] = owner._verified
	owner._state_store["verdict"] = owner._verified_verdict
	owner._state_store["doubt_book"] = owner._doubt_book
	owner._state_store["relations"] = owner._relations.duplicate()


# ===================== 人物派生（图谱人物中心） =====================
func _derive_persons() -> Array:
	var seen := {}
	var out := []
	# 兜底（修根因 2026-08-19 v4）：如果调用方传入的 _clues 为空但 ClueSystem 实际有已收集线索，
	# 实时拉一次（在 easy 模式下对话可能提前结束导致 _clues 没被填到；这层兜底保证人物中心至少能渲染）。
	if owner._clues.is_empty() and ClueSystem and ClueSystem.has_method("get_collected"):
		var live: Array = ClueSystem.get_collected("")
		if not live.is_empty():
			print("[reasoning_wall] 兜底从 ClueSystem.get_collected 拉取 %d 条线索" % live.size())
			owner._clues = live
	for c in owner._clues:
		for p in c.get("related_npcs", []):
			if not seen.has(p):
				seen[p] = true
				# 身份揭示门控：未满足揭示条件时仍保留人物中心，但以占位名居替，
				# 避免提前暴露真名（需求2）且不让人物消失（需求4）。
				var npc_name: String = _npc_display_name(p) if _identity_revealed(p, owner._clues) else owner._masked_name(p)
				out.append({"id": p, "name": npc_name})
	var extra: Array = owner._hypothesis.get("persons", [])
	for p in extra:
		var pid: String = p.get("id", "") if p is Dictionary else str(p)
		if not seen.has(pid):
			seen[pid] = true
			# extra persons 同样要走身份门控，否则配置里的真名会绕过线索揭示流程提前暴露。
			var npc_name: String = _npc_display_name(pid) if _identity_revealed(pid, owner._clues) else owner._masked_name(pid)
			out.append({"id": pid, "name": npc_name})
	return out


func _persons_contain(persons: Array, pid: String) -> bool:
	for p in persons:
		if p.get("id", "") == pid:
			return true
	return false


# ===================== 里程碑 =====================
func _init_milestones(hypo: Dictionary) -> void:
	owner._milestones = []
	var ms: Array = hypo.get("milestones", [])
	for m in ms:
		owner._milestones.append({"id": m.get("id", ""), "text": m.get("text", ""), "lit": false})
	if owner._milestones.is_empty():
		owner._milestones.append({"id": "core", "text": hypo.get("title", "核心结论"), "lit": false})
	owner._milestone_total = owner._milestones.size()
	owner._milestone_confirmed = 0


func _update_milestone_ui() -> void:
	if not owner._milestone_lbl: return
	var blocks := ""
	var lit := 0
	for m in owner._milestones:
		if m["lit"]:
			blocks += "■"
			lit += 1
		else:
			blocks += "□"
	owner._milestone_lbl.text = "结论里程碑：%s  已确认事实 %d/%d" % [blocks, lit, owner._milestone_total]


# ===================== 分枝（推理链）计分 · 统一评分源 =====================
## 裁定 3：四档 verdict 与三星评价共用同一个评分源，杜绝「两套口径各说各话」。
## 说明：WallBranchEvaluator 是纯数据引擎（不依赖场景树），此处只做「取快照 → 调引擎」。
## 旧口径（只看有没有连边、支持≥3 即已证实）已废弃：乱连也能拿好评的根源就在那里。
func _evaluate_branch() -> Dictionary:
	var gv = owner._graph_view
	if gv == null or not is_instance_valid(gv):
		return {}
	if not gv.has_method("snapshot_player_work"):
		return {}
	var snap: Dictionary = gv.snapshot_player_work()
	var ev = load("res://scripts/clue/wall_branch_evaluator.gd")
	if ev == null:
		return {}
	var res: Dictionary = ev.evaluate(
		snap.get("relations", []),
		snap.get("graph_nodes", []),
		snap.get("derived_conclusions", []),
		owner._scene_id,
		owner._practice_mode)
	owner._last_branch = res
	return res


## 四档判定（由分枝正确率派生）。拿不到快照时退回旧计数口径兜底，保证判定不塌。
func _branch_verdict() -> int:
	var res := _evaluate_branch()
	if res.is_empty():
		if _contradiction_signals() > 0: return 0
		if _support_signals() >= 3: return 3
		if _support_signals() >= 1: return 2
		return 1
	return int(res.get("verdict", 1))


# ===================== 三星评价（v4.0 三维离散判定 + 分枝计分） =====================
## 三维分工（2026-09-02 重构，避免「推理正确率」被观察/洞察稀释）：
##   观察之星 —— 线索收集完整度（缺失条数），与推理对错无关，保留原逻辑
##   推理之星 —— ★核心改造★ 由分枝（推理链）逐项比对正确率 R 决定：80/55/25 → 3/2/1/0⭐
##   洞察之星 —— 战场命中比例 + 识破误导项加成（每否定一个误导项 +1，封顶 3⭐）
func _update_star_rating() -> void:
	if not owner._star_lbl: return
	# 1) 观察之星：按缺失条数（缺≥3→1⭐ / 缺1-2→2⭐ / 缺0→3⭐），不区分线索重要性
	# 案件级大墙下，观察星按「本场景已收集条数」(_local_clue_count) 计，不受全案线索池扩大影响
	var collected := owner._local_clue_count
	var missing := maxi(0, owner._expected_clues - collected)
	var observe_stars := 3
	if missing >= 3:
		observe_stars = 1
	elif missing >= 1:
		observe_stars = 2

	# 2) 推理之星：由「分枝（推理链）逐项比对正确率」决定（裁定 2 + 第 4 点）。
	#    计分单元是设计文档 14 条推理链：链内节点与边逐项 0/0.5/1 比对，
	#    错误边同样进分母 → 连得越滥正确率越低，彻底堵死「乱选也能好评」。
	#    阈值 80/55/25 → 3/2/1/0⭐；采纳误导项则三星硬条件失败（封顶 2⭐）。
	var br: Dictionary = _evaluate_branch()
	var reasoning_stars := 1
	var branch_ratio := 0.0
	if not br.is_empty():
		branch_ratio = float(br.get("ratio", 0.0))
		reasoning_stars = int(br.get("stars", 1))

	# 3) 洞察之星：战场命中比例（绕路/重要方向/最优顺序的代理）+ 隐藏线索加成，封顶 3⭐
	var insight_stars := 1
	if not owner._battle.is_empty():
		var txt := owner._bf_ctl._battle_status_text()
		var parts := txt.split("·")
		if parts.size() >= 2:
			var hpart := parts[0].strip_edges()  # "推理战场：假设命中 x/y"
			var cp := hpart.split("/")
			if cp.size() == 2:
				var ok := int(cp[0].split(" ")[-1])
				var tot := int(cp[1])
				if tot > 0:
					var ratio2 := float(ok) / tot
					if ratio2 >= 1.0: insight_stars = 3
					elif ratio2 >= 0.5: insight_stars = 2
					else: insight_stars = 1
	# 隐藏线索/全追问等洞察加成（场景经 hypothesis.insight_bonus 传入）
	insight_stars = clampi(insight_stars + owner._insight_bonus, 1, 3)
	# 识破误导项加成：每否定一个误导项 +1（封顶 3⭐）——奖励「看出陷阱」，与错误无惩罚不冲突
	if not br.is_empty():
		var negated: Array = br.get("negated_misleads", [])
		if not negated.is_empty():
			insight_stars = clampi(insight_stars + negated.size(), 1, 3)

	owner._last_stars = {"observation": observe_stars, "reasoning": reasoning_stars, "insight": insight_stars}
	# 练习墙（裁定 5）：评价体系照常运行并展示（教学反馈需要），只是不提交 StarRatingSystem
	if owner._practice_mode:
		owner._star_lbl.text = "教学评价 观察%d⭐ 推理%d⭐ 洞察%d⭐" % [observe_stars, reasoning_stars, insight_stars]
		return
	owner._star_lbl.text = "观察%d⭐ 推理%d⭐ 洞察%d⭐" % [observe_stars, reasoning_stars, insight_stars]

	# 提交逐链三星到 StarRatingSystem（幂等覆盖；逐链离散制 v4.0）
	if StarRatingSystem and owner._chain_id != "":
		StarRatingSystem.submit_chain(owner._chain_id, observe_stars, reasoning_stars, insight_stars)
