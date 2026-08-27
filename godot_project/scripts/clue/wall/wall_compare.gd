extends RefCounted
class_name WallCompare

## 推理墙 · 提交软比对引擎（纯数据，可 headless 测试）
##
## 输入：
##   true_items   —— 场景预设「正确推断」列表，元素字段：
##                    id, text, dir("affirm"|"negate"|"neutral"),
##                    subject(主体关键词数组), object(客体关键词数组),
##                    gate_clue_ids(支撑线索 id 数组), adopt_desc(命中文案)
##   player_claims —— 玩家图谱上的推断/结论节点列表，元素字段：
##                    id, kind("hypo"|"conclusion"), text,
##                    support_clues(该节点支撑边来源线索 id 数组),
##                    player_made(bool 是否玩家自建), dir_derived("affirm"|"negate"|"neutral")
##   mislead_items —— 场景预设「误导推断」列表，元素字段：id, text
##
## 输出 Dictionary：
##   overall      —— 综合星级 0..3（各 true 项分别评分后取均值，再钳制）
##   per_item     —— [{id,text,stars,line}] 逐条明细
##   mislead_hits —— 玩家命中（文字重叠）到的误导项 text 列表
##   report       —— 可直接展示的多行文案
##
## 评分规则（采纳思傅框架 + 逐项正确增强）：
##   方向相违背(玩家得出相反结论)           → 0★
##   方向正确 且 内容命中(关键词重叠够高)  → 3★
##   方向正确 但 内容有偏差                 → 2★
##   方向不违背但缺失/不明确                → 1★
## 误导项被玩家采纳(文字重叠)             → 提示，影响星级观感
##
## 注意：方向/内容判定基于结构化字段 + 关键词重叠（启发式），非 NLP；
## 内容作者可通过 true_items 的 dir/subject/object 字段调校判定精度。

# ============== 主入口 ==============
func run(true_items: Array, player_claims: Array, mislead_items: Array) -> Dictionary:
	var per_item := []
	var total := 0
	for t in true_items:
		var td: Dictionary = t
		var best: Dictionary = _best_match(td, player_claims)
		var stars: int = 0
		var line: String = ""
		if best.is_empty():
			stars = 1
			line = "⬜ %s　你未涉及此项；建议回场景复核线索 %s" % [str(td.get("text", "")), _clue_hint(td)]
		else:
			var dir_contra: bool = _direction_contra(td, best)
			var dir_ok: bool = _direction_ok(td, best)
			var content_ok: bool = _content_ok(td, best)
			if dir_contra:
				stars = 0
				line = "❌ %s　方向相违背（你得出相反结论）；真相应为：%s" % [str(td.get("text", "")), str(td.get("text", ""))]
			elif dir_ok and content_ok:
				stars = 3
				line = "✅ %s　命中：%s" % [str(td.get("text", "")), str(td.get("adopt_desc", ""))]
			elif dir_ok:
				stars = 2
				line = "⚠️ %s　方向正确但细节有偏差；建议：%s" % [str(td.get("text", "")), str(td.get("adopt_desc", ""))]
			else:
				stars = 1
				line = "⬜ %s　涉及但方向不明确；建议：%s" % [str(td.get("text", "")), str(td.get("adopt_desc", ""))]
		per_item.append({"id": str(td.get("id", "")), "text": str(td.get("text", "")), "stars": 0, "line": line})
		per_item[-1]["stars"] = stars
		total += stars

	var overall: int = 0
	if true_items.size() > 0:
		overall = round(float(total) / float(true_items.size()))
	overall = clampi(overall, 0, 3)

	var mislead_hits := []
	for m in mislead_items:
		var mt: String = str(m.get("text", ""))
		for p in player_claims:
			if _text_overlap(mt, str(p.get("text", ""))) >= 0.5:
				mislead_hits.append(mt)
				break

	var report := "【推理软评估】本案正确推断 %d 项\n" % true_items.size()
	for it in per_item:
		report += (it["line"] as String) + "\n"
	if not mislead_hits.is_empty():
		report += "\n⚠️ 你采纳了误导项：%s（将影响星级评定）\n" % ", ".join(mislead_hits)
	report += "\n综合评定：★ %d / 3（软评估，不影响剧情推进）" % overall
	return {"overall": overall, "per_item": per_item, "mislead_hits": mislead_hits, "report": report}


# ============== 匹配与判定 ==============
func _best_match(td: Dictionary, claims: Array) -> Dictionary:
	var best: Dictionary = {}
	var best_score: float = 0.0
	var ttext: String = str(td.get("text", ""))
	for c in claims:
		var cd: Dictionary = c
		if cd.get("kind", "hypo") != "hypo" and cd.get("kind", "hypo") != "conclusion":
			continue
		var ctext: String = str(cd.get("text", ""))
		var s: float = _text_overlap(ttext, ctext)
		# 结构化对象关键词加权
		var obj: Array = td.get("object", [])
		for o in obj:
			if str(o) != "" and ctext.find(str(o)) >= 0:
				s += 0.25
		# 支撑线索共享加权
		var gates: Array = td.get("gate_clue_ids", [])
		var pclues: Array = cd.get("support_clues", [])
		var shared := 0
		for g in gates:
			if pclues.has(g):
				shared += 1
		if gates.size() > 0 and shared > 0:
			s += 0.3 * float(shared) / float(gates.size())
		if s > best_score:
			best_score = s
			best = cd
	if best_score >= 0.2:
		return best
	return {}


func _direction_ok(td: Dictionary, claim: Dictionary) -> bool:
	var td_dir: String = str(td.get("dir", "neutral"))
	if td_dir == "neutral":
		return true
	var pdir: String = str(claim.get("dir_derived", "affirm"))
	return td_dir == pdir


func _direction_contra(td: Dictionary, claim: Dictionary) -> bool:
	var td_dir: String = str(td.get("dir", "neutral"))
	if td_dir == "neutral":
		return false
	var pdir: String = str(claim.get("dir_derived", "affirm"))
	return td_dir != pdir and pdir != "neutral"


func _content_ok(td: Dictionary, claim: Dictionary) -> bool:
	var ctext: String = str(claim.get("text", ""))
	var subj: Array = td.get("subject", [])
	var obj: Array = td.get("object", [])
	var hit := 0
	var total := 0
	for s in subj:
		total += 1
		if str(s) != "" and ctext.find(str(s)) >= 0:
			hit += 1
	for o in obj:
		total += 1
		if str(o) != "" and ctext.find(str(o)) >= 0:
			hit += 1
	if total == 0:
		# 无结构化关键词时，退回纯文本重叠判定
		return _text_overlap(str(td.get("text", "")), ctext) >= 0.5
	return float(hit) / float(total) >= 0.5


# ============== 文本相似度（启发式） ==============
func _text_overlap(a: String, b: String) -> float:
	if a == "" or b == "":
		return 0.0
	if a == b:
		return 1.0
	var sa := _char_set(a)
	var sb := _char_set(b)
	var inter := 0
	var union := 0
	var keys := {}
	for k in sa.keys():
		keys[k] = true
	for k in sb.keys():
		keys[k] = true
	for k in keys.keys():
		var ca: int = sa.get(k, 0)
		var cb: int = sb.get(k, 0)
		inter += mini(ca, cb)
		union += maxi(ca, cb)
	if union == 0:
		return 0.0
	return float(inter) / float(union)


func _char_set(s: String) -> Dictionary:
	var d := {}
	for i in s.length():
		var ch: String = s[i]
		# 跳过标点/空白/常见虚词，提升关键词对比信噪比
		if ch in " ，。、；：！？（）()“”\"'《》<>—-…·\n\t":
			continue
		d[ch] = (d.get(ch, 0) as int) + 1
	return d


func _clue_hint(td: Dictionary) -> String:
	var gates: Array = td.get("gate_clue_ids", [])
	if gates.is_empty():
		return "（本案相关线索）"
	return ", ".join(gates)
