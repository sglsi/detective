extends RefCounted
class_name GraphViewDerive

## 图谱视图 · 正向推导子系统（拆自 graph_view_controller.gd 的「正向推导：线索→推断→结论」段）
## 职责：从线索推导推断(_derive_hypo/_derive_hypo_custom)、推断推导推断(_derive_hypo_from_hypo)、
## 自定义/预设结论(_derive_conclusion_custom/_derive_conclusion)、统一落节点建边(add_derived_conclusion)。
## 全部状态/共享助手(_hypo_def/_conclusion_def/_conclusion_node_id/_sync_conclusion_gate_edges 等)经 owner. 回读。

var owner: GraphViewController

func derive_hypo(cid: String, hid: String) -> void:
	if owner._state != owner.State.EDITABLE:
		owner._ui_toast("推理墙已封存，仅可浏览")
		return
	var hd := owner._hypo_def(hid)
	if hd.is_empty():
		owner._ui_toast("未找到推断定义：" + hid)
		return
	owner.adopt_candidate(hd, false, cid)   # 正向推导：不自动连带该推断的其他 gate 线索（玩家逐个拖线索驱动）；锚定到来源线索 cid 落点防叠加
	# 玩家从线索推导推断＝明确选择「线索→推断」支撑关系，绘制该 support 绿边（属玩家连线，非系统自动）。
	# 仅补「本条推导」的边；其余 gate 线索→该推断的边由玩家按需手动建立（owner._sync_conclusion_gate_edges 已停用）。
	if not owner.any_edge(cid, hid) and not owner._relations.any(func(r): return r.get("from", "") == cid and r.get("to", "") == hid):
		owner._edge._add_edge(cid, hid, "support", "green", false)
	owner._layout_seed = int(Time.get_ticks_msec()) + owner._graph_nodes.size()
	owner._persist_view()
	owner._rebuild_graph()
	owner._focus_on(hid)
	if not owner._teaching:
		owner._sync_conclusion_gate_edges()   # 新推断上墙后，相关结论（gate 含此推断）自动补边，结论链随推导逐步闭合（教学墙由玩家手动建立，不自动补）
	# 正向推导：选推断后若场景有任意「按难度可见」的预设结论，自动弹结论候选窗（列出全部候选，玩家任选其一）
	var _cons: Array = owner._hypo_current.get("conclusions", [])
	var _has_cand: bool = false
	for _c in _cons:
		if owner._dockctl._conclusion_preset_visible(_c):
			_has_cand = true
			break
	if _has_cand:
		owner.call_deferred("_open_conclusion_choice", hid)


## 困难模式：拖线索 → 玩家手写推断（自由文本），生成「推断」文本框并把线索连到它。
## 生成的节点 id 形如 note_hypo_N（与顶栏「添文本框」同构，困难模式评价引擎按 kind=hypo + text 计入）。
## 建边方向 = from=线索(子/前提) → to=推断(父/结论方向)，绿实线 support，与其余推导路径一致。
## 落尾自动打开「自定义结论」输入窗（可取消），把 线索→推断→结论 三步串成一条顺滑链路。
func derive_hypo_custom(cid: String, text: String) -> void:
	if owner._state != owner.State.EDITABLE:
		owner._ui_toast("推理墙已封存，仅可浏览")
		return
	var t2 := text.strip_edges()
	if t2 == "":
		owner._ui_toast("推断内容不能为空")
		return
	var seq: int = 0
	var nid: String = ""
	while true:
		nid = "note_hypo_%d" % seq
		var _dup: bool = owner._node_center.has(nid) or owner._graph_nodes.any(func(n): return str(n.get("id", "")) == nid)
		if not _dup:
			break
		seq += 1
	owner._graph_nodes.append({"id": nid, "kind": "hypo", "label": t2, "sub": "推断",
		"data": {"correct": true, "player_made": true}})
	# 锚定到来源线索落点，螺旋碰撞检测避免与现有节点叠加
	var base: Vector2 = owner._node_center.get(cid, owner._canvas.size * 0.5)
	var pos: Vector2 = owner._layout._find_non_overlapping_position(base, nid, "hypo", owner._node_center)
	owner._node_center[nid] = pos
	var nps: Dictionary = owner._state_store.get("graph_node_positions", {})
	nps[nid] = pos
	owner._state_store["graph_node_positions"] = nps
	# 线索→推断 绿 support 边（属玩家「拖线索推导」的明确连线）
	if cid != "" and not owner.any_edge(cid, nid) and not owner._relations.any(func(r): return r.get("from", "") == cid and r.get("to", "") == nid):
		owner._edge._add_edge(cid, nid, "support", "green", false)
	owner._layout_seed = int(Time.get_ticks_msec()) + owner._graph_nodes.size()
	owner._persist_view()
	owner._rebuild_graph()
	owner._focus_on(nid)
	# 续接结论：困难模式无预设结论候选，直接开「自定义结论」输入窗（玩家可取消）
	if owner._dockctl != null:
		owner._dockctl.call_deferred("_open_custom_conclusion_popup", nid)


## 拖推断推导推断（方案B：推断可由多个推断/结论组合推得，如 W-C1+W-C2→W-C3）
## 生成下一层推断节点 + 绿 support 边（源推断→目标推断）；已存在节点则只补边。
func derive_hypo_from_hypo(src_hid: String, dst_hid: String) -> void:
	if owner._state != owner.State.EDITABLE:
		owner._ui_toast("推理墙已封存，仅可浏览")
		return
	var hd: Dictionary = owner._hypo_def(dst_hid)
	if hd.is_empty():
		owner._ui_toast("未找到推断定义：" + dst_hid)
		return
	# 校验：源推断必须是目标推断的 gate 之一（避免随意连）
	var _gates: Array = hd.get("gate_hypo_ids", [])
	if not (src_hid in _gates):
		owner._ui_toast("该推断不能由当前组合推导")
		return
	owner.adopt_candidate(hd, false, src_hid)   # 锚定到源推断落点防叠加
	if not owner.any_edge(src_hid, dst_hid) and not owner._relations.any(func(r): return r.get("from", "") == src_hid and r.get("to", "") == dst_hid):
		owner._edge._add_edge(src_hid, dst_hid, "support", "green", false)
	if not owner._teaching:
		owner._sync_conclusion_gate_edges()   # 新推断上墙后，相关结论自动补 gate 边（教学墙不自动补）
	owner._layout_seed = int(Time.get_ticks_msec()) + owner._graph_nodes.size()
	owner._persist_view()
	owner._rebuild_graph()
	owner._focus_on(dst_hid)
	# 同 derive_hypo：选推断后若场景有可见预设结论，自动弹结论候选窗
	var _cons: Array = owner._hypo_current.get("conclusions", [])
	var _has_cand: bool = false
	for _c in _cons:
		if owner._dockctl._conclusion_preset_visible(_c):
			_has_cand = true
			break
	if _has_cand:
		owner.call_deferred("_open_conclusion_choice", dst_hid)


## 自定义结论：玩家输入文本生成结论节点（不选预设项）；con_id 用 "custom_N" 标记
func derive_conclusion_custom(hid: String, text: String) -> void:
	var t2 := text.strip_edges()
	if t2 == "":
		owner._ui_toast("结论内容不能为空")
		return
	var seq: int = 0
	var cid: String = ""
	while true:
		cid = "custom_%d" % seq
		if not owner._derived_conclusions.any(func(d): return str(d.get("id", "")) == cid):
			break
		seq += 1
	add_derived_conclusion(hid, cid, t2)


## 由推断推导结论：生成结论节点 + support 边（推断→结论）；结论节点已存在则只补边（多实例，不覆盖旧结论）
func derive_conclusion(hid: String, con_id: String) -> void:
	if owner._state != owner.State.EDITABLE:
		owner._ui_toast("推理墙已封存，仅可浏览")
		return
	add_derived_conclusion(hid, con_id, "")


## 统一入口：把一条结论（预设 con_id 或 自定义 custom_N）加入已推导列表，生成独立结论节点并连 support 边。
## 同一条结论（相同 con_id）只生成唯一节点；从不同推断推导同一结论时只追加对应 support 边。
func add_derived_conclusion(hid: String, con_id: String, custom_text: String = "") -> void:
	var nid: String = owner._conclusion_node_id(con_id)
	var existed: bool = false
	for _d in owner._derived_conclusions:
		if str(_d.get("id", "")) == con_id:
			existed = true
			break
	if not existed:
		# 预设结论 custom_text 为空时，回填其 battlefield 文本并随 owner._derived_conclusions 持久化，
		# 跨场景带入下一场景后仍可取回正确文本（避免落入「说得通」默认文案，问题3）。
		var _stored_text: String = custom_text
		if _stored_text == "":
			var _cd := owner._conclusion_def(con_id)
			_stored_text = str(_cd.get("text", ""))
		owner._derived_conclusions.append({"id": con_id, "hid": hid, "text": _stored_text})
		# 放置节点：优先锚定到「结论 gate_hypo_ids 中第一个已上墙的 gate 推断」（使结论落在推理链末端），
		# 否则回退触发 hid；螺旋碰撞检测避免与现有节点叠加。
		if not owner._node_center.has(nid):
			var base: Vector2 = owner._node_center.get(hid, owner._canvas.size * 0.5)
			var cdef: Dictionary = owner._conclusion_def(con_id)
			for g in cdef.get("gate_hypo_ids", []):
				if owner._node_center.has(str(g)):
					base = owner._node_center[str(g)]
					break
			var pos: Vector2 = owner._layout._find_non_overlapping_position(base, nid, "conclusion", owner._node_center)
			owner._node_center[nid] = pos
	# 玩家从推断/结论推导下一层结论＝明确选择「源(前提)→新结论(综合)」支撑关系，绘制该 support 绿边（属玩家连线，非系统自动）。
	# 金字塔原理 / XMind 逻辑图「结构服从关系」：由前提推导出的综合结论必须位于源的上一级（root 向），
	# 即新结论是源的「父」而非「子」。故边方向 = from=源(hid, 前提/子)、to=新结论(nid, 综合/父)，
	# 与 _build_parent_of「from=子/to=父」约定一致，也与 derive_hypo_from_hypo 的 _add_edge(src, dst) 方向统一。
	# 结论→结论（rd 同为1）时 _add_edge 不交换方向，故此处显式传 (hid, nid) 让新结论成为源的父节点；
	# 否则新结论会被误判为源的下一级叶（Issue 1 根因）。
	if hid != "" and not owner.any_edge(hid, nid) and not owner._relations.any(func(r): return r.get("from", "") == hid and r.get("to", "") == nid):
		owner._edge._add_edge(hid, nid, "support", "green", false)
	owner._layout_seed = int(Time.get_ticks_msec()) + owner._graph_nodes.size()
	owner._persist_view()
	owner._rebuild_graph()
	# 必须在 owner._rebuild_graph 之后同步：结论节点此刻才进入 owner._node_center，
	# 否则 owner._sync_conclusion_gate_edges 会因「结论节点尚未生成」跳过（旧设计靠自动铺预设掩盖此顺序 bug）。
	if not owner._teaching:
		owner._sync_conclusion_gate_edges()
	owner._focus_on(nid)
	var desc: String = ""
	if con_id.begins_with("custom"):
		desc = custom_text
	else:
		var cd: Dictionary = owner._conclusion_def(con_id)
		desc = str(cd.get("adopt_desc", ""))
	if desc != "":
		owner._ui_toast(desc if desc.length() <= 120 else desc.substr(0, 117) + "…")