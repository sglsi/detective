extends SceneTree
## 复现：场景一华生教学墙（真实 CH01W 数据）折叠独立树枝后是否丢失
## 直接用生产 ReasoningChains.build_wall_dict("CH01W") 取真实结论/推断 id 与 gate 结构，
## 按引擎推导时建立的 support/target 边构造 relations（教学墙玩家逐条手连，结构同源），
## 验证：折叠任一「独立树枝」根后，根仍可见、有展开控件；汇聚点 C-MAIN 不被误吞；叶子折叠后可恢复。
func _initialize() -> void:
    await process_frame
    var GV = load("res://scripts/clue/graph_view_controller.gd")
    var RC = load("res://data/reasoning_chains.gd")
    var gv = GV.new()
    var holder = Control.new(); root.add_child(holder); holder.add_child(gv)
    await process_frame

    # 真实华生教学墙数据
    var wall: Dictionary = RC.build_wall_dict("CH01W")
    var bf: Dictionary = wall.get("battlefield", {})
    var persons := [{"id": "NPC_WT", "name": "华生"}]
    var conclusions: Array = bf.get("conclusions", [])
    var hypos: Array = bf.get("hypotheses", [])

    # 结论 id 列表（真实）
    var concl_ids: Array = []
    for c in conclusions:
        concl_ids.append(str(c.get("id", "")))
    print("CH01W 结论: ", concl_ids)

    # 真实线索（来自 battlefield 各推断 gate_clue_ids）
    var clues := [
        {"id": "wrist", "name": "手腕肤色分界"},
        {"id": "face_dark", "name": "面色黝黑"},
        {"id": "pose", "name": "军人站姿"},
        {"id": "medical", "name": "医疗行业痕迹"},
        {"id": "arm", "name": "左臂旧伤"},
        {"id": "face_haggard", "name": "面容憔悴"},
    ]

    # 按引擎推导顺序构造 relations（与 _add_derived_conclusion / _derive_hypo 同构）：
    # 每条 gate_hypo_ids 引用（剥 conclusion_ 前缀）建 源→目标 support 边；conclusion 的 target→person 建 target 边。
    # 线索→推断 边由 _derive_hypo 建（此处按 gate_clue_ids 还原）。
    var relations := []
    # 线索 → 推断（clue 是叶子，无下级；折叠此类节点即「独立树枝」消失的真实触发点）
    for h in hypos:
        var hid: String = str(h.get("id", ""))
        for cstr in h.get("gate_clue_ids", []):
            relations.append({"from": str(cstr), "to": hid, "kind": "support"})
    # 推断 → 结论 / 结论 → 结论 / 结论 → 人物
    for c in conclusions:
        var cid: String = str(c.get("id", ""))
        var nid: String = "conclusion_" + cid
        for g in c.get("gate_hypo_ids", []):
            var gstr: String = str(g)
            var src: String = gstr if gstr.begins_with("conclusion_") else gstr
            relations.append({"from": src, "to": nid, "kind": "support"})
        var tgt: String = str(c.get("target", ""))
        if tgt.begins_with("person:"):
            relations.append({"from": nid, "to": "NPC_WT", "kind": "target"})

    print("构造 relations 数: ", relations.size())
    for r in relations:
        print("  ", r.get("from"), "->", r.get("to"), "(", r.get("kind"), ")")

    gv.build({
        "clues": clues,
        "hypo": {"title": "", "persons": persons, "battlefield": bf},
        "persons": persons,
        "focus_person": "NPC_WT",
        "difficulty": gv.Diff.NORMAL,
        "editable": true,
        "state_store": {},
        "relations": relations,
        "auto_fold": false,
        "case_wide": false,
        "teaching": true,
    })
    # 让全部结论作为「已上墙」节点
    var dcs := []
    for cid in concl_ids:
        dcs.append({"id": cid})
    gv._derived_conclusions = dcs
    for h in hypos:
        var hid: String = str(h.get("id", ""))
        gv._graph_nodes.append({"id": hid, "kind": "hypo", "label": hid, "sub": "推断", "data": {}})
    gv._rebuild_graph()
    await process_frame

    print("\n=== initial node list ===")
    for nd in gv._node_list():
        print("  ", nd.get("id"), " kind=", nd.get("kind"))
    print("fold controls (initial): ", gv._fold_controls.keys())

    # 折叠「独立树枝」根 conclusion_C-B1（W-B1/W-B2 两条推断汇入，再汇入 C-MAIN）
    print("\n=== 折叠独立树枝 conclusion_C-B1 后 ===")
    gv.toggle_fold("conclusion_C-B1")
    await process_frame
    var nl1 := []
    for nd in gv._node_list(): nl1.append(nd.get("id"))
    print("visible: ", nl1)
    print("C-MAIN 仍可见?: ", "conclusion_C-MAIN" in nl1, "  person 仍可见?: ", "NPC_WT" in nl1)
    print("C-B1 有展开控件?: ", gv._fold_controls.has("conclusion_C-B1"))
    print("folded_nodes: ", gv._folded_nodes)
    print("_node_center keys: ", gv._node_center.keys())
    print("_all_positions has C-B1?: ", gv._all_positions.has("conclusion_C-B1"), " val=", gv._all_positions.get("conclusion_C-B1", "NONE"))

    # 再折叠叶子线索 wrist（线索是叶子 rd=3，无下级、无外向关系 → 旧代码会「隐藏且无法展开」地永久消失）
    print("\n=== 折叠叶子线索 wrist 后 ===")
    var leaf := "wrist"
    gv.toggle_fold(leaf)
    await process_frame
    var nl2 := []
    for nd in gv._node_list(): nl2.append(nd.get("id"))
    print("visible: ", nl2)
    print("折叠叶子 ", leaf, " 后仍可见?: ", leaf in nl2, " 有控件(可展开)?: ", gv._fold_controls.has(leaf), " 有位置?: ", gv._node_center.has(leaf))

    # 断言
    var fail := false
    var nl_ids := []
    for nd in gv._node_list(): nl_ids.append(nd.get("id"))
    if not ("conclusion_C-B1" in nl_ids):
        print("FAIL: 折叠根 conclusion_C-B1 从 _node_list 消失"); fail = true
    if not gv._node_center.has("conclusion_C-B1"):
        print("FAIL: 折叠根 conclusion_C-B1 无位置"); fail = true
    if not gv._fold_controls.has("conclusion_C-B1"):
        print("FAIL: 折叠根 conclusion_C-B1 无折叠控件（无法展开）"); fail = true
    if not ("conclusion_C-MAIN" in nl_ids):
        print("FAIL: 汇聚点 conclusion_C-MAIN 被误吞"); fail = true
    if not ("NPC_WT" in nl_ids):
        print("FAIL: 焦点人物 NPC_WT 被误吞"); fail = true
    # 叶子折叠：必须仍可见 + 有展开控件（旧 bug 会永久消失）
    if not ("wrist" in nl_ids):
        print("FAIL: 叶子线索 wrist 折叠后从 _node_list 消失"); fail = true
    if not gv._node_center.has("wrist"):
        print("FAIL: 叶子 wrist 折叠后无位置"); fail = true
    if not gv._fold_controls.has("wrist"):
        print("FAIL: 叶子 wrist 折叠后无折叠控件（无法展开·旧 bug 复现）"); fail = true
    if fail:
        quit(1)
    else:
        print("PASS: 独立树枝(汇聚根)+叶子线索 折叠后均可见+可展开；汇聚点/人物未被误吞")
        quit(0)
