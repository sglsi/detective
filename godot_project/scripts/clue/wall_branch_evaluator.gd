## 推理墙 · 分枝（推理链）计分引擎
##
## 设计依据：《设计文档/L2_详细设计/系统设计/10_推理墙分枝计分_设计补充说明.md》
## 真相数据：data/case_branch_truth.gd
##
## ── 为什么需要它 ────────────────────────────────────────────────
## 原评价只看「有没有连边」：玩家只要建了任意关系，推理之星就给高分 → 乱选也能好评。
## 本引擎改为「按分枝整体逐项比对」：把设计文档 14 条推理链作为评分单元，
## 每条链的节点与边逐项比对，连错的东西一样进分母 → 连得越滥，正确率越低。
##
## ── 计分公式（思傅 2026-09-02 第 4 点，我加了一处修正）────────────────
##   对每条链：
##     T = 真相项数（节点 + 边）
##     B = 玩家在该链内建的项数（节点 + 边，**含错误边**）
##     H = 其中命中真相的项（逐项 0 / 0.5 / 1 计分）
##     R_b = H / max(B, T)
##   全案：
##     S     = Σ H
##     S_max = Σ max(B, T)
##     R     = S / S_max
##
##   为什么分母取 max(B, T) 而不是只用 B：若分母只用玩家建的 B，
##   玩家只连 1 条对的边 = 1/1 = 100% 三星，比全连对还高。取 max 等价于
##   同时看「精度」与「覆盖率」，仍是单一公式、一句话讲得清。
##
## ── 两个必须补的洞 ──────────────────────────────────────────────
## 洞1（只做最短链就三星）：标 core 链（破案必经 8 条），未激活的 core 链按 R=0
##      计入分母；optional 链激活才计分、做砸不拖分（保住「错误无惩罚」）。
## 洞2（误导项怎么算）：误导节点在真相里标 expect:"negate"。
##      玩家否定它 → 命中得分（奖励识破）；玩家采纳它 → 0 分且三星硬条件失败。
##
## ── 评分只基于「玩家真实关系」(_relations) ──────────────────────
## 绝不纳入 _derive_edges() 自动派生的数据预设边，否则玩家什么都不做也满分。
## 虚线（dashed，存疑）边只显示不判定，也不计分。
##
## 纯数据引擎：不依赖场景树，可 headless 单测（tools/test_branch_evaluator.gd）。
class_name WallBranchEvaluator
extends RefCounted

const Truth = preload("res://data/case_branch_truth.gd")

## 逐项得分档位
const HIT_EXACT := 1.0      # 完全命中（节点/边的方向与真相一致）
const HIT_REVERSED := 0.5   # 关系两端对但方向反了（语义对了、箭头反了）
const HIT_NONE := 0.0       # 未命中

const CONCL_PREFIX := "conclusion_"
const PERSON_PREFIX := "person:"


## 节点 id 归一化：结论节点在画布上形如 "conclusion_CL3-1"，真相表里写作 "CL3-1"。
## 人物节点画布上是裸 id（"KILLER"），真相表里写作 "person:KILLER" —— 一并剥前缀对齐
## （2026-09-02：修复场景一练习墙人物边永不命中的隐性错位）。
static func norm(nid: String) -> String:
	if nid.begins_with(CONCL_PREFIX):
		return nid.substr(CONCL_PREFIX.length())
	if nid.begins_with(PERSON_PREFIX):
		return nid.substr(PERSON_PREFIX.length())
	return nid


## 主入口。
## relations          玩家真实关系 [{from,to,kind,dashed}]（graph_view_controller._relations）
## graph_nodes        画布上玩家节点 [{id,kind,data}]（只取 kind=hypo 的主动产出，note_* 自造节点不计节点分）
## derived_conclusions 玩家落盘结论 [{id,text,...}]
## scene_id           当前场景（只评该场景及之前的链；场景二不该要求玩家完成场景八的链）
## practice           练习墙（场景一）：只算明细不产出星级，调用方据此不提交 StarRatingSystem
static func evaluate(relations: Array, graph_nodes: Array, derived_conclusions: Array,
		scene_id: String, practice: bool = false) -> Dictionary:
	var allowed := _allowed_scenes(scene_id)

	# ── 玩家产物集合 ────────────────────────────────────────────
	var player_nodes := {}          # 归一化 id -> true（玩家主动产出的推断/结论）
	for gn in graph_nodes:
		var gid: String = norm(str(gn.get("id", "")))
		if gid == "" or gid.begins_with("note_"):
			continue
		if str(gn.get("kind", "")) != "hypo":
			continue
		player_nodes[gid] = true
	for dc in derived_conclusions:
		var cid: String = norm(str(dc.get("id", "")))
		if cid != "":
			player_nodes[cid] = true

	var player_edges: Array = []
	for r in relations:
		if bool(r.get("dashed", false)):
			continue                                    # 存疑虚线：只显示，不判定
		player_edges.append({
			"from": norm(str(r.get("from", ""))),
			"to": norm(str(r.get("to", ""))),
			"kind": str(r.get("kind", "relate")),
		})

	# ── 误导项：玩家是否「采纳」 ──────────────────────────────────
	var adopted: Array = []
	var negated: Array = []
	for b in Truth.branches():
		if not allowed.has(str(b.get("scene", ""))):
			continue
		for m in b.get("misleads", []):
			var mid: String = norm(str(m.get("id", "")))
			var expect: String = str(m.get("expect", "negate"))
			var is_adopted := false
			var is_negated := false
			# 采纳 = 主动产出该节点，或对它建 support 边
			if player_nodes.has(mid):
				is_adopted = true
			for e in player_edges:
				if str(e.get("to", "")) == mid and str(e.get("kind", "")) == "support":
					is_adopted = true
				if str(e.get("from", "")) == mid and str(e.get("kind", "")) == "oppose":
					is_negated = true
				if str(e.get("to", "")) == mid and str(e.get("kind", "")) == "oppose":
					is_negated = true
			# 未被否定的误导推断节点 → 视为采纳（玩家把它当真推下去了）
			if player_nodes.has(mid) and not is_negated and expect == "negate":
				is_adopted = true
			if is_adopted:
				adopted.append(mid)
			elif is_negated:
				negated.append(mid)

	# ── 归属：每条玩家产物只归一条链，杜绝跨链公共节点导致重复计分 ──────
	# 背景：c309 同属 CH03/CH05、C_SOTCB_402 同属 CH03/CH07、CL7-1 是 CH09F 阶段结论的输入。
	# 若不归属，同一条边会在多条链各算一次，分子分母同步虚高，正确率失真。
	# 规则：按 branches 顺序，**第一条**「链内节点集包含它」的链认领。
	#   边：两端**任一**在链内即认领（单端=链外乱连，照样进分母、0 分 → 连得越滥正确率越低）。
	#   节点：id 在链内即认领。
	var scope: Array = []
	for b in Truth.branches():
		var bscene: String = str(b.get("scene", ""))
		if not allowed.has(bscene):
			continue
		var is_practice: bool = bool(b.get("practice", false))
		if is_practice and not practice:
			continue      # 练习链只在练习墙里参与（场景一），正式场景不混进来
		scope.append(b)

	var edges_of := {}      # branch_id -> Array
	var nodes_of := {}      # branch_id -> Array
	for b in scope:
		edges_of[str(b.get("id", ""))] = []
		nodes_of[str(b.get("id", ""))] = []
	# 两轮认领：① 双端都在链内（精确归属，优先）；② 只有一端在链内（链外乱连，兜底惩罚）。
	# ⚠️ 不能一轮「单端即认领」：c309 同属 CH03/CH05，单端会让 CH03 抢走 CH05 的
	#    (c309→H3-02)，导致 CH05 少一条真相边、CH03 多一条错误边，完美解永远到不了 100%。
	var claimed := {}
	for pass_two in [false, true]:
		for e in player_edges:
			var ekey: String = "%s>%s|%s" % [str(e.get("from", "")), str(e.get("to", "")), str(e.get("kind", ""))]
			if claimed.has(ekey):
				continue
			var ef: String = str(e.get("from", ""))
			var et: String = str(e.get("to", ""))
			for b in scope:
				var bid: String = str(b.get("id", ""))
				var ns: Dictionary = _node_set(b)
				var both: bool = ns.has(ef) and ns.has(et)
				var one: bool = ns.has(ef) or ns.has(et)
				if (not pass_two and both) or (pass_two and one):
					edges_of[bid].append(e)
					claimed[ekey] = true
					break
	for nid in player_nodes.keys():
		for b in scope:
			var bid2: String = str(b.get("id", ""))
			if _node_set(b).has(nid):
				nodes_of[bid2].append(nid)
				break

	# ── 共享假说/结论节点去重（按真相归属，避免多链重复计 T）─────────────
	# 背景：同一 hypo/concl 节点可能出现在多条链的 nodes 里（如 H7-02 同属
	#   CH09D/CH09E）。节点赋值已「首条链认领」(player_nodes 只归一处)，但 T 仍按
	#   全链 nodes 累加 → 完美解因节点被多链重复计 T 而永远到不了 100%。
	#   修复：hypo/concl 节点只在「首次出现」的那条链计入 T，与边的两轮认领同源。
	var node_owner_truth: Dictionary = {}
	for b in scope:
		var bidx: String = str(b.get("id", ""))
		for n in b.get("nodes", []):
			if str(n.get("layer", "")) in ["hypo", "concl"]:
				var nid: String = norm(str(n.get("id", "")))
				if not node_owner_truth.has(nid):
					node_owner_truth[nid] = bidx

	# ── 逐链计分 ────────────────────────────────────────────────
	var per_branch: Array = []
	var sum_hit := 0.0
	var sum_max := 0.0
	var has_contradict := false
	for e in player_edges:
		if str(e.get("kind", "")) in ["contradict", "oppose"]:
			has_contradict = true

	for b in scope:
		var is_core: bool = bool(b.get("core", false))
		var bid3: String = str(b.get("id", ""))

		var res := _score_branch(b, nodes_of[bid3], edges_of[bid3], node_owner_truth)
		var built: int = int(res.get("built", 0))
		# optional 链「激活」= 至少命中一项（说明玩家真在推这条链），
		# 而不是「碰过一下」——否则一次误连就激活冷门链开始拖分，与「错误无惩罚」冲突。
		var active: bool = float(res.get("hit", 0.0)) > 0.0

		# optional 链：没真正推过就完全不参与（做砸才拖分是 bug，不是设计）
		if not is_core and not active:
			per_branch.append({
				"id": str(b.get("id", "")), "name": str(b.get("name", "")),
				"core": is_core, "active": false, "ratio": 0.0,
				"hit": 0.0, "built": 0, "truth": int(res.get("truth", 0)),
			})
			continue

		var t: int = int(res.get("truth", 0))
		var hit: float = float(res.get("hit", 0.0))
		var denom: float = float(maxi(built, t))
		var rb: float = hit / denom if denom > 0.0 else 0.0
		sum_hit += hit
		sum_max += denom
		per_branch.append({
			"id": str(b.get("id", "")), "name": str(b.get("name", "")),
			"core": is_core, "active": active, "ratio": rb,
			"hit": hit, "built": built, "truth": t,
		})

	var ratio: float = sum_hit / sum_max if sum_max > 0.0 else 0.0
	var hard_fail: bool = not adopted.is_empty()

	var stars := _stars_of(ratio)
	if hard_fail:
		stars = mini(stars, 2)        # 洞2：采纳误导项 → 三星硬条件失败

	var verdict := _verdict_of(ratio, hard_fail or has_contradict)

	return {
		"ratio": ratio,
		"stars": stars,
		"verdict": verdict,
		"hard_fail": hard_fail,
		"adopted_misleads": adopted,
		"negated_misleads": negated,
		"per_branch": per_branch,
		"sum_hit": sum_hit,
		"sum_max": sum_max,
		"practice": practice,
		"summary": _summary(ratio, stars, hard_fail, practice),
	}


## 链内节点集 = nodes 的 id ∪ edges 的端点。
## ⚠️ 必须含边端点：阶段结论（synthesize）的输入结论（如 CH09F 吃的 CL7-1/CL7-2）
## 只出现在 edges 里、不在 nodes 里，漏掉会让这些边永远无法命中，分母虚高。
static func _node_set(b: Dictionary) -> Dictionary:
	var s := {}
	for n in b.get("nodes", []):
		s[norm(str(n.get("id", "")))] = true
	for e in b.get("edges", []):
		s[norm(str(e.get("from", "")))] = true
		s[norm(str(e.get("to", "")))] = true
	return s


## 单条链计分：返回 {truth, built, hit}
## assigned_nodes / assigned_edges 已由 evaluate 归属好，本函数只做比对。
## node_owner_truth 为「hypo/concl 节点 → 其归属链 id」映射（首条链认领），用于
## 共享节点去重：同一节点出现在多条链时，只在归属链计 T，避免完美解 T 虚高。
static func _score_branch(b: Dictionary, assigned_nodes: Array, assigned_edges: Array,
		node_owner_truth: Dictionary = {}) -> Dictionary:
	var truth_nodes: Array = b.get("nodes", [])
	var truth_edges: Array = b.get("edges", [])
	var mislead_ids := {}
	for m in b.get("misleads", []):
		mislead_ids[norm(str(m.get("id", "")))] = str(m.get("expect", "negate"))
	var bid: String = str(b.get("id", ""))

	# 真相项数 T = 边数 + **玩家可产出的**节点数（hypo 推断 / concl 结论）。
	# ⚠️ 线索(clue)与人物(person)不计入 T：线索是观察得来、墙上预置，人物由 related_npcs 自动派生，
	#    玩家都无法在推理墙里「产出」它们——是否用对了体现在**边**上（连对 c201→H2-01 才算用到 c201）。
	#    若把线索也算进 T，则 B 永远小于 T，完美解永远到不了 100%（初版实测卡在 67.8%）。
	# ⚠️ 共享节点去重：hypo/concl 节点若被多条链引用，只在归属链(node_owner_truth)计 T，
	#    其余链跳过——否则节点被重复计 T 而玩家只产一次，完美解 T>B 永远 != 1.0。
	var truth: int = truth_edges.size()
	for n in truth_nodes:
		var nid: String = norm(str(n.get("id", "")))
		if str(n.get("layer", "")) in ["hypo", "concl"]:
			if node_owner_truth.get(nid, bid) != bid:
				continue
			truth += 1
	var built: int = 0
	var hit: float = 0.0

	# ① 节点项：只算玩家「主动产出」的（推断/结论）。线索是墙上预置的，不算玩家产出。
	for n in truth_nodes:
		var nid: String = norm(str(n.get("id", "")))
		var layer: String = str(n.get("layer", ""))
		if layer not in ["hypo", "concl"]:
			continue
		if not (nid in assigned_nodes):
			continue
		built += 1
		if mislead_ids.has(nid):
			hit += HIT_NONE            # 产出误导节点 = 采纳，0 分（并由 evaluate 记 hard_fail）
		else:
			hit += HIT_EXACT

	# ② 边项：归属已保证每条边只进一条链，此处只判命中档位。
	var truth_edge_map := {}
	for e in truth_edges:
		var k := _edge_key(norm(str(e.get("from", ""))), norm(str(e.get("to", ""))), str(e.get("kind", "")))
		truth_edge_map[k] = e
	for e in assigned_edges:
		var ef: String = str(e.get("from", ""))
		var et: String = str(e.get("to", ""))
		built += 1
		var ek: String = str(e.get("kind", ""))
		if truth_edge_map.has(_edge_key(ef, et, ek)):
			hit += HIT_EXACT
		elif truth_edge_map.has(_edge_key(et, ef, ek)):
			hit += HIT_REVERSED          # 两端对、方向反 → 半分
		elif mislead_ids.has(et) and ek == "oppose":
			hit += HIT_EXACT             # 否定误导项 = 识破，给满分
		elif mislead_ids.has(ef) and ek == "oppose":
			hit += HIT_EXACT
		else:
			hit += HIT_NONE              # 错误边：进分母，不给分（连得越滥正确率越低）

	return {"truth": truth, "built": built, "hit": hit}


static func _edge_key(a: String, b: String, kind: String) -> String:
	return "%s>%s|%s" % [a, b, kind]


## 当前场景**及之前**的场景集合（跨场景累积：场景 N 的墙带入场景 2..N）。
## ⚠️ 方向别写反：场景二只该评 scene2 的链，不该要求玩家完成场景八的链。
static func _allowed_scenes(scene_id: String) -> Dictionary:
	var order: Array = ["scene1", "scene2", "scene3", "scene4", "scene5", "scene6", "scene7", "scene8"]
	var allowed := {}
	for sid in order:
		allowed[sid] = true
		if sid == scene_id:
			break
	# 兜底：未知场景号（如自造 id）至少允许自己，避免整表失效
	if not allowed.has(scene_id):
		allowed[scene_id] = true
	return allowed


## 星级：80 / 55 / 25（思傅裁定）
static func _stars_of(ratio: float) -> int:
	if ratio >= Truth.STAR_3:
		return 3
	if ratio >= Truth.STAR_2:
		return 2
	if ratio >= Truth.STAR_1:
		return 1
	return 0


## 四档 verdict 与星级同源（裁定 3：统一评分源）。
## 注：CONTRADICTORY 保留独立语义——存在矛盾/采纳误导项时，即使正确率不低也判矛盾。
static func _verdict_of(ratio: float, contradicted: bool) -> int:
	if contradicted and ratio < Truth.STAR_3:
		return 0      # Verdict.CONTRADICTORY
	if ratio >= Truth.STAR_3:
		return 3      # Verdict.VERIFIED
	if ratio >= Truth.STAR_2:
		return 2      # Verdict.SUPPORTED
	if ratio >= Truth.STAR_1:
		return 1      # Verdict.INSUFFICIENT
	return 1          # 低于 25% 仍归 INSUFFICIENT（无星，但保持四档闭合）


## 验证窗口给玩家看的一句话（裁定 4：侦查中不告诉错在哪）。
static func _summary(ratio: float, stars: int, hard_fail: bool, practice: bool) -> String:
	if practice:
		return "练习墙 · 不计分"
	var pct: int = int(round(ratio * 100.0))
	var s: String = "%d%% · " % pct
	match stars:
		3:
			s += "推理链完整闭合"
		2:
			s += "方向正确，尚有缺口"
		1:
			s += "证据不足，建议复勘"
		_:
			s += "尚未形成有效推理"
	if hard_fail:
		s += "（有推论被证伪）"
	return s
