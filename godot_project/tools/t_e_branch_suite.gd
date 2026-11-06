extends SceneTree

const ReasoningChains = preload("res://data/reasoning_chains.gd")
const WBE = preload("res://scripts/clue/wall_branch_evaluator.gd")

var passed := 0
var failed := 0
var results: Array = []

func _init():
	call_deferred("_run")

func _run():
	print("======================================================================")
	print("E 分支评分测试套件 (E01~E11 + 疑点 A/B/C/D)")
	print("======================================================================")
	_e01_empty_zero()
	_e02_full_score()
	_e03_reversed_half()
	_e04_dup_dedup()
	_e05_extra_penalty()
	_e06_dashed_noscore()
	_e07_cross_scene_crop()
	_e08_display_diff()
	_e09_raw_stable()
	_e10_star_thresholds()
	_e11_verdict_levels()
	_doubt_a_mislead_no_contradict()
	_doubt_b_unknown_scene()
	_doubt_c_hardfail_verdict()
	_doubt_d_difficulty_override()
	_print_summary()
	quit()

# ── 工具函数 ──────────────────────────────────────────────────────
func _rec(id: String, desc: String, expect: String, actual: String, ok: bool, note: String = ""):
	var st = "PASS" if ok else "FAIL"
	if ok:
		passed += 1
	else:
		failed += 1
	var line = "%-6s %-22s expect=%-18s actual=%-18s %-6s %s" % [id, desc, expect, actual, st, note]
	results.append(line)
	if not ok:
		push_warning("FAIL %s: %s" % [id, line])

func _nid(s: String) -> String:
	return s

func _pad(s: String, n: int) -> String:
	if s.length() >= n:
		return s
	var spaces = ""
	for i in range(n - s.length()):
		spaces += " "
	return s + spaces

func _branch(res: Dictionary, bid: String) -> Dictionary:
	for b in res.per_branch:
		if b.id == bid:
			return b
	return {}

func _build_chain_full(chain_id: String) -> Dictionary:
	var ch = ReasoningChains.derive_truth(chain_id)
	var nodes := []
	var concls := []
	var rels := []
	for n in ch.nodes:
		var layer = n.get("layer", "hypo")
		if layer == "concl":
			concls.append({"id": _nid(n.id), "kind": layer})
		elif layer == "hypo":
			nodes.append({"id": _nid(n.id), "kind": layer})
	for e in ch.edges:
		rels.append({"from": _nid(e.from), "to": _nid(e.to), "kind": e.kind})
	return {"nodes": nodes, "concls": concls, "rels": rels}

func _build_ch2_full() -> Dictionary:
	return _build_chain_full("CH02")

# ── E01 空墙零分 ──────────────────────────────────────────────
func _e01_empty_zero():
	# 完全空墙：无边无节点 → ratio=0
	var res = WBE.evaluate([], [], [], "scene2", false, [])
	_rec("E01", "空墙零分", "0.0", "%.4f" % res.ratio, res.ratio == 0.0,
		"sum_hit=%.1f sum_max=%.1f" % [res.sum_hit, res.sum_max])

# ── E02 全对满分 ────────────────────────────────────────────────
func _e02_full_score():
	# 练习墙 + CH01W 全建 → ratio≈1.0（单链激活，其余练习链非core非激活不计分母）
	var data = _build_chain_full("CH01W")
	var res = WBE.evaluate(data.rels, data.nodes, data.concls, "scene1", true, [])
	var ok = res.ratio > 0.99
	_rec("E02", "全对满分(练习单链)", "≈1.0", "%.4f" % res.ratio, ok,
		"sum_hit=%.1f sum_max=%.1f stars=%d verdict=%d" % [res.sum_hit, res.sum_max, res.stars, res.verdict])

# ── E03 反向边半分 ─────────────────────────────────────────────
func _e03_reversed_half():
	var rel = [{"from": "H2-01", "to": "c201", "kind": "support"}]
	var nodes = [
		{"id": "c201", "kind": "clue"},
		{"id": "H2-01", "kind": "hypo"}
	]
	var res = WBE.evaluate(rel, nodes, [], "scene2", false, [])
	var b = _branch(res, "CH02")
	var rev = b.get("reversed_edges", []).size()
	var ext = b.get("extra_edges", []).size()
	var ok = rev == 1 and ext == 0
	_rec("E03", "反向边半分", "reversed=1 extra=0", "rev=%d ext=%d" % [rev, ext], ok,
		"hit=%.1f truth=%d" % [b.get("hit", 0), b.get("truth", 0)])

# ── E04 重复边去重 ─────────────────────────────────────────────
func _e04_dup_dedup():
	var rel = [
		{"from": "c201", "to": "H2-01", "kind": "support"},
		{"from": "c201", "to": "H2-01", "kind": "support"}
	]
	var nodes = [
		{"id": "c201", "kind": "clue"},
		{"id": "H2-01", "kind": "hypo"}
	]
	var res = WBE.evaluate(rel, nodes, [], "scene2", false, [])
	var b = _branch(res, "CH02")
	var matched = b.get("matched_edges", []).size()
	var extra = b.get("extra_edges", []).size()
	var ok = matched == 1 and extra == 1
	_rec("E04", "重复边去重", "matched=1 extra=1", "m=%d e=%d" % [matched, extra], ok,
		"hit=%.1f" % b.get("hit", 0))

# ── E05 多建边扣分(分母取大) ────────────────────────────────────
func _e05_extra_penalty():
	# 练习单链全对 ratio≈1.0，多一条错边后分母变大 ratio 降低
	var data = _build_chain_full("CH01W")
	var rels = data.rels.duplicate()
	# 找一条 hypo 节点连向链外
	var ch = ReasoningChains.derive_truth("CH01W")
	var first_hypo = ""
	for n in ch.nodes:
		if n.get("layer", "") == "hypo":
			first_hypo = _nid(n.id)
			break
	rels.append({"from": first_hypo, "to": "FAKE-X", "kind": "support"})
	var res = WBE.evaluate(rels, data.nodes, data.concls, "scene1", true, [])
	var ok = res.ratio < 1.0 and res.ratio > 0.7
	var b = _branch(res, "CH01W")
	_rec("E05", "多建边扣分(练习单链)", "r < 1.0 且 > 0.7", "%.4f" % res.ratio, ok,
		"extra=%d sum_max=%.1f truth=%d built=%d" % [b.get("extra_edges", []).size(), res.sum_max, b.get("truth",0), b.get("built",0)])

# ── E06 虚线边不计分 ───────────────────────────────────────────
func _e06_dashed_noscore():
	var nodes = [
		{"id": "c201", "kind": "clue"},
		{"id": "H2-01", "kind": "hypo"}
	]
	var rs = [{"from": "c201", "to": "H2-01", "kind": "support"}]
	var rd = [{"from": "c201", "to": "H2-01", "kind": "suggest"}]
	var res_s = WBE.evaluate(rs, nodes, [], "scene2", false, [])
	var res_d = WBE.evaluate(rd, nodes, [], "scene2", false, [])
	var hs = float(_branch(res_s, "CH02").get("hit", 0))
	var hd = float(_branch(res_d, "CH02").get("hit", 0))
	var ed = _branch(res_d, "CH02").get("extra_edges", []).size()
	var ok = hs > hd and ed == 1
	_rec("E06", "虚线边不计分", "solid>dash extra=1",
		"s=%.1f d=%.1f ed=%d" % [hs, hd, ed], ok)

# ── E07 跨场景链按进度裁剪 ──────────────────────────────────────
func _e07_cross_scene_crop():
	var ch3 = ReasoningChains.derive_truth("CH03")
	var nodes := []
	var rels := []
	var all_clues := {}
	var s2_clues := {}
	for n in ch3.nodes:
		nodes.append({"id": _nid(n.id), "kind": n.get("layer", "hypo")})
		if n.get("layer", "") == "clue":
			all_clues[_nid(n.id)] = true
			if str(n.id).begins_with("c2"):
				s2_clues[_nid(n.id)] = true
	for e in ch3.edges:
		rels.append({"from": _nid(e.from), "to": _nid(e.to), "kind": e.kind})
	var res_part = WBE.evaluate(rels, nodes, [], "scene2", false, s2_clues.keys())
	var res_full = WBE.evaluate(rels, nodes, [], "scene2", false, all_clues.keys())
	var bp = _branch(res_part, "CH03")
	var bf = _branch(res_full, "CH03")
	var up = bp.get("unavailable_edges", []).size()
	var uf = bf.get("unavailable_edges", []).size()
	var ok = up > 0 and uf == 0
	_rec("E07", "跨场景链按进度裁剪", "part>0 full=0",
		"part=%d full=%d" % [up, uf], ok,
		"ratio_part=%.4f ratio_full=%.4f" % [res_part.ratio, res_full.ratio])

# ── E08 display_ratio 难度修正 ──────────────────────────────────
func _e08_display_diff():
	var data = _build_ch2_full()
	var re = WBE.evaluate(data.rels, data.nodes, data.concls, "scene2", false, [], 0)
	var rn = WBE.evaluate(data.rels, data.nodes, data.concls, "scene2", false, [], 1)
	var rh = WBE.evaluate(data.rels, data.nodes, data.concls, "scene2", false, [], 2)
	var ok = re.display_ratio < rn.display_ratio and rn.display_ratio <= rh.display_ratio
	_rec("E08", "display 难度修正", "EASY<NORMAL<=HARD",
		"E=%.3f N=%.3f H=%.3f" % [re.display_ratio, rn.display_ratio, rh.display_ratio], ok,
		"raw=%.4f" % re.ratio)

# ── E09 raw_ratio 存档真实性 ────────────────────────────────────
func _e09_raw_stable():
	var data = _build_ch2_full()
	var re = WBE.evaluate(data.rels, data.nodes, data.concls, "scene2", false, [], 0)
	var rn = WBE.evaluate(data.rels, data.nodes, data.concls, "scene2", false, [], 1)
	var rh = WBE.evaluate(data.rels, data.nodes, data.concls, "scene2", false, [], 2)
	var ok = re.ratio == rn.ratio and rn.ratio == rh.ratio
	_rec("E09", "raw 难度无关", "三难度一致",
		"E=%.4f N=%.4f H=%.4f" % [re.ratio, rn.ratio, rh.ratio], ok)

# ── E10 星级阈值 ───────────────────────────────────────────────
func _e10_star_thresholds():
	var data = _build_chain_full("CH01W")
	var rf = WBE.evaluate(data.rels, data.nodes, data.concls, "scene1", true, [])
	var re = WBE.evaluate([], [], [], "scene1", true, [])
	_rec("E10.1", "全对三星(练习单链)", "3", str(rf.stars), rf.stars == 3, "ratio=%.4f" % rf.ratio)
	_rec("E10.2", "空墙零星", "0", str(re.stars), re.stars == 0, "ratio=%.4f" % re.ratio)

# ── E11 verdict 四档映射 ────────────────────────────────────────
func _e11_verdict_levels():
	var data = _build_chain_full("CH01W")
	var rf = WBE.evaluate(data.rels, data.nodes, data.concls, "scene1", true, [])
	var re = WBE.evaluate([], [], [], "scene1", true, [])
	_rec("E11.1", "全对=VERIFIED(3)", "3", str(rf.verdict), rf.verdict == 3)
	_rec("E11.2", "空墙≤INSUFFICIENT", "≤1", str(re.verdict), re.verdict <= 1)

# ── 疑点 A：识破误导项不触发 has_contradict ─────────────────────
func _doubt_a_mislead_no_contradict():
	var Truth = preload("res://data/case_branch_truth.gd")
	var tgt = null
	for b in Truth.branches():
		if b.get("misleads", []).size() > 0:
			tgt = b
			break
	if tgt == null:
		_rec("A", "识破误导不触发矛盾", "N/A", "SKIP", true, "未找到含mislead的链")
		return
	var mid = tgt.misleads[0].id
	var mexp = tgt.misleads[0].expect
	# 建全对 + 加对误导的 oppose 边（识破）
	var nodes := []
	for n in tgt.nodes:
		nodes.append({"id": _nid(n.id), "kind": n.get("layer", "hypo")})
	nodes.append({"id": _nid(mid), "kind": "hypo"})
	var rels := []
	for e in tgt.edges:
		rels.append({"from": _nid(e.from), "to": _nid(e.to), "kind": e.kind})
	# 找一条线索，用 oppose 连向误导（玩家识破误导）
	var first_clue = ""
	for n in tgt.nodes:
		if n.get("layer", "") == "clue":
			first_clue = _nid(n.id)
			break
	if first_clue != "":
		rels.append({"from": first_clue, "to": _nid(mid), "kind": "oppose"})
	var res = WBE.evaluate(rels, nodes, [], str(tgt.scene), false, [])
	var c = res.has_contradict
	# 识破 negate 型误导不触发矛盾
	var ok = not c
	_rec("A", "识破误导不触发矛盾", "false", str(c), ok,
		"chain=%s mis=%s exp=%s" % [tgt.id, mid, mexp])

# ── 疑点 B：未知 scene_id 不放行全部场景 ───────────────────────
func _doubt_b_unknown_scene():
	var data = _build_ch2_full()
	var res = WBE.evaluate(data.rels, data.nodes, data.concls, "sceneX", false, [])
	# 未知场景 CH02 不被允许 → sum_max=0 ratio=0
	var ok = res.ratio == 0.0 and res.sum_max == 0.0
	_rec("B", "未知scene不放行全部", "ratio=0 sum_max=0",
		"r=%.4f sm=%.1f" % [res.ratio, res.sum_max], ok)

# ── 疑点 C：hard_fail 时 verdict 不超过 SUPPORTED ───────────────
func _doubt_c_hardfail_verdict():
	var Truth = preload("res://data/case_branch_truth.gd")
	var tgt = null
	for b in Truth.branches():
		if b.get("misleads", []).size() > 0:
			tgt = b
			break
	if tgt == null:
		_rec("C", "hard_fail时verdict≤2", "N/A", "SKIP", true)
		return
	var mid = tgt.misleads[0].id
	var mexp = tgt.misleads[0].expect
	# 全对 + 采纳误导（对误导建 support 边 = 采纳）
	var nodes := []
	for n in tgt.nodes:
		nodes.append({"id": _nid(n.id), "kind": n.get("layer", "hypo")})
	nodes.append({"id": _nid(mid), "kind": "hypo"})
	var rels := []
	for e in tgt.edges:
		rels.append({"from": _nid(e.from), "to": _nid(e.to), "kind": e.kind})
	# 找一条线索，用 support 连向误导（采纳误导）
	var first_clue = ""
	for n in tgt.nodes:
		if n.get("layer", "") == "clue":
			first_clue = _nid(n.id)
			break
	if first_clue != "":
		rels.append({"from": first_clue, "to": _nid(mid), "kind": "support"})
	var res = WBE.evaluate(rels, nodes, [], str(tgt.scene), false, [])
	var hf = res.hard_fail
	var v = res.verdict
	var s = res.stars
	# 采纳误导 → hard_fail=true → stars封顶2，verdict≤2
	var ok = (not hf) or (v <= 2 and s <= 2)
	_rec("C", "hard_fail时verdict≤SUPPORTED", "verdict≤2 stars≤2",
		"hf=%s v=%d s=%d" % [str(hf), v, s], ok,
		"chain=%s ratio=%.4f dr=%.4f" % [tgt.id, res.ratio, res.display_ratio])

# ── 疑点 D：可注入难度参数 ─────────────────────────────────────
func _doubt_d_difficulty_override():
	var data = _build_ch2_full()
	var rd = WBE.evaluate(data.rels, data.nodes, data.concls, "scene2", false, [])  # 默认
	var re = WBE.evaluate(data.rels, data.nodes, data.concls, "scene2", false, [], 0)
	var rh = WBE.evaluate(data.rels, data.nodes, data.concls, "scene2", false, [], 2)
	var ok1 = re.display_ratio < rd.display_ratio  # EASY 拉低
	var ok2 = rh.display_ratio >= rd.display_ratio  # HARD 不低于
	var ok3 = re.ratio == rd.ratio and rd.ratio == rh.ratio  # raw 不变
	_rec("D.1", "EASY override 拉低display", "EASY < DEFAULT",
		"E=%.3f D=%.3f" % [re.display_ratio, rd.display_ratio], ok1)
	_rec("D.2", "HARD override 不低于default", "HARD >= DEFAULT",
		"H=%.3f D=%.3f" % [rh.display_ratio, rd.display_ratio], ok2)
	_rec("D.3", "override 不影响 raw", "三难度一致",
		"E=%.4f H=%.4f" % [re.ratio, rh.ratio], ok3)

# ── 总结 ────────────────────────────────────────────────────────
func _print_summary():
	print("")
	print("======================================================================")
	print("详细结果")
	print("======================================================================")
	for r in results:
		print(r)
	print("----------------------------------------------------------------------")
	print("总计: %d 通过 / %d 失败 / 共 %d" % [passed, failed, passed + failed])
	if failed > 0:
		push_error("有 %d 个失败用例" % failed)
