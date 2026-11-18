extends SceneTree
## L3 链聚焦功能探针：验证 ReasoningChains.get_chain_node_ids 返回正确

func _init():
	call_deferred("_run")

func _run():
	var st := [0, 0]   # [ok, fail]，引用传递使汇总与退出码真实（原按值传参聚合恒 0）

	# Test 1: CH01W 链节点 id 完整性
	var w_ids: Array = ReasoningChains.get_chain_node_ids("CH01W")
	_p("CH01W 节点数>=10", w_ids.size() >= 10, "实际 %d" % w_ids.size(), st)
	_p("CH01W 含 W-A1", w_ids.has("W-A1"), "", st)
	_p("CH01W 含 conclusion_C-A1", w_ids.has("conclusion_C-A1"), "", st)
	_p("CH01W 含 NPC_WT", w_ids.has("NPC_WT"), "", st)

	# Test 2: CH01M 链节点 id
	var m_ids: Array = ReasoningChains.get_chain_node_ids("CH01M")
	_p("CH01M 节点数>=10", m_ids.size() >= 10, "实际 %d" % m_ids.size(), st)
	_p("CH01M 含 MT-1", m_ids.has("MT-1"), "", st)
	_p("CH01M 含 conclusion_CL1-01", m_ids.has("conclusion_CL1-01"), "", st)
	_p("CH01M 含 NPC_MSG", m_ids.has("NPC_MSG"), "", st)

	# Test 3: 不存在的链返回空
	var no_ids: Array = ReasoningChains.get_chain_node_ids("NO_SUCH_CHAIN")
	_p("不存在的链返回空", no_ids.is_empty(), "", st)

	# Test 4: evaluator display_ratio 字段存在（无 DM 环境下 NORMAL 校正=1.0 → display==ratio）
	# 2026-11-18 修：原 `ev.evaluate_branch("CH01W", t)` 调用不存在的实例方法（WBE 仅有静态 evaluate）
	# 致 SCRIPT ERROR 后引擎挂起 exit=124。改为真实静态签名：scene_id 传真实场景 id，空图调用。
	# 意图保留：验证 evaluate 返回 display_ratio，且 headless（无 DM，current_difficulty≠2）下 correction=1.0。
	var res: Dictionary = WallBranchEvaluator.evaluate([], [], [], "scene1")
	_p("evaluator 有 display_ratio", res.has("display_ratio"), "", st)
	var dr: float = float(res.get("display_ratio", -1))
	var r: float = float(res.get("ratio", -1))
	_p("display_ratio == ratio (NORMAL=1.0)", abs(dr - r) < 0.001,
		"dr=%.3f r=%.3f" % [dr, r], st)

	print("\n===== RESULT: %d passed, %d failed =====" % [st[0], st[1]])
	quit(0 if st[1] == 0 else 1)

func _p(name: String, cond: bool, detail: String, st: Array):
	if cond:
		print("✅ %s%s" % [name, " ("+detail+")" if detail else ""])
		st[0] += 1
	else:
		print("❌ %s — %s" % [name, detail])
		st[1] += 1
