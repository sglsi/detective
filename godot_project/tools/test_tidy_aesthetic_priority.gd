extends SceneTree
## 整洁树美学为纲（2026-09-21 思傅定案「不能因小失大」）回归锁定：
##   旧病：_compute_layout 有钉位时把所有未钉节点冻结在拖前/读档历史位（prev_center），
##        关系树变了布局不变 → 「布局服从于各卡片的位置关系，不是服从于树的美学关系」
##        （图1 带间组配错乱 / 图2 散乱皆源于此累积）。
##   修复：删除 prev_center 冻结。凡重排：
##     T1 未钉节点 = 纯整洁树位（与同一场景的无钉位参考布局逐点一致，美学1~5 完全由关系决定）；
##     T2 玩家钉位子树 = 整棵按锚点 delta 刚性平移（树内相对结构不变，玩家补充不破坏树形）；
##     T3 未钉树带互不交错（整洁森林带状堆叠）。
##   拓扑：纯无根森林 3 链（结论→推断→双线索，全 support），仅链3 根 TC2 被玩家拖动钉位。
##   同一场景算两次：① 干净态参考（纯整洁树位）② 注入 stale 脏位 + 仅 TC2 钉位。

var _ok := true

func _chk(cond: bool, msg: String) -> void:
	if cond:
		print("PASS " + msg)
	else:
		_ok = false
		print("FAIL " + msg)


func _build_scene(prefix: String) -> Dictionary:
	var KIND := {}
	var LABEL := {}
	var REL := []
	for i in 3:
		var c := "%sC%d" % [prefix, i]
		var h := "%sH%d" % [prefix, i]
		KIND[c] = "conclusion"
		LABEL[c] = "链%d结论：围绕现场事实的第一层结论文本" % i
		KIND[h] = "hypo"
		LABEL[h] = "链%d推断：由该结论推出的第二层推断文本" % i
		REL.append({"from": h, "to": c, "kind": "support"})
		for j in 2:
			var l := "%sL%d_%d" % [prefix, i, j]
			KIND[l] = "clue"
			LABEL[l] = "链%d线索%d：支撑该推断的现场痕迹描述" % [i, j]
			REL.append({"from": l, "to": h, "kind": "support"})
	return {"KIND": KIND, "LABEL": LABEL, "REL": REL}


func _setup_gv(gv, scene: Dictionary) -> Array:
	gv._graph_nodes = []
	for id in scene["KIND"]:
		gv._graph_nodes.append({"id": id, "kind": scene["KIND"][id], "label": scene["LABEL"][id], "sub": "", "data": {}})
	gv._relations = scene["REL"].duplicate()
	var nodes := []
	for id in scene["KIND"]:
		nodes.append({"id": id, "kind": scene["KIND"][id], "label": scene["LABEL"][id]})
	return nodes


func _new_gv(GV, canvas: Control, prefix: String) -> Dictionary:
	var gv = GV.new()
	var holder := Control.new()
	root.add_child(holder)
	holder.add_child(gv)
	await process_frame
	gv._canvas = canvas
	gv._mode = GV.ViewMode.MODE_C
	var scene := _build_scene(prefix)
	var nodes := _setup_gv(gv, scene)
	gv._root_anchor_pos = {}
	gv._manual_nodes = []
	gv._node_center = {}
	gv._layout._relayout_on_edge = false
	return {"gv": gv, "nodes": nodes, "KIND": scene["KIND"], "LABEL": scene["LABEL"]}


func _initialize() -> void:
	await process_frame
	var GV = load("res://scripts/clue/graph_view_controller.gd")
	if GV == null:
		print("FAIL 无法加载 graph_view_controller.gd")
		quit()
		return
	var canvas := Control.new()
	canvas.size = Vector2(1920.0, 1080.0)

	var d: Dictionary = await _new_gv(GV, canvas, "T")
	var gv = d["gv"]
	var nodes: Array = d["nodes"]
	var KIND: Dictionary = d["KIND"]
	var LABEL: Dictionary = d["LABEL"]

	# ---- 参考：同一场景干净态（无 stale / 无钉位）→ 纯整洁树位 ----
	gv._node_center = {}
	gv._root_anchor_pos = {}
	gv._manual_nodes = []
	var out_ref: Dictionary = gv._layout._compute_layout(nodes, {})

	# ---- 现场：注入散乱 stale 历史位（仅未钉节点）+ 仅 TC2 被玩家拖动钉位 + 非边重排（旧冻结路径）----
	# 钉位子树（TC2 及其后代）不设 stale：模拟「刚被拖走、无历史脏位」的真实拖拽场景。
	var stale := {}
	var pinned_subtree := ["TC2", "TH2", "TL2_0", "TL2_1"]
	var ids: Array = KIND.keys()
	ids.sort()
	for k in ids.size():
		var nid: String = ids[k]
		if nid in pinned_subtree:
			continue
		stale[nid] = Vector2(1500.0 + (k % 3) * 130.0, 120.0 + k * 61.0)
	gv._node_center = stale
	var anchor := Vector2(420.0, 880.0)
	gv._root_anchor_pos = {"TC2": anchor}
	gv._manual_nodes = ["TC2"]
	gv._layout._relayout_on_edge = false
	var out: Dictionary = gv._layout._compute_layout(nodes, {})

	# T1 未钉节点 = 纯整洁树位（逐点等于参考布局，禁止冻结在历史位）
	# 注意：钉位根 TC2 的整棵子树（TH2/TL2_0/TL2_1）应随锚点刚性平移、不与参考一致，故跳过。
	# T1（R3 修订）：未钉节点必须按**整洁树重排**（而非冻结在 stale 位）。
	# R3 组件装箱会把未钉分量**整块刚性平移**（为避让钉住的块），
	# 故不再要求绝对坐标逐点一致，而是要求「所有未钉节点相对参考位的偏移量 = 同一个向量」
	# （即形状完全一致，只差一个整体平移）。若有节点被冻结在 stale 位，它的偏移量会与其余不同 ⇒ 仍会报错。
	var deltas: Array = []
	var names: Array = []
	for id in out_ref:
		if id in pinned_subtree:
			continue
		if not out.has(id):
			names.append("%s(MISSING)" % id)
			continue
		deltas.append(out[id] - out_ref[id])
		names.append(str(id))
	var frozen := []
	if deltas.is_empty():
		frozen.append("无可比节点")
	else:
		var base: Vector2 = deltas[0]
		for i in deltas.size():
			if (Vector2(deltas[i]) - base).length() > 0.5:
				frozen.append("%s(偏移%s ≠ 基准%s)" % [names[i], str(deltas[i]), str(base)])
	for n in names:
		if str(n).ends_with("(MISSING)"):
			frozen.append(str(n))
	_chk(frozen.is_empty(), "T1 未钉节点全部取纯整洁树位（与无钉位参考只差一个整体刚性平移；未冻结在 stale 位）"
		+ ("" if frozen.is_empty() else "；仍冻结：" + ", ".join(frozen.slice(0, 6))))

	# T2 钉位根停在锚点，其子树刚性平移（树内相对结构不变）
	_chk(out["TC2"].distance_to(anchor) < 0.5, "T2a 钉位根 TC2 停在玩家锚点 (%.0f,%.0f)" % [anchor.x, anchor.y])
	var rigid := true
	for c in ["TH2", "TL2_0", "TL2_1"]:
		if not out.has(c) or not out_ref.has(c):
			rigid = false
			break
		if (out[c] - out["TC2"]).distance_to(out_ref[c] - out_ref["TC2"]) > 0.5:
			rigid = false
	_chk(rigid, "T2b 钉位子树整棵刚性平移（相对根偏移与参考一致，树形不被破坏）")

	# T3 未钉的两棵树带互不交错（整洁森林带状堆叠，图1 交错禁令）
	# 稳健判定：树0 全部节点最大 y < 树1 全部节点最小 y（严格垂直分离，不依赖固定高度近似）
	var t0 := ["TC0", "TH0", "TL0_0", "TL0_1"]
	var t1 := ["TC1", "TH1", "TL1_0", "TL1_1"]
	var max0: float = -1e18
	var min1: float = 1e18
	for id in t0:
		max0 = maxf(max0, out[id].y)
	for id in t1:
		min1 = minf(min1, out[id].y)
	_chk(max0 < min1, "T3 未钉树带互不交错（树0 最大 y %.0f < 树1 最小 y %.0f）" % [max0, min1])

	if _ok:
		print("TIDY_PRIORITY_RESULT: PASS — 整洁树美学为纲语义验证通过")
	else:
		print("TIDY_PRIORITY_RESULT: FAIL")
	quit()
