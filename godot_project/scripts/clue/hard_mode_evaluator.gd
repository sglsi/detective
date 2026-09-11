extends RefCounted
class_name HardModeEvaluator

## 困难模式 · 确定性四维定性反馈引擎（Track A）
##
## 设计依据：《设计文档/L2_详细设计/系统设计/11_游戏智能化改造方案.md》困难模式评价建议
## 与 Track A（无 LLM 概念标注）路线。
##
## 核心思想：「比对真相，而非作者链」。
##   普通/练习模式用 WallBranchEvaluator 对标作者标准链（节点 id / 边顺序硬比对），困难模式下玩家完全
##   自由推理，其节点 id 永远对不上作者链 → 正确率崩 0。本引擎改为四项**定性**维度，只比「案件事实」
##   而非「标准答案路径」：
##     结论准确性 35% —— 玩家得出的终局结论是否与真相核心结论一致（id 别名匹配 + scene1 语义词典）
##     证据支撑度 25% —— 每个玩家结论/推断是否连到支撑它的前驱（不是空中楼阁）
##     结构完整性 20% —— 图谱是否连通、无孤立节点、层级递进合理
##     步骤连贯性 20% —— 每个产出节点是否有前驱、无明显自相矛盾
##
## 真相结构源 = CaseBranchTruth.branches()（含场景二~八全链；但精简结构只有 id+layer+edges，
## 无结论文本）。结论层用「id 别名匹配」（玩家结论别名成 conclusion_X，norm 后对照真相 concl id），
## 规避「推断层 id 失配 → 崩 0」。语义词典（文本/同义词）来自 ReasoningChains.CHAINS（仅 scene1 练习
## 链含完整 text/match_keys），用于 scene1 的语义级匹配；正式场景无文本数据时退化为 id 匹配——
## 后续把场景二~八链迁移进 ReasoningChains.CHAINS 即自动获得语义词典（单一事实源，无需改引擎）。
##
## 纯数据引擎：不依赖场景树，可 headless 单测（tools/test_hard_mode_evaluator.gd）。
## ⚠️ 方案 A：评分只在客户端（此处）算；服务端 /api/evaluate 只接收结果做审计/缓存，不重复实现评分。

const RC := preload("res://data/reasoning_chains.gd")
const Truth = preload("res://data/case_branch_truth.gd")

# 维度权重（用户裁定：结论35 / 证据25 / 结构20 / 步骤20）
const W_CONCLUSION := 0.35
const W_EVIDENCE := 0.25
const W_STRUCTURE := 0.20
const W_STEP := 0.20

# 星级阈值（与 CaseBranchTruth.STAR_* 同源）
const STAR_3 := 0.80
const STAR_2 := 0.55
const STAR_1 := 0.25

const CONCL_MATCH_THRESHOLD := 0.5


## 主入口（与 WallBranchEvaluator.evaluate 同签名，便于 wall_state 接线）。
static func evaluate(relations: Array, graph_nodes: Array, derived_conclusions: Array,
		scene_id: String, practice: bool = false) -> Dictionary:
	# ---- 1. 收集玩家产出 ----
	var player_concl_texts: Array = []
	var player_hypo_texts: Array = []
	var player_node_ids: Dictionary = {}   # id -> "hypo" / "conclusion"
	var player_concl_ids: Array = []
	var player_hypo_ids: Array = []

	for gn in graph_nodes:
		var gkind: String = str(gn.get("kind", ""))
		var gid: String = str(gn.get("id", ""))
		# 玩家「添文本框」新增的节点 id 形如 note_conclusion_0 / note_hypo_0，它们即是玩家在困难模式下的
		# 全部推理贡献（困难模式不预设任何推断，玩家须自行用文本框搭建）。旧代码曾以 note_ 前缀整段跳过 → 四维全 0、0★。
		# 项目内 note_ 前缀仅用于玩家文本框（add_text_node / restore_text_node），无系统占位节点，故不再跳过。
		if gkind == "conclusion":
			player_concl_texts.append(str(gn.get("text", "")))
			player_concl_ids.append(gid)
			player_node_ids[gid] = "conclusion"
		elif gkind == "hypo":
			player_hypo_texts.append(str(gn.get("text", "")))
			player_hypo_ids.append(gid)
			player_node_ids[gid] = "hypo"

	for dc in derived_conclusions:
		var t: String = str(dc.get("text", ""))
		if t != "":
			player_concl_texts.append(t)
		var did: String = str(dc.get("id", ""))
		if did != "":
			player_concl_ids.append(did)
			player_node_ids[did] = "conclusion"

	var player_edges: Array = []
	for r in relations:
		if bool(r.get("dashed", false)):
			continue
		player_edges.append({
			"from": str(r.get("from", "")),
			"to": str(r.get("to", "")),
			"kind": str(r.get("kind", "relate")),
		})

	# ---- 2. 真相结构（branches 含全场景；非 HARD/练习墙排除 practice 链）----
	var branches: Array = _truth_branches(scene_id, practice)
	var truth_concl_ids: Dictionary = {}
	for b in branches:
		for n in b.get("nodes", []):
			var nid: String = norm(str(n.get("id", "")))
			if str(n.get("layer", "")) == "concl":
				truth_concl_ids[nid] = true
	# 终局核心结论（无 target 边时按启发式定位链收敛点）
	var core_concl_ids: Dictionary = _core_conclusion_ids(branches)

	# ---- 3. 结论维度：id 匹配 + 语义词典（scene1）----
	var concept_dict: Dictionary = _concept_dict()
	var hit_ids: Dictionary = {}
	for pt in player_concl_texts:
		for cid in _match_concept_ids(pt, concept_dict):
			hit_ids[cid] = true
	for cid in player_concl_ids:
		var n: String = norm(cid)
		if truth_concl_ids.has(n):
			hit_ids[n] = true
	var target_hit: bool = false
	for h in hit_ids.keys():
		if core_concl_ids.has(h):
			target_hit = true
	var hit_count: int = hit_ids.size()
	var total: int = truth_concl_ids.size()
	var conclusion_score: float = (float(hit_count) / float(total)) if total > 0 else 0.0
	var conclusion_correct: bool = target_hit

	# ---- 4. 证据维度 ----
	var supported_concl: int = 0
	for cid in player_concl_ids:
		var ok_c: bool = false
		for e in player_edges:
			if str(e.get("to", "")) == cid and str(e.get("kind", "")) in ["support", "weak"]:
				ok_c = true
				break
		if ok_c:
			supported_concl += 1
	var supported_hypo: int = 0
	for hid in player_hypo_ids:
		var ok_h: bool = false
		for e2 in player_edges:
			if str(e2.get("to", "")) == hid and str(e2.get("kind", "")) in ["support", "weak"]:
				ok_h = true
				break
		if ok_h:
			supported_hypo += 1
	var total_prod: int = player_concl_ids.size() + player_hypo_ids.size()
	var supported: int = supported_concl + supported_hypo
	var evidence_score: float = (float(supported) / float(total_prod)) if total_prod > 0 else 0.0

	# ---- 5. 结构与步骤维度 ----
	var isolated: int = 0
	for nid in player_node_ids.keys():
		var connected: bool = false
		for e3 in player_edges:
			if str(e3.get("from", "")) == nid or str(e3.get("to", "")) == nid:
				connected = true
				break
		if not connected:
			isolated += 1
	var connectivity: float = (1.0 - float(isolated) / float(total_prod)) if total_prod > 0 else 0.0

	var level_ok: int = 0
	var level_total: int = 0
	for e4 in player_edges:
		var ek4: String = str(e4.get("kind", ""))
		if ek4 in ["support", "weak"]:
			level_total += 1
			if _layer_of(str(e4.get("from", "")), player_node_ids) <= _layer_of(str(e4.get("to", "")), player_node_ids):
				level_ok += 1
	var progression: float = (float(level_ok) / float(level_total)) if level_total > 0 else 1.0

	var structure_score: float = (connectivity * 0.6 + progression * 0.4) if total_prod > 0 else 0.0

	var contra: int = 0
	for e5 in player_edges:
		if str(e5.get("kind", "")) in ["contradict", "oppose"]:
			contra += 1
	var contra_ratio: float = (float(contra) / float(player_edges.size())) if player_edges.size() > 0 else 0.0
	var step_score: float = (connectivity * 0.8 + (1.0 - contra_ratio) * 0.2) if total_prod > 0 else 0.0

	# ---- 6. 综合 ----
	var ratio: float = W_CONCLUSION * conclusion_score + W_EVIDENCE * evidence_score \
		+ W_STRUCTURE * structure_score + W_STEP * step_score

	var stars: int = _stars_of(ratio)
	if not conclusion_correct:
		stars = mini(stars, 2)   # 结论错 → 封顶 2 星

	var contradicted: bool = (contra_ratio > 0.5) or (contra > 0 and not conclusion_correct)
	var verdict: int = _verdict_of(ratio, contradicted)

	var grade: String = _grade_of(ratio)
	var reasons: Array = _build_reasons(conclusion_correct, target_hit, evidence_score,
		isolated, contra, total_prod)
	var summary: String = _summary(grade, conclusion_correct, ratio)

	return {
		"four_dim": true,
		"ratio": ratio,
		"stars": stars,
		"verdict": verdict,
		"hard_fail": false,
		"conclusion_correct": conclusion_correct,
		"four": {
			"conclusion": conclusion_score,
			"evidence": evidence_score,
			"structure": structure_score,
			"step": step_score,
		},
		"grade": grade,
		"reasons": reasons,
		"summary": summary,
		# 兼容字段（避免 wall_verify 兜底分支崩溃）
		"per_branch": [],
		"sum_hit": ratio,
		"sum_max": 1.0,
		"insight_hit": 0.0,
		"insight_truth": 0,
		"insight_ratio": -1.0,
		"adopted_misleads": [],
		"negated_misleads": [],
		"practice": practice,
	}


# ===================== 真相结构派生 =====================
## 当前场景及之前场景的真相链（排除 practice 链，除非 practice 墙）。
## 用 CaseBranchTruth.branches() 作结构真相源（含场景二~八），而非 ReasoningChains.CHAINS
## （后者仅迁移了 scene1 练习链）。
static func _truth_branches(scene_id: String, practice: bool = false) -> Array:
	var allowed: Dictionary = _allowed_scenes(scene_id)
	var out: Array = []
	for b in Truth.branches():
		if not allowed.has(str(b.get("scene", ""))):
			continue
		if bool(b.get("practice", false)) and not practice:
			continue
		out.append(b)
	return out


## 终局核心结论 id 集合（用于 conclusion_correct 判定：是否命中「破案关键结论」）。
## 规则：
##   - 链含 target 边（场景一练习链人物锚定）→ 该结论（target 起点）即核心；
##   - 否则（场景二~八无 target 边）取「每链终止结论（非任何 support 边起点）中
##     入度最高者」作为该链收敛点；标记 synthesize=true 的结论（场景八综合结论）也视作核心。
static func _core_conclusion_ids(branches: Array) -> Dictionary:
	var core: Dictionary = {}
	for b in branches:
		# 1) target 边直接定核心（场景一练习链）
		var has_target := false
		for e in b.get("edges", []):
			if str(e.get("kind", "")) == "target":
				has_target = true
				core[norm(str(e.get("from", "")))] = true
		if has_target:
			continue
		# 2) 统计各结论入度（仅 support/weak）
		var incoming: Dictionary = {}
		for e2 in b.get("edges", []):
			if str(e2.get("kind", "")) in ["support", "weak"]:
				var to := norm(str(e2.get("to", "")))
				incoming[to] = int(incoming.get(to, 0)) + 1
		var concl_ids: Array = []
		for n in b.get("nodes", []):
			if str(n.get("layer", "")) == "concl":
				concl_ids.append(norm(str(n.get("id", ""))))
		var max_in := 0
		for cid in concl_ids:
			max_in = maxi(max_in, int(incoming.get(cid, 0)))
		for cid in concl_ids:
			if int(incoming.get(cid, 0)) == max_in and max_in > 0:
				core[cid] = true
		# 3) synthesize 结论即使入度非最大也视作核心
		for n in b.get("nodes", []):
			if bool(n.get("synthesize", false)):
				core[norm(str(n.get("id", "")))] = true
	return core


# ===================== 语义词典（scene1 练习链，含文本） =====================
## 从 ReasoningChains.CHAINS 提取「结论 id → 文本/同义词/主宾/终局目标」词典。
## 仅 scene1 练习链数据完整；场景二~八迁移进 CHAINS 后自动扩展（单一事实源）。
static func _concept_dict() -> Dictionary:
	var d: Dictionary = {}
	for id in RC.ids():
		var ch: Dictionary = RC.CHAINS[id]
		var bf: Dictionary = ch.get("wall", {}).get("battlefield", {})
		for c in bf.get("conclusions", []):
			var cid: String = str(c.get("id", ""))
			d[cid] = {
				"text": str(c.get("text", "")),
				"dir": str(c.get("dir", "affirm")),
				"subject": c.get("subject", []),
				"object": c.get("object", []),
				"match_keys": c.get("match_keys", []),
				"target": str(c.get("target", "")),
			}
	return d


## 结论文本 → 命中的真相结论 id 列表（语义匹配，阈值 0.5）。
static func _match_concept_ids(t_in: String, concept_dict: Dictionary) -> Array:
	var out: Array = []
	for cid in concept_dict.keys():
		if _match_conclusion_text(t_in, concept_dict[cid]) >= CONCL_MATCH_THRESHOLD:
			out.append(cid)
	return out


## 结论文本 → 真相结论匹配分（复用 graph_view_controller._conclusion_text_match 口径）。
static func _match_conclusion_text(t_in: String, c: Dictionary) -> float:
	var t: String = str(t_in).strip_edges().to_lower()
	if t == "":
		return 0.0
	var best: float = 0.0
	for k in c.get("match_keys", []):
		var kk: String = str(k).to_lower()
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


# ===================== 图形态辅助 =====================
## 节点归一化：剥 conclusion_ / person: 前缀对齐真相 id。
static func norm(nid: String) -> String:
	var s: String = str(nid)
	if s.begins_with("conclusion_"):
		return s.substr("conclusion_".length())
	if s.begins_with("person:"):
		return s.substr("person:".length())
	return s


## 节点层级：clue=0 / hypo=1 / conclusion=2 / person=3。
static func _layer_of(nid: String, player_node_ids: Dictionary) -> int:
	if nid.begins_with("conclusion"):
		return 2
	if nid.begins_with("person:"):
		return 3
	if player_node_ids.has(nid):
		return 1 if str(player_node_ids[nid]) == "hypo" else 2
	return 1   # 默认线索/中间，层级最低（不扣过分）


# ===================== 评分派生 =====================
static func _stars_of(ratio: float) -> int:
	if ratio >= STAR_3:
		return 3
	if ratio >= STAR_2:
		return 2
	if ratio >= STAR_1:
		return 1
	return 0


static func _verdict_of(ratio: float, contradicted: bool) -> int:
	if contradicted and ratio < STAR_3:
		return 0
	if ratio >= STAR_3:
		return 3
	if ratio >= STAR_2:
		return 2
	if ratio >= STAR_1:
		return 1
	return 1


static func _grade_of(ratio: float) -> String:
	if ratio >= 0.80:
		return "优秀"
	if ratio >= 0.55:
		return "良好"
	if ratio >= 0.25:
		return "合格"
	return "待加强"


static func _build_reasons(conclusion_correct: bool, target_hit: bool, evidence_score: float,
		isolated: int, contra: int, total_prod: int) -> Array:
	var r: Array = []
	if total_prod == 0:
		r.append("尚未在图谱中产出任何推断或结论，先尝试从线索推导身份与事件。")
		return r
	if target_hit:
		r.append("已得出核心终局结论（如人物身份/事件真相），方向正确。")
	else:
		r.append("尚未得出核心终局结论，建议向人物身份或事件真凶结论推进。")
	if evidence_score < 0.6:
		r.append("部分结论/推断缺乏证据支撑，建议补充线索或前驱推断的连线。")
	else:
		r.append("证据链路较完整，多数结论有支撑。")
	if isolated > 0:
		r.append("存在 %d 个孤立节点，部分推理未接入主链，建议补齐连接。" % isolated)
	if contra > 0:
		r.append("存在 %d 条相互矛盾的连线，建议厘清后再结案。" % contra)
	return r


static func _summary(grade: String, conclusion_correct: bool, ratio: float) -> String:
	var pct: int = int(round(ratio * 100.0))
	var s: String = "推理质量：%s（%d%%）" % [grade, pct]
	if not conclusion_correct:
		s += " · 核心结论待补"
	return s


# ===================== 场景范围 =====================
## 当前场景及之前场景集合（与 WallBranchEvaluator._allowed_scenes 同源）。
static func _allowed_scenes(scene_id: String) -> Dictionary:
	var order: Array = ["scene1", "scene2", "scene3", "scene4", "scene5", "scene6", "scene7", "scene8"]
	var allowed: Dictionary = {}
	for sid in order:
		allowed[sid] = true
		if sid == scene_id:
			break
	if not allowed.has(scene_id):
		allowed[scene_id] = true
	return allowed
