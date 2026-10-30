extends SceneTree
## t_phase0_baseline.gd — Phase 0.1 基线探针：「真相边按已收集线索裁剪」前后对比。
##
## 背景：跨场景链（如 CH03 标在 scene2，真相含场景三/四线索 c309/c311/C_SOTCB_402）
## 在早期场景结算时这些线索还没收集、物理上连不出来，旧口径把它们的边计进 T，
## 该链 R 有结构性上限（CH03@scene2 = 14/17 ≈ 0.824，与 VERIFIED 阈值 0.80 踩线）。
## Phase 0.1 修复：evaluate() 新增 collected_ids 参数，真相边两端涉及「本墙未收集线索」
## 时从 T 与 missing_edges 剔除（记入 unavailable_edges）；collected 为空 = 旧行为不裁剪。
##
## 用法：GODOT --headless --path . -s res://tools/t_phase0_baseline.gd
## 输出纯文本行，修改前后各跑一次、diff 即回归：
##   CASE_A legacy_noop — collected 为空（旧行为），完美解逐链 ratio 恒 1.0，前后必须零差异
##   CASE_B trim_noop   — collected=全量线索，裁剪不生效，与 CASE_A 同值，前后零差异
##   CASE_C scene2_trim — 场景二缺三枚后置线索（已知缺陷实证）：
##                        修复前 CH03 ratio ≈0.824 / 全案 ≈0.912；修复后必须 1.0 且 unavailable=3
##   CHECK own_scene    — 各链「本场景线索必可用」不变式（裁剪永不阻断链自身场景的线索）

const Evaluator := preload("res://scripts/clue/wall_branch_evaluator.gd")
const Truth := preload("res://data/case_branch_truth.gd")

const SCENES := ["scene1", "scene2", "scene3", "scene4", "scene5", "scene6", "scene7", "scene8"]
## 已知跨场景链后置线索（缺陷实证用，来源：12 号设计文档 §断点6 + AGENTS.md）
const LATE_CLUES_AT_SCENE2 := ["c309", "c311", "C_SOTCB_402"]


func _init() -> void:
	_case_a_legacy_noop()
	_case_b_trim_noop()
	_case_c_scene2_trim()
	_check_own_scene_clues()
	quit()


func _scene_idx(s: String) -> int:
	return SCENES.find(s)


## 场景 N 时已收集线索 = 前缀场景所有链的 clue 节点并集
## （每条链必列本场景线索；跨场景链的后置线索同时出现在其归属场景的链里，故按链 home 场景入集）。
func _collected_up_to(n: int) -> Dictionary:
	var out := {}
	for b in Truth.branches():
		var si := _scene_idx(str(b.get("scene", "")))
		if si < 0 or si > n:
			continue
		for cid in _clue_ids_of(b):
			out[cid] = true
	return out


func _clue_ids_of(b: Dictionary) -> Array:
	var out := {}
	for nd in b.get("nodes", []):
		if str(nd.get("layer", "")) == "clue":
			out[norm(str(nd.get("id", "")))] = true
	return out.keys()


func _scope_for(scene_id: String, practice: bool) -> Array:
	var allowed := Evaluator._allowed_scenes(scene_id)
	var out: Array = []
	for b in Truth.branches():
		if not allowed.has(str(b.get("scene", ""))):
			continue
		if bool(b.get("practice", false)) and not practice:
			continue
		out.append(b)
	return out


## 完美解合成玩家产物：真相节点（hypo/concl）+ 可建真相边（两端线索均已收集才建得出来）
func _synth_work(scope: Array, collected: Dictionary) -> Dictionary:
	var relations: Array = []
	var graph_nodes: Array = []
	var derived: Array = []
	for b in scope:
		for nd in b.get("nodes", []):
			var layer := str(nd.get("layer", ""))
			var nid := norm(str(nd.get("id", "")))
			if layer == "hypo":
				graph_nodes.append({"id": nid, "kind": "hypo"})
			elif layer == "concl":
				derived.append({"id": nid, "text": ""})
		for e in b.get("edges", []):
			var ef := norm(str(e.get("from", "")))
			var et := norm(str(e.get("to", "")))
			if _blocked(ef, et, b, collected):
				continue
			relations.append({"from": ef, "to": et, "kind": str(e.get("kind", "support"))})
	return {"relations": relations, "graph_nodes": graph_nodes, "derived": derived}


func _blocked(ef: String, et: String, b: Dictionary, collected: Dictionary) -> bool:
	if collected.is_empty():
		return false
	var clue_ids := {}
	for nd in b.get("nodes", []):
		if str(nd.get("layer", "")) == "clue":
			clue_ids[norm(str(nd.get("id", "")))] = true
	if clue_ids.has(ef) and not collected.has(ef):
		return true
	if clue_ids.has(et) and not collected.has(et):
		return true
	return false


func norm(nid: String) -> String:
	return Evaluator.norm(nid)


func _dump_case(tag: String, scene_id: String, collected_ids: Array, collected_for_work: Dictionary) -> void:
	var scope := _scope_for(scene_id, false)
	var work := _synth_work(scope, collected_for_work)
	var res := Evaluator.evaluate(work["relations"], work["graph_nodes"], work["derived"],
			scene_id, false, collected_ids)
	var pb: Array = res.get("per_branch", [])
	for b in pb:
		print("%s scene=%s chain=%s core=%s truth=%d built=%d hit=%.1f ratio=%.4f unavailable=%d"
				% [tag, scene_id, str(b.get("id", "")), str(b.get("core", false)),
				int(b.get("truth", 0)), int(b.get("built", 0)), float(b.get("hit", 0.0)),
				float(b.get("ratio", 0.0)), int(b.get("unavailable_edges", []).size())])
	print("%s scene=%s OVERALL ratio=%.4f verdict=%d"
			% [tag, scene_id, float(res.get("ratio", 0.0)), int(res.get("verdict", -1))])


func _case_a_legacy_noop() -> void:
	for i in range(1, SCENES.size()):
		_dump_case("CASE_A", SCENES[i], [], {})


func _case_b_trim_noop() -> void:
	# 场景二：collected=全量线索 → 裁剪不生效
	var scene_id := "scene2"
	var scope := _scope_for(scene_id, false)
	var all_clues := {}
	for b in scope:
		for cid in _clue_ids_of(b):
			all_clues[cid] = true
	var ids: Array = all_clues.keys()
	_dump_case("CASE_B", scene_id, ids, all_clues)


func _case_c_scene2_trim() -> void:
	var scene_id := "scene2"
	var scope := _scope_for(scene_id, false)
	var all_clues := {}
	for b in scope:
		for cid in _clue_ids_of(b):
			all_clues[cid] = true
	for late in LATE_CLUES_AT_SCENE2:
		all_clues.erase(norm(late))
	var ids: Array = all_clues.keys()
	_dump_case("CASE_C", scene_id, ids, all_clues)


## 不变式：任一链「本场景及之前」的线索必可用——裁剪永不阻断链自身场景的线索。
func _check_own_scene_clues() -> void:
	var ok := true
	for b in Truth.branches():
		var si := _scene_idx(str(b.get("scene", "")))
		if si < 0:
			continue
		var collected := _collected_up_to(si)
		for cid in _clue_ids_of(b):
			if not collected.has(cid):
				print("CHECK_own_scene FAIL scene=%s chain=%s clue=%s" % [str(b.get("scene", "")), str(b.get("id", "")), cid])
				ok = false
	if ok:
		print("CHECK_own_scene PASS")
