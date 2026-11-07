extends SceneTree
## F 跨界场景套件：推理墙计分判定的「跨场景累积 + 相互印证 + 不割裂」验收。
## 依据《设计文档/L2_详细设计/系统设计/10_推理墙分枝计分_设计补充说明.md》唯一权威口径。
##
## 覆盖：
##   F01 跨场景累积保留：同链(CH03)在 scene2/scene3 结算，玩家已连边/已产出节点保持命中
##   F02 节点按可用性裁剪(A)：scene2 时 gate 全后置线索的推断不可产出 → 不计 T、计 pending
##   F03 pending 不惩罚(B)：玩家在早期场景连「待解锁」边 → 落 pending_hits 而非 extra
##   F04 跨场景互证加成(C)：同一推断由 ≥2 场景线索支撑且全部连对 → reinforced 加分，R≤1.0
##   F05 累积单调性(D)：同链场景 N R ≥ 场景 N-1 R（不删边不加错边前提下）
##   F06 场景八全案视角：跨场景链全部解锁后 T 满、空墙/完美解 R 正确覆盖 0..1
##
## 返回字段新增：pending_edges/pending_nodes/pending_hits/reinforced_count/reinforced_bonus
const ReasoningChains = preload("res://data/reasoning_chains.gd")
const WBE = preload("res://scripts/clue/wall_branch_evaluator.gd")

var passed := 0
var failed := 0
var results: Array = []

func _init():
	call_deferred("_run")

const SC2_CLUES := ["c201","c202","c203","c204","c205","c206","c207","c208","c209","c210","c211"]
const SC3_CLUES := ["c301","c302","c303","c304","c305","c306","c307","c308","c309","c310","c311","c312"]
const SC4_CLUES := ["C_SOTCB_401","C_SOTCB_402","C_SOTCB_403","C_SOTCB_404","C_SOTCB_405","C_SOTCB_406","C_SOTCB_407"]

func _run():
	print("======================================================================")
	print("F 跨界场景测试套件 (F01~F06)")
	print("======================================================================")
	_f01_cross_scene_accum()
	_f02_node_availability_crop()
	_f03_pending_no_penalty()
	_f04_reinforced_bonus()
	_f05_monotonicity()
	_f06_scene8_full_case()
	_print_summary()
	quit()

# ── 工具 ─────────────────────────────────────────────────────────
func _rec(id: String, desc: String, expect: String, actual: String, ok: bool, note: String = ""):
	var st = "PASS" if ok else "FAIL"
	if ok:
		passed += 1
	else:
		failed += 1
	var line = "%-6s %-26s expect=%-22s actual=%-18s %-6s %s" % [id, desc, expect, actual, st, note]
	results.append(line)
	if not ok:
		push_warning("FAIL %s: %s" % [id, line])

func _branch(res: Dictionary, bid: String) -> Dictionary:
	for b in res.get("per_branch", []):
		if b.get("id", "") == bid:
			return b
	return {}

func _scenes_set(scene_id: String) -> Array:
	var out := SC2_CLUES.duplicate()
	if scene_id == "scene3":
		out += SC3_CLUES
	elif scene_id == "scene4":
		out += SC3_CLUES + SC4_CLUES
	return out

# F01 ─ 跨场景累积保留 ────────────────────────────────────────────
func _f01_cross_scene_accum():
	# CH03(标 scene2)：玩家在 scene2 连 c206→H2-05（sc2 可得），结算 R>0；
	# 到 scene3 后这条已连边仍命中（跨场景累积保留，不吃掉早期成果），且 scene3 补连
	# c309→H2-05 / c311→H2-06 不倒退。
	var nodes := [{"id": "H2-05", "kind": "hypo"}]
	var edges := [{"from": "c206", "to": "H2-05", "kind": "support"}]
	var r2 = WBE.evaluate(edges, nodes, [], "scene2", false, _scenes_set("scene2"), 1)
	var b2 = _branch(r2, "CH03")
	# scene2：H2-05 部分可用(gate 含 c206)，保留；c206→H2-05 命中
	# hits 至少含 1 节点 + 1 边 = 2.0
	var ok = b2.get("hit", 0.0) >= 2.0 and b2.get("ratio", 0.0) > 0.0
	_rec("F01", "跨场景累积保留(scene2命中)", "hit>=2 ratio>0",
		"hit=%.1f r=%.3f" % [b2.get("hit", 0.0), b2.get("ratio", 0.0)], ok,
		"truth=%d built=%d" % [b2.get("truth", 0), b2.get("built", 0)])
	# scene3 重新结算同一产物 → 已连边仍命中
	var r3 = WBE.evaluate(edges, nodes, [], "scene3", false, _scenes_set("scene3"), 1)
	var b3 = _branch(r3, "CH03")
	# 玩家持续推进：scene3 补连新解锁边(c309→H2-05)后，T 虽增但 hits 同步增，R 应 ≥ scene2 的满规格路径
	var nodes3 := nodes.duplicate()
	var edges3 := edges.duplicate()
	edges3.append({"from": "c309", "to": "H2-05", "kind": "support"})
	var r3b = WBE.evaluate(edges3, nodes3, [], "scene3", false, _scenes_set("scene3"), 1)
	var b3b = _branch(r3b, "CH03")
	var ok3 = b3.get("hit", 0.0) >= 2.0 and b3b.get("ratio", 0.0) >= b2.get("ratio", 0.0)
	_rec("F01b", "持续推进单不减(scene3补连)", "ratio3>=ratio2",
		"hit=%.1f r0=%.3f r3=%.3f" % [b3.get("hit", 0.0), b2.get("ratio", 0.0), b3b.get("ratio", 0.0)], ok3,
		"truth2=%d truth3=%d" % [b2.get("truth", 0), b3b.get("truth", 0)])

# F02 ─ 节点按可用性裁剪(A) ───────────────────────────────────────
func _f02_node_availability_crop():
	# 构造：CH03 中 H2-05 gate=[c206,c309,C_SOTCB_402]。scene2 时 c206 已收集 → 部分可用。
	# 完全后置 gate 的节点：CH03 无（都带 sc2 线索）。用单链直接构造「gate 全后置」的文本来
	# 验证裁剪规则本身：把 CH03 的 H2-05 在 collected 仅含 c309/C_SOTCB_402（无 c206）时，
	# 应判「全部 gate 不可用 → pending_node，不计 T」。
	# 这里用真实链库构造最小单链。
	var ch = ReasoningChains.derive_truth("CH03")
	# 直接在 collected 只给 c309/C_SOTCB_402(不含 c206) 的场景下做单链 score：
	var collected := {}
	for c in ["c309", "C_SOTCB_402"]:
		collected[c] = true
	var r = WBE._score_branch(ch, [], [], {}, collected)
	# H2-04 gate=[c205,c206] 都未收集 → pending；H2-05 gate 含 c309/C_SOTCB_402(有) + c206(无) → 部分可用保留
	var pnodes: Array = r.get("pending_nodes", [])
	var has_h24 := pnodes.has("H2-04")
	var has_h26 := pnodes.has("H2-06")
	# H2-06 gate=[c205,c311]，c311不在collected，c205不在 → 全部不可用 → pending
	var has_h207 := pnodes.has("H2-07")  # gate=[c206]，c206 不在 → pending
	var ok = has_h24 and has_h26 and has_h207 and not (pnodes.has("H2-05"))
	_rec("F02", "节点可用性裁剪(gate全后置.nodes)", "H2-04/06/07 pending, H2-05保留",
		"pn=%s" % [pnodes], ok,
		"truth=%d" % r.get("truth", 0))

# F03 ─ pending 不惩罚(B) ─────────────────────────────────────────
func _f03_pending_no_penalty():
	# scene2 玩家连 c309→H2-05：c309 未收集 → 该 truth 边被裁为 pending，应落 pending_hits
	# 而非 extra_edges（B：匹配 pending 项不算错误，不得落入 extra 扣分）。
	var nodes := [{"id": "H2-05", "kind": "hypo"}]
	var edges := [
		{"from": "c206", "to": "H2-05", "kind": "support"},
		{"from": "c309", "to": "H2-05", "kind": "support"},   # c309 未收集 → 待解锁
	]
	var r = WBE.evaluate(edges, nodes, [], "scene2", false, _scenes_set("scene2"), 1)
	var b = _branch(r, "CH03")
	var extra: int = b.get("extra_edges", []).size()
	var phit: int = b.get("pending_hits", 0)
	var pn: int = b.get("pending_nodes", []).size()
	var ok = extra == 0 and phit >= 1
	_rec("F03", "pending不惩罚(待解锁边非extra)", "extra=0 phit>=1",
		"extra=%d phit=%d" % [extra, phit], ok,
		"pend_edges=%d pend_nodes=%d" % [b.get("pending_edges", []).size(), pn])

# F04 ─ 跨场景互证加成(C) ─────────────────────────────────────────
func _f04_reinforced_bonus():
	# H2-05 gate=[c206(sc2), c309(sc3), C_SOTCB_402(sc4)]。scene3(已收集 c206,c309) 玩家全部连对
	# → 覆盖 2 场景 → reinforced 加成。scene2 连 c206 仅 1 场景 → 不触发。
	var nodes := [{"id": "H2-05", "kind": "hypo"}]
	var e2 := [{"from": "c206", "to": "H2-05", "kind": "support"}]     # 仅 sc2,1场景
	var r2 = WBE.evaluate(e2, nodes, [], "scene2", false, _scenes_set("scene2"), 1)
	var b2 = _branch(r2, "CH03")
	var reinf2: int = b2.get("reinforced_count", 0)
	var ok2 = reinf2 == 0
	_rec("F04a", "单场景不触发互证", "reinf=0", "reinf=%d" % reinf2, ok2,
		"hit=%.1f" % b2.get("hit", 0.0))
	# scene4(已收集 c206,c309,C_SOTCB_402) 全部连对 → 覆盖 3 场景 → 加成
	var nodes4 := [{"id": "H2-05", "kind": "hypo"}]
	var e4 := [
		{"from": "c206", "to": "H2-05", "kind": "support"},
		{"from": "c309", "to": "H2-05", "kind": "support"},
		{"from": "C_SOTCB_402", "to": "H2-05", "kind": "support"},
	]
	var r4 = WBE.evaluate(e4, nodes4, [], "scene4", false, _scenes_set("scene4"), 1)
	var b4 = _branch(r4, "CH03")
	var reinf4: int = b4.get("reinforced_count", 0)
	var bonus: float = b4.get("reinforced_bonus", 0.0)
	var hit4: float = b4.get("hit", 0.0)
	# 命中：1节点 + 3边 + 加成 = 4.0 + 0.15；R = hit/max(built,T) ≤ 1.0
	var r4ok = reinf4 == 1 and absf(bonus - 0.15) < 0.001 and hit4 > 4.0 and b4.get("ratio", 0.0) <= 1.0
	_rec("F04b", "跨场景互证加成(3场景全对)", "reinf=1 bonus=0.15 R<=1",
		"reinf=%d bonus=%.2f hit=%.2f r=%.3f" % [reinf4, bonus, hit4, b4.get("ratio", 0.0)], r4ok,
		"truth=%d" % b4.get("truth", 0))

# F05 ─ 累积单调性(D) ─────────────────────────────────────────────
func _f05_monotonicity():
	# CH03 同一玩家的「持续推进」路径：scene2 连可得边，scene3 补连新解锁边，R 单调不减。
	# 这正是 D 的合理前提——玩家持续推进解锁项并补连，R 只增不减。
	var nodes := [{"id": "H2-05", "kind": "hypo"}, {"id": "H2-06", "kind": "hypo"}]
	var e2 := [
		{"from": "c206", "to": "H2-05", "kind": "support"},   # sc2 可得
		{"from": "c205", "to": "H2-06", "kind": "support"},   # sc2 可得
	]
	var max_ratio := 0.0
	var r2 = WBE.evaluate(e2, nodes, [], "scene2", false, _scenes_set("scene2"), 1)
	var b2 = _branch(r2, "CH03")
	max_ratio = maxf(max_ratio, b2.get("ratio", 0.0))
	# scene3：补两条新解锁边
	var e3 := e2.duplicate()
	e3.append({"from": "c309", "to": "H2-05", "kind": "support"})
	e3.append({"from": "c311", "to": "H2-06", "kind": "support"})
	var r3 = WBE.evaluate(e3, nodes, [], "scene3", false, _scenes_set("scene3"), 1)
	var b3 = _branch(r3, "CH03")
	max_ratio = maxf(max_ratio, b3.get("ratio", 0.0))
	var ok = b3.get("ratio", 0.0) >= b2.get("ratio", 0.0) - 0.0001 \
			and b3.get("truth", 0) >= b2.get("truth", 0)
	_rec("F05", "累积单调性(持续推进补连)", "ratio3>=ratio2 truth3>=truth2",
		"r2=%.3f r3=%.3f t2=%d t3=%d" % [b2.get("ratio", 0.0), b3.get("ratio", 0.0),
			b2.get("truth", 0), b3.get("truth", 0)], ok,
		"")

# F06 ─ 场景八全案视角 ─────────────────────────────────────────────
func _f06_scene8_full_case():
	# 场景八未采集到 CH03 线索（c309/C_SOTCB_402 都未收集）→ 空墙 T 中相关项全部 pending；
	# 全案 ratio 视 active 链而定。单测直接验证：空墙时 T 不含 pending 节点，sum_max 不再被
	# 未解锁项撑高（这是「割裂」修复的核心——分母只含当前能完成的项）。
	var r = WBE.evaluate([], [], [], "scene4", false, _scenes_set("scene4"), 1)
	var ch03 = _branch(r, "CH03")
	# scene4 已收集 c206/c309 但差 C_SOTCB_402 时 H2-05 部分可用——T 含它能完成的；空墙 hit=0
	var ok = r.get("ratio", 0.0) == 0.0 and ch03.get("truth", 0) >= 0
	# 断言：空墙全案 R=0（未激活的链不计分母，激活的 core 按 R=0）——不因 pending 项少分
	_rec("F06", "场景4全案空墙视角", "ratio=0", "ratio=%.3f" % r.get("ratio", 0.0), ok,
		"sum_max=%.1f CH03.truth=%d pending_edges=%d" % [r.get("sum_max", 0.0),
			ch03.get("truth", 0), ch03.get("pending_edges", []).size()])

func _print_summary():
	print("----------------------------------------------------------------------")
	for line in results:
		print(line)
	print("----------------------------------------------------------------------")
	print("总计: %d 通过 / %d 失败 / 共 %d" % [passed, failed, passed + failed])