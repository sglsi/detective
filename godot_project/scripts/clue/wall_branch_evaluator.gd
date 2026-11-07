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
## 洞1（只做最短链就三星）：标 core 链（破案必经 10 条），未激活的 core 链按 R=0
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

## 跨场景互证加成（C）：同一推断由 ≥2 个不同场景的线索共同支撑、且玩家全部连对时，
## 该推断节点的命中权重从 1.0 提升到 1.0 + REINFORCED_BONUS，体现「相互印证并加强」。
## 取值依据：一个额外场景的独立佐证约等于「多读到一条强证」的边际增益，取 0.15 ≈ 1/7 项
## （低于任何两条独立边的增量，避免稀释「多连一条正确边」的权重）。整体 R 在 evaluate
## 末尾 clamp 到 1.0，天然不会超过满分，与设计文档 80/55/25 阈值正交（阈值在 display_ratio 上检，
## 加成只推高由真实命中带来的 R，不会凭空造星）。
const REINFORCED_BONUS := 0.15


## 线索 → 所属场景推断（实现互证判定用，纯数据模式匹配，不加载场景脚本）。
## 场景二线索 c2xx、场景三 c3xx、场景四~八均为 C_SOTCB_4xx~8xx。无法识别返回 ""。
static func _scene_of_clue(clue_id: String) -> String:
	if clue_id.begins_with("c2"):
		return "scene2"
	if clue_id.begins_with("c3"):
		return "scene3"
	if clue_id.begins_with("C_SOTCB_4"):
		return "scene4"
	if clue_id.begins_with("C_SOTCB_5"):
		return "scene5"
	if clue_id.begins_with("C_SOTCB_6"):
		return "scene6"
	if clue_id.begins_with("C_SOTCB_7"):
		return "scene7"
	if clue_id.begins_with("C_SOTCB_8"):
		return "scene8"
	return ""


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
## collected_ids      本墙已收集线索 id 集（Phase 0.1）。真相边两端涉及未收集线索时，
##                    该边从 T 与 missing_edges 剔除、记入 unavailable_edges——跨场景链
##                    （CH03 标在 scene2，真相含场景三/四线索）在早期场景结算不再被
##                    永远缺失的边压低 R。传空数组 = 不裁剪（旧行为，兼容旧调用方/探针）。
static func evaluate(relations: Array, graph_nodes: Array, derived_conclusions: Array,
		scene_id: String, practice: bool = false, collected_ids: Array = [],
		difficulty_override: int = -1) -> Dictionary:
	var allowed := _allowed_scenes(scene_id)

	# ── 已收集线索集合（归一化与真相 id 同一空间）──────────────────
	var collected := {}
	for cid in collected_ids:
		var ck := norm(str(cid))
		if ck != "":
			collected[ck] = true

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
	var edge_idx := 0
	for pass_two in [false, true]:
		edge_idx = 0
		for e in player_edges:
			edge_idx += 1
			if claimed.has(edge_idx):
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
					claimed[edge_idx] = true
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
	# 注意：对误导项的 oppose（正确识破）不算矛盾，只有真正的矛盾边才算
	var has_contradict := false
	# 收集所有误导项 id（用于排除正确识破的 oppose 边）
	var mislead_all := {}
	for b in Truth.branches():
		if not allowed.has(str(b.get("scene", ""))):
			continue
		for m in b.get("misleads", []):
			mislead_all[norm(str(m.get("id", "")))] = str(m.get("expect", "negate"))
	for e in player_edges:
		var ek: String = str(e.get("kind", ""))
		if ek == "contradict":
			has_contradict = true
		elif ek == "oppose":
			# 如果两端任一是误导项且 expect=negate，这是正确识破，不算矛盾
			var ef: String = str(e.get("from", ""))
			var et: String = str(e.get("to", ""))
			var is_negate_mislead := false
			if mislead_all.has(ef) and mislead_all[ef] == "negate":
				is_negate_mislead = true
			if mislead_all.has(et) and mislead_all[et] == "negate":
				is_negate_mislead = true
			if not is_negate_mislead:
				has_contradict = true

	# 洞察（合成层）聚合：非线索层真相边 + 结论节点产出（用户裁定：战场不再作为洞察数据源）
	var ins_hit := 0.0
	var ins_truth := 0
	var produced: Dictionary = {}
	for bid_key in nodes_of:
		for pn in nodes_of[bid_key]:
			produced[norm(str(pn))] = true

	for b in scope:
		var is_core: bool = bool(b.get("core", false))
		var bid3: String = str(b.get("id", ""))

		var res := _score_branch(b, nodes_of[bid3], edges_of[bid3], node_owner_truth, collected)
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
				"missing_nodes": [], "missing_edges": [],
				"reversed_edges": [], "extra_edges": [],
				"unavailable_edges": [],
				"pending_edges": [], "pending_nodes": [], "pending_hits": 0,
				"reinforced_count": 0, "reinforced_bonus": 0.0,
			})
			continue

		var t: int = int(res.get("truth", 0))
		var hit: float = float(res.get("hit", 0.0))
		var denom: float = float(maxi(built, t))
		var rb: float = hit / denom if denom > 0.0 else 0.0
		rb = minf(rb, 1.0)            # 互证加成可能让单链 hit 超过 truth，R 上限封 1.0（C 硬约束）
		sum_hit += hit
		sum_max += denom
		per_branch.append({
			"id": str(b.get("id", "")), "name": str(b.get("name", "")),
			"core": is_core, "active": active, "ratio": rb,
			"hit": hit, "built": built, "truth": t,
			"missing_nodes": res.get("missing_nodes", []),
			"missing_edges": res.get("missing_edges", []),
			"reversed_edges": res.get("reversed_edges", []),
			"extra_edges": res.get("extra_edges", []),
			"matched_edges": res.get("matched_edges", []),
			"unavailable_edges": res.get("unavailable_edges", []),
			"pending_edges": res.get("pending_edges", []),
			"pending_nodes": res.get("pending_nodes", []),
			"pending_hits": int(res.get("pending_hits", 0)),
			"reinforced_count": int(res.get("reinforced_count", 0)),
			"reinforced_bonus": float(res.get("reinforced_bonus", 0.0)),
		})

		# —— 洞察（合成层）聚合：非线索层的真相边 + 结论节点 ——
		# 分母 = 真相合成边（matched exact/reversed + missing 全覆盖）+ 真相结论节点（共享去重）
		# 分子 = exact 1.0 / reversed 0.5 + 产出的结论节点
		var layer_of: Dictionary = {}
		for n in b.get("nodes", []):
			layer_of[norm(str(n.get("id", "")))] = str(n.get("layer", ""))
		for me in res.get("matched_edges", []):
			if _is_synthesis_edge(str(me.get("from", "")), str(me.get("to", "")), layer_of):
				ins_truth += 1
				ins_hit += float(me.get("weight", 1.0))
		for me2 in res.get("missing_edges", []):
			if _is_synthesis_edge(str(me2.get("from", "")), str(me2.get("to", "")), layer_of):
				ins_truth += 1
		for n2 in b.get("nodes", []):
			var nid2: String = norm(str(n2.get("id", "")))
			if str(n2.get("layer", "")) == "concl":
				if node_owner_truth.get(nid2, bid3) != bid3:
					continue
				ins_truth += 1
				if nid2 in produced:
					ins_hit += 1.0

	var ratio: float = sum_hit / sum_max if sum_max > 0.0 else 0.0
	ratio = minf(ratio, 1.0)       # 互证加成（C）可让全局 hit 超过 sum_max，R 上限封 1.0
	var hard_fail: bool = not adopted.is_empty()

	# ============== L2 · 难度统一 R 轴 ==============
	# 不同难度下误导项数量不同，raw ratio 不可直接比较。
	# 引入 display_ratio = clamp(ratio × correction, 0, 1)
	# 作为显示用的统一 R 轴，星级 / 档位 / 进程条全部基于 display_ratio。
	# raw ratio 保留用于存档、结算竞技分等真实数据用途。
	# DifficultyManager 是 autoload，无主循环/工具脚本环境下不可用，走 Engine.has_singleton 安全访问
	# difficulty_override >= 0 时强制使用指定难度（用于探针/测试），-1 表示读 autoload
	var correction: float = 1.0
	if difficulty_override >= 0:
		match difficulty_override:
			0:  # EASY
				correction = 0.8
			2:  # HARD
				correction = 1.25
			_:
				correction = 1.0
	else:
		var dm: Object = null
		if Engine.has_singleton("DifficultyManager"):
			dm = Engine.get_singleton("DifficultyManager")
		if dm != null:
			match int(dm.get("current_difficulty")):
				0:  # EASY
					correction = 0.8
				2:  # HARD
					correction = 1.25
				_:
					correction = 1.0
	var display_ratio: float = clamp(ratio * correction, 0.0, 1.0)

	var stars := _stars_of(display_ratio)
	if hard_fail:
		stars = mini(stars, 2)        # 洞2：采纳误导项 → 三星硬条件失败

	var verdict := _verdict_of(display_ratio, hard_fail or has_contradict)

	return {
		"ratio": ratio,
		"display_ratio": display_ratio,
		"difficulty_correction": correction,
		"stars": stars,
		"verdict": verdict,
		"has_contradict": has_contradict,
		"hard_fail": hard_fail,
		"adopted_misleads": adopted,
		"negated_misleads": negated,
		"per_branch": per_branch,
		"sum_hit": sum_hit,
		"sum_max": sum_max,
		"insight_hit": ins_hit,
		"insight_truth": ins_truth,
		"insight_ratio": (ins_hit / float(ins_truth)) if ins_truth > 0 else -1.0,
		"practice": practice,
		"summary": _summary(display_ratio, stars, hard_fail, practice),
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
		node_owner_truth: Dictionary = {}, collected: Dictionary = {}) -> Dictionary:
	var truth_nodes: Array = b.get("nodes", [])
	var truth_edges: Array = b.get("edges", [])
	var mislead_ids := {}
	for m in b.get("misleads", []):
		mislead_ids[norm(str(m.get("id", "")))] = str(m.get("expect", "negate"))
	var bid: String = str(b.get("id", ""))

	# ── 可用性裁剪：边按「本墙已收集线索」裁（Phase 0.1+），节点按「可达闭包」裁（A）──
	# 跨场景链在早期场景结算时，真相引用的后置场景线索还没收集；不裁剪则 T 含永远缺失项，
	# 链 R 有结构性上限（CH03@scene2 未裁 = 14/17≈0.824）。
	#   边：clue 一端未收集 → 该边当前连不出来，从 T/missing 剔除，记 unavailable_edges，
	#      同时记 pending_edges（待解锁：解锁后边进入 T，玩家补连即可得分，R 只增不减）。
	#   节点（A，Phase 0.2）：hypo/concl 节点按「图可达闭包」裁剪——从已收集线索出发，沿真相边
	#      传播可达性；某一推断只要「任一 gate 线索已收集」或「任一 gate 推断已可达」即部分可用、
	#      保留（与用户判据「部分可用时保留」逐字一致）；全部 gate 都不可达 → 未解锁 → 记
	#      pending_node，从 T/missing 剔除、玩家产出它不惩罚。这是「墙预设并集只到当前场景
	#      （get_hypo_union_up_to）」在计分侧的对应：早期场景不要求玩家完成后置场景才能做的项。
	# collected 为空 = 不裁剪（旧行为，兼兼容旧调用方/探针）。
	var unavailable_edges: Array = []
	var pending_edges: Array = []
	var truth_edges_full: Array = b.get("edges", [])
	var eff_edges: Array = truth_edges
	if not collected.is_empty():
		var clue_ids := {}
		for n in truth_nodes:
			if str(n.get("layer", "")) == "clue":
				clue_ids[norm(str(n.get("id", "")))] = true
		eff_edges = []
		for e in truth_edges:
			var efk := norm(str(e.get("from", "")))
			var etk := norm(str(e.get("to", "")))
			if (clue_ids.has(efk) and not collected.has(efk)) \
					or (clue_ids.has(etk) and not collected.has(etk)):
				unavailable_edges.append({
					"from": str(e.get("from", "")), "to": str(e.get("to", "")),
					"kind": str(e.get("kind", "")),
				})
				pending_edges.append({
					"from": str(e.get("from", "")), "to": str(e.get("to", "")),
					"kind": str(e.get("kind", "")),
				})
				continue
			eff_edges.append(e)
		truth_edges = eff_edges

	# 节点可达闭包：原点=已收集线索（truth 内的 clue 且已收集）；沿「全量真相边」传播。
	# 边 from 可达 + to 是推断/结论 → to 可达。collected 空时全部可达（不裁剪）。
	var reachable := {}
	for n in truth_nodes:
		var l: String = str(n.get("layer", ""))
		var nid0: String = norm(str(n.get("id", "")))
		if l == "clue" and collected.has(nid0):
			reachable[nid0] = true
	if collected.is_empty():
		for n in truth_nodes:
			if str(n.get("layer", "")) in ["hypo", "concl"]:
				reachable[norm(str(n.get("id", "")))] = true
	var changed := true
	while changed:
		changed = false
		for e in truth_edges_full:
			var f: String = norm(str(e.get("from", "")))
			var t: String = norm(str(e.get("to", "")))
			if reachable.has(f) and not reachable.has(t):
				reachable[t] = true
				changed = true
	var pending_node := {}
	for n in truth_nodes:
		if str(n.get("layer", "")) in ["hypo", "concl"]:
			var pn: String = norm(str(n.get("id", "")))
			if not reachable.has(pn):
				pending_node[pn] = true

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
			if pending_node.has(nid):
				continue          # 未解锁节点不计 T（A）
			truth += 1
	var built: int = 0
	var hit: float = 0.0
	var missing_nodes: Array = []     # 真相要求的推断/结论节点，玩家未产出
	var missing_edges: Array = []     # 真相边，玩家未连（任何形式都没命中）
	var reversed_edges: Array = []    # 玩家连了但方向反的真相边（半分）
	var extra_edges: Array = []       # 玩家建的、不匹配任何真相边的连线（进分母拉低正确率）
	var matched_edges: Array = []     # 真相边被命中的记录（weight: 1.0 精确 / 0.5 方向反），供洞察星聚合
	var pending_hits: int = 0         # 玩家碰触了「待解锁」节点/边的次数（不惩罚、不计分）
	var reinforced_count: int = 0     # 命中「跨场景互证」的推断个数（C）
	var reinforced_bonus: float = 0.0 # 互证加成累计加分（计入 hit，R≤1.0 由 evaluate 收口）

	# ① 节点项：只算玩家「主动产出」的（推断/结论）。线索是墙上预置的，不算玩家产出。
	for n in truth_nodes:
		var nid: String = norm(str(n.get("id", "")))
		var layer: String = str(n.get("layer", ""))
		if layer not in ["hypo", "concl"]:
			continue
		if node_owner_truth.get(nid, bid) != bid:
			continue
		if pending_node.has(nid):
			if nid in assigned_nodes:
				pending_hits += 1     # 玩家提前产出了未解锁推断：不惩罚、不加分
			continue
		if not (nid in assigned_nodes):
			missing_nodes.append(nid)
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
	# 待解锁边密钥集（B）：被裁的真相边玩家此刻连不出来（线索未收集），若玩家提前连了，
	# 不能落进 extra_edges 扣分——它匹配的是「待解锁」项，不是错误项。同样也不进 built/built 分母。
	var pending_edge_keys := {}
	for e in pending_edges:
		pending_edge_keys[_edge_key(norm(str(e.get("from", ""))), norm(str(e.get("to", ""))), str(e.get("kind", "")))] = true
	var matched_truth := {}
	for e in assigned_edges:
		var ef: String = norm(str(e.get("from", "")))
		var et: String = norm(str(e.get("to", "")))
		var ek: String = str(e.get("kind", ""))
		built += 1
		var fk := _edge_key(ef, et, ek)
		var rk := _edge_key(et, ef, ek)
		if (pending_edge_keys.has(fk) or pending_edge_keys.has(rk)) \
				and not truth_edge_map.has(fk) and not truth_edge_map.has(rk):
			built -= 1                     # 待解锁边：不惩罚（不进 extra）、不拉分母
			pending_hits += 1
			continue
		if truth_edge_map.has(fk) and not matched_truth.has(fk):
			matched_truth[fk] = true
			matched_edges.append({"from": ef, "to": et, "kind": ek, "weight": 1.0})
			hit += HIT_EXACT
		elif truth_edge_map.has(rk) and not matched_truth.has(rk):
			matched_truth[rk] = true
			reversed_edges.append({"from": et, "to": ef, "kind": ek})
			matched_edges.append({"from": et, "to": ef, "kind": ek, "weight": 0.5})
			hit += HIT_REVERSED          # 两端对、方向反 → 半分
		elif truth_edge_map.has(fk) and matched_truth.has(fk):
			extra_edges.append({"from": ef, "to": et, "kind": ek})
			hit += HIT_NONE              # 重复边：进分母，不给分
		elif truth_edge_map.has(rk) and matched_truth.has(rk):
			extra_edges.append({"from": ef, "to": et, "kind": ek})
			hit += HIT_NONE              # 重复反向边：进分母，不给分
		elif mislead_ids.has(et) and ek == "oppose":
			hit += HIT_EXACT             # 否定误导项 = 识破，给满分
		elif mislead_ids.has(ef) and ek == "oppose":
			hit += HIT_EXACT
		else:
			extra_edges.append({"from": ef, "to": et, "kind": ek})
			hit += HIT_NONE              # 错误边：进分母，不给分（连得越滥正确率越低）

	for e in truth_edges:
		var tk := _edge_key(norm(str(e.get("from", ""))), norm(str(e.get("to", ""))), str(e.get("kind", "")))
		if not matched_truth.has(tk):
			missing_edges.append({
				"from": str(e.get("from", "")),
				"to": str(e.get("to", "")),
				"kind": str(e.get("kind", "")),
			})

	# ③ 跨场景互证加成（C）：在本链全部边比对完后统一计算（此时 matched_truth 才完整）。
	# 对每个「已产出、非误导、未待解锁」的 direct hypo 推断节点，统计其直接线索门控覆盖的
	# 不同场景数；≥2 且全部精确命中 → 该推断获得互证加成，写进 hit 与 per_branch 可诊断字段。
	for n in truth_nodes:
		var rn: String = norm(str(n.get("id", "")))
		if str(n.get("layer", "")) != "hypo" or mislead_ids.has(rn):
			continue
		if node_owner_truth.get(rn, bid) != bid:
			continue
		if pending_node.has(rn) or not (rn in assigned_nodes):
			continue
		if _cross_scene_score(rn, truth_edges_full, matched_truth) <= 1:
			continue                # 线索门控不足 2 个不同场景，或未全部命中 → 不触发
		hit += REINFORCED_BONUS
		reinforced_count += 1
		reinforced_bonus += REINFORCED_BONUS

	return {
		"truth": truth, "built": built, "hit": hit,
		"missing_nodes": missing_nodes, "missing_edges": missing_edges,
		"reversed_edges": reversed_edges, "extra_edges": extra_edges,
		"matched_edges": matched_edges, "unavailable_edges": unavailable_edges,
		"pending_edges": pending_edges, "pending_nodes": pending_node.keys(),
		"pending_hits": pending_hits,
		"reinforced_count": reinforced_count, "reinforced_bonus": reinforced_bonus,
	}


## 跨场景互证强度（C）：返回该推断的直接线索门控覆盖的不同场景数；若存在任一未命中的
## 线索门控边则返回 0（未「全部连对」不触发加成）。truth_edges_full 需为本链全量真相边
## （未做线索裁剪），matched 为玩家精确命中的真相边密钥集。
static func _cross_scene_score(hypo_id: String, truth_edges_full: Array, matched: Dictionary) -> int:
	var scenes := {}
	for e in truth_edges_full:
		var ef: String = norm(str(e.get("from", "")))
		var et: String = norm(str(e.get("to", "")))
		var ek: String = str(e.get("kind", ""))
		var sc := _scene_of_clue(ef)
		if et != hypo_id or ek != "support" or sc == "":
			continue
		if not matched.has(_edge_key(ef, hypo_id, "support")):
			return 0                # 有线索门控没连对 → 不算「全部印证」
		scenes[sc] = true
	return scenes.size()


static func _edge_key(a: String, b: String, kind: String) -> String:
	return "%s>%s|%s" % [a, b, kind]


## 洞察星合成边判定：两端均为非线索层（推断/链/结论/人物）的真相边。
## 线索→人物（直连证据）与线索→线索不算合成；节点→人物（归属）算。
static func _is_synthesis_edge(from_id: String, to_id: String, layer_of: Dictionary) -> bool:
	if from_id.begins_with("person:"):
		return false
	if to_id.begins_with("person:"):
		return true
	var fl: String = str(layer_of.get(norm(from_id), ""))
	var tl: String = str(layer_of.get(norm(to_id), ""))
	return fl != "" and tl != "" and fl != "clue" and tl != "clue"


## 当前场景**及之前**的场景集合（跨场景累积：场景 N 的墙带入场景 2..N）。
## ⚠️ 方向别写反：场景二只该评 scene2 的链，不该要求玩家完成场景八的链。
static func _allowed_scenes(scene_id: String) -> Dictionary:
	var order: Array = ["scene1", "scene2", "scene3", "scene4", "scene5", "scene6", "scene7", "scene8"]
	var allowed := {}
	var found := false
	for sid in order:
		if sid == scene_id:
			found = true
			allowed[sid] = true
			break
		allowed[sid] = true
	# 兜底：未知场景号（如自造 id）只允许自己，避免整表失效
	# （如果找不到就放行全部 8 个，玩家在 sceneX 也能看到所有链，等于没边界）
	if not found:
		allowed.clear()
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
## 采纳误导项(hard_fail) 或有矛盾边(has_contradict) 时，最高只能到 SUPPORTED，
## 不能判 VERIFIED（与三星硬条件一致）。
static func _verdict_of(ratio: float, contradicted: bool) -> int:
	if contradicted:
		if ratio < Truth.STAR_1:
			return 1  # INSUFFICIENT（有矛盾但连基本结构都没有，归入证据不足）
		if ratio < Truth.STAR_3:
			return 0  # CONTRADICTORY（有矛盾且正确率不高）
		return 2      # SUPPORTED（方向大致正确，但存在硬伤<采纳误导/矛盾边>，未达验证标准）
	if ratio >= Truth.STAR_3:
		return 3      # VERIFIED
	if ratio >= Truth.STAR_2:
		return 2      # SUPPORTED
	if ratio >= Truth.STAR_1:
		return 1      # INSUFFICIENT
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
