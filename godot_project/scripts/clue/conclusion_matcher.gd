extends RefCounted

## 结论文本 · 宽容匹配器（概念级语义匹配）
##
## 目的（思傅 2026-09-11 裁定）：玩家在推理墙写下的自由文本结论，按「核心概念是否命中」判定，
## 而非字面串完全相等。让「意思对、说法不同」也能得分，不再因措辞差异直接判 0。
##
## 单一事实源：GraphViewController._conclusion_text_match 与 HardModeEvaluator._match_conclusion_text
## 原先各自复制了一份口径，容易漂移；现统一委托到本文件。
##
## 打分分层（对候选结论的 match_keys / text / subject / object 取最大值）：
##   L1 原文完全相等（match_keys）                          -> 1.00
##   L2 原文子串包含（任一方向，match_keys）                -> 0.85
##   L2b 原文子串包含（结论文本 text）                      -> 0.70
##   L3 概念集合 F1（同义词归一化后，玩家概念 vs 候选概念）  -> 0..1
##   L4 实词字符 Dice 系数（去停用词后的字符集合）          -> 0..0.85
##   L5 subject/object 关键词重叠（旧口径兜底）             -> 0..1
##
## 红线：本文件只放宽「措辞匹配」；是否命中「破案核心结论（conclusion_correct）」的硬判定
## 仍在 HardModeEvaluator 中按 core_concl_ids 严格进行，维持「堵死乱选」的设计初衷。

## 命中阈值（≥ 即判为命中）。较旧 0.5 略降，配合 L3/L4 提高召回但不过度泛化。
const MATCH_THRESHOLD := 0.45

## 概念同义词表：canonical -> 变体列表。任一变体作为子串出现即认定该概念命中。
## 仅收录本案（华生链 CH01W / 信使链 CH01M）涉及的核心概念，避免过度泛化造成误命中/分数注水。
const SYNONYMS := {
	# 注意：刻意不含裸字「兵」「军旅」——二者会泄漏进别的结论关键词（如 C-B1 的「医疗兵」、
	# C-C2 的「军旅负伤」），造成概念集合注水与误命中。宁可少召回，也不要假阳性。
	"服役": ["服役", "当兵", "当过兵", "参过军", "参军", "从军", "入伍", "退伍", "老兵", "军人"],
	"军医": ["军医", "医生", "医务", "医疗兵", "医疗", "卫生员", "医护人员"],
	"热带": ["热带", "炎热", "酷热", "南方", "晒黑", "黝黑", "晒得黑", "暴晒"],
	"阿富汗": ["阿富汗"],
	"英国": ["英国", "大英", "英吉利"],
	"殖民地": ["殖民地", "属地", "殖民", "占领地"],
	"军事任务": ["军事任务", "军务", "作战任务", "作战", "打仗", "战事", "军事行动", "战场"],
	"伤害": ["伤害", "负伤", "受伤", "旧伤", "创伤", "外伤"],
	"海军": ["海军", "水兵", "舰队"],
	"陆战队": ["陆战", "陆战队"],
	"军士": ["军士", "士官", "中士", "下士"],
}

## 实词相似度计算时剔除的虚词/高频字（避免「的/了/在」等制造虚假相似）。
const STOP_CHARS := "的了过在有是就也都只曾一位于个名着和与很这那些什么我他她它们把被从对到不"


## 主入口：玩家文本 vs 单条候选结论，返回 0..1 匹配分。
static func score(t_in: String, c: Dictionary) -> float:
	var t: String = str(t_in).strip_edges().to_lower()
	if t == "":
		return 0.0

	var keys: Array = c.get("match_keys", [])
	var ctext: String = str(c.get("text", "")).strip_edges().to_lower()
	var best: float = 0.0

	# ── L1/L2：字面（保留旧口径，保证既有正确输入零倒退）──
	for k in keys:
		var kk: String = str(k).strip_edges().to_lower()
		if kk == "":
			continue
		if t == kk:
			return 1.0
		if t.find(kk) >= 0 or kk.find(t) >= 0:
			best = maxf(best, 0.85)
	if ctext != "" and (t.find(ctext) >= 0 or ctext.find(t) >= 0):
		best = maxf(best, 0.70)

	# ── L3：概念集合 F1（宽容核心：跨措辞识别同一概念）──
	var cand_concepts: Dictionary = _concepts_of(c)
	var player_concepts: Dictionary = _concepts_of({"match_keys": [t], "text": t})
	if not cand_concepts.is_empty() and not player_concepts.is_empty():
		var inter: int = 0
		for cc in player_concepts.keys():
			if cand_concepts.has(cc):
				inter += 1
		if inter > 0:
			var prec: float = float(inter) / float(player_concepts.size())
			var rec: float = float(inter) / float(cand_concepts.size())
			var f1: float = (2.0 * prec * rec) / (prec + rec)
			best = maxf(best, f1)

	# ── L4：实词字符 Dice（容忍语序/多字少字）──
	var ref_text: String = ctext
	if ref_text == "":
		ref_text = " ".join(keys)
	var dice: float = _content_dice(t, ref_text)
	best = maxf(best, dice * 0.85)

	# ── L5：subject/object 关键词重叠（旧兜底，防倒退）──
	var total: int = 0
	var hits: int = 0
	for ssub in c.get("subject", []):
		total += 1
		if t.find(str(ssub).strip_edges().to_lower()) >= 0:
			hits += 1
	for sobj in c.get("object", []):
		total += 1
		if t.find(str(sobj).strip_edges().to_lower()) >= 0:
			hits += 1
	if total > 0:
		best = maxf(best, float(hits) / float(total))

	return clampf(best, 0.0, 1.0)


## 判定是否命中（阈值封装，调用方无须各自持有阈值）。
static func matches(t_in: String, c: Dictionary) -> bool:
	return score(t_in, c) >= MATCH_THRESHOLD


## 从一条候选结论中抽取「规范化概念集合」（canonical -> true）。
## 扫描 match_keys + text + subject + object，命中任一 synonym 变体即计入该 canonical。
static func _concepts_of(c: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var toks: Array = []
	for k in c.get("match_keys", []):
		toks.append(str(k))
	toks.append(str(c.get("text", "")))
	for s in c.get("subject", []):
		toks.append(str(s))
	for o in c.get("object", []):
		toks.append(str(o))
	for tk in toks:
		var low: String = str(tk).strip_edges().to_lower()
		if low == "":
			continue
		for canon in SYNONYMS.keys():
			for v in SYNONYMS[canon]:
				if low.find(str(v).to_lower()) >= 0:
					out[canon] = true
					break
	return out


## 两段文本的实词字符 Dice 系数（去停用词 + 去空白）。
static func _content_dice(a: String, b: String) -> float:
	var ca: Dictionary = _content_chars(a)
	var cb: Dictionary = _content_chars(b)
	if ca.is_empty() or cb.is_empty():
		return 0.0
	var inter: int = 0
	for ch in ca.keys():
		if cb.has(ch):
			inter += 1
	var denom: int = ca.size() + cb.size()
	if denom == 0:
		return 0.0
	return 2.0 * float(inter) / float(denom)


static func _content_chars(s: String) -> Dictionary:
	var out: Dictionary = {}
	var low: String = str(s).to_lower()
	for i in low.length():
		var ch: String = low[i]
		if ch.strip_edges() == "":
			continue
		if STOP_CHARS.find(ch) >= 0:
			continue
		out[ch] = true
	return out
