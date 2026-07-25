extends Control
## Scene 2 — 劳瑞斯顿花园街3号 · 案发现场（室外）
## 设计依据：02_血字的研究_场景设计与流程 §10 + 03_关卡设计稿 §3.3

enum Phase { ARRIVAL, DETECTIVE_DIALOGUE, GARDEN_OBSERVE, REASONING, TRANSITION }

var _phase := Phase.ARRIVAL
var _dm: DialogueManager
var _ui: SceneFramework
var _difficulty := 1
var _garden_obs: ClueObserver
var _garden_clues: Array = []
var _stars_observe := 1
var _stars_reason := 1
var _stars_insight := 1
var _wall_auto := false

# Dummy labels for ClueObserver (actual text routed via _ui.set_dialogue)
var _obs_text_lbl: Label
var _obs_speaker_lbl: Label

const HOTSPOTS = [
	{"id":"c201","label":"碾轧的花草","x":260,"y":430,"w":150,"h":42,
	 "desc":"花园外围花草大片倒伏，被重物来回碾轧——有马车在此反复掉头或停靠。","tool":"none"},
	{"id":"c202","label":"平行车轮印","x":520,"y":430,"w":150,"h":42,
	 "desc":"泥地上两道平行的深沟轮印，间距约4.5英尺（约1.37米）——典型的四轮出租马车轴距。用卷尺精确测量后确认为伦敦双座出租马车。","tool":"卷尺"},
	{"id":"c203","label":"右前蹄新蹄铁","x":260,"y":530,"w":150,"h":42,
	 "desc":"四只马蹄印中，右前蹄的蹄铁崭新锃亮，其余三只明显磨损——这匹马近期刚修过蹄铁，说明马车主经常维护座驾。","tool":"none"},
	{"id":"c204","label":"马蹄印迹零乱","x":520,"y":530,"w":150,"h":42,
	 "desc":"蹄印分布杂乱无章，非直线排列而是多方向散开——马曾在无人驾驭状态下自由走动。说明驾者中途下车，无人看管马匹。","tool":"none"},
	{"id":"c205","label":"两组初始足迹","x":260,"y":630,"w":150,"h":42,
	 "desc":"泥地边缘有两组清晰的脚印，自街道方向走来，一深一浅指向空屋门口。案发当晚曾有两人步行进入花园。","tool":"卷尺"},
	{"id":"c206","label":"步伐距离差异","x":520,"y":630,"w":150,"h":42,
	 "desc":"测量后：第一人每步约2英尺（61cm），身高应超6英尺（183cm）；第二人步幅较小约5英尺半（168cm）。两人体格差异明显——高的一个与醉汉描述吻合。","tool":"卷尺"},
]

func _ready() -> void:
	if DifficultyManager: _difficulty = DifficultyManager.current_difficulty
	_init_game_state()
	_build_ui()
	_create_dummy_labels()
	_create_garden_observer()
	_connect_ui_signals()
	# 检查是否有存档状态需恢复
	if _restore_saved_state():
		return
	_show_arrival_dialogue()

## 恢复存档进度（通过通用 SaveSystem 取回本场景快照）
func _restore_saved_state() -> bool:
	var ss = SaveSystem.take_save_state("scene2")
	if ss.is_empty(): return false
	var saved_phase := int(ss.get("phase", 0))
	var saved_ids: Array = ss.get("clue_ids", [])
	# 统一先把阶段恢复到存档值，避免子方法漏设 _phase 时阶段错乱（与 scene1 同款防御）
	_phase = saved_phase
	print("[RESTORE scene2] phase=", saved_phase, " clue_ids=", saved_ids)
	# 明确告知用户读档成功并恢复到哪个阶段，避免「不知道进到哪了」
	_ui.show_notification("✅ 读档成功 — 已恢复至「" + _phase_name(saved_phase) + "」")
	# 预填已收线索：优先取自通用线索登记（由 SaveManager 已恢复），回退到 saved_ids 推导
	_garden_clues = ClueSystem.get_collected("garden") if ClueSystem else []
	if _garden_clues.is_empty():
		for cid in saved_ids:
			var h = _get_hotspot(cid)
			if not h.is_empty(): _garden_clues.append(h)
	match saved_phase:
		Phase.ARRIVAL:
			_show_arrival_dialogue(); return true
		Phase.DETECTIVE_DIALOGUE:
			_show_detective_dialogue(); return true
		Phase.GARDEN_OBSERVE:
			_phase = Phase.GARDEN_OBSERVE
			if _garden_clues.size() < HOTSPOTS.size():
				var owned_ids: Array = []
				for h in HOTSPOTS: owned_ids.append(h["id"])
				_ui.restore_observer(_garden_obs, saved_ids, owned_ids)
			_ui.set_dialogue("提示", "已恢复进度 — 花园勘查阶段（已收集 "+str(_garden_clues.size())+"/"+str(HOTSPOTS.size())+" 条）")
			return true
		Phase.REASONING:
			_phase = Phase.REASONING; _wall_auto = true; _open_wall(); return true
		Phase.TRANSITION:
			_enter_transition(); return true
	return false

func _phase_name(p: int) -> String:
	match p:
		Phase.ARRIVAL: return "抵达案发现场"
		Phase.DETECTIVE_DIALOGUE: return "警长对话"
		Phase.GARDEN_OBSERVE: return "花园勘查"
		Phase.REASONING: return "推理验证"
		Phase.TRANSITION: return "过渡"
		_: return "未知阶段"

func _init_game_state() -> void:
	if GameManager:
		GameManager.current_case_id = "case_blood_letter"
		GameManager.current_scene_id = "scene2"
		if AuthManager: GameManager.is_guest = AuthManager.is_guest()

func _build_ui() -> void:
	_ui = SceneFramework.new(); _ui.name = "ui"; add_child(_ui)
	_ui.setup("劳瑞斯顿花园街 3号", "DAY 1 上午11:15")
	# stub background - dark rainy garden tone
	var bg_tex = load("res://assets/characters/watson/watson_standing.jpg")
	if bg_tex: _ui.add_portrait(bg_tex, "", Vector2(0, 0), Vector2(1920, 1080))

func _create_dummy_labels() -> void:
	_obs_text_lbl = Label.new(); _obs_text_lbl.visible = false; add_child(_obs_text_lbl)
	_obs_speaker_lbl = Label.new(); _obs_speaker_lbl.visible = false; add_child(_obs_speaker_lbl)

func _create_garden_observer() -> void:
	_garden_obs = ClueObserver.new()
	_garden_obs.setup(self, _obs_text_lbl, _obs_speaker_lbl, HOTSPOTS, null)
	_garden_obs.hotspot_clicked.connect(_on_hotspot_seen)
	_garden_obs.clue_recorded.connect(_on_clue_recorded)
	_garden_obs.all_recorded.connect(_on_garden_all_done)

func _on_hotspot_seen(clue_id: String) -> void:
	var h = _get_hotspot(clue_id)
	if not h: return
	var tip := ""
	if h.get("tool","") == "卷尺":
		tip = "\n\n[📏 使用卷尺精确测量 — 场景二解锁工具]"
	_ui.set_dialogue("发现：" + str(h.get("label","")), str(h.get("desc","")) + tip)

func _on_clue_recorded(_clue_id: String, _clue_data: Dictionary) -> void:
	_garden_clues.append(_clue_data)
	# 同步登记到通用线索系统（ClueSystem 为单一真相源，推理墙统一从此读取）
	if ClueSystem:
		ClueSystem.collect_clue(
			_clue_data.get("id", _clue_id),
			_clue_data.get("name", ""),
			_clue_data.get("desc", ""),
			_clue_data.get("correct", true),
			"garden"
		)
	var total := HOTSPOTS.size()
	_ui.show_notification("线索已记录：" + str(_clue_data.get("name","")) + "（" + str(_garden_clues.size()) + "/" + str(total) + "）")

func _on_garden_all_done(_clues: Array) -> void:
	_ui.set_dialogue("华生", "福尔摩斯，花园里的痕迹全都记录好了——轮印间距、马蹄蹄铁、两组不同身高的足迹……证据很充足。")
	await get_tree().create_timer(2.5).timeout
	_enter_reasoning()

func _get_hotspot(id: String):
	for h in HOTSPOTS:
		if str(h.get("id","")) == id: return h
	return {}

func _connect_ui_signals() -> void:
	_ui.nav_clicked.connect(_on_nav)
	_ui.action_clicked.connect(_on_action)

# ==================== NAVIGATION ====================

func _on_nav(nav_id: String) -> void:
	match nav_id:
		"map": _show_map_panel()
		"casebook": _show_casebook_panel()
		"evidence": _open_evidence()
		"inventory": _show_inventory_panel()
		"options": _show_options_panel()

func _show_map_panel() -> void:
	var items: Array = []
	for loc in [
		{"t":"贝克街221B", "d":"福尔摩斯寓所 — 场景一"},
		{"t":"劳瑞斯顿花园街3号·室外","d":"案发现场 — 当前场景"},
		{"t":"花园街3号·室内","d":"尸体现场 — 待进入场景三"}
	]:
		items.append({"name":"◆ "+loc["t"], "desc":loc["d"]})
	_popup("伦敦地图", items)

func _show_casebook_panel() -> void:
	var items: Array = []
	var ms := ["抵达案发现场","听取警长汇报","勘查花园痕迹","推理墙验证"]
	var done := [_phase>=Phase.DETECTIVE_DIALOGUE, _phase>=Phase.GARDEN_OBSERVE, _garden_clues.size()>=HOTSPOTS.size(), _phase>=Phase.REASONING]
	for i in ms.size():
		items.append({"name":("✅ " if done[i] else "⬜ ")+ms[i], "desc":""})
	_popup("案件簿 — 血字的研究 · 场景二", items)

func _show_inventory_panel() -> void:
	var items: Array = []
	if _garden_clues.size() > 0:
		items.append({"name":"📝 案发现场线索","desc":"已收集 "+str(_garden_clues.size())+"/"+str(HOTSPOTS.size())+" 条"})
	for t in ["🔍 放大镜（初始）","📏 卷尺（场景二解锁）","🧪 化学试剂盒"]:
		items.append({"name":t, "desc":""})
	_popup("物品栏", items)

func _show_options_panel() -> void:
	var p = Control.new(); p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); p.mouse_filter=Control.MOUSE_FILTER_STOP
	add_child(p)
	var dim=ColorRect.new(); dim.color=Color(0,0,0,0.7); dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter=Control.MOUSE_FILTER_IGNORE; p.add_child(dim)
	var f=Panel.new(); f.size=Vector2(520,460); f.position=Vector2(700,310)
	f.add_theme_stylebox_override("panel",_sb(Color(0.13,0.10,0.07,0.97),Color(0.78,0.62,0.28),3,8))
	var t=Label.new(); t.text="⚙ 选项"; t.position=Vector2(20,15); t.add_theme_font_size_override("font_size",26)
	t.add_theme_color_override("font_color",Color(0.85,0.75,0.45)); f.add_child(t)
	var lines := [
		"难度："+["简单","普通","困难"][_difficulty]+" — 选定场景后不可更改",
		"操作：点击观察→放大查看→记录线索→推理墙→评价",
		"📏 卷尺：场景二起可用，测量轴距/步幅等物理证据",
		"💡 本案马车轴距≈4.5英尺（伦敦出租马车标准）",
		"音效：MVP 阶段暂无（M3 补全）"
	]
	var y=65
	for ln in lines:
		var l=Label.new(); l.text="· "+ln; l.position=Vector2(20,y); l.size=Vector2(480,28)
		l.add_theme_font_size_override("font_size",16); l.add_theme_color_override("font_color",Color(0.75,0.7,0.6))
		f.add_child(l); y+=35
	var cl=Button.new(); cl.text="关闭"; cl.position=Vector2(190,405); cl.size=Vector2(140,38)
	cl.add_theme_color_override("font_color",Color(0.85,0.75,0.45)); cl.add_theme_font_size_override("font_size",18)
	cl.pressed.connect(func(): p.queue_free()); f.add_child(cl); p.add_child(f)

func _open_evidence() -> void:
	if _garden_clues.is_empty(): _ui.show_notification("尚未发现任何证据。请先勘查花园。")
	else: _open_wall()

func _sb(bg:Color,bd:Color,w:int,r:int):
	var s=StyleBoxFlat.new(); s.bg_color=bg; s.border_width_left=w; s.border_width_right=w
	s.border_width_top=w; s.border_width_bottom=w; s.border_color=bd
	s.set_corner_radius_all(r); return s

func _popup(title_txt:String,items:Array) -> void:
	var o=Panel.new(); o.position=Vector2(460,120); o.size=Vector2(1000,700); o.z_index=100
	o.add_theme_stylebox_override("panel",_sb(Color(0.08,0.06,0.04,0.97),Color(0.78,0.62,0.28),2,6))
	var tt=Label.new(); tt.text=title_txt; tt.position=Vector2(30,20); tt.add_theme_font_size_override("font_size",28)
	tt.add_theme_color_override("font_color",Color(0.85,0.75,0.45)); o.add_child(tt)
	var sc=ScrollContainer.new(); sc.position=Vector2(30,70); sc.size=Vector2(940,570)
	var ct=Control.new(); ct.size=Vector2(920,len(items)*60)
	var yy=0
	for it in items:
		var n=Label.new(); n.text=str(it.get("name","")); n.position=Vector2(10,yy); n.size=Vector2(900,24)
		n.add_theme_font_size_override("font_size",20); n.add_theme_color_override("font_color",Color(0.92,0.88,0.78))
		ct.add_child(n)
		var d=Label.new(); d.text=str(it.get("desc","")); d.position=Vector2(30,yy+26); d.size=Vector2(880,24)
		d.add_theme_font_size_override("font_size",16); d.add_theme_color_override("font_color",Color(0.6,0.55,0.45))
		ct.add_child(d); yy+=60
	sc.add_child(ct); o.add_child(sc)
	var cl=Button.new(); cl.text="关闭"; cl.position=Vector2(430,620); cl.size=Vector2(140,45)
	cl.add_theme_color_override("font_color",Color(0.85,0.75,0.45)); cl.add_theme_font_size_override("font_size",20)
	cl.pressed.connect(func(): o.queue_free()); o.add_child(cl); add_child(o)

# ==================== ACTIONS ====================

func _on_action(action_id: String) -> void:
	match action_id:
		"look": _toggle_observe()
		"talk": _npc_talk()
		"examine": _use_magnifier()
		"think": _open_wall()
		"journal": _show_journal()
		"save": _do_save()
		"load": _do_load()

func _toggle_observe() -> void:
	if _phase != Phase.GARDEN_OBSERVE: _ui.show_notification("请先听取警长们的现场说明"); return
	if _garden_obs.is_active():
		_garden_obs.hide()
		_ui.show_notification("观察模式关闭")
	else:
		_garden_obs.show()
		_ui.show_notification("🔍 观察模式 — 点击花园中的标记点进行勘查")

func _npc_talk() -> void:
	var gc = _garden_clues.size()
	var t = ""
	match gc:
		0,1: t = "葛莱森踱步道：\"这些花草全被碾平了。昨晚一定有马车在这门口停过。\""
		2,3: t = "雷斯垂德指向地面：\"双轨平行轮印——四轮马车。再看看马蹄印，福尔摩斯。\""
		4: t = "福尔摩斯蹲下：\"马蹄印里有一只是新换的蹄铁。记下这一点，华生——修过蹄，说明马车主很重视。\""
		5: t = "福尔摩斯直起身：\"两组足迹，一深一浅……一个高个子加一个中等身材。就差进屋看尸体了。\""
		_: t = "福尔摩斯：\"花园的证据够了。推推理墙，串起这些线索。\""
	if t != "": _ui.set_dialogue("", t)

func _use_magnifier() -> void:
	if _phase != Phase.GARDEN_OBSERVE: _ui.show_notification("当前无法使用放大镜"); return
	_garden_obs.show(); _ui.show_notification("🔍 放大镜就绪 — 仔细检查现场痕迹")

func _open_wall() -> void:
	if _garden_clues.is_empty() and (not ClueSystem or ClueSystem.count_collected("garden") == 0):
		_ui.show_notification("推理墙需要至少一条线索才能打开。"); return
	_wall_auto = false
	var rw = load("res://scripts/clue/reasoning_wall.gd")
	if not rw: _ui.show_notification("推理墙模块未找到"); return
	var wall = rw.new(); wall.name = "ReasoningWall"; add_child(wall)
	# 推理墙读取通用线索登记（单一真相源），与场景内 _garden_clues 保持一致
	var clues: Array = ClueSystem.get_collected("garden") if ClueSystem else _garden_clues
	var hypothesis := {
		"title": "案发当晚的交通与人员",
		"description": "一辆伦敦出租马车停在花园街3号门口，驾车者高大男性，另一人同行进入花园。"
	}
	wall.setup(clues, hypothesis, func(verdict: int):
		var labels = {0:"CONTRADICTORY", 1:"INSUFFICIENT", 2:"SUPPORTED", 3:"VERIFIED"}
		var v = labels.get(verdict, "WAITING")
		var star_icons = {0:"⭐", 1:"★★", 2:"★★★", 3:"🌟🌟🌟"}
		_ui.show_notification("推理验证结果："+v+" "+star_icons.get(verdict,"⭐"))
		if _wall_auto: _enter_transition()
	)

func _show_journal() -> void:
	var items: Array = []
	if _garden_clues.is_empty(): items.append({"name":"暂无记录","desc":"去花园勘查现场痕迹"})
	else:
		for c in _garden_clues:
			items.append({"name":"📌 "+str(c.get("name","")),"desc":str(c.get("desc",""))})
	_popup("侦探笔记", items)

func _do_save() -> void:
	if GameManager.is_guest: _ui.show_notification("游客模式下无法存档，请先注册账号。"); return
	var data := {"clue_ids": []}
	var ids: Array = ClueSystem.get_collected_ids("garden") if ClueSystem else []
	if ids.is_empty():
		for c in _garden_obs.get_recorded_clues():
			ids.append(c.get("id", ""))
	data["clue_ids"] = ids
	print("[SAVE scene2] _phase=", _phase, " data=", data)
	await SaveSystem.request_save("scene2", _phase, data)
	_ui.show_notification("✅ 进度已保存")

func _do_load() -> void:
	_ui.show_notification("正在读取存档…")
	if not SaveManager:
		_ui.show_notification("存档系统不可用")
		return
	# 从磁盘/云端重新读取最新存档，刷新 GameManager.scene_state 与 ClueSystem
	var ok = await SaveSystem.load_game()
	if not ok:
		_ui.show_notification("没有可用的存档")
		return
	# 就地重置当前场景：_ready 会调用 _restore_saved_state，从刚刷新的存档恢复进度
	get_tree().reload_current_scene()

# ==================== DIALOGUE PHASES ====================

func _show_arrival_dialogue() -> void:
	_dm = DialogueManager.new(); add_child(_dm)
	_dm.dialogue_advanced.connect(_on_line); _dm.dialogue_ended.connect(_on_arrival_end)
	_dm.dialogue_resource = _make_dialogue_resource("s2_arrival", _make_nodes([
		["a0","葛莱森","福尔摩斯先生！您总算来了——昨晚在花园街三号的空屋里发现了一具男尸，表面没有任何外伤，像是中毒而死……"],
		["a1","福尔摩斯","没有外伤的中毒死者？有意思。带我们去看看现场，警长。"],
		["a2","华生","（环顾四周）这座花园……轮印、马蹄印、脚印全都混在泥里。昨晚这里可真热闹。"],
		["a3","福尔摩斯","先别急着下结论，华生。看——栅栏外面还有一个人。雷斯垂德，你也来了？"]]), "a0")
	_dm.start_dialogue()

func _on_arrival_end() -> void:
	_show_detective_dialogue()

func _show_detective_dialogue() -> void:
	_phase = Phase.DETECTIVE_DIALOGUE
	_dm.dialogue_advanced.disconnect(_on_line)
	_dm.dialogue_ended.disconnect(_on_arrival_end); _dm.queue_free()
	_dm = DialogueManager.new(); add_child(_dm)
	_dm.dialogue_advanced.connect(_on_line); _dm.dialogue_ended.connect(_on_detective_end)
	_dm.dialogue_resource = _make_dialogue_resource("s2_detectives", _make_nodes([
		["b0","雷斯垂德","福尔摩斯，你来晚了。我和葛莱森已经把屋内初步查过了——墙上用血写了几个字母：'R-A-C-H-E'。"],
		["b1","葛莱森","德语，意思是'复仇'。我们推测凶手可能是德国人。"],
		["b2","福尔摩斯","（微微一笑）德语倒是没错，但我不认为这是德国人干的。真正的德国人不会在犯罪现场用母语留字——太刻意。这几个字写得歪歪扭扭，像是用左手蘸血随意涂抹的。"],
		["b3","雷斯垂德","左手？你怎么……算了。说正经的——附近居民昨晚听到马车声和马蹄声，还有一个醉汉在街上踉跄。"],
		["b4","葛莱森","所以我们先来外面勘查花园——地上这些痕迹说不定比屋里更有用。"],
		["b5","福尔摩斯","很好。华生，你戴上放大镜仔细检查地面——注意车轮印的间距、马蹄印中哪只新旧不一，以及脚印的多少和大小。我和警长们先在边上等着。"]]), "b0")
	_dm.start_dialogue()

func _on_detective_end() -> void:
	_phase = Phase.GARDEN_OBSERVE
	_garden_obs.show()
	_ui.set_dialogue("提示", "🔍 观察模式已开启。点击花园中的标记点开始勘查。\n左侧 LOOK 可重新激活标记；收集完全部 6 条线索后打开推理墙整理。")

func _on_line(_id: String) -> void:
	var n = _dm.current_node; if n: _ui.set_dialogue(n.speaker, n.text)

func _make_nodes(raw: Array) -> Array:
	var nodes: Array[Resource] = []
	for r in raw:
		var n = DialogueNodeResource.new()
		n.node_id=r[0]; n.speaker=r[1]; n.text=r[2]; n.trigger="click"
		var nxt: Array[String] = []
		if len(r) > 3:
			nxt.append(r[3])
		else:
			var base: String = r[0]
			var num: int = int(base.substr(1)) + 1
			nxt.append(base[0] + str(num))
		n.next_nodes = nxt; n.mood = "neutral"; nodes.append(n)
	return nodes

func _make_dialogue_resource(sid:String,ns:Array,start:String):
	var r=DialogueResource.new(); r.scene_id=sid; r.scene_name="scene2"
	r.nodes=ns; r.easy_start_node=start; r.normal_start_node=start; r.hard_start_node=start
	return r

# ==================== REASONING & TRANSITION ====================

func _enter_reasoning() -> void:
	_phase = Phase.REASONING; _wall_auto = true
	_ui.set_dialogue("福尔摩斯", "华生，证据齐全了。把这些线索摆上推理墙——什么车、什么人、几号人，在案发那晚进过这座花园。")
	await get_tree().create_timer(2.5).timeout; _open_wall()

func _enter_transition() -> void:
	_phase = Phase.TRANSITION
	_dm = DialogueManager.new(); add_child(_dm)
	_dm.dialogue_advanced.connect(func(_id): var n=_dm.current_node; if n: _ui.set_dialogue(n.speaker,n.text))
	_dm.dialogue_ended.connect(_go_to_next_scene)
	_dm.dialogue_resource = _make_dialogue_resource("s2_trans", _make_nodes([
		["c0","福尔摩斯","推理墙的结果印证了我的判断：一辆伦敦出租马车、两人一高一矮。高个子的体貌特征和'醉汉'吻合——他很可能就是凶手，或者凶手的帮手。"],
		["c1","华生","花园的证据都齐了。外面看完了——进去看看尸体现场吧。"],
		["c2","葛莱森","跟我来。死者的遗体还在里面没有动过。"]]), "c0")
	_dm.start_dialogue()

func _go_to_next_scene() -> void:
	if GameManager and not GameManager.is_guest and SaveManager:
		await SaveManager.save_game()
	# 场景三已实现，进入室内尸体现场
	get_tree().change_scene_to_file("res://scenes/scene3.tscn")

# ==================== INPUT ====================

func _input(event: InputEvent) -> void:
	var in_dialogue = (_phase == Phase.ARRIVAL or _phase == Phase.DETECTIVE_DIALOGUE or _phase == Phase.TRANSITION)
	if in_dialogue:
		if event is InputEventMouseButton and event.pressed:
			if _dm and _dm.is_active() and _dm.get_current_trigger() != "choice": _dm.advance()
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode in [KEY_ENTER, KEY_SPACE, KEY_E]:
				if _dm and _dm.is_active() and _dm.get_current_trigger() != "choice": _dm.advance()
