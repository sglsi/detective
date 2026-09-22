extends SceneTree
## P3 钉位三档回归（2026-09-22 · 思傅定案三档）
##   free   ：无钉位 → 完全由规则决定
##   semi   ：软约束「顺序意图」→ 落点只决定兄弟先后；x 由深度写死、y 由规则决定
##            （断言点：顺序被尊重、x 不变、落点 y 不被采用、五律/零重叠全保）
##   pinned ：硬锚点 → 真根所在整棵子树刚性平移（断言点：根精确落锚点、子树相对形状不变）
var _ok := true
func _chk(c: bool, m: String) -> void:
	if c: print("PASS " + m)
	else:
		_ok = false
		print("FAIL " + m)

func _clear(gv, canvas) -> void:
	for ch in canvas.get_children(): ch.queue_free()
	gv._node_views = {}; gv._node_center = {}; gv._node_kind = {}; gv._node_data = {}
	gv._relations = []; gv._root_anchor_pos = {}; gv._manual_nodes = []
	gv._pin_order_hints = {}
	gv._balanced_layout = false; gv._use_rank_layout = false; gv._state_store = {}
	gv._layout._row_step_scale = 1.0
	gv._layout._relayout_on_edge = false

func _build(gv, canvas, nodes: Array) -> void:
	for nd in nodes:
		gv._node_kind[nd.id] = nd.kind; gv._node_data[nd.id] = {}
		var v = gv._cards.make_node(nd); canvas.add_child(v); gv._node_views[nd.id] = v

func _layout(gv, nodes: Array, pre: Dictionary) -> Dictionary:
	var out: Dictionary = gv._layout._compute_layout(nodes, pre)
	gv._node_center = out.duplicate()
	gv._layout._apply_global_overlap_fix()
	if gv._layout._has_overlap():
		out = gv._layout._resolve_residual_overlaps(nodes, {})
		gv._node_center = out.duplicate()
	return gv._node_center

func _initialize() -> void:
	await process_frame
	var GV = load("res://scripts/clue/graph_view_controller.gd")
	var gv = GV.new()
	var holder := Control.new(); holder.size = Vector2(1920, 1080); root.add_child(holder); holder.add_child(gv)
	await process_frame
	var canvas := Control.new(); canvas.size = Vector2(1920, 1080); holder.add_child(canvas); gv._canvas = canvas
	gv._mode = GV.ViewMode.MODE_C

	# 拓扑：结论 A（根）+ 三个推断 H1/H2/H3（同层兄弟，支持边 from=子）
	var SPEC := [["A", "conclusion", "结论"], ["H1", "hypo", "推断一"],
		["H2", "hypo", "推断二"], ["H3", "hypo", "推断三"]]
	var nodes := []
	for s in SPEC: nodes.append({"id": s[0], "kind": s[1], "label": s[2], "sub": "", "data": {}})
	var REL := [
		{"from": "H1", "to": "A", "kind": "support"},
		{"from": "H2", "to": "A", "kind": "support"},
		{"from": "H3", "to": "A", "kind": "support"},
	]
	_clear(gv, canvas); await _build(gv, canvas, nodes)
	gv._relations = REL.duplicate()
	await process_frame

	# ---------- ① free：无钉位 ----------
	var o1: Dictionary = _layout(gv, nodes, {})
	print("== ① free ==")
	for id in ["A", "H1", "H2", "H3"]:
		print("  %-3s x=%7.1f y=%7.1f" % [id, o1[id].x, o1[id].y])
	_chk(o1["H1"].y < o1["H2"].y and o1["H2"].y < o1["H3"].y, "free：兄弟按既有顺序 H1→H2→H3")
	_chk(absf(o1["H1"].x - o1["H2"].x) < 1.0 and absf(o1["H2"].x - o1["H3"].x) < 1.0, "free：三兄弟同列（同层共线）")
	_chk(absf(o1["A"].y - (o1["H1"].y + o1["H3"].y) * 0.5) < 1.0, "free：父居中于子群")
	var rel_y1: float = o1["H1"].y - o1["A"].y
	var rel_x1: float = o1["H1"].x - o1["A"].x
	_chk(gv.pin_tier_of("H1") == "free", "① 档位判定：free")

	# ---------- ② semi：把 H3 拖到 H1 上方（顺序意图） ----------
	var drop := Vector2(o1["H3"].x, o1["H1"].y - 480.0)
	gv._pin_order_hints["H3"] = drop
	var o2: Dictionary = _layout(gv, nodes, o1.duplicate())
	print("== ② semi（H3 落点 y=%.0f，在 H1 上方一行） ==" % drop.y)
	for id in ["A", "H1", "H2", "H3"]:
		print("  %-3s x=%7.1f y=%7.1f" % [id, o2[id].x, o2[id].y])
	_chk(o2["H3"].y < o2["H1"].y and o2["H1"].y < o2["H2"].y, "semi：顺序意图生效（H3 排到最上）")
	_chk(absf(o2["H3"].x - o2["H1"].x) < 1.0, "semi：x 由深度写死（H3 仍在兄弟列）")
	_chk(absf(o2["H3"].y - drop.y) > 1.0, "semi：落点 y 未被采用（不是硬钉位；y 由规则决定）")
	_chk(absf(o2["A"].y - (o2["H3"].y + o2["H2"].y) * 0.5) < 1.0, "semi：父仍居中于新子群（A3 保）")
	var viol2: Array = gv._layout.check_invariants()
	_chk(viol2.is_empty(), "semi：五律不变量合规%s" % ("" if viol2.is_empty() else "；" + str(viol2)))
	_chk(not gv._layout._has_overlap(), "semi：零重叠")
	_chk(gv.pin_tier_of("H3") == "semi", "② 档位判定：semi")

	# ---------- ③ 拖动端档位规则：树内节点 = semi，真根 = pinned ----------
	_chk(gv._dropped_tier("H3") == "semi", "拖动规则：树内节点（有父）→ semi（顺序意图）")
	_chk(gv._dropped_tier("A") == "pinned", "拖动规则：真根（无父）→ pinned（硬锚点）")

	# ---------- ④ pinned：真根硬锚点，整棵子树刚性平移 ----------
	gv._pin_order_hints = {}
	gv._root_anchor_pos = {"A": Vector2(900.0, 500.0)}
	gv._manual_nodes = ["A"]
	var o3: Dictionary = _layout(gv, nodes, {})
	print("== ④ pinned（A 锚点 900,500） ==")
	for id in ["A", "H1", "H2", "H3"]:
		print("  %-3s x=%7.1f y=%7.1f" % [id, o3[id].x, o3[id].y])
	_chk(absf(o3["A"].x - 900.0) < 1.0 and absf(o3["A"].y - 500.0) < 1.0, "pinned：真根精确落在锚点")
	_chk(absf((o3["H1"].y - o3["A"].y) - rel_y1) < 1.0, "pinned：子树相对 y 形状不变（刚性平移）")
	_chk(absf((o3["H1"].x - o3["A"].x) - rel_x1) < 1.0, "pinned：子树相对 x 形状不变")
	_chk(gv.pin_tier_of("A") == "pinned", "④ 档位判定：pinned")
	var viol3: Array = gv._layout.check_invariants()
	_chk(viol3.is_empty(), "pinned：不变量合规%s" % ("" if viol3.is_empty() else "；" + str(viol3)))

	print("PIN_TIERS_REPRO: " + ("PASS" if _ok else "FAIL"))
	quit()
