extends DetectiveScene
## Scene 1 — 贝克街221B（华生登场 / 阿富汗军医推理练习）
## 架构：与场景二/三同继承统一框架 DetectiveScene（所有通用机制在基类，
## 仅本场景「观察器/推理墙为两组」与「对话节点用显式 next」两点结构不同，
## 故覆盖相应钩子；其余导航/弹窗/存读档/对话引擎等均已复用基类）。
## 设计依据：02_血字的研究_场景设计与流程 §9 + 03_关卡设计稿 §3.2

enum Verdict { CONTRADICTORY=0, INSUFFICIENT=1, SUPPORTED=2, VERIFIED=3 }
enum Phase { MRS_HUDSON, OPENING, OBSERVE_WATSON, WATSON_REASONING, MESSENGER_OBSERVE, MESSENGER_REASONING, RATING, COMPLETE }

# 场景一专属状态（两组观察 / 评分等）；_phase/_dm/_ui/_difficulty/_wall_auto 继承自基类
var _watson_obs: ClueObserver
var _messenger_obs: ClueObserver
var _portrait_ctrl: Control = null   # 华生立绘控件（仅在 OBSERVE_WATSON 阶段显示）
var _messenger_portrait_ctrl: Control = null  # 信使立绘控件（仅在 MESSENGER_OBSERVE 阶段显示）
var _watson_v := 0
var _messenger_v := 0
var _watson_clues: Array = []
var _messenger_clues: Array = []
var _stars_observe := 1
var _stars_reason := 1
var _stars_insight := 1
var _look_active := false
var _talk_active := false

## 场景一是贝克街221B室内（华生登场），必须用维多利亚起居室。
## ⚠️ 曾误挂 crime_scene_1920x1080.jpg（命案现场），与场景三「劳瑞斯顿花园街3号·室内」
## 内容撞车，玩家在场景一会看到场景三的现场图。换图时注意与各场景所在地对应：
##   scene1 贝克街221B室内 / scene2 花园外景 / scene3 命案现场室内。
func scene_background() -> Texture2D: return load("res://assets/backgrounds/baker_street_parlor.jpg")

func _ready() -> void:
	super._ready()

## 恢复存档进度 — 返回 true 表示有存档且已恢复，false 表示新游戏。
## 两组观察器分别同步 ClueSystem（单一真相源），并以存档 clue_ids 为权威，
## 杜绝「场景内进度」与「推理墙（ClueSystem）」不一致的「两层皮」。
func _restore_saved_state() -> bool:
	var ss = SaveSystem.take_save_state("scene1")
	if ss.is_empty(): return false
	var saved_phase := int(ss.get("phase", 0))
	var saved_ids: Array = ss.get("clue_ids", [])
	# 兼容旧存档：华生左肩线索早期 id 为 "arm"，现统一为 "shoulder"（与观察器/锚点表一致）。
	# 只做读取时的就地映射，绝不改写或删除玩家存档文件。
	for i in range(saved_ids.size()):
		if str(saved_ids[i]) == "arm": saved_ids[i] = "shoulder"
	if ClueSystem:
		ClueSystem.clear_source("watson")
		ClueSystem.clear_source("messenger")
		for cid in saved_ids:
			var h = _find_hotspot(cid)
			if not h.is_empty():
				var src := "watson" if cid in ["wrist","shoulder","face","pose"] else "messenger"
				ClueSystem.collect_clue_from_catalog(cid, h.get("name", cid), h.get("desc",""), h.get("correct", true), src)
	_phase = saved_phase
	_create_notification("✅ 读档成功 — 已恢复至「" + _phase_name(saved_phase) + "」")

	match saved_phase:
		Phase.MRS_HUDSON:
			_show_mrs_hudson_dialogue()
			return true
		Phase.OPENING:
			_show_opening_dialogue()
			return true
		Phase.OBSERVE_WATSON:
			if _portrait_ctrl: _portrait_ctrl.visible = true
			_ui.restore_observer(_watson_obs, saved_ids, ["wrist","shoulder","face","pose"])
			if _watson_obs.get_recorded() >= 4:
				_on_watson_all_recorded(_watson_obs.get_recorded_clues()); return true
			_ui.set_dialogue("提示", "已恢复进度 — 华生观察阶段（已收集 "+str(_watson_obs.get_recorded())+"/4 条）\n点击 LOOK 查看剩余标记点")
			return true
		Phase.WATSON_REASONING:
			_phase = Phase.WATSON_REASONING; _wall_auto = false
			_ui.restore_observer(_watson_obs, saved_ids, ["wrist","shoulder","face","pose"])
			_show_watson_reasoning_wall()
			return true
		Phase.MESSENGER_OBSERVE:
			_phase = Phase.MESSENGER_OBSERVE
			_ui.restore_observer(_messenger_obs, saved_ids, ["tattoo","beard","posture","manner","sleeve","limp"])
			if _messenger_obs.get_recorded() >= 6:
				_on_messenger_all_recorded(_messenger_obs.get_recorded_clues()); return true
			_ui.set_dialogue("提示", "已恢复进度 — 信使观察阶段（已收集 "+str(_messenger_obs.get_recorded())+"/6 条）\n点击 LOOK 查看剩余标记点")
			return true
		Phase.MESSENGER_REASONING:
			_phase = Phase.MESSENGER_REASONING; _wall_auto = false
			_ui.restore_observer(_messenger_obs, saved_ids, ["tattoo","beard","posture","manner","sleeve","limp"])
			_show_messenger_reasoning_wall()
			return true
		Phase.RATING, Phase.COMPLETE:
			_phase = Phase.RATING
			_show_rating()
			return true
	return false

func _find_hotspot(id: String) -> Dictionary:
	for h in _all_hotspots():
		if h.get("id","") == id: return h
	return {}

## 观察器内部的热点信号转发到全局 SceneEventBus.hotspot_clicked，
## 让工具栏（放大镜/卷尺/黄页）知道「当前正在看哪条细节」。
func _on_obs_hotspot_to_tool(clue_id: String) -> void:
	if SceneEventBus:
		SceneEventBus.hotspot_clicked.emit(clue_id)

func _phase_name(p: int) -> String:
	match p:
		Phase.MRS_HUDSON: return "赫德森太太开场"
		Phase.OPENING: return "开场对话"
		Phase.OBSERVE_WATSON: return "华生观察"
		Phase.WATSON_REASONING: return "华生推理"
		Phase.MESSENGER_OBSERVE: return "信使观察"
		Phase.MESSENGER_REASONING: return "信使推理"
		Phase.RATING: return "评分阶段"
		Phase.COMPLETE: return "已完成"
		_: return "未知阶段"

func _all_hotspots() -> Array:
	var w = [{"id":"wrist","name":"手腕肤色分界","desc":"华生手腕肤色分界明显——长期暴露于热带阳光"},{"id":"shoulder","name":"左肩旧伤","desc":"华生左肩动作略显僵硬——战场负伤留下的旧疾"},{"id":"face","name":"面色黝黑憔悴","desc":"华生面色黝黑且憔悴——久病初愈的迹象"},{"id":"pose","name":"军人站姿","desc":"华生站姿挺拔，带有明显军人气质"}]
	var m = [{"id":"tattoo","name":"锚形文身","desc":"信使手背上有蓝色锚形文身——皇家海军标志"},{"id":"beard","name":"络腮胡","desc":"信使留着军人式络腮胡"},{"id":"posture","name":"挺拔站姿","desc":"信使站姿挺拔有力"},{"id":"manner","name":"神态平静","desc":"信使神态从容淡定"},{"id":"sleeve","name":"袖口细节","desc":"信使袖口有磨损痕迹"},{"id":"limp","name":"轻微跛行","desc":"信使走路有轻微跛行"}]
	var r: Array = []
	r.append_array(w); r.append_array(m)
	return r

func _init_game_state() -> void:
	if GameManager:
		GameManager.current_case_id = "case_blood_letter"
		GameManager.current_scene_id = "scene1"
		if AuthManager: GameManager.is_guest = AuthManager.is_guest()

func _build_ui() -> void:
	_ui = SceneFramework.new(); _ui.name = "ui"; add_child(_ui)
	_ui.setup("贝克街221B", "DAY 1 上午10:30", scene_background())
	# 实例化道具工具栏（基类 _setup_toolbar 在 super._build_ui 中，但本场景覆盖了 _build_ui，
	# 故在此显式调用，否则 _toolbar 为 null → 调查按钮无法显示/选择工具）
	_setup_toolbar()
	var tex = load("res://assets/characters/watson/watson_teaching.png")
	if tex:
		_portrait_ctrl = _ui.add_portrait(tex, "华生", Vector2(160, 350), Vector2(280, 360), false)
		# 默认隐藏：仅在 OBSERVE_WATSON 阶段显示
		if _portrait_ctrl: _portrait_ctrl.visible = false
	# 信使立绘（默认隐藏，MESSENGER_OBSERVE 阶段显示）
	var mtex = load("res://assets/characters/messenger/messenger_portrait.png")
	if mtex:
		_messenger_portrait_ctrl = _ui.add_portrait(mtex, "信使", Vector2(580, 300), Vector2(280, 420), false)
		if _messenger_portrait_ctrl: _messenger_portrait_ctrl.visible = false

## 场景一用 UI 内部对话标签渲染观察层，不需要占位标签
func _create_dummy_labels() -> void:
	pass

## 创建两组观察器（华生 / 信使），各自连线到本场景回调
func _create_observers() -> void:
	var tex = load("res://assets/characters/watson/watson_teaching.png")
	var sa = _ui.get_scene_area()
	_watson_obs = ClueObserver.new(); _watson_obs.name = "watson_observer"; add_child(_watson_obs)
	_watson_obs.setup(sa, _ui._dialogue_label, _ui._speaker_label, [
		# crop 为「锚点表缺失时」的回退取景，数值已与 clue_image_anchors.gd
		# 中 watson_teaching.png 的定稿锚点对齐（x=cx-w/2, y=cy-h/2, cx=cx+w/2, cy=cy+h/2）
		{"id":"wrist","label":"手腕肤色分界","x":580,"y":400,"w":100,"h":60,"desc":"手部微晒黑，手腕偏白 -> 刚从热带回来",
		 "crop":{"x":0.2215,"y":0.5605,"cx":0.4985,"cy":0.7695}},
		{"id":"shoulder","label":"左肩旧伤","x":450,"y":450,"w":100,"h":70,"desc":"左肩动作略显僵硬 -> 战场负伤",
		 "crop":{"x":0.5845,"y":0.3225,"cx":0.7575,"cy":0.4575}},
		{"id":"face","label":"面色憔悴","x":520,"y":240,"w":110,"h":70,"desc":"面色微晒黑且憔悴 -> 久病初愈",
		 "crop":{"x":0.392,"y":0.040,"cx":0.632,"cy":0.326}},
		{"id":"pose","label":"军人站姿","x":500,"y":600,"w":130,"h":80,"desc":"站姿挺拔 -> 阿富汗军医",
		 "crop":{"x":0.0,"y":0.0,"cx":1.0,"cy":1.0}},
	], tex)
	_watson_obs.all_recorded.connect(_on_watson_all_recorded)
	_watson_obs.clue_recorded.connect(_on_collect_clue.bind("watson"))
	# 把观察热点转发到全局 SceneEventBus，使工具栏能用「放大镜/卷尺/黄页」定位当前细节
	_watson_obs.hotspot_clicked.connect(_on_obs_hotspot_to_tool)

	_messenger_obs = ClueObserver.new(); _messenger_obs.name = "messenger_observer"; add_child(_messenger_obs)
	var mess_tex = load("res://assets/characters/messenger/messenger_portrait.png")
	_messenger_obs.setup(sa, _ui._dialogue_label, _ui._speaker_label, [
		{"id":"tattoo","label":"手背锚文身","x":580,"y":260,"w":130,"h":50,"desc":"蓝色锚形文身 -> 海军标志","correct":true,
		 "crop":{"x":0.16,"y":0.39,"cx":0.46,"cy":0.59}},
		{"id":"beard","label":"络腮胡须","x":680,"y":200,"w":120,"h":55,"desc":"军人式络腮胡 -> 军队常见","correct":true,
		 "crop":{"x":0.36884,"y":0.1568,"cx":0.59970,"cy":0.3408}},
		{"id":"posture","label":"笔挺站姿","x":620,"y":520,"w":130,"h":60,"desc":"昂首挺胸 -> 军事训练","correct":true,
		 "crop":{"x":0.0,"y":0.0,"cx":1.0,"cy":1.0}},
		{"id":"manner","label":"发号施令","x":520,"y":230,"w":110,"h":50,"desc":"发号施令 -> 军士/士官","correct":true,
		 "crop":{"x":0.35698,"y":0.0855,"cx":0.60997,"cy":0.3500}},
		{"id":"sleeve","label":"袖口磨损","x":780,"y":420,"w":115,"h":50,"desc":"袖口磨损 -> 干扰:衣服旧了","correct":false,
		 "crop":{"x":0.6606,"y":0.52,"cx":0.8406,"cy":0.72}},
		{"id":"limp","label":"走路略跛","x":580,"y":600,"w":120,"h":55,"desc":"右腿略跛 -> 干扰:扭伤","correct":false,
		 "crop":{"x":0.4905,"y":0.7800,"cx":0.7005,"cy":0.98768}},
	], mess_tex)
	_messenger_obs.all_recorded.connect(_on_messenger_all_recorded)
	_messenger_obs.clue_recorded.connect(_on_collect_clue.bind("messenger"))
	_messenger_obs.hotspot_clicked.connect(_on_obs_hotspot_to_tool)

func _on_watson_all_recorded(clues: Array) -> void:
	_watson_clues = clues; _wall_auto = true; _show_watson_reasoning_wall()

func _on_messenger_all_recorded(clues: Array) -> void:
	_messenger_clues = clues; _wall_auto = true; _show_messenger_reasoning_wall()

## 观察器记录一条线索时，同步登记到通用线索系统（ClueSystem 为单一真相源）
func _on_collect_clue(clue_id: String, clue_data: Dictionary, source: String) -> void:
	if ClueSystem:
		ClueSystem.collect_clue_from_catalog(
			clue_id,
			clue_data.get("name", clue_id),
			clue_data.get("desc", ""),
			clue_data.get("correct", true),
			source
		)

# ===== 基类钩子：地图 / 案件簿（内容） =====
func map_locations() -> Array:
	return [{"t":"贝克街221B","d":"福尔摩斯与华生的寓所 — 当前场景"},{"t":"劳瑞斯顿花园街3号","d":"葛莱森警长发现的尸体现场 — 待调查"},{"t":"苏格兰场","d":"伦敦警察总部 — 葛莱森办公处"}]

func casebook_steps() -> Array:
	return ["赫德森太太开场", "华生观察练习", "信使观察练习", "推理验证完成"]

func casebook_done_flags() -> Array:
	return [_phase >= Phase.OPENING, _watson_obs.get_recorded() >= 4, _messenger_obs.get_recorded() >= 6, _phase >= Phase.MESSENGER_REASONING]

func _enter_arrival() -> void:
	_show_mrs_hudson_dialogue()

# ===== 左侧动作（场景一为观察/对话切换式） =====
func _on_action(action_id: String) -> void:
	match action_id:
		"look":
			_look_active = not _look_active; _ui.set_action_active("look", _look_active)
			if not _look_active: _create_notification("观察已关闭")
			else: _do_look()
		"talk":
			_talk_active = not _talk_active; _ui.set_action_active("talk", _talk_active)
			if not _talk_active: _create_notification("对话已关闭")
			else: _do_talk()
		"examine": _do_examine()
		"think": _do_think()
		"journal": _open_notebook()
		"save": _do_save()
		"load": _do_load()
		_: _create_notification("「" + action_id + "」已激活")

func _do_look() -> void:
	if _phase == Phase.OBSERVE_WATSON: _watson_obs.show(); _ui.set_dialogue("提示", "观察模式 — 点击华生身上的按钮"); _ui.set_dialogue_color(Color(0.5,0.9,0.5))
	elif _phase == Phase.MESSENGER_OBSERVE: _messenger_obs.show(); _ui.set_dialogue("提示", "观察模式 — 点击信使身上的按钮"); _ui.set_dialogue_color(Color(0.5,0.9,0.5))
	elif _phase == Phase.WATSON_REASONING or _phase == Phase.MESSENGER_REASONING: _create_notification("已在推理墙中，请先完成验证")

func _do_talk() -> void:
	if _dm and _dm.is_active(): _dm.advance(); return
	if _phase == Phase.MRS_HUDSON or _phase == Phase.OPENING: _dm.advance()
	elif _phase == Phase.OBSERVE_WATSON: _ui.set_dialogue("华生", "福尔摩斯先生，您是怎么看出我从阿富汗回来的？"); _ui.set_dialogue_color(Color(0.7,0.8,0.9))
	elif _phase == Phase.MESSENGER_OBSERVE: _ui.set_dialogue("福尔摩斯", "这位信使身上也有值得观察的细节。"); _ui.set_dialogue_color(Color(0.85,0.75,0.45))
	else: _create_notification("当前无法进行对话")

func _do_examine() -> void:
	if _phase == Phase.OBSERVE_WATSON or _phase == Phase.MESSENGER_OBSERVE:
		# 调查按钮：toggle 道具工具栏（显示/隐藏）
		if _toolbar:
			if _toolbar.is_active:
				_toolbar.hide_toolbar()
				_create_notification("道具栏已收起")
			else:
				_toolbar.show_toolbar()
				_create_notification("🔍 放大镜工具 — 点击场景中的人物细节进行观察")
		if not _look_active:
			_look_active = true; _ui.set_action_active("look", true)
	else:
		_create_notification("请在观察阶段使用放大镜工具")
		if _toolbar:
			_toolbar.hide_toolbar()

## scene1 覆盖：当前是否在观察阶段（华生/信使观察）。
func _in_observe_phase() -> bool:
	return _phase == Phase.OBSERVE_WATSON or _phase == Phase.MESSENGER_OBSERVE

## scene1 覆盖：返回当前阶段对应的观察器（华生或信使）。
func _current_observer() -> ClueObserver:
	if _phase == Phase.OBSERVE_WATSON: return _watson_obs
	if _phase == Phase.MESSENGER_OBSERVE: return _messenger_obs
	return null

func _do_think() -> void:
	if _phase == Phase.OBSERVE_WATSON and _watson_obs.get_recorded() > 0:
		_show_watson_reasoning_wall()
	elif _phase == Phase.MESSENGER_OBSERVE and _messenger_obs.get_recorded() > 0:
		_show_messenger_reasoning_wall()
	elif _phase == Phase.WATSON_REASONING:
		_show_watson_reasoning_wall()   # 已关墙后可重新打开
	elif _phase == Phase.MESSENGER_REASONING:
		_show_messenger_reasoning_wall()
	else:
		_create_notification("请先收集至少 1 条线索再使用推理墙")

func _do_save(slot: int = -1) -> void:
	# 存档为登录用户专属（游客不可存档）
	if GameManager and GameManager.is_guest:
		_create_notification("游客模式不支持存档 — 请返回主菜单注册/登录")
		return
	# 以本场景两个观察器的已记录线索为权威（不读全局 ClueSystem，避免跨轮累计污染存档）
	var data := {"clue_ids": [], "watson_recorded": 0, "messenger_recorded": 0}
	var ids: Array = []
	for c in _watson_obs.get_recorded_clues(): ids.append(c.get("id",""))
	for c in _messenger_obs.get_recorded_clues(): ids.append(c.get("id",""))
	data["clue_ids"] = ids
	for cid in ids:
		if cid in ["wrist","shoulder","face","pose"]: data["watson_recorded"] += 1
		else: data["messenger_recorded"] += 1
	print("[SAVE scene1] phase=", _phase, " data=", data)
	# 保存不需要选槽位：自动分配（空槽位优先，满则覆盖最旧）
	await SaveSystem.request_save("scene1", _phase, data, slot)
	_create_notification("✅ 进度已保存")

# ===== 对话（场景一用显式 next 的 _dn 构造器） =====
func _dn(id, sp, txt, tri, nxt, mood="neutral") -> DialogueNodeResource:
	var n = DialogueNodeResource.new()
	n.node_id=id; n.speaker=sp; n.text=txt; n.trigger=tri
	var nn: Array[String] = []
	for s in nxt:
		if s is String: nn.append(s)
	n.next_nodes = nn
	n.mood = mood
	return n

func _show_mrs_hudson_dialogue() -> void:
	# 对齐 08 稿 v3.16.0 §阶段1初次见面（L133-153）：悬念开场 + 赫德森太太端茶
	_dm = DialogueManager.new(); add_child(_dm)
	_dm.dialogue_advanced.connect(_on_line)
	_dm.dialogue_ended.connect(_on_mrs_hudson_end)
	var nodes: Array[Resource] = []
	nodes.append(_dn("h0","赫德森太太","福尔摩斯先生，茶来了。哦，华生医生，欢迎您。","click",["h1"]))
	nodes.append(_dn("h1","福尔摩斯","（上下打量华生，停顿）……阿富汗军医。","click",["h2"],"自信"))
	nodes.append(_dn("h2","华生","（一愣）什么？","click",["h3"],"吃惊"))
	nodes.append(_dn("h3","福尔摩斯","我说，你是一名刚从阿富汗回来的军医。我说对了吗？","click",["h4"],"从容"))
	nodes.append(_dn("h4","华生","您……您怎么知道的？我们刚认识不到十秒钟。","click",["h5"],"惊讶"))
	nodes.append(_dn("h5","福尔摩斯","（微笑，转向玩家视角）这位新朋友显然不相信。不如——你来告诉他我是怎么看出来的？","click",["end"],"指导"))
	var res = DialogueResource.new(); res.scene_id="s1_intro"; res.nodes=nodes
	res.easy_start_node="h0"; res.normal_start_node="h0"; res.hard_start_node="h0"
	_dm.dialogue_resource=res; _dm.start_dialogue()

func _on_mrs_hudson_end() -> void:
	_dm.dialogue_ended.disconnect(_on_mrs_hudson_end)
	_dm.dialogue_ended.connect(_on_opening_end)
	_show_opening_dialogue()

func _show_opening_dialogue() -> void:
	# 对齐 08 稿 v3.16.0 §阶段1教程环节（L155-282）：六步探索闭环引导
	_phase = Phase.OPENING
	var nodes: Array[Resource] = []
	nodes.append(_dn("s0", "福尔摩斯", "证据在你身上: 手腕、左臂、靨色、站姿", "click", ["s1"], "从容"))
	nodes.append(_dn("s1","系统","[新手教程] 第一次观察\n目标：找出4条线索，证明'华生是阿富汗军医'\n操作：点击华生身上的高亮按钮，逐一观察细节","click",["s2"],"guide"))
	nodes.append(_dn("s2","系统","点击华生身上的可交互区域。完成后进入推理墙验证。","click",["end"],"guide"))
	var res = DialogueResource.new(); res.scene_id="s1_open"; res.nodes=nodes
	res.easy_start_node="s0"; res.normal_start_node="s0"; res.hard_start_node="s0"
	_dm.dialogue_resource=res; _dm.start_dialogue()

func _on_opening_end() -> void:
	_phase = Phase.OBSERVE_WATSON
	if _portrait_ctrl: _portrait_ctrl.visible = true
	_watson_obs.show()
	_ui.set_dialogue("提示", "点击华生身上的按钮，观察 4 处线索。")
	_ui.set_dialogue_color(Color(0.5, 0.9, 0.5))
	# 进入观察阶段即自动弹出道具工具栏
	if _toolbar: _toolbar.show_toolbar()

func _on_line(_id: String) -> void:
	var n = _dm.current_node; if not n: return
	var sp = n.speaker
	var col = Color(0.7,0.8,0.9) if sp=="华生" else Color(0.5,0.9,0.5) if sp=="system" else Color(0.85,0.75,0.45)
	if sp=="赫德森太太": col = Color(0.95,0.80,0.60)
	_ui.set_dialogue(sp if sp!="system" else "提示", n.text, n.mood)
	_ui.set_dialogue_color(col)

# ===== 推理墙辅助（场景一为双组：watson / messenger，均走基类统一 _open_wall） =====
func _show_watson_reasoning_wall() -> void:
	_watson_obs.hide()
	if _toolbar: _toolbar.hide_toolbar()
	if _portrait_ctrl: _portrait_ctrl.visible = false
	_phase = Phase.WATSON_REASONING
	var hypo := {"title": "华生刚从阿富汗回来？", "description": "从华生身上的痕迹（手腕肤色分界、左臂旧伤、面色憔悴、军人站姿）推断其身份与经历。",
		"battlefield": {
			"hypotheses": [
				{"id":"W-01","text":"华生手腕有热带晒痕","correct":true},
				{"id":"W-02","text":"华生左臂有旧伤","correct":true},
				{"id":"W-03","text":"华生面色憔悴","correct":true},
				{"id":"W-04","text":"华生站姿像军人","correct":true},
			],
			"contradictions": [],
		},
		"milestones": [
			{"id":"MW-1","text":"华生刚从阿富汗战场归来"},
			{"id":"MW-2","text":"华生是军医（左臂旧伤、军人站姿）"},
			{"id":"MW-3","text":"身份可经观察痕迹推断（演绎法初探）"},
		],
	}
	_open_wall("watson", hypo, func(v: int):
		_watson_v = v
		_start_messenger_phase()
	)

func _start_messenger_phase() -> void:
	# 对齐 08 稿 v3.16.0 §阶段2信使到访（L395-416）
	_phase = Phase.MESSENGER_OBSERVE; _messenger_obs.show()
	if _messenger_portrait_ctrl: _messenger_portrait_ctrl.visible = true
	# 进入信使观察阶段即自动弹出道具工具栏
	if _toolbar: _toolbar.show_toolbar()
	_dm = DialogueManager.new(); add_child(_dm)
	_dm.dialogue_advanced.connect(_on_line)
	_dm.dialogue_ended.connect(_on_messenger_dialogue_end)
	var nodes: Array[Resource] = []
	nodes.append(_dn("m0","系统","（门铃响起）赫德森太太：福尔摩斯先生，有一位信使要送一封信给您，让他进来吗？","click",["m1"],"guide"))
	nodes.append(_dn("m1","福尔摩斯","让他进来吧，谢谢你，女士。","click",["m2"]))
	nodes.append(_dn("m2","信使","（递信封，手背露出锚形文身）福尔摩斯先生，这是特白厄斯·葛莱森警官给您的信。","click",["m3"]))
	nodes.append(_dn("m3","福尔摩斯","（瞥了一眼信使手背，漫不经心）谢谢。您曾经是海军陆战队军士吧。","click",["m4"],"从容"))
	nodes.append(_dn("m4","信使","（惊讶）啊，您怎么知道我是海军陆战队的军士？","click",["m5"]))
	nodes.append(_dn("m5","福尔摩斯","（转向玩家）又一个练习机会。这次，你来试试？","click",["end"],"指导"))
	var res = DialogueResource.new(); res.scene_id="s1_mess"; res.nodes=nodes
	res.easy_start_node="m0"; res.normal_start_node="m0"; res.hard_start_node="m0"
	_dm.dialogue_resource=res; _dm.start_dialogue()

func _on_messenger_dialogue_end() -> void:
	_phase = Phase.MESSENGER_OBSERVE
	_ui.set_dialogue("提示", "点击信使身上的可交互区域。注意分辨干扰项！")
	_ui.set_dialogue_color(Color(0.5,0.9,0.5))

func _show_messenger_reasoning_wall() -> void:
	_messenger_obs.hide(); _phase = Phase.MESSENGER_REASONING
	if _toolbar: _toolbar.hide_toolbar()
	if _messenger_portrait_ctrl: _messenger_portrait_ctrl.visible = false
	var hypo := {"title": "信使是海军陆战队军士？", "description": "从信使身上（锚形文身、络腮胡、挺拔站姿、发号施令神态）推断其军旅身份；注意分辨干扰项（袖口磨损、轻微跛行）。",
		"battlefield": {
			"hypotheses": [
				{"id":"M-01","text":"锚文身=海军标志","correct":true},
				{"id":"M-02","text":"络腮胡=军人常见","correct":true},
				{"id":"M-03","text":"站姿挺拔=军事训练","correct":true},
				{"id":"M-04","text":"发号施令=军士/士官","correct":true},
				{"id":"M-05","text":"袖口磨损=旧衣服（干扰）","correct":false},
				{"id":"M-06","text":"轻微跛行=扭伤（干扰）","correct":false},
			],
			"contradictions": [],
		},
		"milestones": [
			{"id":"MM-1","text":"信使是海军陆战队军士"},
			{"id":"MM-2","text":"锚形文身为海军标志（关键证据）"},
			{"id":"MM-3","text":"袖口磨损/跛行为干扰项，非身份证据"},
		],
	}
	_open_wall("messenger", hypo, func(v: int):
		_messenger_v = v
		_calc_stars(); _show_commission_letter_dialogue()
	)

func _calc_stars() -> void:
	_stars_observe = 2 if _watson_obs.get_recorded() >= 4 and _messenger_obs.get_recorded() >= 6 else 1
	_stars_reason = 3 if _watson_v == 3 and _messenger_v == 3 else (2 if _watson_v >= 2 or _messenger_v >= 2 else 1)
	_stars_insight = 2 if _watson_v >= 2 and _messenger_v >= 2 else 1

func _vname(v: int) -> String:
	match v:
		3: return "VERIFIED"
		2: return "SUPPORTED"
		1: return "INSUFFICIENT"
		_: return "CONTRADICTORY"

func _show_rating() -> void:
	_watson_obs.hide(); _messenger_obs.hide()
	if _portrait_ctrl: _portrait_ctrl.visible = false
	_phase = Phase.RATING
	var w = Control.new(); w.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	w.mouse_filter = Control.MOUSE_FILTER_STOP; add_child(w)
	var bg = ColorRect.new(); bg.color = Color(0.06,0.05,0.08,0.97); bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); w.add_child(bg)
	var tt = Label.new(); tt.text = "场景一 完成"; tt.add_theme_font_size_override("font_size", 32)
	tt.add_theme_color_override("font_color", Color(0.92,0.82,0.45)); tt.position = Vector2(0,60); tt.size = Vector2(1920,50); tt.horizontal_alignment = 1
	w.add_child(tt)
	var items = [{"name":"观察之星","s":_stars_observe},{"name":"推理之星","s":_stars_reason,"d":"华生"+_vname(_watson_v)+" 信使"+_vname(_messenger_v)},{"name":"洞察之星","s":_stars_insight,"d":"双层验证综合判断"}]
	for i in items.size():
		var it = items[i]
		var y = 170 + i*160
		var nl = Label.new(); nl.text = it["name"]; nl.add_theme_font_size_override("font_size", 24); nl.add_theme_color_override("font_color", Color(0.88,0.82,0.72))
		nl.position = Vector2(300,y); nl.size = Vector2(200,35); w.add_child(nl)
		for s in range(it["s"]):
			var sl = Label.new(); sl.text = "★"; sl.add_theme_font_size_override("font_size",32); sl.add_theme_color_override("font_color", Color(0.95,0.78,0.20))
			sl.position = Vector2(500+s*50,y-5); sl.size = Vector2(40,40); w.add_child(sl)
		for s in range(it["s"], 3):
			var sl = Label.new(); sl.text = "☆"; sl.add_theme_font_size_override("font_size",32); sl.add_theme_color_override("font_color", Color(0.35,0.30,0.22))
			sl.position = Vector2(500+s*50,y-5); sl.size = Vector2(40,40); w.add_child(sl)
		if it.has("d"):
			var dl = Label.new(); dl.text = it["d"]; dl.add_theme_font_size_override("font_size",15); dl.add_theme_color_override("font_color", Color(0.55,0.50,0.40))
			dl.position = Vector2(700,y+5); dl.size = Vector2(900,25); w.add_child(dl)
	var cont = Button.new(); cont.text = "存档并进入场景二"; cont.position = Vector2(660,700); cont.size = Vector2(600,65)
	cont.add_theme_font_size_override("font_size",26); cont.add_theme_color_override("font_color", Color(0.92,0.84,0.55))
	cont.add_theme_stylebox_override("normal", _sb(Color(0.50,0.10,0.10,0.95), Color(0.85,0.65,0.25), 2, 4))
	cont.pressed.connect(_show_case_branch.bind(w))
	w.add_child(cont)

func _on_rating_continue(w: Control) -> void:
	w.queue_free(); _save_and_continue()

func _save_and_continue() -> void:
	_phase = Phase.COMPLETE
	if GameStateMachine: GameStateMachine.go_complete()
	if GameManager: GameManager.add_milestone("sc_01_completed")
	if not (GameManager and GameManager.is_guest) and SaveManager:
		# 自动存档必须写入本场景的 scene_state（phase + scene_id + clue_ids），
		# 否则读档时 _restore_saved_state 因 scene_id 不匹配而判定「无存档」→ 场景从头重启。
		var ids: Array = []
		for c in _watson_obs.get_recorded_clues(): ids.append(c.get("id",""))
		for c in _messenger_obs.get_recorded_clues(): ids.append(c.get("id",""))
		await SaveSystem.request_save("scene1", Phase.COMPLETE, {"clue_ids": ids})
		_create_notification("进度已保存")
	else: _create_notification("注册后可解锁云端存档")
	await get_tree().create_timer(2.0).timeout
	SceneLoader.transition_to("res://scenes/scene2.tscn")

# ===== 委托信解锁 + 双钩子结尾（依据 02 §9 双钩子系统 + 委托信解锁） =====
func _show_commission_letter_dialogue() -> void:
	_phase = Phase.RATING
	# 委托信解锁为线索（B-01 前置：信使验证通过 ≥ SUPPORTED 后解锁）
	if ClueSystem:
		ClueSystem.collect_clue_from_catalog(
			"commission_letter", "案件委托信",
			"葛莱森警长的委托：劳瑞斯顿花园街3号发现一具无外伤男尸，疑似中毒。这是承接「血字的研究」一案的正式起点。",
			true, "commission")
	_dm = DialogueManager.new(); add_child(_dm)
	_dm.dialogue_advanced.connect(_on_line)
	_dm.dialogue_ended.connect(_on_commission_ended)
	var nodes: Array[Resource] = []
	nodes.append(_dn("cl0","福尔摩斯","信使留下的，是葛莱森警长的委托信。花园街3号，一具男尸，无外伤——像是中毒。","click",["cl1"],"从容"))
	nodes.append(_dn("cl1","华生","所以真正的案子，从这一刻开始。","click",["cl2"],"思考"))
	nodes.append(_dn("cl2","system","📜 案件委托信已解锁 — 记入侦探笔记（来源：案件委托）","click",["end"],"guide"))
	var res = DialogueResource.new(); res.scene_id="s1_letter"; res.nodes=nodes
	res.easy_start_node="cl0"; res.normal_start_node="cl0"; res.hard_start_node="cl0"
	_dm.dialogue_resource=res; _dm.start_dialogue()

func _on_commission_ended() -> void:
	_show_hooks_dialogue()

## 双钩子（剧情钩子 + 谜题钩子），融入对话不做独立 UI（02 §9 §11）
func _show_hooks_dialogue() -> void:
	_dm = DialogueManager.new(); add_child(_dm)
	_dm.dialogue_advanced.connect(_on_line)
	_dm.dialogue_ended.connect(_on_hooks_ended)
	var nodes: Array[Resource] = []
	# 剧情钩子
	nodes.append(_dn("hk0","福尔摩斯","（瞥了一眼信，嘴角微扬）有意思——伦敦郊区发生了一起谋杀案，警方束手无策。","click",["hk1"],"从容"))
	nodes.append(_dn("hk1","华生","你要去吗？","click",["hk2"],"好奇"))
	nodes.append(_dn("hk2","福尔摩斯","当然。正好——让你见识一下什么叫真正的侦探工作。","click",["hk3"],"自信"))
	# 谜题钩子
	nodes.append(_dn("hk3","system","委托信上只有短短几行字——死者是谁？死在哪？怎么死的？（推理战场「案件三要素」待解问题已记录）","click",["end"],"guide"))
	var res = DialogueResource.new(); res.scene_id="s1_hooks"; res.nodes=nodes
	res.easy_start_node="hk0"; res.normal_start_node="hk0"; res.hard_start_node="hk0"
	_dm.dialogue_resource=res; _dm.start_dialogue()

func _on_hooks_ended() -> void:
	_show_rating()

# ===== 分支 B-01：承接 / 拒绝案件（02 §9 §7） =====
func _show_case_branch(w: Control) -> void:
	w.queue_free()
	var p = Control.new(); p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); p.mouse_filter = Control.MOUSE_FILTER_STOP; add_child(p)
	var dim = ColorRect.new(); dim.color = Color(0,0,0,0.7); dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE; p.add_child(dim)
	var f = Panel.new(); f.size = Vector2(660,360); f.position = Vector2(630,310)
	f.add_theme_stylebox_override("panel", _sb(Color(0.13,0.10,0.07,0.97), Color(0.78,0.62,0.28),3,8)); p.add_child(f)
	var t = Label.new(); t.text = "是否承接这桩案件？"; t.add_theme_font_size_override("font_size",26)
	t.add_theme_color_override("font_color", Color(0.92,0.82,0.45)); t.position = Vector2(40,28); t.size = Vector2(580,40); f.add_child(t)
	var sub = Label.new(); sub.text = "（分支 B-01）承接后将前往劳瑞斯顿花园街3号勘查现场"; sub.add_theme_font_size_override("font_size",15)
	sub.add_theme_color_override("font_color", Color(0.6,0.55,0.45)); sub.position = Vector2(40,76); sub.size = Vector2(580,36); f.add_child(sub)
	var accept = Button.new(); accept.text = "承接案件"; accept.position = Vector2(60,210); accept.size = Vector2(250,60)
	accept.add_theme_font_size_override("font_size",22); accept.add_theme_color_override("font_color", Color(0.92,0.84,0.55))
	accept.add_theme_stylebox_override("normal", _sb(Color(0.20,0.40,0.15,0.95), Color(0.60,0.85,0.30),2,4))
	accept.pressed.connect(func(): p.queue_free(); _accept_case()); f.add_child(accept)
	var reject = Button.new(); reject.text = "拒绝委托"; reject.position = Vector2(350,210); reject.size = Vector2(250,60)
	reject.add_theme_font_size_override("font_size",22); reject.add_theme_color_override("font_color", Color(0.92,0.84,0.55))
	reject.add_theme_stylebox_override("normal", _sb(Color(0.40,0.15,0.10,0.95), Color(0.85,0.45,0.25),2,4))
	reject.pressed.connect(func(): p.queue_free(); _reject_case()); f.add_child(reject)

func _accept_case() -> void:
	_phase = Phase.COMPLETE
	if GameManager: GameManager.add_milestone("sc_01_completed")
	if not (GameManager and GameManager.is_guest) and SaveManager:
		var ids: Array = []
		for c in _watson_obs.get_recorded_clues(): ids.append(c.get("id",""))
		for c in _messenger_obs.get_recorded_clues(): ids.append(c.get("id",""))
		await SaveSystem.request_save("scene1", Phase.COMPLETE, {"clue_ids": ids})
		_create_notification("进度已保存")
	else: _create_notification("注册后可解锁云端存档")
	await get_tree().create_timer(1.0).timeout
	SceneLoader.transition_to("res://scenes/scene2.tscn")

func _reject_case() -> void:
	_create_notification("你拒绝了这桩委托 — 回到贝克街的日常")
	await get_tree().create_timer(1.5).timeout
	if GameStateMachine: GameStateMachine.go_menu()
	else: SceneLoader.transition_to("res://scenes/main_menu.tscn")

# ===== 笔记、证物（场景一自建弹窗内容，沿用基类 _popup 统一样式） =====
func _clue_sources() -> Array:
	return ["watson", "messenger"]

func _open_notebook() -> void:
	var items: Array = []
	for c in _watson_obs.get_recorded_clues():
		items.append({"name":c["name"], "desc":c["desc"], "src":"华生"})
	for c in _messenger_obs.get_recorded_clues():
		items.append({"name":c["name"], "desc":c["desc"], "src":"信使"})
	_popup("侦探笔记", items)

func _show_inventory_panel() -> void:
	var items: Array = []
	if _watson_obs.get_recorded() > 0: items.append({"name":"📝 华生线索","desc":"已收集 "+str(_watson_obs.get_recorded())+"/4 条"})
	if _messenger_obs.get_recorded() > 0: items.append({"name":"📝 信使线索","desc":"已收集 "+str(_messenger_obs.get_recorded())+"/6 条"})
	if items.is_empty(): items.append({"name":"暂无物品","desc":"继续探案，收集线索和证物"})
	_popup("物品栏", items)

func _show_options_panel() -> void:
	var p = Control.new(); p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); p.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(p)
	var dim = ColorRect.new(); dim.color = Color(0,0,0,0.7); dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE; p.add_child(dim)
	var f = Panel.new(); f.size = Vector2(600, 500); f.position = Vector2(660, 290)
	f.add_theme_stylebox_override("panel", _sb(Color(0.13,0.10,0.07,0.97), Color(0.78,0.62,0.28), 3, 8))
	p.add_child(f)
	var t = Label.new(); t.text = "⚙  选项"; t.add_theme_font_size_override("font_size", 30)
	t.add_theme_color_override("font_color", Color(0.92,0.82,0.45)); t.position = Vector2(30,20); t.size = Vector2(540,40)
	f.add_child(t)
	var sep = ColorRect.new(); sep.color = Color(0.55,0.42,0.20,0.5); sep.position = Vector2(30,68); sep.size = Vector2(540,1)
	f.add_child(sep)
	var info = Label.new()
	info.text = "难度模式: "+["简单 (自动高亮)","普通 (标准提示)","困难 (无提示)"][_difficulty]+"\n\n操作: 点击 Enter/Space 推进对话\n场景: 贝克街221B 实验室\n案件: 血字的研究\n\n    ✦  音效与音乐  — 即将开放\n    ✦  画面质量     — 自适应\n    ✦  语言        — 简体中文"
	info.add_theme_font_size_override("font_size", 17); info.add_theme_color_override("font_color", Color(0.85,0.78,0.62))
	info.position = Vector2(30, 90); info.size = Vector2(540, 320)
	f.add_child(info)
	var diff_names = ["简单", "普通", "困难"]
	for i in 3:
		var db = Button.new(); db.text = diff_names[i]
		db.position = Vector2(30 + i*190, 340); db.size = Vector2(175, 45)
		db.add_theme_font_size_override("font_size", 20); db.add_theme_color_override("font_color", Color(0.92,0.84,0.55))
		db.add_theme_stylebox_override("normal", _sb(Color(0.20,0.15,0.10,0.95), Color(0.60,0.48,0.25) if i!=_difficulty else Color(0.90,0.65,0.25), 2, 4))
		db.pressed.connect(func(idx=i): _difficulty = idx; _create_notification("难度已切换为: "+diff_names[idx]); p.queue_free())
		f.add_child(db)
	var cb = Button.new(); cb.text = "关闭"; cb.position = Vector2(170, 420); cb.size = Vector2(260, 45)
	cb.add_theme_font_size_override("font_size",20); cb.add_theme_color_override("font_color", Color(0.92,0.84,0.55))
	cb.add_theme_stylebox_override("normal", _sb(Color(0.20,0.15,0.10,0.95), Color(0.60,0.48,0.25), 2, 4))
	cb.pressed.connect(func(): p.queue_free())
	f.add_child(cb)

func _input(event: InputEvent) -> void:
	if not _dm or not _dm.is_active(): return
	if event is InputEventMouseButton and event.pressed: _dm.advance(); return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_SPACE or event.keycode == KEY_E: _dm.advance()
