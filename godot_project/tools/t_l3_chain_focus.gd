extends SceneTree
## L3 链聚焦功能探针：验证 ReasoningChains.get_chain_node_ids 返回正确

func _init():
	call_deferred("_run")

func _run():
	var ok := 0
	var fail := 0

	# Test 1: CH01W 链节点 id 完整性
	var w_ids: Array = ReasoningChains.get_chain_node_ids("CH01W")
	_p("CH01W 节点数>=10", w_ids.size() >= 10, "实际 %d" % w_ids.size(), ok, fail)
	_p("CH01W 含 W-A1", w_ids.has("W-A1"), "", ok, fail)
	_p("CH01W 含 conclusion_C-A1", w_ids.has("conclusion_C-A1"), "", ok, fail)
	_p("CH01W 含 NPC_WT", w_ids.has("NPC_WT"), "", ok, fail)

	# Test 2: CH01M 链节点 id
	var m_ids: Array = ReasoningChains.get_chain_node_ids("CH01M")
	_p("CH01M 节点数>=10", m_ids.size() >= 10, "实际 %d" % m_ids.size(), ok, fail)
	_p("CH01M 含 MT-1", m_ids.has("MT-1"), "", ok, fail)
	_p("CH01M 含 conclusion_CL1-01", m_ids.has("conclusion_CL1-01"), "", ok, fail)
	_p("CH01M 含 NPC_MSG", m_ids.has("NPC_MSG"), "", ok, fail)

	# Test 3: 不存在的链返回空
	var no_ids: Array = ReasoningChains.get_chain_node_ids("NO_SUCH_CHAIN")
	_p("不存在的链返回空", no_ids.is_empty(), "", ok, fail)

	# Test 4: evaluator display_ratio 字段存在（无 DM 环境下 NORMAL=1.0）
	var ev := WallBranchEvaluator.new()
	var t := {"edges": [{"from":"c1","to":"h1","kind":"support","correct":true}],
		"truth_edges": ["c1:h1:support"], "truth_nodes": ["h1"], "missing_edges": 0}
	var res: Dictionary = ev.evaluate_branch("CH01W", t)
	_p("evaluator 有 display_ratio", res.has("display_ratio"), "", ok, fail)
	var dr: float = float(res.get("display_ratio", -1))
	var r: float = float(res.get("ratio", -1))
	_p("display_ratio == ratio (NORMAL=1.0)", abs(dr - r) < 0.001,
		"dr=%.3f r=%.3f" % [dr, r], ok, fail)

	print("\n===== RESULT: %d passed, %d failed =====" % [ok, fail])
	quit(0 if fail == 0 else 1)

func _p(name: String, cond: bool, detail: String, ok, fail):
	if cond:
		print("✅ %s%s" % [name, " ("+detail+")" if detail else ""])
		ok += 1
	else:
		print("❌ %s — %s" % [name, detail])
		fail += 1
