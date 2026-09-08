extends RefCounted
class_name ReasoningChains
## 统一推理链描述库（单一事实源，2026-09-07 模块化重构）。
## 每条推理链一个条目：wall 为 reasoning_wall 需要的完整运行数据（与各场景
## reasoning_hypothesis() 钩子同构），misleads 为干扰项期望表。
## 真相表（case_branch_truth.gd）不再手工维护——由 derive_truth() 从 wall 数据
## 机械派生，"真相表与 gate 同源"由构造保证。新增链只需在此加一个条目。

const CHAINS := {
	"CH01W": {
		"name": "华生教学（练习）", "scene": "scene1", "core": false, "practice": true,
		"misleads": [],
		"wall": {
			"title": "华生刚从阿富汗回来？",
			"persons": [{"id": "NPC_WT"}],
			"description": "从华生身上的痕迹（手腕肤色分明、脸色黝黑、军人站姿、消毒液气味、左臂旧伤、面容憔悴）逐层推断：肤色→热带生活→英国殖民地为阿富汗；军人气质＋医疗行业→军医；旧伤＋久病→伤痛来自军事任务；三线闭合→在阿富汗服役过。",
			"battlefield": {
				"hypotheses": [
					{"id": "W-A1", "text": "不是原来的肤色", "correct": true, "gate_clue_ids": ["wrist", "face_dark"]},
					{"id": "W-B1", "text": "多年军事行业形成的气质", "correct": true, "gate_clue_ids": ["pose"]},
					{"id": "W-B2", "text": "从事医疗行业", "correct": true, "gate_clue_ids": ["medical"]},
					{"id": "W-C1", "text": "左臂受过伤未完全恢复", "correct": true, "gate_clue_ids": ["arm"]},
					{"id": "W-C2", "text": "久病初愈而又历尽了苦难", "correct": true, "gate_clue_ids": ["face_haggard"]},
				],
				"conclusions": [
					{"id": "C-A1", "text": "曾经在热带生活过", "correct": true, "dir": "affirm", "subject": ["华生"], "object": ["热带"], "match_keys": ["在热带生活过", "热带生活", "热带待过", "在热带待过"], "gate_hypo_ids": ["W-A1"], "adopt_desc": "肤色分明与黝黑的脸——他曾在热带生活过。"},
					{"id": "C-B1", "text": "是名军医", "correct": true, "dir": "affirm", "subject": ["华生"], "object": ["军医", "医生"], "match_keys": ["军医", "是医生", "医疗兵", "医务人员"], "gate_hypo_ids": ["W-B1", "W-B2"], "adopt_desc": "军人气质与医疗行业的痕迹，合起来是一名军医。"},
					{"id": "C-C1", "text": "承受了这个年龄本不该承受的伤痛", "correct": true, "dir": "affirm", "subject": ["华生"], "object": ["伤痛", "苦难"], "match_keys": ["承受伤痛", "不该承受的伤痛", "经历过苦难", "久病初愈"], "gate_hypo_ids": ["W-C1", "W-C2"], "adopt_desc": "旧伤未愈又久病初愈——他承受了不该承受的伤痛。"},
					{"id": "C-A2", "text": "英国在热带的殖民地为阿富汗", "correct": true, "dir": "affirm", "subject": ["英国"], "object": ["阿富汗"], "match_keys": ["阿富汗", "英国殖民地是阿富汗", "热带殖民地是阿富汗", "去过阿富汗"], "gate_hypo_ids": ["conclusion_C-A1"], "adopt_desc": "英国在热带的殖民地——最近的那块是阿富汗。"},
					{"id": "C-C2", "text": "不该有的伤害只可能来自军事任务", "correct": true, "dir": "affirm", "subject": ["伤害"], "object": ["军事任务"], "match_keys": ["军事任务", "伤害来自军事", "战场负伤", "军旅负伤"], "gate_hypo_ids": ["conclusion_C-C1"], "adopt_desc": "这样的伤痛，只可能来自军事任务。"},
					{"id": "C-MAIN", "text": "在阿富汗服役过", "correct": true, "dir": "affirm", "subject": ["华生"], "object": ["阿富汗", "服役"], "match_keys": ["在阿富汗服役", "阿富汗服役过", "去过阿富汗当兵", "阿富汗当兵"], "gate_hypo_ids": ["conclusion_C-A2", "conclusion_C-B1", "conclusion_C-C2"], "target": "person:NPC_WT", "adopt_desc": "热带殖民地、军医身份、军事任务的伤痛——三线闭合，他在阿富汗服役过。"},
				],
				"contradictions": [],
			},
			"milestones": [
				{"id": "MW-1", "text": "华生曾在热带生活过（肤色推导）"},
				{"id": "MW-2", "text": "华生是名军医（军人气质＋医疗行业）"},
				{"id": "MW-3", "text": "华生承受过不该有的伤痛（旧伤＋久病）"},
				{"id": "MW-4", "text": "华生曾在阿富汗服役（三线闭合）"},
			],
			# 裁定 5：练习墙不计分。scene_id 供分枝评分引擎定位到场景一的练习链。
			"scene_id": "scene1", "practice": true,
		},
	},
	"CH01M": {
		"name": "信使判定（练习）", "scene": "scene1", "core": false, "practice": true,
		"misleads": [],
		"wall": {
			"title": "信使是海军陆战队军士？",
			"persons": [
				{"id": "NPC_MSG", "name": "信使"},
				{"id": "NPC_SERGEANT", "name": "海军军士"},
			],
			"description": "从信使身上（手臂锚文身、军人式络腮胡、笔挺站姿、发号施令神态）推断其海军陆战队军士身份；注意分辨干扰项（袖口磨损、轻微跛行）。",
			"battlefield": {
				# 表格六列映射：线索→推导(MT 层)→结论1(M-01/02/04)→结论2(CL1-01)→结论3(CL1-02)→人物
				"hypotheses": [
					{"id": "MT-1", "text": "锚文身是海员中的常见标志", "correct": true, "gate_clue_ids": ["tattoo"]},
					{"id": "MT-2", "text": "军人式络腮胡，军人中常见", "correct": true, "gate_clue_ids": ["beard"]},
					{"id": "MT-3", "text": "站姿笔挺是军事训练中形成的肌肉记忆", "correct": true, "gate_clue_ids": ["posture"]},
					{"id": "MT-4", "text": "发号施令中形成的气质", "correct": true, "gate_clue_ids": ["manner"]},
					{"id": "M-05", "text": "袖口磨损说明常年奔波劳碌", "correct": false, "gate_clue_ids": ["sleeve"]},
					{"id": "M-06", "text": "走路轻微跛行受过伤", "correct": false, "gate_clue_ids": ["limp"]},
				],
				"conclusions": [
					{"id": "M-01", "text": "在海军中当兵", "kind": "true", "dir": "affirm", "subject": ["信使"], "object": ["海军"], "match_keys": ["在海军中当兵", "海军"], "gate_hypo_ids": ["MT-1"]},
					{"id": "M-02", "text": "当过兵", "kind": "true", "dir": "affirm", "subject": ["信使"], "object": ["兵"], "match_keys": ["当过兵", "军人"], "gate_hypo_ids": ["MT-2", "MT-3"]},
					{"id": "M-04", "text": "当过军士", "kind": "true", "dir": "affirm", "subject": ["信使"], "object": ["军士"], "match_keys": ["当过军士", "军士"], "gate_hypo_ids": ["MT-4"]},
					{"id": "CL1-01", "text": "海军陆战队员", "kind": "true", "dir": "affirm", "subject": ["信使"], "object": ["海军", "海军陆战队"], "match_keys": ["海军陆战队员", "是陆战队员", "海军陆战队"], "gate_hypo_ids": ["conclusion_M-01", "conclusion_M-02"], "adopt_desc": "在海军中当兵，又是正规军人出身——海军陆战队员。"},
					{"id": "CL1-02", "text": "海军军士", "kind": "true", "dir": "affirm", "subject": ["信使"], "object": ["军士"], "match_keys": ["海军军士", "军士"], "gate_hypo_ids": ["conclusion_M-04", "conclusion_CL1-01"], "target": "person:NPC_MSG", "adopt_desc": "陆战队员的底子，再加发号施令的军士气度——他是海军军士。"},
				],
				"contradictions": [],
			},
			"milestones": [
				{"id": "MM-0", "text": "先从线索归纳身份特征（海员标志、军人气质）"},
				{"id": "MM-1", "text": "信使是海军陆战队员（在海军当兵＋当过兵）"},
				{"id": "MM-2", "text": "信使是海军军士（陆战队员＋当过军士）"},
				{"id": "MM-3", "text": "袖口磨损/跛行为干扰项，非身份证据"},
			],
			# 裁定 5：练习墙不计分（信使墙为教学示范，干扰项用于教「信号 vs 噪音」）
			"scene_id": "scene1", "practice": true,
		},
	},
}

static func ids() -> Array:
	return CHAINS.keys()

static func has(id: String) -> bool:
	return CHAINS.has(id)

## 返回 reasoning_wall 需要的完整运行 dict（与 reasoning_hypothesis() 钩子同构）。
## 深拷贝：场景侧可安全改写（如重置 verified）而不污染链库。
static func build_wall_dict(id: String) -> Dictionary:
	var ch: Dictionary = CHAINS.get(id, {})
	if ch.is_empty():
		return {}
	var d: Dictionary = ch["wall"].duplicate(true)
	var ml := Engine.get_main_loop() as SceneTree
	var dm: Node = null if ml == null or ml.root == null else ml.root.get_node_or_null("DifficultyManager")
	if dm != null and dm.mislead_chance <= 0.0:
		var bf: Dictionary = d.get("battlefield", {})
		var kept: Array = []
		for h in bf.get("hypotheses", []):
			if h.get("correct", true):
				kept.append(h)
		bf["hypotheses"] = kept
	return d

## 从 wall 数据机械派生真相表（与手写版逐条等价）：
## clue 层 = 全部 hypotheses（含 correct:false 干扰）的 gate_clue_ids 并集；
## hypo 层 = 仅 correct:true；concl 层 = 全部 conclusions；
## person 层 = conclusions 的 target；边：clue→hypo / hypo→concl / concl→concl
## （gate_hypo_ids 中 "conclusion_" 前缀引用剥前缀）/ concl→person（kind=target）。
static func derive_truth(id: String) -> Dictionary:
	var ch: Dictionary = CHAINS.get(id, {})
	if ch.is_empty():
		return {}
	var bf: Dictionary = ch["wall"].get("battlefield", {})
	var nodes: Array = []
	var seen := {}
	for h in bf.get("hypotheses", []):
		for c in h.get("gate_clue_ids", []):
			if not seen.has(c):
				seen[c] = true
				nodes.append({"id": c, "layer": "clue"})
	for h in bf.get("hypotheses", []):
		if h.get("correct", false) and not seen.has(h["id"]):
			seen[h["id"]] = true
			nodes.append({"id": h["id"], "layer": "hypo"})
	for c in bf.get("conclusions", []):
		if not seen.has(c["id"]):
			seen[c["id"]] = true
			nodes.append({"id": c["id"], "layer": "concl"})
	var edges: Array = []
	for h in bf.get("hypotheses", []):
		if not h.get("correct", false):
			continue
		for c in h.get("gate_clue_ids", []):
			edges.append({"from": c, "to": h["id"], "kind": "support"})
	for c in bf.get("conclusions", []):
		for g in c.get("gate_hypo_ids", []):
			var src: String = g
			if src.begins_with("conclusion_"):
				src = src.substr("conclusion_".length())
			edges.append({"from": src, "to": c["id"], "kind": "support"})
	for c in bf.get("conclusions", []):
		var t: String = c.get("target", "")
		if t != "":
			if t.begins_with("person:") and not seen.has(t):
				seen[t] = true
				nodes.append({"id": t, "layer": "person"})
			edges.append({"from": c["id"], "to": t, "kind": "target"})
	return {
		"id": id, "name": ch.get("name", ""), "scene": ch.get("scene", ""),
		"core": ch.get("core", false), "practice": ch.get("practice", false),
		"nodes": nodes, "edges": edges, "misleads": ch.get("misleads", []),
	}

## 闭合自检：返回错误清单（空数组 = 通过）。建议导出前对全部链跑一遍。
## 校验项：边端点闭合、gate_clue_ids 引用可解析、conclusion_ 前缀指向本链结论、
## target 为 person: 前缀、练习/核心元数据齐全。
static func validate(id: String) -> Array:
	var errs: Array = []
	var t := derive_truth(id)
	if t.is_empty():
		return ["chain not found: " + id]
	var ids := {}
	for n in t["nodes"]:
		ids[n["id"]] = true
	var concl_ids := {}
	for n in t["nodes"]:
		if n["layer"] == "concl":
			concl_ids[n["id"]] = true
	for e in t["edges"]:
		if not ids.has(e["from"]):
			errs.append("%s: edge from 未定义 %s" % [id, e["from"]])
		if not ids.has(e["to"]):
			errs.append("%s: edge to 未定义 %s" % [id, e["to"]])
	var bf: Dictionary = CHAINS[id]["wall"].get("battlefield", {})
	for h in bf.get("hypotheses", []):
		for c in h.get("gate_clue_ids", []):
			if not ids.has(c):
				errs.append("%s: %s gate 线索未定义 %s" % [id, h["id"], c])
	for c in bf.get("conclusions", []):
		for g in c.get("gate_hypo_ids", []):
			if g.begins_with("conclusion_"):
				if not concl_ids.has(g.substr("conclusion_".length())):
					errs.append("%s: %s 引用结论不存在 %s" % [id, c["id"], g])
			elif not ids.has(g):
				errs.append("%s: %s gate 假设未定义 %s" % [id, c["id"], g])
		var t2: String = c.get("target", "")
		if t2 != "" and not t2.begins_with("person:"):
			errs.append("%s: %s target 非 person: %s" % [id, c["id"], t2])
	return errs

static func validate_all() -> Array:
	var errs: Array = []
	for id in CHAINS:
		errs.append_array(validate(id))
	return errs
