extends Control
## Scene 3 — 劳瑞斯顿花园街3号 · 室内（尸体现场）
## 设计依据：02_血字的研究_场景设计与流程 §10 + 03_关卡设计稿 §3.4
## 架构：复用 SceneFramework + ClueObserver + 推理墙（与 scene2 同款模式，source="indoor"）

enum Phase { ARRIVAL, DETECTIVE_DIALOGUE, INDOOR_OBSERVE, REASONING, TRANSITION }

var _phase := Phase.ARRIVAL
var _dm: DialogueManager
var _ui: SceneFramework
var _difficulty := 1
var _indoor_obs: ClueObserver
var _indoor_clues: Array = []
var _stars_observe := 1
var _stars_reason := 1
var _stars_insight := 1
var _wall_auto := false

# Dummy labels for ClueObserver (actual text routed via _ui.set_dialogue)
var _obs_text_lbl: Label
var _obs_speaker_lbl: Label

const HOTSPOTS = [
	# ── 死者与尸体 ──
	{"id":"c301","label":"德雷伯名片","x":320,"y":150,"w":200,"h":46,
	 "desc":"死者衣袋里掉落的名片：伊诺克·J·德雷伯，美国克利夫兰人。这是辨认死者身份的第一条线索。","tool":"none"},
	{"id":"c302","label":"死尸无外伤","x":560,"y":150,"w":220,"h":46,
	 "desc":"尸体表面没有任何殴打、刀伤或勒痕，面色青紫——典型的非暴力中毒死亡。用化学试剂盒检验，确认血液里有生物碱残留。","tool":"化学试剂盒"},
	{"id":"c303","label":"面部痉挛痕迹","x":810,"y":150,"w":220,"h":46,
	 "desc":"死者面部保留着极度痛苦的痉挛扭曲，是死前剧烈绞痛的表现，符合生物碱类毒物（如苦杏仁酸/番木鳖碱）中毒特征。用放大镜细看更明显。","tool":"放大镜"},
	# ── 血字 ──
	{"id":"c304","label":"\"RACHE\"血字","x":1060,"y":150,"w":240,"h":46,
	 "desc":"墙上用血写下的「R-A-C-H-E」——德语「复仇」之意。但福尔摩斯判断：真正的德国人不会在作案现场用母语留字，这是刻意伪装。用放大镜细看笔迹。","tool":"放大镜"},
	{"id":"c305","label":"血字笔顺异常","x":1330,"y":150,"w":240,"h":46,
	 "desc":"血字笔画歪斜、起笔拖沓、收尾草率，像是凶手用左手蘸血、随手涂抹而成，而非从容书写。这进一步证明血字是伪装。","tool":"放大镜"},
	# ── 戒指与随身物 ──
	{"id":"c306","label":"戒指内刻\"L·F\"","x":320,"y":560,"w":240,"h":46,
	 "desc":"死者右手紧攥一枚女式结婚戒指，内圈刻着「L·F」——属于一位女性，并非德雷伯的原配妻子。这是本案的核心线索。","tool":"none"},
	{"id":"c307","label":"共济会图案","x":600,"y":560,"w":220,"h":46,
	 "desc":"戒指侧面刻有共济会式样的图案——或许购买渠道与共济会成员有关。但福尔摩斯认为这多半是干扰项，别被带偏。用放大镜看。","tool":"放大镜"},
	{"id":"c308","label":"礼帽（坎伯韦尔路）","x":860,"y":560,"w":200,"h":46,
	 "desc":"角落里一顶高档礼帽，内衬标着坎伯韦尔路的帽商标记——指向物品购买地点。困难模式下才是关键细节奖励。","tool":"none"},
	{"id":"c309","label":"死者随身财物","x":1100,"y":560,"w":220,"h":46,
	 "desc":"金表、金链、书信等随身财物原封未动——死者并未遭抢劫，作案动机不在钱财。","tool":"none"},
]

func _ready() -> void:
	if DifficultyManager: _difficulty = DifficultyManager.current_difficulty
	_init_game_state()
	_build_ui()
	_create_dummy_labels()
	_create_indoor_observer()
	_connect_ui_signals()
	# 检查是否有存档状态需恢复
	if _restore_saved_state():
		return
	_show_arrival_dialogue()

## 恢复存档进度（通过通用 SaveSystem 取回本场景快照）
func _restore_saved_state() -> bool:
	var ss = SaveSystem.take_save_state("scene3")
	if ss.is_empty(): return false
	var saved_phase := int(ss.get("phase", 0))
	var saved_ids: Array = ss.get("clue_ids", [])
	# 统一先把阶段恢复到存档值，避免子方法漏设 _phase 时阶段错乱（与 scene1/scene2 同款防御）
	_phase = saved_phase
	print("[RESTORE scene3] phase=", saved_phase, " clue_ids=", saved_ids)
	# 明确告知用户读档成功并恢复到哪个阶段，避免「不知道进到哪了」
	_ui.show_notification("✅ 读档成功 — 已恢复至「" + _phase_name(saved_phase) + "」")
	# 预填已收线索：优先取自通用线索登记（由 SaveManager 已恢复），回退到 saved_ids 推导
	_indoor_clues = ClueSystem.get_collected("indoor") if ClueSystem else []
	if _indoor_clues.is_empty():
		for cid in saved_ids:
			var h = _get_hotspot(cid)
			if not h.is_empty(): _indoor_clues.append(h)
	match saved_phase:
		Phase.ARRIVAL:
			_show_arrival_dialogue(); return true
		Phase.DETECTIVE_DIALOGUE:
			_show_detective_dialogue(); return true
		Phase.INDOOR_OBSERVE:
			_phase = Phase.INDOOR_OBSERVE
			if _indoor_clues.size() < HOTSPOTS.size():
				var owned_ids: Array = []
				for h in HOTSPOTS: owned_ids.append(h["id"])
				_ui.restore_observer(_indoor_obs, saved_ids, owned_ids)
			_ui.set_dialogue("提示", "已恢复进度 — 室内勘查阶段（已收集 "+str(_indoor_clues.size())+"/"+str(HOTSPOTS.size())+" 条）")
			return true
		Phase.REASONING:
			_phase = Phase.REASONING; _wall_auto = true; _open_wall(); return true
		Phase.TRANSITION:
			_enter_transition(); return true
	return false

func _phase_name(p: int) -> String:
	match p:
		Phase.ARRIVAL: return "进入尸体现场"
		Phase.DETECTIVE_DIALOGUE: return "警长说明"
		Phase.INDOOR_OBSERVE: return "室内勘查"
		Phase.REASONING: return "推理验证"
		Phase.TRANSITION: return "过渡"
		_: return "未知阶段"

func _init_game_state() -> void:
	if GameManager:
		GameManager.current_case_id = "case_blood_letter"
		GameManager.current_scene_id = "scene3"
		if AuthManager: GameManager.is_guest = AuthManager.is_guest()

func _build_ui() -> void:
	_ui = SceneFramework.new(); _ui.name = "ui"; add_child(_ui)
	var bg_tex = load("res://assets/scenes/sc_03_indoor.png")
	_ui.setup("劳瑞斯顿花园街 3号 · 室内", "DAY 1 正午12:05", bg_tex)

func _create_dummy_labels() -> void:
	_obs_text_lbl = Label.new(); _obs_text_lbl.visible = false; add_child(_obs_text_lbl)
	_obs_speaker_lbl = Label.new(); _obs_speaker_lbl.visible = false; add_child(_obs_speaker_lbl)

func _create_indoor_observer() -> void:
	_indoor_obs = ClueObserver.new()
	_indoor_obs.setup(self, _obs_text_lbl, _obs_speaker_lbl, HOTSPOTS, null)
	_indoor_obs.hotspot_clicked.connect(_on_hotspot_seen)
	_indoor_obs.clue_recorded.connect(_on_clue_recorded)
	_indoor_obs.all_recorded.connect(_on_indoor_all_done)

func _on_hotspot_seen(clue_id: String) -> void:
	var h = _get_hotspot(clue_id)
	if not h: return
	var tip := ""
	match h.get("tool", ""):
		"放大镜": tip = "\n\n[🔍 使用放大镜仔细查看 — 初始工具]"
		"化学试剂盒": tip = "\n\n[🧪 使用化学试剂盒检验 — 场景三解锁工具]"
	_ui.set_dialogue("发现：" + str(h.get("label", "")), str(h.get("desc", "")) + tip)

func _on_clue_recorded(_clue_id: String, _clue_data: Dictionary) -> void:
	_indoor_clues.append(_clue_data)
	# 同步登记到通用线索系统（ClueSystem 为单一真相源，推理墙统一从此读取）
	if ClueSystem:
		ClueSystem.collect_clue(
			_clue_data.get("id", _clue_id),
			_clue_data.get("name", ""),
			_clue_data.get("desc", ""),
			_clue_data.get("correct", true),
			"indoor"
		)
	var total := HOTSPOTS.size()
	_ui.show_notification("线索已记录：" + str(_clue_data.get("name", "")) + "（" + str(_indoor_clues.size()) + "/" + str(total) + "）")

func _on_indoor_all_done(_clues: Array) -> void:
	_ui.set_dialogue("华生", "福尔摩斯，屋里的线索都记下了——尸体的中毒痕迹、墙上的血字、还有那枚刻着「L·F」的戒指……指向的恐怕不是德国人。")
	await get_tree().create_timer(2.5).timeout
	_enter_reasoning()

func _get_hotspot(id: String):
	for h in HOTSPOTS:
		if str(h.get("id", "")) == id: return h
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
		{"t":"劳瑞斯顿花园街3号·室外","d":"案发现场花园 — 场景二"},
		{"t":"花园街3号·室内","d":"尸体现场 — 当前场景"}
	]:
		items.append({"name":"◆ "+loc["t"], "desc":loc["d"]})
	_popup("伦敦地图", items)

func _show_casebook_panel() -> void:
	var items: Array = []
	var ms := ["进入尸体现场","听取警长说明","勘查尸体与血字","推理墙验证"]
	var done := [_phase>=Phase.DETECTIVE_DIALOGUE, _phase>=Phase.INDOOR_OBSERVE, _indoor_clues.size()>=HOTSPOTS.size(), _phase>=Phase.REASONING]
	for i in ms.size():
		items.append({"name":("✅ " if done[i] else "⬜ ")+ms[i], "desc":""})
	_popup("案件簿 — 血字的研究 · 场景三", items)

func _show_inventory_panel() -> void:
	var items: Array = []
	if _indoor_clues.size() > 0:
		items.append({"name":"📝 尸体现场线索","desc":"已收集 "+str(_indoor_clues.size())+"/"+str(HOTSPOTS.size())+" 条"})
	for t in ["🔍 放大镜（初始）","📏 卷尺（场景二解锁）","🧪 化学试剂盒（场景三解锁）"]:
		items.append({"name":t, "desc":""})
	_popup("物品栏", items)

func _show_options_panel() -> void:
	var p = Control.new(); p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); p.mouse_filter=Control.MOUSE_FILTER_STOP
	add_child(p)
	var dim=ColorRect.new(); dim.color=Color(0,0,0,0.7); dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter=Control.MOUSE_FILTER_IGNORE; p.add_child(dim)
	var f=Panel.new(); f.size=Vector2(520,470); f.position=Vector2(700,300)
	f.add_theme_stylebox_override("panel",_sb(Color(0.13,0.10,0.07,0.97),Color(0.78,0.62,0.28),3,8))
	var t=Label.new(); t.text="⚙ 选项"; t.position=Vector2(20,15); t.add_theme_font_size_override("font_size",26)
	t.add_theme_color_override("font_color",Color(0.85,0.75,0.45)); f.add_child(t)
	var lines := [
		"难度："+["简单","普通","困难"][_difficulty]+" — 选定场景后不可更改",
		"操作：点击观察→放大查看→记录线索→推理墙→评价",
		"🔍 放大镜：查看血字笔顺、面部痉挛等细节",
		"🧪 化学试剂盒：场景三起可用，检验尸体中毒痕迹",
		"💡 核心：墙上的「RACHE」是伪装，戒指「L·F」才是真线索",
		"音效：MVP 阶段暂无（M3 补全）"
	]
	var y=65
	for ln in lines:
		var l=Label.new(); l.text="· "+ln; l.position=Vector2(20,y); l.size=Vector2(480,28)
		l.add_theme_font_size_override("font_size",16); l.add_theme_color_override("font_color",Color(0.75,0.7,0.6))
		f.add_child(l); y+=35
	var cl=Button.new(); cl.text="关闭"; cl.position=Vector2(190,415); cl.size=Vector2(140,38)
	cl.add_theme_color_override("font_color",Color(0.85,0.75,0.45)); cl.add_theme_font_size_override("font_size",18)
	cl.pressed.connect(func(): p.queue_free()); f.add_child(cl); p.add_child(f)

func _open_evidence() -> void:
	if _indoor_clues.is_empty(): _ui.show_notification("尚未发现任何证据。请先勘查室内。")
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
	if _phase != Phase.INDOOR_OBSERVE: _ui.show_notification("请先听完警长对现场的说明"); return
	if _indoor_obs.is_active():
		_indoor_obs.hide()
		_ui.show_notification("观察模式关闭")
	else:
		_indoor_obs.show()
		_ui.show_notification("🔍 观察模式 — 点击屋内的标记点进行勘查")

func _npc_talk() -> void:
	var gc = _indoor_clues.size()
	var t = ""
	match gc:
		0,1: t = "雷斯垂德指着墙角：\"尸体就在这儿，表面一点伤都没有——葛莱森说他从没见过这种死法。墙上那几个血字，你看见了吧？\""
		2,3: t = "葛莱森压低声音：\"血字写的是 R-A-C-H-E，德语'复仇'。我们猜凶手是个德国人。你看这人脸，死前像疼得抽搐过。\""
		4,5: t = "福尔摩斯俯身：\"血字笔画歪斜，是用左手蘸血随手抹的——真德国人不会在案发现场留母语字。这是伪装。\""
		6,7: t = "福尔摩斯拾起那枚戒指：\"看内圈的'L·F'。这是女人的结婚戒指，不是德雷伯的原配。真正的线索在这枚戒指上。\""
		_: t = "福尔摩斯：\"屋里的证据够了。把线索摆上推理墙，串起死因、血字和这枚戒指。\""
	if t != "": _ui.set_dialogue("", t)

func _use_magnifier() -> void:
	if _phase != Phase.INDOOR_OBSERVE: _ui.show_notification("当前无法使用放大镜"); return
	_indoor_obs.show(); _ui.show_notification("🔍 放大镜就绪 — 仔细检查血字与尸体细节")

func _open_wall() -> void:
	if _indoor_clues.is_empty() and (not ClueSystem or ClueSystem.count_collected("indoor") == 0):
		_ui.show_notification("推理墙需要至少一条线索才能打开。"); return
	# REASONING 阶段打开的墙（自动弹出或手动重开）验证后必须推进过渡；
	# 观察阶段手动开墙仅预览，不推进。不能无条件置 false（scene2 同款 bug）。
	_wall_auto = (_phase == Phase.REASONING)
	var rw = load("res://scripts/clue/reasoning_wall.gd")
	if not rw: _ui.show_notification("推理墙模块未找到"); return
	var wall = rw.new(); wall.name = "ReasoningWall"; add_child(wall)
	# 推理墙读取通用线索登记（单一真相源），与场景内 _indoor_clues 保持一致
	var clues: Array = ClueSystem.get_collected("indoor") if ClueSystem else _indoor_clues
	var hypothesis := {
		"title": "死者身份、死因与血字真相",
		"description": "死者是美国克利夫兰人德雷伯，死于生物碱中毒（非暴力）；墙上的「RACHE」血字是凶手伪装成德国人复仇的假象，真正的线索是那枚刻着「L·F」的女性结婚戒指。"
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
	if _indoor_clues.is_empty(): items.append({"name":"暂无记录","desc":"去室内勘查尸体与血字"})
	else:
		for c in _indoor_clues:
			items.append({"name":"📌 "+str(c.get("name","")),"desc":str(c.get("desc",""))})
	_popup("侦探笔记", items)

func _do_save() -> void:
	if GameManager.is_guest: _ui.show_notification("游客模式下无法存档，请先注册账号。"); return
	var data := {"clue_ids": []}
	var ids: Array = ClueSystem.get_collected_ids("indoor") if ClueSystem else []
	if ids.is_empty():
		for c in _indoor_obs.get_recorded_clues():
			ids.append(c.get("id", ""))
	data["clue_ids"] = ids
	print("[SAVE scene3] _phase=", _phase, " data=", data)
	await SaveSystem.request_save("scene3", _phase, data)
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
	_dm.dialogue_resource = _make_dialogue_resource("s3_arrival", _make_nodes([
		["i0","葛莱森","跟我来。死者的遗体还在里面，原封没动过——就躺在这间空屋的地板上。"],
		["i1","华生","（迈入屋内）煤气灯早就熄了，壁炉里只剩冷灰。这屋子空得让人发毛。"],
		["i2","福尔摩斯","（环视四周）血字写在墙上，尸体倒在墙角。凶手进过这间屋，却不拿财物——有意思。"],
		["i3","葛莱森","雷斯垂德已经在里头了，他第一个发现血字。让他给你讲讲经过。"]]), "i0")
	_dm.start_dialogue()

func _on_arrival_end() -> void:
	_show_detective_dialogue()

func _show_detective_dialogue() -> void:
	_phase = Phase.DETECTIVE_DIALOGUE
	_dm.dialogue_advanced.disconnect(_on_line)
	_dm.dialogue_ended.disconnect(_on_arrival_end); _dm.queue_free()
	_dm = DialogueManager.new(); add_child(_dm)
	_dm.dialogue_advanced.connect(_on_line); _dm.dialogue_ended.connect(_on_detective_end)
	_dm.dialogue_resource = _make_dialogue_resource("s3_detectives", _make_nodes([
		["j0","雷斯垂德","福尔摩斯，你说巧不巧——墙上这几个字母：R-A-C-H-E。德语，'复仇'的意思。我们多半是碰上德国人了。"],
		["j1","葛莱森","尸体一点外伤都没有，脸色发青，像是中了毒。我们猜凶手下了药。"],
		["j2","福尔摩斯","（凑近血字）德语没错。可你见过哪个真德国人，会在犯罪现场用母语留字、生怕别人认不出来？这字写得太刻意了。"],
		["j3","雷斯垂德","你是说……不是德国人？那这血字干嘛写的？"],
		["j4","福尔摩斯","伪装。凶手想把我们引向'复仇的德国人'。再看笔顺——歪歪扭扭，像左手蘸血随手抹的。华生，戴上你的放大镜，把屋里每样东西都看一遍：尸体、戒指、随身物。"]]), "j0")
	_dm.start_dialogue()

func _on_detective_end() -> void:
	_phase = Phase.INDOOR_OBSERVE
	_indoor_obs.show()
	_ui.set_dialogue("提示", "🔍 观察模式已开启。点击屋内的标记点开始勘查（共 "+str(HOTSPOTS.size())+" 处）。\n左侧 LOOK 可重新激活标记；收集完全部线索后打开推理墙整理。")

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
	var r=DialogueResource.new(); r.scene_id=sid; r.scene_name="scene3"
	r.nodes=ns; r.easy_start_node=start; r.normal_start_node=start; r.hard_start_node=start
	return r

# ==================== REASONING & TRANSITION ====================

func _enter_reasoning() -> void:
	_phase = Phase.REASONING; _wall_auto = true
	_ui.set_dialogue("福尔摩斯", "华生，证据齐了。把线索摆上推理墙——谁死了、怎么死的、那行血字是真还是假、那枚戒指又指向谁。")
	await get_tree().create_timer(2.5).timeout; _open_wall()

func _enter_transition() -> void:
	_phase = Phase.TRANSITION
	_dm = DialogueManager.new(); add_child(_dm)
	_dm.dialogue_advanced.connect(func(_id): var n=_dm.current_node; if n: _ui.set_dialogue(n.speaker,n.text))
	_dm.dialogue_ended.connect(_go_to_next_scene)
	_dm.dialogue_resource = _make_dialogue_resource("s3_trans", _make_nodes([
		["k0","福尔摩斯","推理墙印证了：死者德雷伯，死于生物碱中毒；血字是伪装，凶手根本不是德国人。真正的线头，是那枚刻着'L·F'的戒指。"],
		["k1","华生","一枚女人的结婚戒指……德雷伯的原配可没来过伦敦。这背后还有个人。"],
		["k2","葛莱森","案子比我们想的复杂。接下来去奥德利大院，找找昨晚的巡警问问话。"]]), "k0")
	_dm.start_dialogue()

func _go_to_next_scene() -> void:
	if GameManager and not GameManager.is_guest and SaveManager:
		await SaveManager.save_game()
	# FIXME: change to scene4 when scene4 is implemented
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

# ==================== INPUT ====================

func _input(event: InputEvent) -> void:
	var in_dialogue = (_phase == Phase.ARRIVAL or _phase == Phase.DETECTIVE_DIALOGUE or _phase == Phase.TRANSITION)
	if in_dialogue:
		if event is InputEventMouseButton and event.pressed:
			if _dm and _dm.is_active() and _dm.get_current_trigger() != "choice": _dm.advance()
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode in [KEY_ENTER, KEY_SPACE, KEY_E]:
				if _dm and _dm.is_active() and _dm.get_current_trigger() != "choice": _dm.advance()
