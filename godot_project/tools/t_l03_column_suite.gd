extends SceneTree
## L03 同列节点无重叠 —— 带 PASS/FAIL 断言的长期回归套件。
## 判定基准（清单 L03）：同列节点 y差 ≥ (h1+h2)/2 + 15；同列中心 x 差 ≤ 1.0px。
## 高度口径：与布局同源，统一用 _real_node_height（布局 _compute_layout 的 est_h 即由其产出）。
## headless 局限：沙箱无字体，_real_node_height 走兜底 ⇒ 全部节点等高（~400）。
##   因此本套件验证的是「等高真实 build 输出」下的同列间距；混合高度差异由文末 U1/U2
##   （绕开视图，直接调 _pack_contour/_band_next 并传自定义 est_h/带高）单元级覆盖。
## 曾尝试注入差异化 size.y 复测高矮差异，但视图 size 会被 Control 的 minimum_size 拉回
##   （注入根本不生效），而 _analyze 用注入高判 need ⇒ 系统性伪 FAIL，该注入法已废弃。

var _pass := 0
var _fail := 0

var _gvclass = null
func _clue(id, name, tags, rel=null):
	if rel == null: rel = []
	return {"id":id,"name":name,"correct":true,"relation_tags":tags,"related_npcs":rel}

func _make_gv():
	if _gvclass == null:
		_gvclass = load("res://scripts/clue/graph_view_controller.gd")
	var gv = _gvclass.new()
	var holder := Control.new(); root.add_child(holder); holder.add_child(gv)
	await process_frame
	gv._canvas = Control.new()
	return gv

## 按真实高度分析同列间距（A 同列 x 差、B 同列间距 ≥ (h1+h2)/2+15）
func _analyze(gv, tag: String):
	var L: Object = gv._layout
	var h := {}
	var hsrc := {}
	for id in gv._node_center:
		var nd: Dictionary = gv._node_data.get(str(id), {})
		var hv: float = L._real_node_height(str(id), nd)
		h[str(id)] = hv
		hsrc[str(id)] = hv
	# 同列分组：x 差 ≤ 1.0 视为同列（先归拢近似列）
	var cols := []
	var assigned := {}
	for id in gv._node_center:
		if assigned.has(id): continue
		var c: Vector2 = gv._node_center[id]
		var members := []
		for id2 in gv._node_center:
			if assigned.has(id2): continue
			if absf(gv._node_center[id2].x - c.x) <= 1.0:
				members.append(str(id2)); assigned[id2]=true
		if members.size() > 1:
			cols.append({"x":c.x, "members":members})
	print("== %s ==" % tag)
	print("  nodes=%d 列组=%d(单节点列不计)" % [gv._node_center.size(), cols.size()])
	var hdump := ""
	for id in gv._node_center:
		hdump += "%s=%.0f " % [str(id), h[str(id)]]
	print("  真实高: %s" % hdump)
	var worst_xdiff := 0.0
	var worst_gap := 1e18
	var worst_gap_desc := ""
	for col in cols:
		var ms: Array = col["members"]
		# 同列 x 差
		for i in range(ms.size()):
			for j in range(i + 1, ms.size()):
				worst_xdiff = maxf(worst_xdiff, absf(gv._node_center[ms[i]].x - gv._node_center[ms[j]].x))
		# 同列间距：按 y 排序求相邻差 vs (h1+h2)/2+15
		ms.sort_custom(func(a,b): return gv._node_center[a].y < gv._node_center[b].y)
		for i in range(ms.size()-1):
			var a: String = ms[i]; var b: String = ms[i+1]
			var gap: float = gv._node_center[b].y - gv._node_center[a].y
			var need: float = (h[a]+h[b])*0.5 + 15.0
			var margin: float = gap - need
			if margin < worst_gap:
				worst_gap = margin
				worst_gap_desc = "%s(%sH=%.0f) - %s(%sH=%.0f) gap=%.1f need=%.1f margin=%.1f with_x=%.2f" % [a,gv._node_center[a].x,h[a],b,gv._node_center[b].x,h[b],gap,need,margin,col["x"]]
	print("  同列最大x差=%.3fpx" % worst_xdiff)
	if worst_gap_desc == "":
		print("  (无 >1 节点同列组，跳过间距)")
		_pass += 1
		print("  L03-[%s]: PASS(无同列组)" % tag)
		return true
	print("  最紧同列间距: %s" % worst_gap_desc)
	# 收集本墙上所有 FAIL 对，打印所属列全部成员，便于定位布局函数
	var fail_cols := {}
	for col in cols:
		var ms: Array = col["members"]
		ms.sort_custom(func(a,b): return gv._node_center[a].y < gv._node_center[b].y)
		for i in range(ms.size()-1):
			var a: String = ms[i]; var b: String = ms[i+1]
			var gap: float = gv._node_center[b].y - gv._node_center[a].y
			var need: float = (h[a]+h[b])*0.5 + 15.0
			if gap - need < -0.01:
				fail_cols[col["x"]] = col
	if not fail_cols.is_empty():
		print("  !! FAIL 列详情:")
		for fx in fail_cols:
			var fcol: Dictionary = fail_cols[fx]
			var fms: Array = fcol["members"].duplicate()
			fms.sort_custom(func(a,b): return gv._node_center[a].y < gv._node_center[b].y)
			for a in fms:
				var ndk: String = str(gv._node_kind.get(str(a), "?"))
				print("     [x=%.0f y=%.0f H=%.0f kind=%s id=%s]" % [gv._node_center[a].x, gv._node_center[a].y, h[str(a)], ndk, a])
		# 全墙结构（便于定位带归属）
		for r in gv._relations:
			print("     edge %s → %s kind=%s" % [str(r.get("from","")), str(r.get("to","")), str(r.get("kind",""))])
	# 断言 A：同列中心 x 差 ≤ 1.0
	var okA := worst_xdiff <= 1.0
	# 断言 B：同列相邻间距 → margin = gap - (h1+h2)/2 - 15 ≥ 0
	var okB := worst_gap >= -0.01
	var ok := okA and okB
	if ok:
		_pass += 1
	else:
		_fail += 1
	print("  L03-[%s]: %s  (A同列x差=%.3f≤1.0: %s | B最紧margin=%.1f≥0: %s)" % \
		[tag, "PASS" if ok else "FAIL", worst_xdiff, "ok" if okA else "FAIL", worst_gap, "ok" if okB else "FAIL"])
	return ok

func _proc():
	# ---------- 形态1：正向星型（人物 + 结论分支，各带推断/线索）----------
	print("\n########## 形态1 正向星型 ##########")
	var gv = await _make_gv()
	var clues := [
		_clue("c101","花园街3号门前泥土有车辙",["H1-01"],["PERSON_A"]),
		_clue("c102","门把手上沾有煤灰",["H1-02"],["PERSON_B"]),
	]
	var hypo := {"scenes":{},"battlefield":{"hypotheses":[
		{"id":"H1-01","text":"凶手曾驾马车至门前","correct":true,"gate_clue_ids":["c101"]},
		{"id":"H1-02","text":"凶手与煤炉有过接触","correct":true,"gate_clue_ids":["c102"]},
	],"conclusions":[
		{"id":"CL1-1","text":"凶手从花园街3号门前离开","correct":true,"gate_hypo_ids":["H1-01"],"target":"person:PERSON_A"},
		{"id":"CL1-2","text":"凶手在室内翻动过物品","correct":true,"gate_hypo_ids":["H1-02"],"target":"person:PERSON_B"},
	],"persons":[{"id":"PERSON_A","name":"嫌疑人甲"},{"id":"PERSON_B","name":"嫌疑人乙"}]}}
	gv.build({"clues":clues,"hypo":hypo,"persons":[{"id":"PERSON_A","name":"嫌疑人甲"},{"id":"PERSON_B","name":"嫌疑人乙"}],
		"focus_person":"","difficulty":gv.Diff.NORMAL,"editable":true,"state_store":{},"auto_fold":false})
	await process_frame
	gv._derive.derive_hypo("c101","H1-01"); await process_frame
	gv._derive.derive_hypo("c102","H1-02"); await process_frame
	gv._derive.derive_conclusion("H1-01","CL1-1"); await process_frame
	gv._derive.derive_conclusion("H1-02","CL1-2"); await process_frame
	gv._derive.derive_conclusion("CL1-1","person:PERSON_A"); await process_frame
	gv._derive.derive_conclusion("CL1-2","person:PERSON_B"); await process_frame
	gv._rebuild_graph(); await process_frame
	_analyze(gv, "形态1 正向星型(2人物各1结论分支)")
	

	# ---------- 形态2：反转单链（真实场景二 c201→H2-01→CL2-1，persons 派生含 KILLER）----------
	print("\n########## 形态2 反转单链 ##########")
	await _m2()
	# ---------- 形态3：反转多根同列（4 线索共享 1 推断）----------
	print("\n########## 形态3 反转多根同列 ##########")
	await _m3()
	# ---------- 形态4：装箱大墙（真实场景二完整墙，~28 节点触发装箱）----------
	print("\n########## 形态4 装箱大墙 ##########")
	await _m4()
	# ---------- 形态5：含钉位 + 折叠 ----------
	print("\n########## 形态5 钉位+折叠 ##########")
	await _m5()
	# ---------- U1/U2：单元级（绕开视图，直接调 _pack_contour/_band_next，覆盖混合高度）----------
	print("\n########## U1/U2 单元级混合高度 ##########")
	await _u1_pack()
	await _u2_band()
	print("\n########## L03 汇总 ##########")
	print("L03_RESULT: %s (%d PASS / %d FAIL)" % ["PASS" if _fail == 0 else "FAIL", _pass, _fail])
	quit()

func _m2() -> void:
	var gv = await _make_gv()
	var clues := [
		_clue("c201","碾轧的花草",["H2-01"],["KILLER"]),
		_clue("c202","平行车轮印",["H2-01"]),
	]
	var hyps := [
		{"id":"H2-01","gate_clue_ids":["c201","c202"]},
	]
	var cons := [
		{"id":"CL2-1","gate_hypo_ids":["H2-01"]},
	]
	var persons := [{"id":"KILLER","name":"KILLER"}]
	var hypo := {"battlefield":{
		"hypotheses": hyps, "conclusions": cons, "persons": [],
	}}
	gv.build({"clues":clues,"hypo":hypo,"persons":persons,"focus_person":"",
		"difficulty":gv.Diff.NORMAL,"editable":true,"state_store":{},"auto_fold":false})
	await process_frame
	for h in hyps:
		for cid in h.get("gate_clue_ids", []):
			gv._derive.derive_hypo(cid, h.get("id","")); await process_frame
	for cn in cons:
		for hid in cn.get("gate_hypo_ids", []):
			gv._derive.derive_conclusion(hid, cn.get("id","")); await process_frame
	gv._rebuild_graph(); await process_frame
	_analyze(gv, "形态2 反转单链(c201/c202→H2-01→CL2-1, persons=KILLER)")
	

func _m3() -> void:
	var gv = await _make_gv()
	var clues := [
		_clue("c311","线索一：染血袖口",["H3-01"]),
		_clue("c312","线索二：断怀表链",["H3-01"]),
		_clue("c313","线索三：蹭落的煤灰",["H3-01"]),
		_clue("c314","线索四：带钩的鞋钉",["H3-01"]),
	]
	var hyps := [
		{"id":"H3-01","gate_clue_ids":["c311","c312","c313","c314"]},
	]
	var cons := [
		{"id":"CL3-1","gate_hypo_ids":["H3-01"]},
	]
	var hypo := {"battlefield":{"hypotheses": hyps, "conclusions": cons, "persons": []}}
	gv.build({"clues":clues,"hypo":hypo,"persons":[],"focus_person":"",
		"difficulty":gv.Diff.NORMAL,"editable":true,"state_store":{},"auto_fold":false})
	await process_frame
	for h in hyps:
		for cid in h.get("gate_clue_ids", []):
			gv._derive.derive_hypo(cid, h.get("id","")); await process_frame
	for cn in cons:
		for hid in cn.get("gate_hypo_ids", []):
			gv._derive.derive_conclusion(hid, cn.get("id","")); await process_frame
	gv._rebuild_graph(); await process_frame
	_analyze(gv, "形态3 反转多根同列(c311~c314→H3-01→CL3-1)")
	

func _m4() -> void:
	var gv = await _make_gv()
	var clues := [
		_clue("c201","碾轧的花草",["H2-01"],["KILLER"]),
		_clue("c202","平行车轮印",["H2-01"]),
		_clue("c203","右前蹄新蹄铁",["H2-02"]),
		_clue("c204","马蹄印迹零乱",["H2-03"]),
		_clue("c205","两组不同脚印",["H2-04","H2-06","H2-08"]),
		_clue("c206","步伐距离差异",["H2-04","H2-05"]),
		_clue("c209","方头靴印",["H2-06","H2-07"]),
		_clue("c210","尖头漆皮靴印",["H2-09"]),
		_clue("c211","两串脚印的往返",["H2-10"]),
	]
	var hyps := [
		{"id":"H2-01","gate_clue_ids":["c201","c202"]},
		{"id":"H2-02","gate_clue_ids":["c203"]},
		{"id":"H2-03","gate_clue_ids":["c204"]},
		{"id":"H2-04","gate_clue_ids":["c205","c206"]},
		{"id":"H2-05","gate_clue_ids":["c206"]},
		{"id":"H2-06","gate_clue_ids":["c205"]},
		{"id":"H2-07","gate_clue_ids":["c206"]},
		{"id":"H2-08","gate_clue_ids":["c205"]},
		{"id":"H2-09","gate_clue_ids":["c210","c206"]},
		{"id":"H2-10","gate_clue_ids":["c211"]},
	]
	var cons := [
		{"id":"CL2-1","gate_hypo_ids":["H2-01"]},
		{"id":"CL2-2","gate_hypo_ids":["H2-02"]},
		{"id":"CL2-3","gate_hypo_ids":["H2-03"]},
		{"id":"CL2-4","gate_hypo_ids":["H2-01","H2-02","H2-03"],"target":"person:KILLER"},
		{"id":"CL2-5","gate_hypo_ids":["H2-04"]},
		{"id":"CL2-6","gate_hypo_ids":["H2-05","H2-06"],"target":"person:KILLER"},
		{"id":"CL2-7","gate_hypo_ids":["H2-04","H2-08"]},
		{"id":"CL2-8","gate_hypo_ids":["H2-09"]},
		{"id":"CL2-9","gate_hypo_ids":["H2-10"]},
	]
	var persons := [{"id":"KILLER","name":"KILLER"}]
	var hypo := {"battlefield":{"hypotheses": hyps, "conclusions": cons, "persons": []}}
	gv.build({"clues":clues,"hypo":hypo,"persons":persons,"focus_person":"",
		"difficulty":gv.Diff.NORMAL,"editable":true,"state_store":{},"auto_fold":false})
	await process_frame
	for h in hyps:
		for cid in h.get("gate_clue_ids", []):
			gv._derive.derive_hypo(cid, h.get("id","")); await process_frame
	for cn in cons:
		for hid in cn.get("gate_hypo_ids", []):
			gv._derive.derive_conclusion(hid, cn.get("id","")); await process_frame
	for cn in cons:
		var tg = cn.get("target","")
		if "person:" in str(tg):
			gv._derive.derive_conclusion(cn.get("id",""), "person:"+str(tg).replace("person:","")); await process_frame
	gv._rebuild_graph(); await process_frame
	_analyze(gv, "形态4 装箱大墙(真实场景二完整墙, ~28 节点触发装箱>20)")
	

func _m5() -> void:
	var gv = await _make_gv()
	var clues := [
		_clue("c501","线索甲",["H5-01"]),
		_clue("c502","线索乙",["H5-02"]),
	]
	var hyps := [
		{"id":"H5-01","gate_clue_ids":["c501"]},
		{"id":"H5-02","gate_clue_ids":["c502"]},
	]
	var cons := [
		{"id":"CL5-1","gate_hypo_ids":["H5-01"]},
		{"id":"CL5-2","gate_hypo_ids":["H5-02"]},
	]
	var hypo := {"battlefield":{"hypotheses": hyps, "conclusions": cons, "persons": []}}
	gv.build({"clues":clues,"hypo":hypo,"persons":[],"focus_person":"",
		"difficulty":gv.Diff.NORMAL,"editable":true,"state_store":{},"auto_fold":false})
	await process_frame
	for h in hyps:
		for cid in h.get("gate_clue_ids", []):
			gv._derive.derive_hypo(cid, h.get("id","")); await process_frame
	for cn in cons:
		for hid in cn.get("gate_hypo_ids", []):
			gv._derive.derive_conclusion(hid, cn.get("id","")); await process_frame
	await process_frame
	# 钉位：手动拖 H5-01 到近 y 列，让它与同列推断更近
	if gv._node_center.has("H5-01"):
		gv._node_center["H5-01"] = Vector2(gv._node_center["H5-01"].x, gv._node_center["H5-01"].y + 10.0)
		gv._root_anchor_pos["H5-01"] = gv._node_center["H5-01"]
		gv._manual_nodes.append("H5-01")
	# 折叠一个子树：CL5-1 推断链折叠
	if gv.has_method("set_folded"):
		gv.set_folded("H5-01", true)
	gv._rebuild_graph(); await process_frame
	_analyze(gv, "形态5 钉位+折叠(H5-01钉到同列附近, CL5-1链折叠)")
	

## U1：直接调 _pack_contour，自定义 est_h 混入 120/412/840 三档高度，验证任意高度组合下
##   同 depth（同列）节点中心距 ≥ (h1+h2)/2+15，并报告最严边到边(≥期望 _CONTOUR_SEP=80)。
##   绕开 _node_views / 字体 — headless 下视图高度注入会被 Control minimum_size 拉回，无效。
func _u1_pack() -> void:
	var gv = await _make_gv()
	var L: Object = gv._layout
	var groups := {}
	groups["a 单根4直接子 120/840交错"] = {
		"root":"A",
		"child_map":{"A":["B","C","D","E"]},
		"depth_of":{"A":0,"B":1,"C":1,"D":1,"E":1},
		"est_h":{"A":120.0,"B":120.0,"C":840.0,"D":120.0,"E":840.0},
	}
	groups["b 根+3子各带2孙 堂兄弟高度混搭"] = {
		"root":"A",
		"child_map":{"A":["B1","B2","B3"],"B1":["K1","K2"],"B2":["K3","K4"],"B3":["K5","K6"]},
		"depth_of":{"A":0,"B1":1,"B2":1,"B3":1,"K1":2,"K2":2,"K3":2,"K4":2,"K5":2,"K6":2},
		"est_h":{"A":168.0,"B1":120.0,"B2":412.0,"B3":840.0,"K1":840.0,"K2":120.0,"K3":412.0,"K4":840.0,"K5":120.0,"K6":412.0},
	}
	groups["c 深层链+侧枝 同depth≥3个不同父"] = {
		"root":"A",
		"child_map":{"A":["B","C"],"B":["D1","D2"],"C":["E1","E2"],
			"D1":["M1"],"D2":["M2"],"E1":["M3"],"E2":["M6"],"M6":["N"]},
		"depth_of":{"A":0,"B":1,"C":1,"D1":2,"D2":2,"E1":2,"E2":2,
			"M1":3,"M2":3,"M3":3,"M6":3,"N":4},
		"est_h":{"A":120.0,"B":840.0,"C":120.0,"D1":412.0,"D2":120.0,"E1":840.0,"E2":412.0,
			"M1":120.0,"M2":840.0,"M3":412.0,"M6":120.0,"N":840.0},
	}
	var worst_edge: float = 1e18
	var worst_desc := ""
	for gname in groups:
		var G: Dictionary = groups[gname]
		var out: Dictionary = L._pack_contour(G["root"], G["child_map"], G["depth_of"], G["est_h"], G)
		var rel: Dictionary = out["rel"]
		var est_h: Dictionary = G["est_h"]
		var by_depth := {}
		for nid in rel:
			var d: int = G["depth_of"].get(nid, -1)
			if d < 1: continue
			if not by_depth.has(d): by_depth[d] = []
			by_depth[d].append(String(nid))
		var g_fail := 0
		var g_min_edge := 1e18; var g_min_desc := ""
		for d in by_depth:
			var ms: Array = by_depth[d]
			ms.sort_custom(func(a,b): return rel[a] < rel[b])
			for i in range(ms.size()-1):
				var a: String = ms[i]; var b: String = ms[i+1]
				var diff: float = rel[b] - rel[a]
				var halfsum: float = (est_h.get(a,140.0) + est_h.get(b,140.0)) * 0.5
				var edge: float = diff - halfsum
				if edge < g_min_edge:
					g_min_edge = edge
					g_min_desc = "%s(H=%d)-%s(H=%d) depth=%d" % [a, int(est_h.get(a,0)), b, int(est_h.get(b,0)), int(d)]
				if diff < halfsum + 15.0:
					g_fail += 1
					print("  U1-FAIL %s: %s-%s diff=%.1f need=%.1f" % [gname, a, b, diff, halfsum+15.0])
		if worst_edge > g_min_edge: worst_edge = g_min_edge; worst_desc = g_min_desc
		var strict_ok: bool = g_min_edge >= 80.0 - 1e-6
		if g_fail == 0: _pass += 1
		else: _fail += 1
		print("  U1-[%s]: %s  同列min边到边=%.1fpx (%s)  期望80档:%s" % [gname, "PASS" if g_fail==0 else "FAIL", g_min_edge, g_min_desc, "满足" if strict_ok else "未达80(仅报)"])
	print("  U1 三组合并 min同列边到边=%.1fpx (%s)" % [worst_edge, worst_desc])


## U2：直接调 _band_next，用不同带高(120/840/300…)连续推进，断言相邻带绘制区间间隙 ≥ gap(40)
##   且带不交错（后一带顶 ≥ 前一带底 + 15）。
func _u2_band() -> void:
	var gv = await _make_gv()
	var L: Object = gv._layout
	var runs := [
		{"heights":[120.0,840.0,300.0], "grid":0.0, "step":80.0},
		{"heights":[120.0,840.0,840.0,120.0], "grid":0.0, "step":900.0},
		{"heights":[100.0,48.0,840.0,412.0], "grid":120.0, "step":840.0},
		{"heights":[412.0,412.0,412.0], "grid":0.0, "step":412.0},
	]
	var gap: float = 40.0
	var worst_gap := 1e18
	var fail := 0
	for ri in range(runs.size()):
		var run: Dictionary = runs[ri]
		var H: Array = run["heights"]
		var grid: float = run["grid"]; var step: float = run["step"]
		var prev_bottom: float = 0.0
		var min_gap := 1e18; var min_desc := ""
		for hi in range(H.size()):
			var res: Array = L._band_next(prev_bottom, H[hi], grid, step, gap)
			var top: float = res[0]; var bottom: float = res[1]
			var band_gap: float = top - prev_bottom
			if band_gap < min_gap: min_gap = band_gap; min_desc = "带%d→%d" % [hi, hi+1]
			if top < prev_bottom + gap - 1e-6 or top < prev_bottom + 15.0 - 1e-6:
				fail += 1
				print("  U2-FAIL run%d: prev=%.0f top=%.0f < prev+gap(%.0f) 高=%.0f" % [ri, prev_bottom, top, gap, H[hi]])
			prev_bottom = bottom
		if min_gap < worst_gap: worst_gap = min_gap
		if fail == 0 and min_gap < 40.0 - 1e-6: fail += 1
		print("  U2-[run%d heights=%s grid=%.0f step=%.0f]: 最小带间隙=%.1fpx (%s)" % [ri, str(H), grid, step, min_gap, min_desc])
	if fail == 0: _pass += 1
	else: _fail += 1
	print("  U2 全run最小带间隙=%.1fpx  (期望>=%.1f, 且>=15)" % [worst_gap, gap])


func _initialize() -> void:
	await process_frame
	await _proc()