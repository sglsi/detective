## 回归测试：结论文本宽容匹配器（conclusion_matcher.gd）
## 用法：godot --headless --script res://tools/test_conclusion_matcher.gd
## 覆盖：①字面输入零倒退 ②措辞变体/语义改写新命中 ③负样本不误命中
extends SceneTree

const CM = preload("res://scripts/clue/conclusion_matcher.gd")

# CH01W 华生链真相结论（与 data/reasoning_chains.gd 保持一致）
var CONCLS: Dictionary = {
	"C-A1": {"text": "曾经在热带生活过", "dir": "affirm", "subject": ["华生"], "object": ["热带"],
		"match_keys": ["在热带生活过", "热带生活", "热带待过", "在热带待过"]},
	"C-B1": {"text": "是名军医", "dir": "affirm", "subject": ["华生"], "object": ["军医", "医生"],
		"match_keys": ["军医", "是医生", "医疗兵", "医务人员"]},
	"C-A2": {"text": "英国在热带的殖民地为阿富汗", "dir": "affirm", "subject": ["英国"], "object": ["阿富汗"],
		"match_keys": ["阿富汗", "英国殖民地是阿富汗", "热带殖民地是阿富汗", "去过阿富汗"]},
	"C-C2": {"text": "不该有的伤害只可能来自军事任务", "dir": "affirm", "subject": ["伤害"], "object": ["军事任务"],
		"match_keys": ["军事任务", "伤害来自军事", "战场负伤", "军旅负伤"]},
	"C-MAIN": {"text": "在阿富汗服役过", "dir": "affirm", "subject": ["华生"], "object": ["阿富汗", "服役"],
		"match_keys": ["在阿富汗服役", "阿富汗服役过", "去过阿富汗当兵", "阿富汗当兵"]},
}

var _fails: int = 0


func _init() -> void:
	print("===== 结论文本宽容匹配器回归 =====")
	print("阈值 MATCH_THRESHOLD = %.2f\n" % CM.MATCH_THRESHOLD)

	# ① 字面输入：不得倒退（旧逻辑本来就能命中）
	_check("在阿富汗服役", ["C-MAIN"], "字面精确")
	_check("在热带生活过", ["C-A1"], "字面精确")
	_check("是名军医", ["C-B1"], "字面精确")

	# ② 宽容新增：措辞变体 / 语义改写（旧逻辑多半判 0）
	_check("在阿富汗当过兵", ["C-MAIN"], "措辞变体（当兵≈服役）")
	_check("去阿富汗打过仗", ["C-MAIN"], "语义改写（远赴战区≈服役）")
	_check("受外伤", ["C-C2"], "语义（外伤≈伤害·军事任务）")
	_check("他的皮肤很黑，像是常年暴晒", ["C-A1"], "语义（暴晒≈热带）")

	# ③ 负样本：不得误命中目标
	_check_absent("这是一句完全无关的话", ["C-MAIN", "C-A1", "C-B1", "C-C2"], "无关文本")
	_check_absent("受外伤", ["C-MAIN", "C-A1", "C-B1"], "受外伤不应命中别的结论")
	_check_absent("在热带生活过", ["C-C2", "C-MAIN"], "热带不应命中军事/服役结论")

	print("\n===== 结果：%s =====" % ("PASS" if _fails == 0 else "FAIL (%d)" % _fails))
	quit(0 if _fails == 0 else 1)


func _check(text: String, must_hit: Array, label: String) -> void:
	var hits: Array = []
	for cid in CONCLS.keys():
		var s: float = CM.score(text, CONCLS[cid])
		var o: float = _old_score(text, CONCLS[cid])
		if s >= CM.MATCH_THRESHOLD:
			hits.append(cid)
		print("  [%s] vs %-6s  新=%.2f 旧=%.2f" % [label, cid, s, o])
	for cid in must_hit:
		if not hits.has(cid):
			_fails += 1
			print("  ❌ 期望命中 %s，实际 hits=%s" % [cid, str(hits)])
	print("  -> hits=%s  %s\n" % [str(hits), "PASS" if _has_all(hits, must_hit) else "FAIL"])


func _check_absent(text: String, forbidden: Array, label: String) -> void:
	var hits: Array = []
	for cid in CONCLS.keys():
		if CM.score(text, CONCLS[cid]) >= CM.MATCH_THRESHOLD:
			hits.append(cid)
	var bad: Array = []
	for f in forbidden:
		if hits.has(f):
			bad.append(f)
	if not bad.is_empty():
		_fails += 1
		print("  ❌ [%s] 误命中 %s  (hits=%s)" % [label, str(bad), str(hits)])
	else:
		print("  ✅ [%s] 无越界命中  (hits=%s)\n" % [label, str(hits)])


func _has_all(hits: Array, must: Array) -> bool:
	for m in must:
		if not hits.has(m):
			return false
	return true


## 旧口径复刻（用于对照展示，验证「不倒退 + 有新增」）。
func _old_score(t_in: String, c: Dictionary) -> float:
	var t: String = str(t_in).strip_edges().to_lower()
	if t == "":
		return 0.0
	var best: float = 0.0
	for k in c.get("match_keys", []):
		var kk: String = str(k).strip_edges().to_lower()
		if kk == "":
			continue
		if t == kk:
			return 1.0
		if t.find(kk) >= 0 or kk.find(t) >= 0:
			best = maxf(best, 0.8)
	var total: int = 0
	var hits: int = 0
	for ssub in c.get("subject", []):
		total += 1
		if t.find(str(ssub).to_lower()) >= 0:
			hits += 1
	for sobj in c.get("object", []):
		total += 1
		if t.find(str(sobj).to_lower()) >= 0:
			hits += 1
	if total > 0:
		best = maxf(best, float(hits) / float(total))
	var ctext: String = str(c.get("text", "")).to_lower()
	if ctext != "" and (t.find(ctext) >= 0 or ctext.find(t) >= 0):
		best = maxf(best, 0.7)
	return best
