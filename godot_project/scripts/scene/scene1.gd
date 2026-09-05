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
var _holmes_portrait_ctrl: Control = null  # 福尔摩斯全身立绘控件（仅在开场[MRS_HUDSON/OPENING]阶段显示）
var _watson_v := 0
var _messenger_v := 0
var _watson_clues: Array = []
var _messenger_clues: Array = []
# 教学墙状态隔离（需求：华生/信使为独立推理环节，互不携带内容）：各自独立的图谱 state 字典，
# 均不写入 ClueSystem.case_wall_state（故也不会泄漏到场景二~八）。
var _watson_wall_state: Dictionary = {}
var _messenger_wall_state: Dictionary = {}
var _stars_observe := 1
var _stars_reason := 1
var _stars_insight := 1
var _look_active := false
var _talk_active := false

## 场景一是贝克街221B室内（华生登场），必须用维多利亚起居室。
## ⚠️ 曾误挂 crime_scene_1920x1080.jpg（命案现场），与场景三「劳瑞斯顿花园街3号·室内」
## 内容撞车，玩家在场景一会看到场景三的现场图。换图时注意与各场景所在地对应：
##   scene1 贝克街221B室内 / scene2 花园外景 / scene3 命案现场室内。
func scene_background() -> Texture2D: return load("res://assets/backgrounds/screen01-sofa01.png")

# 华生观察及之后阶段使用「开门(门廊视角)」背景
func _opendoor_bg() -> Texture2D: return load("res://assets/backgrounds/screen01-opendoor.png")

func _ready() -> void:
	super._ready()
	# GDScript 类级 Dictionary 默认值是实例间共享的，必须逐实例重建（基类已对 _wall_state 这样做）。
	_watson_wall_state = {}
	_messenger_wall_state = {}

## 恢复存档进度 — 返回 true 表示有存档且已恢复，false 表示新游戏。
## 两组观察器分别同步 ClueSystem（单一真相源），并以存档 clue_ids 为权威，
## 杜绝「场景内进度」与「推理墙（ClueSystem）」不一致的「两层皮」。
func _restore_saved_state() -> bool:
	var ss = SaveSystem.take_save_state("scene1")
	if ss.is_empty(): return false
	var saved_phase := int(ss.get("phase", 0))
	var saved_ids: Array = ss.get("clue_ids", [])
	# 修复（2026-08-19 思傅报）：恢复推理墙持久化状态（relations/节点位置/associated/milestones/verified 等）
	# 此前 _do_save 未把 _wall_state 存进 data → 读档后关系与位置全部丢失。
	var saved_wall_state: Dictionary = ss.get("wall_state", {})
	if not saved_wall_state.is_empty():
		_wall_state = saved_wall_state
	# 教学墙状态隔离：两堵墙各自独立恢复（旧存档仅有单一 wall_state，这里兼容忽略，教学进度重新建立即可）
	var saved_ws: Dictionary = ss.get("wall_state_watson", {})
	if not saved_ws.is_empty():
		_watson_wall_state = saved_ws
	var saved_ms: Dictionary = ss.get("wall_state_messenger", {})
	if not saved_ms.is_empty():
		_messenger_wall_state = saved_ms
	# 兼容旧存档：早期华生左肩线索 id 为 "shoulder"（现统一为 "arm"）、合并脸线索 id 为 "face"
	# （现拆分为 face_dark/face_haggard）。只做读取时的就地映射，绝不改写或删除玩家存档文件。
	for i in range(saved_ids.size()):
		if str(saved_ids[i]) == "shoulder": saved_ids[i] = "arm"
		elif str(saved_ids[i]) == "face": saved_ids[i] = "face_dark"
	if ClueSystem:
		ClueSystem.clear_source("watson")
		ClueSystem.clear_source("messenger")
		for cid in saved_ids:
			var h = _find_hotspot(cid)
			if not h.is_empty():
				var src := "watson" if cid in ["wrist","arm","face_dark","face_haggard","pose","medical"] else "messenger"
				ClueSystem.collect_clue_from_catalog(cid, h.get("name", cid), h.get("desc",""), h.get("correct", true), src)
	_phase = saved_phase
	# 读到终局阶段时，阻止后续「进入场景二」按钮再次自动存档，避免 identical 重复槽位。
	_suppress_terminal_save = _is_terminal_phase(saved_phase)
	_create_notification("✅ 读档成功 — 已恢复至「" + _phase_name(saved_phase) + "」")
	# 读档恢复到「华生观察及其后」阶段时，使用开门(门廊视角)背景，福尔摩斯全身立绘隐藏（仅开场显示）
	if saved_phase >= Phase.OBSERVE_WATSON:
		_ui.set_scene_background(_opendoor_bg())
		if _holmes_portrait_ctrl: _holmes_portrait_ctrl.visible = false
	else:
		if _holmes_portrait_ctrl: _holmes_portrait_ctrl.visible = true

	match saved_phase:
		Phase.MRS_HUDSON:
			_show_mrs_hudson_dialogue()
			return true
		Phase.OPENING:
			_show_opening_dialogue()
			return true
		Phase.OBSERVE_WATSON:
			if _portrait_ctrl: _portrait_ctrl.visible = true
			_ui.restore_observer(_watson_obs, saved_ids, ["wrist","arm","face_dark","face_haggard","pose","medical"])
			if _watson_obs.get_recorded() >= _watson_obs.needs_count():
				_on_watson_all_recorded(_watson_obs.get_recorded_clues()); return true
			_ui.set_dialogue("提示", "已恢复进度 — 华生观察阶段（已收集 "+str(_watson_obs.get_recorded())+"/"+str(_watson_obs.needs_count())+" 条）\n点击 LOOK 查看剩余标记点")
			return true
		Phase.WATSON_REASONING:
			_phase = Phase.WATSON_REASONING; _wall_auto = false
			_ui.restore_observer(_watson_obs, saved_ids, ["wrist","arm","face_dark","face_haggard","pose","medical"])
			_show_watson_reasoning_wall()
			return true
		Phase.MESSENGER_OBSERVE:
			_phase = Phase.MESSENGER_OBSERVE
			if _messenger_portrait_ctrl: _messenger_portrait_ctrl.visible = true
			_ui.restore_observer(_messenger_obs, saved_ids, ["tattoo","beard","posture","manner","sleeve","limp"])
			if _messenger_obs.get_recorded() >= _messenger_obs.needs_count():
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
			# 场景一评分由各推理墙得出的实例星级，未走 StarRatingSystem 链，读档须显式恢复，
			# 否则 _show_rating 读到默认值（1⭐），与游玩时实得星级不符（评价体系丢失）。
			if ss.has("stars_observe"): _stars_observe = int(ss["stars_observe"])
			if ss.has("stars_reason"): _stars_reason = int(ss["stars_reason"])
			if ss.has("stars_insight"): _stars_insight = int(ss["stars_insight"])
			if ss.has("watson_v"): _watson_v = int(ss["watson_v"])
			if ss.has("messenger_v"): _messenger_v = int(ss["messenger_v"])
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

func _is_terminal_phase(p: int) -> bool:
	return p == Phase.RATING or p == Phase.COMPLETE

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
	var w = [{"id":"wrist","name":"肤色黑白分明","desc":"华生手腕处肤色分界明显——长期暴露于热带阳光，刚从热带归来"},{"id":"arm","name":"左臂损伤","desc":"华生左臂动作略显僵硬——战场负伤留下的旧疾"},{"id":"face_dark","name":"脸色黝黑","desc":"华生脸部肤色明显偏深——长期热带日照的痕迹"},{"id":"face_haggard","name":"面容憔悴","desc":"华生面容灰暗、眼窝深陷——久病初愈、长途劳顿的痕迹"},{"id":"pose","name":"军人气质","desc":"华生站姿挺拔、气质干练——典型的军人作风"},{"id":"medical","name":"身上有消毒液气味","desc":"华生身上有淡淡的消毒液气味——长期接触医院与战地救护的印记"}]
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
		# 华生立绘（1024 正方图）：显示高与福尔摩斯一致（福尔摩斯框 373x843 contain 显示高≈831）。
		# 正方图须框 ≥831 → (843,843) box=831 contain 显示 831。站位：门框(源x336)与壁炉(源x330)
		# 交界处≈场景 x625 → pos.x = 625-843/2 ≈ 203。
		# 脚底对齐三尊共同地面线 y≈920 → box 高831，脚底=pos.y+6+831 → pos.y=83。
		_portrait_ctrl = _ui.add_portrait(tex, "华生", Vector2(203, 83), Vector2(843, 843), false)
		# 默认隐藏：仅在 OBSERVE_WATSON 阶段显示
		if _portrait_ctrl: _portrait_ctrl.visible = false
	# 信使立绘（默认隐藏，MESSENGER_OBSERVE 阶段显示）
	var mtex = load("res://assets/characters/messenger/messenger_portrait.png")
	if mtex:
		# 新图 808x1920（竖图，宽高比 0.421），放大 4/3 后框 373x843(box=361x831)。
		# 站「门框前、桌子旁」：门框右竖边(源x572→场景1073)与桌子左缘(源x634→场景1189)
		# 之间的空档，立绘中心 x≈1100 → pos.x = 1100-373/2 ≈ 913。
		# 脚底对齐三尊共同地面线 y≈920 → box 高831，脚底=pos.y+6+831 → pos.y=83。
		_messenger_portrait_ctrl = _ui.add_portrait(mtex, "信使", Vector2(913, 83), Vector2(373, 843), false)
		if _messenger_portrait_ctrl: _messenger_portrait_ctrl.visible = false  # MESSENGER_OBSERVE 阶段才显示（_start_messenger_phase）
	# 福尔摩斯全身立绘（新竖图 391x1024，透明底）：仅开场（华生线索收集前）阶段显示。
	# 放大 4/3 后框 373x843；开场 sofa 场景左侧窗旁，脚底保持 y≈923 → pos.y=923-6-831=86。
	var htex = load("res://assets/characters/holmes/holmes_fullbody.png")
	if htex:
		_holmes_portrait_ctrl = _ui.add_portrait(htex, "福尔摩斯", Vector2(210, 86), Vector2(373, 843), false)
		# 默认显示：开场阶段（sofa 场景）即可见，进入华生观察（_on_opening_end）时隐藏

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
		{"id":"wrist","label":"肤色黑白分明","x":580,"y":400,"w":100,"h":60,"desc":"手腕处肤色分界明显——长期暴露于热带阳光，刚从热带归来",
		 "crop":{"x":0.08,"y":0.20,"cx":0.30,"cy":0.42},"image":"res://assets/characters/watson/watson_teaching.png","anchor":"wrist"},
		{"id":"arm","label":"左臂损伤","x":450,"y":450,"w":100,"h":70,"desc":"左臂动作略显僵硬——战场负伤留下的旧疾",
		 "crop":{"x":0.69,"y":0.31,"cx":0.89,"cy":0.65},"image":"res://assets/characters/watson/watson_teaching.png","anchor":"shoulder"},
		{"id":"face_dark","label":"脸色黝黑","x":520,"y":200,"w":110,"h":60,"desc":"脸部肤色明显偏深——长期热带日照的痕迹",
		 "crop":{"x":0.297,"y":0.0,"cx":0.637,"cy":0.14},"image":"res://assets/characters/watson/watson_teaching.png","anchor":"face"},
		{"id":"face_haggard","label":"面容憔悴","x":520,"y":290,"w":110,"h":60,"desc":"面容灰暗、眼窝深陷——久病初愈的痕迹",
		 "crop":{"x":0.297,"y":0.0,"cx":0.637,"cy":0.14},"image":"res://assets/characters/watson/watson_teaching.png","anchor":"face"},
		{"id":"pose","label":"军人气质","x":500,"y":600,"w":130,"h":80,"desc":"站姿挺拔、气质干练——典型的军人作风",
		 "crop":{"x":0.0,"y":0.0,"cx":1.0,"cy":1.0},"image":"res://assets/characters/watson/watson_teaching.png","anchor":"pose"},
		{"id":"medical","label":"身上有消毒液气味","x":500,"y":430,"w":120,"h":120,"desc":"身上有淡淡的消毒液气味——长期接触医院与战地救护的印记",
		 "crop":{"x":0.35,"y":0.27,"cx":0.65,"cy":0.53},"image":"res://assets/characters/watson/watson_teaching.png","anchor":"torso"},
	], tex, _portrait_ctrl, "res://assets/characters/watson/watson_teaching.png")
	_watson_obs.all_recorded.connect(_on_watson_all_recorded)
	_watson_obs.clue_recorded.connect(_on_collect_clue.bind("watson"))
	# 把观察热点转发到全局 SceneEventBus，使工具栏能用「放大镜/卷尺/黄页」定位当前细节
	_watson_obs.hotspot_clicked.connect(_on_obs_hotspot_to_tool)

	_messenger_obs = ClueObserver.new(); _messenger_obs.name = "messenger_observer"; add_child(_messenger_obs)
	var mess_tex = load("res://assets/characters/messenger/messenger_portrait.png")
	var mhot := DifficultyManager.filter_hotspots_by_difficulty([
		# 热点位置与新全身立绘 560,343/150,447（等比 0.75）对齐，观察时仍用 spritesheet 细节图
		{"id":"tattoo","label":"手背锚文身","x":590,"y":628,"w":68,"h":30,"desc":"蓝色锚形文身 -> 海军标志","correct":true,
		 "crop":{"x":0.16,"y":0.39,"cx":0.46,"cy":0.59},"image":"res://assets/characters/messenger/messenger_spritesheet.png","anchor":"tattoo"},
		{"id":"beard","label":"络腮胡须","x":598,"y":463,"w":68,"h":34,"desc":"军人式络腮胡 -> 军队常见","correct":true,
		 "crop":{"x":0.36884,"y":0.1568,"cx":0.59970,"cy":0.3408},"image":"res://assets/characters/messenger/messenger_spritesheet.png","anchor":"beard"},
		{"id":"posture","label":"笔挺站姿","x":583,"y":583,"w":75,"h":41,"desc":"昂首挺胸 -> 军事训练","correct":true,
		 "crop":{"x":0.0,"y":0.0,"cx":1.0,"cy":1.0},"image":"res://assets/characters/messenger/messenger_spritesheet.png","anchor":"posture"},
		{"id":"manner","label":"发号施令","x":594,"y":418,"w":71,"h":34,"desc":"发号施令 -> 军士/士官","correct":true,
		 "crop":{"x":0.35698,"y":0.0855,"cx":0.60997,"cy":0.3500},"image":"res://assets/characters/messenger/messenger_spritesheet.png","anchor":"manner"},
		{"id":"sleeve","label":"袖口磨损","x":631,"y":553,"w":60,"h":30,"desc":"袖口磨损 -> 干扰:衣服旧了","correct":false,
		 "crop":{"x":0.6606,"y":0.52,"cx":0.8406,"cy":0.72},"image":"res://assets/characters/messenger/messenger_spritesheet.png","anchor":"sleeve"},
		{"id":"limp","label":"走路略跛","x":598,"y":726,"w":68,"h":34,"desc":"右腿略跛 -> 干扰:扭伤","correct":false,
		 "crop":{"x":0.4905,"y":0.7800,"cx":0.7005,"cy":0.98768},"image":"res://assets/characters/messenger/messenger_spritesheet.png","anchor":"limp"},
	])
	# 困难模式 70% 深度干扰项：信使口袋露出半张药房收据（看似线索，实际只是感冒药）— 08 §阶段2 L545
	if DifficultyManager.current_difficulty == DifficultyManager.Difficulty.HARD and randf() < 0.7:
		mhot.append({"id":"receipt","label":"半张药房收据","x":622,"y":600,"w":62,"h":32,
			"desc":"信使口袋露出半张药房收据——看似线索，实际只是感冒药","correct":false,
			"crop":{"x":0.62,"y":0.62,"cx":0.80,"cy":0.82},"image":"res://assets/characters/messenger/messenger_spritesheet.png","anchor":"receipt"})
	_messenger_obs.setup(sa, _ui._dialogue_label, _ui._speaker_label, mhot, mess_tex, _messenger_portrait_ctrl, "res://assets/characters/messenger/messenger_portrait.png")
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
			source,
			-1,
			clue_data.get("image", ""),
			clue_data.get("anchor", "")
		)
	# M1 摄像机：记录一条线索后平滑推近到该部位（点线索推近）
	if _ui:
		var obs = _current_observer()
		if obs != null:
			var wp = obs.get_clue_world_point(clue_id)
			if wp != Vector2.ZERO:
				_ui.focus_world_point(wp, 2.2)

# ===== 基类钩子：地图 / 案件簿（内容） =====
func map_locations() -> Array:
	return [{"t":"贝克街221B","d":"福尔摩斯与华生的寓所 — 当前场景"},{"t":"劳瑞斯顿花园街3号","d":"葛莱森警长发现的尸体现场 — 待调查"},{"t":"苏格兰场","d":"伦敦警察总部 — 葛莱森办公处"}]

func casebook_steps() -> Array:
	return ["赫德森太太开场", "华生观察练习", "信使观察练习", "推理验证完成"]

func casebook_done_flags() -> Array:
	return [_phase >= Phase.OPENING, _watson_obs.get_recorded() >= _watson_obs.needs_count(), _messenger_obs.get_recorded() >= _messenger_obs.needs_count(), _phase >= Phase.MESSENGER_REASONING]

func _enter_arrival() -> void:
	if _ui: _ui.set_camera_enabled(false)   # 开场对话阶段禁用摄像机
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
	if _phase == Phase.OBSERVE_WATSON: _watson_obs.show(); _ui.set_dialogue("提示", _observe_hint("华生")); _ui.set_dialogue_color(Color(0.5,0.9,0.5))
	elif _phase == Phase.MESSENGER_OBSERVE: _messenger_obs.show(); _ui.set_dialogue("提示", _observe_hint("信使")); _ui.set_dialogue_color(Color(0.5,0.9,0.5))
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
	var data := {"clue_ids": [], "watson_recorded": 0, "messenger_recorded": 0,
		"wall_state_watson": _watson_wall_state.duplicate(true),
		"wall_state_messenger": _messenger_wall_state.duplicate(true)}
	var ids: Array = []
	for c in _watson_obs.get_recorded_clues(): ids.append(c.get("id",""))
	for c in _messenger_obs.get_recorded_clues(): ids.append(c.get("id",""))
	data["clue_ids"] = ids
	for cid in ids:
		if cid in ["wrist","arm","face_dark","face_haggard","pose","medical"]: data["watson_recorded"] += 1
		else: data["messenger_recorded"] += 1
	print("[SAVE scene1] phase=", _phase, " data=", data)
	# 保存不需要选槽位：自动分配（空槽位优先，满则覆盖最旧）
	await SaveSystem.request_save("scene1", _phase, data, slot)
	_create_notification("✅ 进度已保存")

# ===== 对话（场景一用显式 next 的 _dn 构造器） =====
func _dn(id, sp, txt, tri, nxt, mood="neutral", diff_filter: int = 0, sd: String = "") -> DialogueNodeResource:
	var n = DialogueNodeResource.new()
	n.node_id=id; n.speaker=sp; n.text=txt; n.trigger=tri
	var nn: Array[String] = []
	for s in nxt:
		if s is String: nn.append(s)
	n.next_nodes = nn
	n.mood = mood
	if sd != "": n.stage_direction = sd
	n.difficulty_filter = diff_filter   # 0=全难度 / 1=EASY / 2=NORMAL / 3=HARD（见 DialogueNodeResource.should_show）
	return n

## 观察提示/返回尾句已下沉为基类 DetectiveScene._observe_hint / _resume_suffix
## （场景一仅调用，传 person=true 用「身上」措辞；详见基类）。

func _show_mrs_hudson_dialogue() -> void:
	if _ui: _ui.set_camera_enabled(false)   # 对话阶段禁用摄像机
	# 对齐 08 稿 v3.16.0 §阶段1初次见面（L133-153）：悬念开场 + 赫德森太太端茶
	_dm = DialogueManager.new(); add_child(_dm)
	_dm.dialogue_advanced.connect(_on_line)
	_dm.dialogue_ended.connect(_on_mrs_hudson_end)
	var nodes: Array[Resource] = []
	nodes.append(_dn("h0","赫德森太太","福尔摩斯先生，茶来了。哦，华生医生，欢迎您。","click",["h1"]))
	nodes.append(_dn("h1","福尔摩斯","您好，我是福尔摩斯，您应该是从阿富汗刚回来不久吧。","click",["h2"],"自信",0,"上下打量华生，停顿两秒，把雪茄从嘴边拿开"))
	nodes.append(_dn("h2","华生","什么？","click",["h3"],"吃惊",0,"愣住"))
	nodes.append(_dn("h3","福尔摩斯","确切的说，您是阿富汗军医。我说对了吗？","click",["h4"],"从容",0,"平静地"))
	nodes.append(_dn("h4","华生","您——您怎么知道？我们才刚见面不到十秒！","click",["h5"],"惊讶",0,"惊讶得差点从椅子上站起来"))
	nodes.append(_dn("h5","福尔摩斯","你看这位新朋友——他不相信自己的眼睛。不如你来做个见证，替我告诉他：我是怎么看出来的？","click",["h_w"],"指导",0,"没回答华生，转向玩家，眼神里多了一点兴致"))
	nodes.append(_dn("h_w","华生","……我更想知道你是怎么看出来的。","click",["h5_e","h5_n","h5_h"],"思考",0,"小声嘟囔"))
	# 不同难度不同引导：h5 之后分流，难度过滤节点须「链式为 next」(h5_e→h5_n→h5_h→end)，
	# 引擎 should_show 跳过隐藏变体时才会依次走到第一个可见变体（否则会误判 end 提前结束）。
	nodes.append(_dn("h5_e","福尔摩斯","从手腕晒痕、左臂旧伤、脸色黝黑、面容憔悴、军人站姿、身上的消毒液气味这几处下手，每条都要讲出证据。","click",["h5_n"],"指导",1,"低声"))
	nodes.append(_dn("h5_n","福尔摩斯","用你观察到的证据，把结论串起来。","click",["h5_h"],"指导",2,"点头"))
	nodes.append(_dn("h5_h","福尔摩斯","……","click",["end"],"从容",3,"什么也没说，只是望着你"))
	var res = DialogueResource.new(); res.scene_id="s1_intro"; res.nodes=nodes
	res.easy_start_node="h0"; res.normal_start_node="h0"; res.hard_start_node="h0"
	_dm.dialogue_resource=res; _dm.start_dialogue()

func _on_mrs_hudson_end() -> void:
	_dm.dialogue_ended.disconnect(_on_mrs_hudson_end)
	_dm.dialogue_ended.connect(_on_opening_end)
	_show_opening_dialogue()

func _show_opening_dialogue() -> void:
	if _ui: _ui.set_camera_enabled(false)   # 对话阶段禁用摄像机
	# 对齐 08 稿 v3.16.0 §阶段1教程环节（L155-282）：六步探索闭环引导
	# ⚠️ 不同难度不同台词：三难度各走独立链（start_node 分流），
	#    EASY 逐条点出部位+全部高亮 / NORMAL 标准提示 / HARD 无引导、严格证据
	_phase = Phase.OPENING
	var nodes: Array[Resource] = []
	# —— 简单（EASY）：详细引导，逐条点出部位 ——
	nodes.append(_dn("s0_e","福尔摩斯","看这位朋友——手腕的晒痕、左臂的旧伤、脸色的黝黑、面容的憔悴、军人的站姿、身上消毒液的气味，都在说他刚从战场回来。来，我们把这些一条条看清楚。","click",["s1_e"],"从容"))
	nodes.append(_dn("s1_e","系统","[新手教程] 第一次观察\n目标：找出 6 条线索（手腕晒痕、左臂旧伤、脸色黝黑、面容憔悴、军人站姿、身上消毒液气味）\n操作：可观察点已全部高亮，点击圆圈逐一查看细节","click",["s2_e"],"guide"))
	nodes.append(_dn("s2_e","系统","所有可观察点已高亮，点击华生身上高亮的圆圈即可。完成后进入推理墙验证。","click",["end"],"guide"))
	# —— 普通（NORMAL）：标准提示 ——
	nodes.append(_dn("s0_n","福尔摩斯","证据在你身上: 手腕、左臂、脸色、面容、站姿、身上的消毒液气味","click",["s1_n"],"从容"))
	nodes.append(_dn("s1_n","系统","[新手教程] 第一次观察\n目标：找出 6 条线索，证明'华生是阿富汗军医'\n操作：点击华生身上高亮的圆圈，逐一观察细节","click",["s2_n"],"guide"))
	nodes.append(_dn("s2_n","系统","点击华生身上高亮的圆圈。完成后进入推理墙验证。","click",["end"],"guide"))
	# —— 困难（HARD）：无引导，严格证据 ——
	nodes.append(_dn("s0_h","福尔摩斯","……证据都在他身上。自己看，别等我喂。","click",["s1_h"],"从容",0,"审视华生"))
	nodes.append(_dn("s1_h","系统","[硬核模式] 第一次观察\n目标：凭观察找出 6 条线索\n无任何高亮提示，自行判断华生身上值得注意的细节","click",["s2_h"],"guide"))
	nodes.append(_dn("s2_h","系统","无提示。自行观察华生，找出关键线索后进入推理墙。","click",["end"],"guide"))
	var res = DialogueResource.new(); res.scene_id="s1_open"; res.nodes=nodes
	res.easy_start_node="s0_e"; res.normal_start_node="s0_n"; res.hard_start_node="s0_h"
	_dm.dialogue_resource=res; _dm.start_dialogue()

func _on_opening_end() -> void:
	_phase = Phase.OBSERVE_WATSON
	# 进入华生观察阶段起切换到「从门廊向内看」背景（含之后信使观察等全部阶段）
	if _ui: _ui.set_scene_background(load("res://assets/backgrounds/screen01-opendoor.png"))
	if _ui: _ui.set_camera_enabled(true)   # 进入观察：启用摄像机（统览/缩放/拖拽）
	# 福尔摩斯全身立绘仅属于开场（sofa 场景），华生观察开始时隐藏
	if _holmes_portrait_ctrl: _holmes_portrait_ctrl.visible = false
	if _portrait_ctrl: _portrait_ctrl.visible = true
	_watson_obs.show()
	_ui.set_dialogue("提示", _observe_hint("华生", true) + "，观察 6 处线索。")
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
	if _ui: _ui.set_camera_enabled(false)   # 推理墙：禁用摄像机
	# 华生教学链（2026-09-05 用户关系表）：三层结论逐级推导——
	# 热带线：肤色→热带生活过→英国殖民地为阿富汗；军医线：军人气质＋医疗行业→是名军医（无结论2）；
	# 伤痛线：旧伤＋久病→承受伤痛→伤害来自军事任务；三线汇聚"在阿富汗服役过"→锚华生。
	# 维护规则：gate_hypo_ids 引用结论节点时必须写完整节点 id（"conclusion_C-A1"，含前缀），
	# 真相表（case_branch_truth.gd CH01W）与 gate 同源，norm 会剥前缀。
	var hypo := {"title": "华生刚从阿富汗回来？", "persons": [{"id": "NPC_WT"}], "description": "从华生身上的痕迹（手腕肤色分明、脸色黝黑、军人站姿、消毒液气味、左臂旧伤、面容憔悴）逐层推断：肤色→热带生活→英国殖民地为阿富汗；军人气质＋医疗行业→军医；旧伤＋久病→伤痛来自军事任务；三线闭合→在阿富汗服役过。",
		"battlefield": {
			"hypotheses": [
				{"id":"W-A1","text":"不是原来的肤色","correct":true,"gate_clue_ids":["wrist","face_dark"]},
				{"id":"W-B1","text":"多年军事行业形成的气质","correct":true,"gate_clue_ids":["pose"]},
				{"id":"W-B2","text":"从事医疗行业","correct":true,"gate_clue_ids":["medical"]},
				{"id":"W-C1","text":"左臂受过伤未完全恢复","correct":true,"gate_clue_ids":["arm"]},
				{"id":"W-C2","text":"久病初愈而又历尽了苦难","correct":true,"gate_clue_ids":["face_haggard"]},
			],
			"conclusions": [
				{"id":"C-A1","text":"曾经在热带生活过","correct":true,"dir":"affirm","subject":["华生"],"object":["热带"],"match_keys":["在热带生活过","热带生活","热带待过","在热带待过"],"gate_hypo_ids":["W-A1"],"adopt_desc":"肤色分明与黝黑的脸——他曾在热带生活过。"},
				{"id":"C-B1","text":"是名军医","correct":true,"dir":"affirm","subject":["华生"],"object":["军医","医生"],"match_keys":["军医","是医生","医疗兵","医务人员"],"gate_hypo_ids":["W-B1","W-B2"],"adopt_desc":"军人气质与医疗行业的痕迹，合起来是一名军医。"},
				{"id":"C-C1","text":"承受了这个年龄本不该承受的伤痛","correct":true,"dir":"affirm","subject":["华生"],"object":["伤痛","苦难"],"match_keys":["承受伤痛","不该承受的伤痛","经历过苦难","久病初愈"],"gate_hypo_ids":["W-C1","W-C2"],"adopt_desc":"旧伤未愈又久病初愈——他承受了不该承受的伤痛。"},
				{"id":"C-A2","text":"英国在热带的殖民地为阿富汗","correct":true,"dir":"affirm","subject":["英国"],"object":["阿富汗"],"match_keys":["阿富汗","英国殖民地是阿富汗","热带殖民地是阿富汗","去过阿富汗"],"gate_hypo_ids":["conclusion_C-A1"],"adopt_desc":"英国在热带的殖民地——最近的那块是阿富汗。"},
				{"id":"C-C2","text":"不该有的伤害只可能来自军事任务","correct":true,"dir":"affirm","subject":["伤害"],"object":["军事任务"],"match_keys":["军事任务","伤害来自军事","战场负伤","军旅负伤"],"gate_hypo_ids":["conclusion_C-C1"],"adopt_desc":"这样的伤痛，只可能来自军事任务。"},
				{"id":"C-MAIN","text":"在阿富汗服役过","correct":true,"dir":"affirm","subject":["华生"],"object":["阿富汗","服役"],"match_keys":["在阿富汗服役","阿富汗服役过","去过阿富汗当兵","阿富汗当兵"],"gate_hypo_ids":["conclusion_C-A2","conclusion_C-B1","conclusion_C-C2"],"target":"person:NPC_WT","adopt_desc":"热带殖民地、军医身份、军事任务的伤痛——三线闭合，他在阿富汗服役过。"},
			],
			"contradictions": [],
		},
		"milestones": [
			{"id":"MW-1","text":"华生曾在热带生活过（肤色推导）"},
			{"id":"MW-2","text":"华生是名军医（军人气质＋医疗行业）"},
			{"id":"MW-3","text":"华生承受过不该有的伤痛（旧伤＋久病）"},
			{"id":"MW-4","text":"华生曾在阿富汗服役（三线闭合）"},
		],
		# 裁定 5：练习墙不计分。scene_id 供分枝评分引擎定位到场景一的练习链。
		"scene_id": "scene1", "practice": true,
	}
	_open_wall("watson", hypo, func(v: int):
		_watson_v = v
		_show_watson_verdict_dialogue(v)
	, Callable(self, "_resume_observe"), true, _watson_wall_state)

## 华生墙验证后四档回应（08 §阶段1 验证段 L386/L398-406）：
## VERIFIED 含逐特征详解 + 伟大人物名言；低于 VERIFIED 给简短回应。播完进信使阶段。
func _show_watson_verdict_dialogue(v: int) -> void:
	if _ui: _ui.set_camera_enabled(false)   # 验证回应：禁用摄像机
	_dm = DialogueManager.new(); add_child(_dm)
	_dm.dialogue_advanced.connect(_on_line)
	_dm.dialogue_ended.connect(_on_watson_verdict_end)
	var nodes: Array[Resource] = []
	if v >= 3:
		nodes.append(_dn("wv1","福尔摩斯","你刚才做得不错。让我告诉你，我是怎么看出来的——","click",["wv2"],"从容"))
		nodes.append(_dn("wv2","福尔摩斯","手腕的晒痕、左臂的旧伤，说明他在热带扛过枪；脸色的黝黑、面容的憔悴，是久病初愈又长途劳顿；军人的站姿、身上的消毒液气味，拼在一起——阿富汗军医。","click",["wv3"],"从容"))
		nodes.append(_dn("wv3","福尔摩斯","记住：对一个伟大人物来说，任何事情都不是微不足道的。","click",["wv4"],"哲理"))
		nodes.append(_dn("wv4","福尔摩斯","不错。你已经摸到门道了。","click",["wv5"],"认可",0,"点了一下头"))
		nodes.append(_dn("wv5","华生","福尔摩斯认可了——这可不容易。","click",["end"],"思考",0,"在小本子上记"))
	else:
		nodes.append(_dn("wv1","福尔摩斯","方向是对的，但还有关键的细节你漏掉了。需要在后续多加练习？","click",["wv2"],"从容",0,"没评价，只递过放大镜"))
		nodes.append(_dn("wv2","华生","别急，我陪你。","click",["end"],"思考",0,"合上笔记"))
	var res = DialogueResource.new(); res.scene_id="s1_watson_verdict"; res.nodes=nodes
	res.easy_start_node="wv1"; res.normal_start_node="wv1"; res.hard_start_node="wv1"
	_dm.dialogue_resource=res; _dm.start_dialogue()

func _on_watson_verdict_end() -> void:
	_start_messenger_phase()

func _start_messenger_phase() -> void:
	if _ui: _ui.reset_camera()   # 华生→信使切换：先归位摄像机，避免残留华生推近放大态挡住信使立绘/操作
	if _ui: _ui.set_camera_enabled(false)   # 信使对话阶段禁用摄像机
	# 对齐 08 稿 v3.16.0 §阶段2信使到访（L395-416）
	# ⚠️ 时序修复（思傅 2026-08-15）：此前信使立绘与线索高亮圈在对话开始前就一次性显示，
	# 表现为「赫德森太太还在问'让不让他进来'时，信使与线索就已经在场景里」；
	# 后又发现挂在 m1/m3 节点「进入」时触发，导致福尔摩斯「说让他进来」的**同时**信使就
	# 显现（台词还在播放）。现改为挂到「该节点说完后」的下一个节点进入时才触发：
	#   - m2（信使说话节点进入 = m1「让他进来吧」已说完后）→ 信使入场（立绘显示）
	#   - m4（信使惊讶节点进入 = m3「您曾经是海军陆战队军士吧」已说完后）→ 点亮线索提示圈
	#     （仅提示，暂不开放点击）
	#   - 对话结束 _on_messenger_dialogue_end → 正式激活观察（开放点击 + 弹出工具栏）
	# 故此处先不 show 信使观察器（不画圈、不激活点击），由 _on_messenger_node_entered 驱动。
	_phase = Phase.MESSENGER_OBSERVE
	_dm = DialogueManager.new(); add_child(_dm)
	_dm.dialogue_advanced.connect(_on_line)
	_dm.dialogue_node_entered.connect(_on_messenger_node_entered)
	_dm.dialogue_ended.connect(_on_messenger_dialogue_end)
	var nodes: Array[Resource] = []
	nodes.append(_dn("m0","赫德森太太","福尔摩斯先生，有一位信使要送一封信给您，让他进来吗？","click",["m1"],"平静",0,"门铃响起"))
	nodes.append(_dn("m1","福尔摩斯","让他进来吧，谢谢你，女士。","click",["m2"]))
	nodes.append(_dn("m2","信使","福尔摩斯先生，这是特白厄斯·葛莱森警官给您的信。","click",["m3"],"neutral",0,"递信封，手背露出锚形文身"))
	nodes.append(_dn("m3","福尔摩斯","谢谢。您曾经是海军陆战队军士吧。","click",["m4"],"从容",0,"瞥了一眼信使手背，漫不经心"))
	nodes.append(_dn("m4","信使","啊，您怎么知道我是海军陆战队的军士？","click",["m5"],"neutral",0,"惊讶"))
	nodes.append(_dn("m5","福尔摩斯","又一个练习机会。这次，你来试试？","click",["m5_e","m5_n","m5_h"],"指导",0,"转向玩家"))
	# 不同难度不同引导（链式为 next：m5_e→m5_n→m5_h→end，确保隐藏变体被跳过而非误结束）
	nodes.append(_dn("m5_e","福尔摩斯","提示：他的手背文身、络腮胡、站姿、神态——都是军人标志，逐一找出。","click",["m5_n"],"指导",1))
	nodes.append(_dn("m5_n","福尔摩斯","这次靠你自己观察，找出信使身上的军人特征。","click",["m5_h"],"从容",2))
	nodes.append(_dn("m5_h","福尔摩斯","……证据在他身上。自己看。","click",["end"],"从容",3,"望着信使"))
	var res = DialogueResource.new(); res.scene_id="s1_mess"; res.nodes=nodes
	res.easy_start_node="m0"; res.normal_start_node="m0"; res.hard_start_node="m0"
	_dm.dialogue_resource=res; _dm.start_dialogue()

## 信使对话节点钩子：按剧情节点分步显现信使与线索提示（修复「对话前信使与线索就已出现」）。
## 仅绑定在 _start_messenger_phase 创建的 _dm 上，对话结束的 _on_messenger_dialogue_end 中解绑。
func _on_messenger_node_entered(node_id: String) -> void:
	if node_id == "m2":
		# m1「让他进来吧」已说完后（进入信使说话节点 m2）才让信使入场（立绘显示），
		# 避免福尔摩斯「说让他进来」的同时信使就显现。
		if _messenger_portrait_ctrl: _messenger_portrait_ctrl.visible = true
	elif node_id == "m4":
		# m3「您曾经是海军陆战队军士吧」已说完后（进入 m4）才点亮线索提示圈，
		# 仅提示、暂不开放点击（对话未结束防误点）。
		if _messenger_obs: _messenger_obs.reveal_hints()

func _on_messenger_dialogue_end() -> void:
	if _dm: _dm.dialogue_node_entered.disconnect(_on_messenger_node_entered)
	_phase = Phase.MESSENGER_OBSERVE
	if _ui: _ui.set_camera_enabled(true)   # 进入信使观察：启用摄像机
	_messenger_obs.show()   # 正式激活观察（开放点击；reveal_hints 在 m3 画的提示圈保留，已记录线索不重复显示）
	_ui.set_dialogue("提示", _observe_hint("信使", true) + ("。注意分辨干扰项！" if DifficultyManager.mislead_chance > 0.0 else "。"))
	_ui.set_dialogue_color(Color(0.5,0.9,0.5))
	# 普通模式 70% 中途提示 / 30% 误导强调（08 §阶段2 信使观察 L526-527，接 DifficultyManager.should_show_hint）
	if DifficultyManager.current_difficulty == DifficultyManager.Difficulty.NORMAL:
		if DifficultyManager.should_show_hint():
			_ui.set_dialogue("🔎 中途提示", "袖口那个磨损……可能只是穿久了。别被它带偏。", "提示")
		else:
			_ui.set_dialogue("🔎 注意", "等等，他走路好像有点跛？也许藏着什么。", "提示")
	if _toolbar: _toolbar.show_toolbar()   # 观察阶段弹出道具工具栏

func _show_messenger_reasoning_wall() -> void:
	_messenger_obs.hide(); _phase = Phase.MESSENGER_REASONING
	if _ui: _ui.set_camera_enabled(false)   # 推理墙：禁用摄像机
	if _toolbar: _toolbar.hide_toolbar()
	if _messenger_portrait_ctrl: _messenger_portrait_ctrl.visible = false
	var hypo := {
		"title": "信使是海军陆战队军士？",
		"persons": [
			{"id": "NPC_MSG", "name": "信使"},
			{"id": "NPC_SERGEANT", "name": "海军军士"},
		],
		"description": "从信使身上（锚形文身、络腮胡、挺拔站姿、发号施令神态）推断其海军陆战队军士身份；注意分辨干扰项（袖口磨损、轻微跛行）。",
		"battlefield": {
			"hypotheses": _messenger_hypotheses(),
			"conclusions": [
				{"id":"CL1-01","text":"在海军中当兵","kind":"true","dir":"affirm","subject":["信使"],"object":["海军"],"match_keys":["在海军当兵","海军服役","是海军","当过海军"],"gate_hypo_ids":["M-01","M-02","M-03"],"target":"person:NPC_SERGEANT"},
				{"id":"CL1-02","text":"当过军士/士官","kind":"true","dir":"affirm","subject":["信使"],"object":["军士","士官"],"match_keys":["当过军士","是士官","军士衔","士官"],"gate_hypo_ids":["M-04"],"target":"person:NPC_SERGEANT"},
			],
			"contradictions": [],
		},
		"milestones": [
			{"id":"MM-1","text":"信使曾在海军中当兵"},
			{"id":"MM-2","text":"信使当过军士/士官"},
			{"id":"MM-3","text":"袖口磨损/跛行为干扰项，非身份证据"},
		],
		# 裁定 5：练习墙不计分（信使墙为教学示范，干扰项用于教「信号 vs 噪音」）
		"scene_id": "scene1", "practice": true,
	}
	# 信使(教学示范)墙使用独立 state：不携带华生墙内容；每堵墙独立验证，故重置本墙 verified。
	_messenger_wall_state["verified"] = false
	_open_wall("messenger", hypo, func(v: int):
		_messenger_v = v
		_show_messenger_verdict_dialogue(v)
	, Callable(self, "_resume_observe"), true, _messenger_wall_state)

## 信使墙验证后四档回应（08 §阶段2 验证四档 L536-538/L549）：
## VERIFIED 普通/困难差异化台词；SUPPORTED/INSUFFICIENT 简短；CONTRADICTORY 通用回退。
func _show_messenger_verdict_dialogue(v: int) -> void:
	if _ui: _ui.set_camera_enabled(false)   # 验证回应：禁用摄像机
	_dm = DialogueManager.new(); add_child(_dm)
	_dm.dialogue_advanced.connect(_on_line)
	_dm.dialogue_ended.connect(_on_messenger_verdict_end)
	var nodes: Array[Resource] = []
	var line := ""
	match v:
		3:
			line = "（微微点头）还行。" if DifficultyManager.current_difficulty == DifficultyManager.Difficulty.HARD else "不错。你已经学会区分信号和噪音了。"
		2:
			line = "方向对了。但有些无关的东西，你还得学会过滤。"
		1:
			line = "还不够。再仔细看看——关键的特征就在眼前。"
		_:
			line = "你的证据和结论对不上——推翻重来，别急。"
	nodes.append(_dn("mv1","福尔摩斯",line,"click",["end"],"从容"))
	var res = DialogueResource.new(); res.scene_id="s1_messenger_verdict"; res.nodes=nodes
	res.easy_start_node="mv1"; res.normal_start_node="mv1"; res.hard_start_node="mv1"
	_dm.dialogue_resource=res; _dm.start_dialogue()

func _on_messenger_verdict_end() -> void:
	_calc_stars(); _show_commission_letter_dialogue()

## 信使推理墙假设：仅当当前难度存在干扰线索时才纳入干扰假设（简单模式无干扰）。
func _messenger_hypotheses() -> Array:
	var arr := [
		{"id":"M-01","text":"锚文身是海军士兵中的常见标志","correct":true,"gate_clue_ids":["tattoo"]},
		{"id":"M-02","text":"络腮胡在军人中常见","correct":true,"gate_clue_ids":["beard"]},
		{"id":"M-03","text":"挺拔站姿是军事训练中形成的肌肉记忆","correct":true,"gate_clue_ids":["posture"]},
		{"id":"M-04","text":"发号施令中形成的气度","correct":true,"gate_clue_ids":["manner"]},
	]
	if DifficultyManager.mislead_chance > 0.0:
		arr.append({"id":"M-05","text":"袖口磨损=旧衣服（干扰）","correct":false,"gate_clue_ids":["sleeve"]})
		arr.append({"id":"M-06","text":"轻微跛行=扭伤（干扰）","correct":false,"gate_clue_ids":["limp"]})
	return arr

## 推理墙「继续收集线索」回调：把玩家从推理墙状态带回未完成的线索收集页面。
## 开墙时 _show_*_reasoning_wall 已把 phase 改为 *_REASONING 并隐藏立绘/观察器，
## 这里据此还原回对应的 *_OBSERVE 阶段，重新显示人物与可点击热点。
func _resume_observe() -> void:
	_wall_auto = false
	if _phase == Phase.WATSON_REASONING:
		if _watson_obs.get_recorded() >= _watson_obs.needs_count():
			# 线索已收满：回观察界面会卡死（线索都标记过、无再入推理入口），直接重开推理墙继续推理
			_show_watson_reasoning_wall()
			return
		_phase = Phase.OBSERVE_WATSON
		if _portrait_ctrl: _portrait_ctrl.visible = true
		_watson_obs.show()
		_ui.set_dialogue("提示", "已回到华生观察 — " + _resume_suffix() + "（" + str(_watson_obs.get_recorded()) + "/" + str(_watson_obs.needs_count()) + "）")
		_ui.set_dialogue_color(Color(0.5, 0.9, 0.5))
	elif _phase == Phase.MESSENGER_REASONING:
		if _messenger_obs.get_recorded() >= _messenger_obs.needs_count():
			# 同上：信使线索收满 → 重开信使推理墙
			_show_messenger_reasoning_wall()
			return
		_phase = Phase.MESSENGER_OBSERVE
		if _messenger_portrait_ctrl: _messenger_portrait_ctrl.visible = true
		_messenger_obs.show()
		_ui.set_dialogue("提示", "已回到信使观察 — " + _resume_suffix() + "（" + str(_messenger_obs.get_recorded()) + "/6）")
		_ui.set_dialogue_color(Color(0.5, 0.9, 0.5))
	if _ui: _ui.set_camera_enabled(true)
	if _toolbar: _toolbar.show_toolbar()

## 推理墙验证提交后的阶段推进（修复「退出推理墙后回到华生界面、无下一阶段」卡死，问题4）。
## 仅 verified 墙经 _advance_now → _enter_transition 调到此；按当前 *_REASONING 阶段分流到下一阶段。
func _enter_transition() -> void:
	if _phase == Phase.WATSON_REASONING:
		_start_messenger_phase()                 # 华生推理通过 → 信使到访（赫德森「让不让进」对话）
	elif _phase == Phase.MESSENGER_REASONING:
		_show_commission_letter_dialogue()       # 信使推理通过 → 解锁委托信 + 双钩子 → 进入 scene2
	else:
		_resume_observe()                        # 兜底：非推理阶段（预览墙不应到这）回观察

func _calc_stars() -> void:
	_stars_observe = 2 if _watson_obs.get_recorded() >= _watson_obs.needs_count() and _messenger_obs.get_recorded() >= _messenger_obs.needs_count() else 1
	_stars_reason = 3 if _watson_v == 3 and _messenger_v == 3 else (2 if _watson_v >= 2 or _messenger_v >= 2 else 1)
	_stars_insight = 2 if _watson_v >= 2 and _messenger_v >= 2 else 1

func _vname(v: int) -> String:
	match v:
		3: return "VERIFIED"
		2: return "SUPPORTED"
		1: return "INSUFFICIENT"
		_: return "CONTRADICTORY"

func _show_rating() -> void:
	if _ui: _ui.set_camera_enabled(false)   # 评分阶段：禁用摄像机
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
	cont.pressed.connect(func(): w.queue_free(); _accept_case())
	w.add_child(cont)

func _on_sc1_rating_done(w: Control) -> void:
	w.queue_free(); _save_and_continue()

func _save_and_continue() -> void:
	_phase = Phase.COMPLETE
	if GameStateMachine: GameStateMachine.go_complete()
	if GameManager: GameManager.add_milestone("sc_01_completed")
	if not (GameManager and GameManager.is_guest) and SaveManager:
		if _suppress_terminal_save:
			_create_notification("已恢复至终局进度，直接进入场景二")
		else:
			# 自动存档必须写入本场景的 scene_state（phase + scene_id + clue_ids），
			# 否则读档时 _restore_saved_state 因 scene_id 不匹配而判定「无存档」→ 场景从头重启。
			# 同时写入场景一的三维星级与两墙验证值，确保读档后评分面板与游玩时一致。
			var ids: Array = []
			for c in _watson_obs.get_recorded_clues(): ids.append(c.get("id",""))
			for c in _messenger_obs.get_recorded_clues(): ids.append(c.get("id",""))
			await SaveSystem.request_save("scene1", Phase.COMPLETE, {
				"clue_ids": ids,
				"stars_observe": _stars_observe,
				"stars_reason": _stars_reason,
				"stars_insight": _stars_insight,
				"watson_v": _watson_v,
				"messenger_v": _messenger_v,
			})
			_create_notification("进度已保存")
	else: _create_notification("注册后可解锁云端存档")
	await get_tree().create_timer(2.0).timeout
	SceneLoader.transition_to("res://scenes/scene2.tscn")

# ===== 委托信解锁 + 双钩子结尾（依据 02 §9 双钩子系统 + 委托信解锁） =====
func _show_commission_letter_dialogue() -> void:
	if _ui: _ui.set_camera_enabled(false)   # 委托信对话：禁用摄像机
	_phase = Phase.RATING
	# 委托信解锁为线索（B-01 前置：信使验证通过 ≥ SUPPORTED 后解锁）
	if ClueSystem:
		ClueSystem.collect_clue_from_catalog(
			"commission_letter", "案件委托信",
			"葛莱森警长的委托：劳瑞斯顿花园街3号发现一具男尸，死因不明，葛莱森百思不得其解，邀福尔摩斯十二点前到场。这是承接「血字的研究」一案的正式起点。",
			true, "commission")
	_dm = DialogueManager.new(); add_child(_dm)
	_dm.dialogue_advanced.connect(_on_line)
	_dm.dialogue_ended.connect(_on_commission_ended)
	var nodes: Array[Resource] = []
	nodes.append(_dn("cl0","福尔摩斯","信使留下的，是葛莱森警长的委托信。","click",["cl1"],"从容"))
	nodes.append(_dn("cl1","系统","〔葛莱森警长来信 · 全文〕\n\n亲爱的福尔摩斯先生：\n\n昨夜，在布瑞克斯顿路的尽头、劳瑞斯顿花园街三号发生了一件凶杀案。今晨两点左右，巡逻警察忽见该处有灯光，因素悉该房无人居住，故而怀疑出了什么问题。该巡警发现房门大开，前室空无一物，内有男尸一具。该尸衣着整齐，袋中装有名片，上有“伊诺克·J.德雷伯，美国俄亥俄州克利夫兰”字样。既无被抢劫迹象，亦未发现任何能说明致死原因之证据。屋中虽有几处血迹，但死者身上并无伤痕。死者如何在空屋里遇害，我等百思不得其解，深感此案棘手之至。希望阁下在十二点之前惠临，我将在此恭候。在接信回示前，现场一切均将保持原状。如果不能莅临，亦必将详情告之，倘蒙指教，不胜感激之至。\n\n您忠实的　特白厄斯·葛莱森","click",["cl2"],"信件"))
	nodes.append(_dn("cl2","福尔摩斯","葛莱森是苏格兰场首屈一指的能干人物。中士，请转告葛莱森警长，我会在十二点之前到达。","click",["cl3"],"从容"))
	nodes.append(_dn("cl3","信使","好的，谢谢！福尔摩斯先生，那我就先告辞了。","click",["cl4"],"平静"))
	nodes.append(_dn("cl4","福尔摩斯","准备好了吗？一场真正的探案开始了。","click",["cl5"],"从容",0,"对玩家，眼神锐利"))
	nodes.append(_dn("cl5","福尔摩斯","空屋、男尸、身上没有伤痕……葛莱森说他们百思不得其解。","click",["cl6"],"思考",0,"略微踱步，思考状"))
	nodes.append(_dn("cl6","福尔摩斯","你怎么看？先别急着回答——到了现场，让证据说话。","click",["cl7"],"从容",0,"看向玩家"))
	nodes.append(_dn("cl7","华生","听起来是个大案子！福尔摩斯，我们什么时候出发？","click",["cl8"],"好奇",0,"在一旁兴奋"))
	nodes.append(_dn("cl8","福尔摩斯","现在就出发。但记住三条原则：第一，先观察再动手；第二，每样东西都值得量一量、记一记；第三，在有全部证据之前，不要急于下结论。","click",["cl9"],"自信",0,"拿起帽子"))
	nodes.append(_dn("cl9","系统","【推理墙解锁新功能】案件推理链已创建（空链，等待玩家填充）\n【侦探笔记新增】案件档案：血字的研究 · 劳瑞斯顿花园街三号","click",["end"],"guide"))
	var res = DialogueResource.new(); res.scene_id="s1_letter"; res.nodes=nodes
	res.easy_start_node="cl0"; res.normal_start_node="cl0"; res.hard_start_node="cl0"
	_dm.dialogue_resource=res; _dm.start_dialogue()

func _on_commission_ended() -> void:
	_show_hooks_dialogue()

## 双钩子（剧情钩子 + 谜题钩子），融入对话不做独立 UI（02 §9 §11）
func _show_hooks_dialogue() -> void:
	if _ui: _ui.set_camera_enabled(false)   # 钩子对话：禁用摄像机
	_dm = DialogueManager.new(); add_child(_dm)
	_dm.dialogue_advanced.connect(_on_line)
	_dm.dialogue_ended.connect(_on_hooks_ended)
	var nodes: Array[Resource] = []
	# 剧情钩子
	nodes.append(_dn("hk0","福尔摩斯","有意思——伦敦郊区发生了一起谋杀案，警方束手无策。","click",["hk1"],"从容",0,"瞥了一眼信，嘴角微扬"))
	nodes.append(_dn("hk1","华生","你要去吗？","click",["hk2"],"好奇"))
	nodes.append(_dn("hk2","福尔摩斯","当然。正好——让你见识一下什么叫真正的侦探工作。","click",["hk3"],"自信"))
	# 谜题钩子
	nodes.append(_dn("hk3","system","委托信上只有短短几行字——死者是谁？死在哪？怎么死的？（推理战场「案件三要素」待解问题已记录）","click",["end"],"guide"))
	var res = DialogueResource.new(); res.scene_id="s1_hooks"; res.nodes=nodes
	res.easy_start_node="hk0"; res.normal_start_node="hk0"; res.hard_start_node="hk0"
	_dm.dialogue_resource=res; _dm.start_dialogue()

func _on_hooks_ended() -> void:
	_show_rating()

# ===== 分支 B-01（承接 / 拒绝案件）已取消：案件自动承接，评分面板点「进入场景二」即承接并前往现场 =====
func _accept_case() -> void:
	_phase = Phase.COMPLETE
	if GameManager: GameManager.add_milestone("sc_01_completed")
	if not (GameManager and GameManager.is_guest) and SaveManager:
		if _suppress_terminal_save:
			_create_notification("已恢复至终局进度，直接进入场景二")
		else:
			var ids: Array = []
			for c in _watson_obs.get_recorded_clues(): ids.append(c.get("id",""))
			for c in _messenger_obs.get_recorded_clues(): ids.append(c.get("id",""))
			await SaveSystem.request_save("scene1", Phase.COMPLETE, {
				"clue_ids": ids,
				"stars_observe": _stars_observe,
				"stars_reason": _stars_reason,
				"stars_insight": _stars_insight,
				"watson_v": _watson_v,
				"messenger_v": _messenger_v,
			})
			_create_notification("进度已保存")
	else: _create_notification("注册后可解锁云端存档")
	await get_tree().create_timer(1.0).timeout
	SceneLoader.transition_to("res://scenes/scene2.tscn")

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

