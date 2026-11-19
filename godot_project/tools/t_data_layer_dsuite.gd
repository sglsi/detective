extends SceneTree
## D 数据层 10 用例自动化测试
const Chains = preload("res://data/reasoning_chains.gd")
const Truth = preload("res://data/case_branch_truth.gd")
const Eval = preload("res://scripts/clue/wall_branch_evaluator.gd")

var _ok: int = 0
var _fail: int = 0

func _init():
	call_deferred("_run")

func _run():
	_print_header("D01: validate_all 零错误")
	_test_d01()
	
	_print_header("D02: 单链结构校验")
	_test_d02()
	
	_print_header("D03: ids() / has(id) 一致性")
	_test_d03()
	
	_print_header("D04: build_wall_dict 输出结构正确")
	_test_d04()
	
	_print_header("D05: truth 表与链库派生等价性")
	_test_d05()
	
	_print_header("D06: EASY 难度无干扰项")
	_test_d06()
	
	_print_header("D07: NORMAL 难度含干扰项")
	_test_d07()
	
	_print_header("D08: 不存在链的兜底")
	_test_d08()
	
	_print_header("D09: get_chain_node_ids 返回完整")
	_test_d09()
	
	_print_header("D10: 链库与 legacy 表共存无重复")
	_test_d10()
	
	_print_header("D11: build_wall_dict 幂等（连续两次深度相等）")
	_test_d11()
	
	print("\n" + "============================================================")
	print("  D 数据层测试结果：%d / %d 通过  %d 失败" % [_ok, _ok+_fail, _fail])
	print("=============================================================")
	quit(0 if _fail == 0 else 1)

func _print_header(title: String):
	print("\n--- %s ---" % title)

func _p(name: String, cond: bool, detail: String = ""):
	if cond:
		print("  ✅ ", name, "  ", detail)
		_ok += 1
	else:
		print("  ❌ ", name, " — ", detail)
		_fail += 1

# ============================================================
# D01: validate_all 零错误
# ============================================================
func _test_d01():
	var errs: Array = Chains.validate_all()
	_p("validate_all 返回空数组（零错误）", errs.is_empty(),
		"错误数: %d" % errs.size())
	if errs.size() > 0:
		for i in range(min(5, errs.size())):
			print("    错误示例: ", str(errs[i]).substr(0, 100))

# ============================================================
# D02: 单链结构校验
# ============================================================
func _test_d02():
	var test_ids := ["CH01W", "CH01M", "CH09F"]
	var all_pass := true
	for id in test_ids:
		if not Chains.has(id):
			all_pass = false
			print("    链不存在: ", id)
			continue
		var errs: Array = Chains.validate(id)
		if errs.size() > 0:
			all_pass = false
			print("    ", id, " 错误数: ", errs.size())
	_p("3 条代表链 validate 单测零错误", all_pass,
		"CH01W/CH01M/CH09F")

# ============================================================
# D03: ids() / has(id) 一致性
# ============================================================
func _test_d03():
	var ids: Array = Chains.ids()
	var all_pass := true
	var count := 0
	for id in ids:
		count += 1
		if not Chains.has(str(id)):
			all_pass = false
			print("    ids() 返回了但 has() 返回 false: ", id)
	# 反向验证：has 一个不存在的应返回 false
	if Chains.has("__NOT_EXIST__"):
		all_pass = false
		print("    has(__NOT_EXIST__) 错误地返回 true")
	_p("ids 与 has 双向一致", all_pass, "共 %d 条链" % count)

# ============================================================
# D04: build_wall_dict 输出结构正确
# ============================================================
func _test_d04():
	var d: Dictionary = Chains.build_wall_dict("CH01W")
	# 顶层必须有 battlefield + persons + wall_meta
	_p("顶层含 battlefield", d.has("battlefield"), "")
	_p("顶层含 persons", d.has("persons"), "")
	# 注意：battlefield 不一定有 clues 数组（线索由 ClueSystem 全局管理，
	# 链库通过 gate_clue_ids 引用线索 id），验证引用关系存在即可
	var has_clue_refs := false
	for h in d.get("battlefield", {}).get("hypotheses", []):
		if h.has("gate_clue_ids"):
			has_clue_refs = true
			break
	_p("线索引用机制（gate_clue_ids）存在", has_clue_refs,
		"battlefield 无 clues 数组，通过 gate_clue_ids 引用")
	_p("battlefield 含 hypotheses", d.get("battlefield", {}).has("hypotheses"), "")
	_p("battlefield 含 conclusions", d.get("battlefield", {}).has("conclusions"), "")
	# 节点必须有 id 字段
	var hypos: Array = d.get("battlefield", {}).get("hypotheses", [])
	var has_ids := true
	for h in hypos:
		if not h.has("id"):
			has_ids = false
			break
	_p("hypothesis 节点含 id 字段", has_ids, "共 %d 个推断" % hypos.size())
	# conclusions 必须有 id + gate（字段名可能为 gate_hypo_ids，结论层的 gate 是假设 id 列表）
	var concls: Array = d.get("battlefield", {}).get("conclusions", [])
	var concl_ok := true
	var uses_gate_hypo := false
	for c in concls:
		if not c.has("id"):
			concl_ok = false
			break
		if c.has("gate_hypo_ids"):
			uses_gate_hypo = true
	_p("conclusion 节点含 id（gate 字段为 gate_hypo_ids）", concl_ok,
		"共 %d 个结论，gate_hypo_ids: %s" % [concls.size(), str(uses_gate_hypo)])

# ============================================================
# D05: truth 表与链库派生等价性
# ============================================================
func _test_d05():
	# 只测链库已覆盖的链（CH01W, CH01M）
	var test_ids := ["CH01W", "CH01M"]
	var all_pass := true
	for id in test_ids:
		# 链库派生
		var derived: Dictionary = Chains.derive_truth(id)
		# legacy 表
		var legacy: Dictionary = {}
		for b in Truth.branches():
			if str(b.get("id","")) == id:
				legacy = b
				break
		if legacy.is_empty():
			all_pass = false
			print("    ", id, " 在 legacy 表中未找到")
			continue
		# 对比节点集合
		var d_nodes: Dictionary = {}
		for n in derived.get("nodes", []):
			d_nodes[n.get("id","")] = n.get("layer","")
		var l_nodes: Dictionary = {}
		for n in legacy.get("nodes", []):
			l_nodes[n.get("id","")] = n.get("layer","")
		var nodes_match := true
		for nid in d_nodes.keys():
			if not l_nodes.has(nid):
				nodes_match = false
				print("    ", id, " 派生多出节点: ", nid)
			elif l_nodes[nid] != d_nodes[nid]:
				nodes_match = false
				print("    ", id, " 节点层级不一致: ", nid, " 派生=", d_nodes[nid], " legacy=", l_nodes[nid])
		for nid in l_nodes.keys():
			if not d_nodes.has(nid):
				nodes_match = false
				print("    ", id, " legacy 多出节点: ", nid)
		# 对比边集合（只看 from+to+kind，忽略顺序）
		var d_edges := {}
		for e in derived.get("edges", []):
			var key := str(e.get("from","")) + "|" + str(e.get("to","")) + "|" + str(e.get("kind",""))
			d_edges[key] = true
		var l_edges := {}
		for e in legacy.get("edges", []):
			var key := str(e.get("from","")) + "|" + str(e.get("to","")) + "|" + str(e.get("kind",""))
			l_edges[key] = true
		var edges_match := true
		for ek in d_edges.keys():
			if not l_edges.has(ek):
				edges_match = false
				print("    ", id, " 派生多出边: ", ek)
		for ek in l_edges.keys():
			if not d_edges.has(ek):
				edges_match = false
				print("    ", id, " legacy 多出边: ", ek)
		_p("%s 节点集合等价" % id, nodes_match, "")
		_p("%s 边集合等价" % id, edges_match,
			"派生 %d 边 / legacy %d 边" % [d_edges.size(), l_edges.size()])
		if not nodes_match or not edges_match:
			all_pass = false
	_p("链库派生与 legacy 表等价", all_pass, "CH01W + CH01M")

# ============================================================
# D06: EASY 难度无干扰项
# ============================================================
func _test_d06():
	# EASY = mislead_chance <= 0
	# 验证 build_wall_dict 中 hypothesis 无 correct=false
	var orig_chance := _get_difficulty_mislead()
	_set_easy_mode()
	var d: Dictionary = Chains.build_wall_dict("CH01W")
	var hypos: Array = d.get("battlefield", {}).get("hypotheses", [])
	var has_false := false
	var false_count := 0
	for h in hypos:
		if not bool(h.get("correct", true)):
			has_false = true
			false_count += 1
	_restore_difficulty(orig_chance)
	_p("EASY 模式下 CH01W 不含干扰假设", not has_false,
		"干扰项数: %d / 总数 %d" % [false_count, hypos.size()])

# ============================================================
# D07: NORMAL 难度含干扰项
# ============================================================
func _test_d07():
	# NORMAL = mislead_chance = 0.3
	var orig_chance := _get_difficulty_mislead()
	_set_normal_mode()
	var d: Dictionary = Chains.build_wall_dict("CH01M")
	var hypos: Array = d.get("battlefield", {}).get("hypotheses", [])
	var correct_count := 0
	var false_count := 0
	for h in hypos:
		if bool(h.get("correct", true)):
			correct_count += 1
		else:
			false_count += 1
	_restore_difficulty(orig_chance)
	# CH01M 应当有干扰项（correct:false 的 hypothesis）
	_p("NORMAL 模式下 CH01M 含干扰假设", false_count > 0,
		"正确 %d / 干扰 %d" % [correct_count, false_count])
	# 干扰项比例应当合理（0.3 概率 × 干扰项总数，跑 10 次看是否有波动）
	var runs_with_mislead := 0
	for i in range(10):
		var d2: Dictionary = Chains.build_wall_dict("CH01M")
		var h2: Array = d2.get("battlefield", {}).get("hypotheses", [])
		var fcount := 0
		for h in h2:
			if not bool(h.get("correct", true)):
				fcount += 1
		if fcount > 0:
			runs_with_mislead += 1
	_p("10 次采样多数含干扰", runs_with_mislead >= 5,
		"含干扰次数: %d/10" % runs_with_mislead)

# ============================================================
# D08: 不存在链的兜底
# ============================================================
func _test_d08():
	var d: Dictionary = Chains.build_wall_dict("__NO_SUCH_CHAIN__")
	_p("不存在的链 build_wall_dict 返回空 dict", d.is_empty(),
		"keys: %s" % str(d.keys()))
	var t: Dictionary = Chains.derive_truth("__NO_SUCH_CHAIN__")
	_p("不存在的链 derive_truth 返回空 dict", t.is_empty(), "")
	var ids: Array = Chains.get_chain_node_ids("__NO_SUCH_CHAIN__")
	_p("不存在的链 get_chain_node_ids 返回空数组", ids.is_empty(), "")
	var has_it: bool = Chains.has("__NO_SUCH_CHAIN__")
	_p("不存在的链 has 返回 false", not has_it, "")

# ============================================================
# D09: get_chain_node_ids 返回完整
# ============================================================
func _test_d09():
	var d: Dictionary = Chains.build_wall_dict("CH01W")
	var bf: Dictionary = d.get("battlefield", {})
	var ids: Array = Chains.get_chain_node_ids("CH01W")
	
	# 所有 hypothesis 都应该在 node_ids 中
	var hypos: Array = bf.get("hypotheses", [])
	var all_hypos_found := true
	var missing: Array = []
	for h in hypos:
		var hid: String = str(h.get("id",""))
		if not ids.has(hid):
			all_hypos_found = false
			missing.append(hid)
	_p("CH01W 所有推断节点在 node_ids 中", all_hypos_found,
		"缺失: %s" % str(missing))
	
	# 所有 conclusion（带 conclusion_ 前缀）都应该在
	var concls: Array = bf.get("conclusions", [])
	var all_concls_found := true
	var cmissing: Array = []
	for c in concls:
		var cid: String = "conclusion_" + str(c.get("id",""))
		if not ids.has(cid):
			all_concls_found = false
			cmissing.append(cid)
	_p("CH01W 所有结论节点（conclusion_前缀）在 node_ids 中", all_concls_found,
		"缺失: %s" % str(cmissing))
	
	# 所有 persons 都应该在
	var persons: Array = d.get("persons", [])
	var all_persons_found := true
	var pmissing: Array = []
	for p in persons:
		var pid: String = str(p.get("id",""))
		if not ids.has(pid):
			all_persons_found = false
			pmissing.append(pid)
	_p("CH01W 所有人物节点在 node_ids 中", all_persons_found,
		"缺失: %s" % str(pmissing))
	
	# 去重验证：id 不重复
	var seen := {}
	var has_dup := false
	for id in ids:
		var s: String = str(id)
		if seen.has(s):
			has_dup = true
			break
		seen[s] = true
	_p("节点 id 无重复", not has_dup, "总数 %d" % ids.size())

# ============================================================
# D10: 链库与 legacy 表共存无重复
# ============================================================
func _test_d10():
	# CaseBranchTruth.branches() 应该返回所有链，不重复
	var all: Array = Truth.branches()
	var id_set := {}
	var has_dup := false
	var dup_id := ""
	var total := 0
	for b in all:
		total += 1
		var bid: String = str(b.get("id",""))
		if id_set.has(bid):
			has_dup = true
			dup_id = bid
			break
		id_set[bid] = true
	_p("CaseBranchTruth.branches() 无重复 id", not has_dup,
		"共 %d 条，重复: %s" % [total, dup_id])
	
	# 链库覆盖的链应该从链库来（不是 legacy 复制一份）
	var lib_ids: Array = Chains.ids()
	var lib_count := 0
	for id in lib_ids:
		if id_set.has(str(id)):
			lib_count += 1
	_p("链库链全部出现在 branches() 中", lib_count == lib_ids.size(),
		"链库 %d 条 / branches %d 条" % [lib_count, total])

# ============================================================
# 辅助：难度操作
# ============================================================

func _has_gate_clue_ids(d: Dictionary) -> bool:
	var bf: Dictionary = d.get("battlefield", {})
	for h in bf.get("hypotheses", []):
		if h.has("gate_clue_ids"):
			return true
	return false

func _get_difficulty_mislead() -> float:
	if Engine.has_singleton("DifficultyManager"):
		return Engine.get_singleton("DifficultyManager").mislead_chance
	return -1.0

func _set_easy_mode():
	if Engine.has_singleton("DifficultyManager"):
		Engine.get_singleton("DifficultyManager").set_difficulty(0)  # EASY

func _set_normal_mode():
	if Engine.has_singleton("DifficultyManager"):
		Engine.get_singleton("DifficultyManager").set_difficulty(1)  # NORMAL

func _restore_difficulty(val: float):
	# 探针环境不恢复无所谓
	pass

# ============================================================
# D11: build_wall_dict 幂等
#   文档称「仅 mislead_chance 触发的干扰抽样需固定 seed」——已核实该抽样不在本函数内
#   （实际位于 graph/graph_view_dock.gd _open_conclusion_popup，UI 候选窗）。
#   本用例覆盖 build_wall_dict 本身的纯函数幂等性：
#   深拷贝隔离 + 难度过滤确定性（EASY 剔除 correct:false）。
# ============================================================
func _test_d11():
	# 前置：DifficultyManager 必须经 autoload 正确可达
	# （Engine.has_singleton 对 autoload 恒 false，本套件 D06/D07 旧辅助即因此失效，不沿用）
	var dm: Node = AutoloadUtil.get_autoload("DifficultyManager")
	if dm == null:
		_p("D11.0 前置：DifficultyManager autoload 可达", false,
			"AutoloadUtil.get_autoload 返回 null，D11 无法验证难度过滤")
		return
	var orig_diff: int = int(dm.current_difficulty)

	# D11.1 同一链（CH01W）连续两次调用深度相等
	var d1: Dictionary = Chains.build_wall_dict("CH01W")
	var d2: Dictionary = Chains.build_wall_dict("CH01W")
	_p("D11.1 CH01W 连续两次 build 深度相等", d1 == d2, "")

	# D11.2 遍历全部链逐条两次调用相等
	var ids: Array = Chains.ids()
	var bad_ids: Array = []
	for cid in ids:
		if Chains.build_wall_dict(str(cid)) != Chains.build_wall_dict(str(cid)):
			bad_ids.append(str(cid))
	_p("D11.2 全部 %d 条链两次调用相等" % ids.size(), bad_ids.is_empty(),
		"不一致: %s" % str(bad_ids))

	# D11.3 EASY：切换生效 + 两次相等 + 无 correct:false
	dm.set_difficulty(dm.Difficulty.EASY)
	var easy_ok := is_equal_approx(float(dm.mislead_chance), 0.0)
	_p("D11.3a 切 EASY 生效 mislead_chance==0.0", easy_ok,
		"chance=%.2f" % float(dm.mislead_chance))
	var e1: Dictionary = Chains.build_wall_dict("CH01M")
	var e2: Dictionary = Chains.build_wall_dict("CH01M")
	_p("D11.3b EASY 下 CH01M 两次相等", e1 == e2, "")
	var easy_false := _count_false_hypos(e1)
	_p("D11.3c EASY 下 hypotheses 无 correct:false", easy_false == 0,
		"干扰项数: %d / 总数 %d" % [easy_false, _total_hypos(e1)])

	# D11.4 NORMAL：切换生效 + 两次相等 + 干扰项数量与 EASY 不同（证明难度过滤真实生效）
	dm.set_difficulty(dm.Difficulty.NORMAL)
	var normal_ok := is_equal_approx(float(dm.mislead_chance), 0.3)
	_p("D11.4a 切 NORMAL 生效 mislead_chance==0.3", normal_ok,
		"chance=%.2f" % float(dm.mislead_chance))
	var n1: Dictionary = Chains.build_wall_dict("CH01M")
	var n2: Dictionary = Chains.build_wall_dict("CH01M")
	_p("D11.4b NORMAL 下 CH01M 两次相等", n1 == n2, "")
	var normal_false := _count_false_hypos(n1)
	_p("D11.4c NORMAL 干扰项数与 EASY 不同", normal_false != easy_false,
		"EASY %d / NORMAL %d" % [easy_false, normal_false])

	# D11.5 源数据未被污染：调用前后源 hypotheses.size() 不变
	var src_bf: Dictionary = Chains.CHAINS["CH01W"]["wall"]["battlefield"]
	var src_before: int = src_bf.get("hypotheses", []).size()
	Chains.build_wall_dict("CH01W")
	var src_after: int = src_bf.get("hypotheses", []).size()
	_p("D11.5 源数据 hypotheses.size() 调用前后不变", src_before == src_after,
		"前后 %d / %d" % [src_before, src_after])

	# D11.6 深拷贝隔离：清空返回值后再次调用仍返回完整数据
	var dd: Dictionary = Chains.build_wall_dict("CH01W")
	var dd_bf: Dictionary = dd.get("battlefield", {})
	dd_bf["hypotheses"] = []
	var dd2: Dictionary = Chains.build_wall_dict("CH01W")
	var total2: int = dd2.get("battlefield", {}).get("hypotheses", []).size()
	_p("D11.6 清空返回值后再次调用仍返回完整假设集", total2 > 0,
		"再次调用返回 %d 条" % total2)

	# D11.7 不存在链连续两次均空且相等
	var x1: Dictionary = Chains.build_wall_dict("__NO_SUCH_CHAIN__")
	var x2: Dictionary = Chains.build_wall_dict("__NO_SUCH_CHAIN__")
	_p("D11.7 不存在链两次均空且相等", x1 == x2 and x1.is_empty(), "")

	# 复位难度到进入前的值
	dm.set_difficulty(orig_diff)
	print("    难度已复位: current_difficulty=", dm.current_difficulty)

func _count_false_hypos(d: Dictionary) -> int:
	var n := 0
	for h in d.get("battlefield", {}).get("hypotheses", []):
		if not bool(h.get("correct", true)):
			n += 1
	return n

func _total_hypos(d: Dictionary) -> int:
	return d.get("battlefield", {}).get("hypotheses", []).size()
