extends Control

enum Verdict { CONTRADICTORY=0, INSUFFICIENT=1, SUPPORTED=2, VERIFIED=3 }
enum Phase { MRS_HUDSON, OPENING, OBSERVE_WATSON, WATSON_REASONING, MESSENGER_OBSERVE, MESSENGER_REASONING, RATING, COMPLETE }

var _phase := Phase.MRS_HUDSON
var _dm: DialogueManager
var _ui: SceneFramework
var _difficulty := 1
var _watson_obs: ClueObserver
var _messenger_obs: ClueObserver
var _watson_v := 0
var _messenger_v := 0
var _watson_clues: Array = []
var _messenger_clues: Array = []
var _stars_observe := 1
var _stars_reason := 1
var _stars_insight := 1
var _wall_auto := false

func _ready() -> void:
	if DifficultyManager: _difficulty = DifficultyManager.current_difficulty
	_init_game_state(); _build_ui(); _create_observers()
	_connect_ui_signals()
	# 检查是否有存档状态需恢复
	if _restore_saved_state():
		return  # _restore_saved_state 内会调用合适的阶段启动方法
	_show_mrs_hudson_dialogue()

## 恢复存档进度 — 返回 true 表示有存档且已恢复，false 表示新游戏
## 通过通用 SaveSystem 取回属于本场景的快照；线索本身已由 SaveManager
## 恢复进 ClueSystem（单一真相源），推理墙直接读 ClueSystem，无需这里再搬数据。
func _restore_saved_state() -> bool:
	var ss = SaveSystem.take_save_state("scene1")
	if ss.is_empty(): return false
	var saved_phase := int(ss.get("phase", 0))
	var saved_ids: Array = ss.get("clue_ids", [])
	# 以存档 clue_ids 为权威，同步 ClueSystem 的 watson/messenger 来源，
	# 保证推理墙显示与观察器记录数一致（避免「两层皮」）。
	if ClueSystem:
		ClueSystem.clear_source("watson")
		ClueSystem.clear_source("messenger")
		for cid in saved_ids:
			var h = _find_hotspot(cid)
			if not h.is_empty():
				var src := "watson" if cid in ["wrist","arm","face","pose"] else "messenger"
				ClueSystem.collect_clue(cid, h.get("name", cid), h.get("desc",""), h.get("correct", true), src)
	# 关键：先把阶段恢复到存档值（OPENING / OBSERVE_WATSON 等分支的子方法不会设 _phase，
	# 若漏掉会导致新场景实例 _phase 停在默认的 MRS_HUDSON=0 —— 即「读档后阶段错乱」）
	_phase = saved_phase
	print("[RESTORE scene1] phase=", saved_phase, " clue_ids=", saved_ids)
	# 明确告知用户读档成功并恢复到哪个阶段，避免「不知道进到哪了」
	_create_notification("✅ 读档成功 — 已恢复至「" + _phase_name(saved_phase) + "」")

	match saved_phase:
		Phase.MRS_HUDSON:
			_show_mrs_hudson_dialogue()
			return true
		Phase.OPENING:
			_show_opening_dialogue()
			return true
		Phase.OBSERVE_WATSON:
			_ui.restore_observer(_watson_obs, saved_ids, ["wrist","arm","face","pose"])
			if _watson_obs.get_recorded() >= 4:
				# 死局防御：线索已集齐但阶段停在观察——all_recorded 不会再触发
				_on_watson_all_recorded(_watson_obs.get_recorded_clues()); return true
			_ui.set_dialogue("提示", "已恢复进度 — 华生观察阶段（已收集 "+str(_watson_obs.get_recorded())+"/4 条）\n点击 LOOK 查看剩余标记点")
			return true
		Phase.WATSON_REASONING:
			_phase = Phase.WATSON_REASONING; _wall_auto = false
			_ui.restore_observer(_watson_obs, saved_ids, ["wrist","arm","face","pose"])
			_show_watson_reasoning_wall()
			return true
		Phase.MESSENGER_OBSERVE:
			_phase = Phase.MESSENGER_OBSERVE
			_ui.restore_observer(_messenger_obs, saved_ids, ["tattoo","beard","posture","manner","sleeve","limp"])
			if _messenger_obs.get_recorded() >= 6:
				# 死局防御：线索已集齐但阶段停在观察——all_recorded 不会再触发
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
	var w = [{"id":"wrist","name":"手腕肤色分界","desc":"华生手腕肤色分界明显——长期暴露于热带阳光"},{"id":"arm","name":"左臂僵硬","desc":"华生左臂动作僵硬，似有旧伤"},{"id":"face","name":"面色黝黑憔悴","desc":"华生面色黝黑且憔悴——久病初愈的迹象"},{"id":"pose","name":"军人站姿","desc":"华生站姿挺拔，带有明显军人气质"}]
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
	_ui.setup("贝克街221B", "DAY 1 上午10:30")
	var tex = load("res://assets/characters/watson/watson_standing.jpg")
	if tex: _ui.add_portrait(tex, "华生", Vector2(160, 350), Vector2(280, 360))

func _connect_ui_signals() -> void:
	_ui.nav_clicked.connect(_on_nav)
	_ui.action_clicked.connect(_on_action)

# === 顶部导航按钮 ===

func _on_nav(nav_id: String) -> void:
	match nav_id:
		"map": _show_map_panel()
		"casebook": _show_casebook_panel()
		"evidence": _open_evidence()
		"inventory": _show_inventory_panel()
		"options": _show_options_panel()

func _show_map_panel() -> void:
	var items: Array = []
	for loc in [{"t":"贝克街221B","d":"福尔摩斯与华生的寓所 — 当前场景"},{"t":"劳瑞斯顿花园街3号","d":"葛莱森警长发现的尸体现场 — 待调查"},{"t":"苏格兰场","d":"伦敦警察总部 — 葛莱森办公处"}]:
		items.append({"name":"◆ "+loc["t"], "desc":loc["d"]})
	_popup("伦敦地图", items)

func _show_casebook_panel() -> void:
	var items: Array = []
	var milestones := ["赫德森太太开场","华生观察练习","信使观察练习","推理验证完成"]
	var done := [_phase >= Phase.OPENING, _watson_obs.get_recorded() >= 4, _messenger_obs.get_recorded() >= 6, _phase >= Phase.MESSENGER_REASONING]
	for i in milestones.size():
		var prefix := "✅ " if done[i] else "⬜ "
		items.append({"name":prefix + milestones[i], "desc":""})
	_popup("案件簿 — 血字的研究", items)

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
	# 难度按钮
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

# === 左侧动作按钮 ===

var _look_active := false
var _talk_active := false

func _on_action(action_id: String) -> void:
	match action_id:
		"look":
			_look_active = not _look_active; _ui.set_action_active("look", _look_active)
			_create_notification("观察模式" if _look_active else "观察已关闭") if not _look_active else _do_look()
		"talk":
			_talk_active = not _talk_active; _ui.set_action_active("talk", _talk_active)
			_create_notification("对话模式" if _talk_active else "对话已关闭") if not _talk_active else _do_talk()
		"examine":
			_do_examine()
		"think":
			_do_think()
		"journal":
			_open_notebook()
		"save":
			_do_save()
		"load":
			_do_load()
		_:
			_create_notification("「"+action_id+"」已激活")

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
		_create_notification("🔍 放大镜工具 — 点击场景中的人物细节进行观察")
		# 自动启用观察模式
		if not _look_active: _look_active = true; _ui.set_action_active("look", true)
	else: _create_notification("请在观察阶段使用放大镜工具")

func _do_think() -> void:
	if _phase == Phase.OBSERVE_WATSON and _watson_obs.get_recorded() > 0:
		_wall_auto = true; _show_watson_reasoning_wall()
	elif _phase == Phase.MESSENGER_OBSERVE and _messenger_obs.get_recorded() > 0:
		_wall_auto = true; _show_messenger_reasoning_wall()
	elif _phase == Phase.WATSON_REASONING or _phase == Phase.MESSENGER_REASONING:
		_create_notification("已在推理墙中")
	else: _create_notification("请先收集至少 1 条线索再使用推理墙")

func _do_load() -> void:
	_create_notification("正在读取存档…")
	if not SaveManager:
		_create_notification("存档系统不可用")
		return
	# 从磁盘/云端重新读取最新存档，刷新 GameManager.scene_state 与 ClueSystem
	var ok = await SaveSystem.load_game()
	if not ok:
		_create_notification("没有可用的存档")
		return
	# 就地重置当前场景：_ready 会调用 _restore_saved_state，从刚刷新的存档恢复进度
	# 不回主菜单，避免依赖已被消费的运行时 scene_state 导致重新开局
	get_tree().reload_current_scene()

func _create_notification(msg: String) -> void:
	if _ui: _ui.show_notification(msg)

func _do_save() -> void:
	if GameManager.is_guest:
		_create_notification("游客模式不支持存档，请先注册账号")
		return
	# 收集场景运行状态：以本场景两个观察器的已记录线索为权威（不读全局 ClueSystem，避免跨轮累计污染存档）
	var data := {"clue_ids": [], "watson_recorded": 0, "messenger_recorded": 0}
	var ids: Array = []
	for c in _watson_obs.get_recorded_clues(): ids.append(c.get("id",""))
	for c in _messenger_obs.get_recorded_clues(): ids.append(c.get("id",""))
	data["clue_ids"] = ids
	for cid in ids:
		if cid in ["wrist","arm","face","pose"]: data["watson_recorded"] += 1
		else: data["messenger_recorded"] += 1
	await SaveSystem.request_save("scene1", _phase, data)
	print("[SAVE scene1] phase=", _phase, " data=", data)
	_create_notification("进度已保存")

# === 观察器(不使用 multiline lambda) ===

func _create_observers() -> void:
	var tex = load("res://assets/characters/watson/watson_standing.jpg")
	var sa = _ui.get_scene_area()
	_watson_obs = ClueObserver.new(); _watson_obs.name = "watson_observer"; add_child(_watson_obs)
	_watson_obs.setup(sa, _ui._dialogue_label, _ui._speaker_label, [
		{"id":"wrist","label":"手腕肤色","x":550,"y":370,"w":120,"h":50,"desc":"长期日晒痕迹 -> 刚从热带回来"},
		{"id":"arm","label":"左臂旧伤","x":420,"y":440,"w":110,"h":60,"desc":"袖口疤痕 -> 曾受枪伤"},
		{"id":"face","label":"憔悴面容","x":530,"y":220,"w":100,"h":60,"desc":"面容消瘦 -> 长期患病"},
		{"id":"pose","label":"军人站姿","x":480,"y":580,"w":120,"h":60,"desc":"身板挺直 -> 军事训练"},
	], tex)
	_watson_obs.all_recorded.connect(_on_watson_all_recorded)
	_watson_obs.clue_recorded.connect(_on_collect_clue.bind("watson"))

	_messenger_obs = ClueObserver.new(); _messenger_obs.name = "messenger_observer"; add_child(_messenger_obs)
	_messenger_obs.setup(sa, _ui._dialogue_label, _ui._speaker_label, [
		{"id":"tattoo","label":"手背锚文身","x":700,"y":340,"w":130,"h":48,"desc":"蓝色锚形文身 -> 海军标志","correct":true},
		{"id":"beard","label":"络腮胡须","x":820,"y":270,"w":120,"h":50,"desc":"军人式络腮胡 -> 军队常见","correct":true},
		{"id":"posture","label":"笔挺站姿","x":750,"y":520,"w":120,"h":55,"desc":"昂首挺胸 -> 军事训练","correct":true},
		{"id":"manner","label":"发号施令","x":880,"y":390,"w":140,"h":50,"desc":"发号施令 -> 军士/士官","correct":true},
		{"id":"sleeve","label":"袖口磨损","x":650,"y":450,"w":115,"h":50,"desc":"袖口磨损 -> 干扰:衣服旧了","correct":false},
		{"id":"limp","label":"走路略跛","x":600,"y":570,"w":120,"h":55,"desc":"右腿略跛 -> 干扰:扭伤","correct":false},
	], tex)
	_messenger_obs.all_recorded.connect(_on_messenger_all_recorded)
	_messenger_obs.clue_recorded.connect(_on_collect_clue.bind("messenger"))

func _on_watson_all_recorded(clues: Array) -> void:
	_watson_clues = clues; _wall_auto = true; _show_watson_reasoning_wall()

func _on_messenger_all_recorded(clues: Array) -> void:
	_messenger_clues = clues; _wall_auto = true; _show_messenger_reasoning_wall()

## 观察器记录一条线索时，同步登记到通用线索系统（ClueSystem 为单一真相源）
## source 用于区分华生 / 信使两轮观察，推理墙据此筛选
func _on_collect_clue(clue_id: String, clue_data: Dictionary, source: String) -> void:
	if ClueSystem:
		ClueSystem.collect_clue(
			clue_id,
			clue_data.get("name", clue_id),
			clue_data.get("desc", ""),
			clue_data.get("correct", true),
			source
		)

# === 对话 ===

func _dn(id, sp, txt, tri, nxt, mood="neutral") -> DialogueNodeResource:
	var n = DialogueNodeResource.new()
	n.node_id=id; n.speaker=sp; n.text=txt; n.trigger=tri
	# next_nodes 是 Array[String]，必须用强类型数组赋值，否则 GDScript 运行时报类型错误、
	# 导致本函数异常返回 null，对话资源混入 Nil 节点、find_node 崩溃
	var nn: Array[String] = []
	for s in nxt:
		if s is String: nn.append(s)
	n.next_nodes = nn
	n.mood = mood
	return n

func _show_mrs_hudson_dialogue() -> void:
	_dm = DialogueManager.new(); add_child(_dm)
	_dm.dialogue_advanced.connect(_on_line)
	_dm.dialogue_ended.connect(_on_mrs_hudson_end)
	var nodes: Array[Resource] = []
	nodes.append(_dn("h0","赫德森太太","福尔摩斯先生，茶来了。这位就是您说的新同租伙伴吧？","click",["h1"]))
	nodes.append(_dn("h1","福尔摩斯","是的，赫德森太太。华生医生，刚从阿富汗回来。","click",["h2"],"从容"))
	nodes.append(_dn("h2","赫德森太太","阿富汗？那可够远的。看这天怕是要下雪了。","click",["h3"]))
	nodes.append(_dn("h3","华生","谢谢您，赫德森太太。","click",["h4"],"惊讶"))
	nodes.append(_dn("h4","system","赫德森太太微笑着退出房间，轻轻关上门。","click",["end"]))
	var res = DialogueResource.new(); res.scene_id="s1_intro"; res.nodes=nodes
	res.easy_start_node="h0"; res.normal_start_node="h0"; res.hard_start_node="h0"
	_dm.dialogue_resource=res; _dm.start_dialogue()

func _on_mrs_hudson_end() -> void:
	_dm.dialogue_ended.disconnect(_on_mrs_hudson_end)
	_dm.dialogue_ended.connect(_on_opening_end)
	_show_opening_dialogue()

func _show_opening_dialogue() -> void:
	_phase = Phase.OPENING
	var nodes: Array[Resource] = []
	nodes.append(_dn("s0","福尔摩斯","......阿富汗军医。","click",["s1"],"自信"))
	nodes.append(_dn("s1","华生","什么？您怎么知道？","click",["s2"],"吃惊"))
	nodes.append(_dn("s2","福尔摩斯","证据就在你身上——手腕、左臂、面色、站姿。","click",["s3"],"从容"))
	nodes.append(_dn("s3","system","点击华生身上的高亮按钮观察细节，记录后进入推理墙。","click",["end"],"guide"))
	var res = DialogueResource.new(); res.scene_id="s1_open"; res.nodes=nodes
	res.easy_start_node="s0"; res.normal_start_node="s0"; res.hard_start_node="s0"
	_dm.dialogue_resource=res; _dm.start_dialogue()

func _on_opening_end() -> void:
	_phase = Phase.OBSERVE_WATSON
	_watson_obs.show()
	_ui.set_dialogue("提示", "点击华生身上的按钮，观察 4 处线索。")
	_ui.set_dialogue_color(Color(0.5, 0.9, 0.5))

func _on_line(_id: String) -> void:
	var n = _dm.current_node; if not n: return
	var sp = n.speaker
	var col = Color(0.7,0.8,0.9) if sp=="华生" else Color(0.5,0.9,0.5) if sp=="system" else Color(0.85,0.75,0.45)
	if sp=="赫德森太太": col = Color(0.95,0.80,0.60)
	_ui.set_dialogue(sp if sp!="system" else "提示", n.text)
	_ui.set_dialogue_color(col)

# === 推理墙辅助 ===

func _sb(bg: Color, bc: Color, bw: int, cr: int) -> StyleBoxFlat:
	var s = StyleBoxFlat.new(); s.bg_color = bg; s.border_color = bc
	s.border_width_left = bw; s.border_width_right = bw; s.border_width_top = bw; s.border_width_bottom = bw
	s.set_corner_radius_all(cr); return s

func _mk_wall(title: String, hypo: String) -> Control:
	var w = Control.new(); w.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	w.mouse_filter = Control.MOUSE_FILTER_STOP; add_child(w)
	var bg = ColorRect.new(); bg.color = Color(0.06,0.05,0.08,0.98); bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	w.add_child(bg)
	var tt = Label.new(); tt.text = "推理墙 - "+title; tt.add_theme_font_size_override("font_size", 26)
	tt.add_theme_color_override("font_color", Color(0.92,0.82,0.45)); tt.position = Vector2(40,12); tt.size = Vector2(1800,34)
	w.add_child(tt)
	var st = Label.new(); st.text = "点击线索卡片添加到推理板 | 再次点击移除"; st.add_theme_font_size_override("font_size", 13)
	st.add_theme_color_override("font_color", Color(0.45,0.40,0.30)); st.position = Vector2(40,48); st.size = Vector2(1800,20)
	w.add_child(st)
	var bd = Control.new(); bd.name = "wall_board"; bd.position = Vector2(40,135); bd.size = Vector2(1840,470)
	w.add_child(bd)
	var bbg = ColorRect.new(); bbg.color = Color(0.08,0.06,0.04,0.92); bbg.position = Vector2(0,0); bbg.size = Vector2(1840,470)
	bd.add_child(bbg)
	var hl = Label.new(); hl.text = hypo; hl.add_theme_font_size_override("font_size", 20)
	hl.add_theme_color_override("font_color", Color(0.88,0.82,0.72)); hl.position = Vector2(15,8); hl.size = Vector2(1800,28)
	bd.add_child(hl)
	return w

# === 推理墙 — 华生 ===

func _show_watson_reasoning_wall() -> void:
	_watson_obs.hide(); _phase = Phase.WATSON_REASONING
	var bids: Array = []
	var w = _mk_wall("华生: 阿富汗军医?", "假设: 华生刚从阿富汗回来")
	var flow = HFlowContainer.new()
	flow.position = Vector2(15, 45); flow.size = Vector2(1810, 410)
	flow.add_theme_constant_override("h_separation", 10); flow.add_theme_constant_override("v_separation", 6)
	var bd = w.find_child("wall_board", false, false)
	if bd: bd.add_child(flow)
	var clues: Array = ClueSystem.get_collected("watson") if ClueSystem else _watson_obs.get_recorded_clues()
	for i in clues.size():
		var cl = clues[i]; var cid = cl["id"]; var cn = cl.get("name", cid)
		var card = Button.new(); card.text = cn; card.position = Vector2(40 + i*195, 75); card.size = Vector2(180, 50)
		card.add_theme_font_size_override("font_size", 13); card.add_theme_color_override("font_color", Color(0.95,0.90,0.78))
		card.add_theme_stylebox_override("normal", _sb(Color(0.18,0.14,0.09,0.95), Color(0.55,0.42,0.20), 2, 6))
		card.pressed.connect(_on_watson_card_pressed.bind(cid, cn, bids, flow))
		w.add_child(card)
	var vb = Button.new(); vb.text = "提交验证"; vb.position = Vector2(620,620); vb.size = Vector2(300,55)
	vb.add_theme_font_size_override("font_size", 24); vb.add_theme_color_override("font_color", Color(0.92,0.84,0.55))
	vb.add_theme_stylebox_override("normal", _sb(Color(0.50,0.10,0.10,0.95), Color(0.85,0.65,0.25), 2, 4))
	vb.pressed.connect(_on_watson_verify.bind(w, clues, bids))
	w.add_child(vb)
	var cb = Button.new(); cb.text = "跳过"; cb.position = Vector2(970,620); cb.size = Vector2(180,55)
	cb.add_theme_font_size_override("font_size", 20)
	cb.pressed.connect(_on_watson_skip.bind(w))
	w.add_child(cb)

func _on_watson_card_pressed(cid: String, cn: String, bids: Array, flow: HFlowContainer) -> void:
	if bids.has(cid): return
	bids.append(cid)
	var bc = Button.new(); bc.text = cn; bc.custom_minimum_size = Vector2(165, 44)
	bc.add_theme_font_size_override("font_size", 13); bc.add_theme_color_override("font_color", Color(0.95,0.90,0.78))
	bc.add_theme_stylebox_override("normal", _sb(Color(0.08,0.30,0.08,0.95), Color(0.2,0.8,0.2), 2, 6))
	bc.pressed.connect(func(): bids.erase(cid); bc.queue_free())
	flow.add_child(bc)

func _on_watson_verify(w: Control, clues: Array, bids: Array) -> void:
	var corr = 0; var wrong = 0
	for cl in clues:
		if bids.has(cl["id"]):
			if cl.get("correct", true): corr += 1
			else: wrong += 1
	var vv := 1
	if wrong > 0: vv = 0
	elif corr >= 3: vv = 3
	elif corr >= 1: vv = 2
	_show_verdict(w, vv, wrong, corr)
	await get_tree().create_timer(2.0).timeout; w.queue_free()
	_watson_v = vv; _start_messenger_phase()

func _on_watson_skip(w: Control) -> void:
	w.queue_free()
	if _wall_auto:
		_watson_v = 3; _start_messenger_phase()
	else:
		_phase = Phase.OBSERVE_WATSON; _watson_obs.show()
		_ui.set_dialogue("提示", "已返回观察模式。收集全部 4 条线索后自动进入推理墙。")
		_ui.set_dialogue_color(Color(0.5,0.9,0.5))

# === 信使阶段 ===

func _start_messenger_phase() -> void:
	_phase = Phase.MESSENGER_OBSERVE; _messenger_obs.show()
	_dm = DialogueManager.new(); add_child(_dm)
	_dm.dialogue_advanced.connect(_on_line)
	_dm.dialogue_ended.connect(_on_messenger_dialogue_end)
	var nodes: Array[Resource] = []
	nodes.append(_dn("m0","福尔摩斯","很好。我们的信使朋友带来了葛莱森警长的委托。","click",["m1"],"从容"))
	nodes.append(_dn("m1","信使","先生们，这是葛莱森警长的信。花园街3号。","click",["m2"]))
	nodes.append(_dn("m2","福尔摩斯","先别急。华生，第二次练习机会。从这位信使身上，你能读出什么？","click",["m3"]))
	nodes.append(_dn("m3","system","点击信使身上的可交互区域。完成后进入推理墙验证。","click",["end"]))
	var res = DialogueResource.new(); res.scene_id="s1_mess"; res.nodes=nodes; res.easy_start_node="m0"; res.normal_start_node="m0"; res.hard_start_node="m0"
	_dm.dialogue_resource=res; _dm.start_dialogue()

func _on_messenger_dialogue_end() -> void:
	_phase = Phase.MESSENGER_OBSERVE
	_ui.set_dialogue("提示", "点击信使身上的可交互区域。注意分辨干扰项！")
	_ui.set_dialogue_color(Color(0.5,0.9,0.5))

# === 推理墙 — 信使 ===

func _show_messenger_reasoning_wall() -> void:
	_messenger_obs.hide(); _phase = Phase.MESSENGER_REASONING
	var bids: Array = []
	var w = _mk_wall("信使: 海军陆战队军士?", "假设: 信使是海军陆战队军士")
	var flow = HFlowContainer.new()
	flow.position = Vector2(15, 45); flow.size = Vector2(1810, 430)
	flow.add_theme_constant_override("h_separation", 10); flow.add_theme_constant_override("v_separation", 6)
	var bd = w.find_child("wall_board", false, false)
	if bd: bd.add_child(flow)
	var clues: Array = ClueSystem.get_collected("messenger") if ClueSystem else _messenger_obs.get_recorded_clues()
	for i in clues.size():
		var cl = clues[i]; var cid = cl["id"]; var cn = cl.get("name", cid)
		var card = Button.new(); card.text = cn; card.position = Vector2(40 + i*200, 75); card.size = Vector2(185, 48)
		card.add_theme_font_size_override("font_size", 13); card.add_theme_color_override("font_color", Color(0.95,0.90,0.78))
		card.add_theme_stylebox_override("normal", _sb(Color(0.18,0.14,0.09,0.95), Color(0.55,0.42,0.20), 2, 6))
		card.pressed.connect(_on_watson_card_pressed.bind(cid, cn, bids, flow))
		w.add_child(card)
	var vb = Button.new(); vb.text = "提交验证"; vb.position = Vector2(620,620); vb.size = Vector2(300,55)
	vb.add_theme_font_size_override("font_size", 24); vb.add_theme_color_override("font_color", Color(0.92,0.84,0.55))
	vb.add_theme_stylebox_override("normal", _sb(Color(0.50,0.10,0.10,0.95), Color(0.85,0.65,0.25), 2, 4))
	vb.pressed.connect(_on_messenger_verify.bind(w, clues, bids))
	w.add_child(vb)
	var cb = Button.new(); cb.text = "跳过"; cb.position = Vector2(970,620); cb.size = Vector2(180,55)
	cb.add_theme_font_size_override("font_size", 20)
	cb.pressed.connect(_on_messenger_skip.bind(w))
	w.add_child(cb)

func _on_messenger_verify(w: Control, clues: Array, bids: Array) -> void:
	var corr = 0; var wrong = 0
	for cl in clues:
		if bids.has(cl["id"]):
			if cl.get("correct", true): corr += 1
			else: wrong += 1
	var vv := 1
	if wrong > 0: vv = 0
	elif corr >= 3: vv = 3
	elif corr >= 1: vv = 2
	_show_verdict(w, vv, wrong, corr)
	await get_tree().create_timer(2.0).timeout; w.queue_free()
	_messenger_v = vv; _calc_stars(); _show_rating()

func _on_messenger_skip(w: Control) -> void:
	w.queue_free()
	if _wall_auto:
		_messenger_v = 3; _calc_stars(); _show_rating()
	else:
		_phase = Phase.MESSENGER_OBSERVE; _messenger_obs.show()
		_ui.set_dialogue("提示", "已返回观察模式。收集全部 6 处线索后自动进入推理墙。")
		_ui.set_dialogue_color(Color(0.5,0.9,0.5))

func _show_verdict(w: Control, v: int, wrong: int, corr: int) -> void:
	var vt := "INSUFFICIENT"; var vc := Color(0.95,0.8,0.2)
	if wrong > 0: vt = "CONTRADICTORY - 含干扰 "+str(wrong)+" 条"; vc = Color(0.95,0.3,0.3)
	elif v >= 3: vt = "VERIFIED - 正确 "+str(corr)+"/4"; vc = Color(0.3,0.95,0.3)
	elif v >= 2: vt = "SUPPORTED - "+str(corr)+"/4"; vc = Color(0.4,0.8,0.4)
	var rl = Label.new(); rl.text = vt; rl.add_theme_font_size_override("font_size", 36)
	rl.add_theme_color_override("font_color", vc); rl.position = Vector2(0,690); rl.size = Vector2(1920,60)
	rl.horizontal_alignment = 1; w.add_child(rl)

# === 评价 ===

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
	_watson_obs.hide(); _messenger_obs.hide(); _phase = Phase.RATING
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
		for s in it["s"]:
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
	cont.pressed.connect(_on_rating_continue.bind(w))
	w.add_child(cont)

func _on_rating_continue(w: Control) -> void:
	w.queue_free(); _save_and_continue()

func _save_and_continue() -> void:
	_phase = Phase.COMPLETE
	if GameStateMachine: GameStateMachine.go_complete()
	if GameManager: GameManager.add_milestone("sc_01_completed")
	if not (GameManager and GameManager.is_guest) and SaveManager:
		# 关键：自动存档必须写入本场景的 scene_state（phase + scene_id + clue_ids），
		# 否则读档时 _restore_saved_state 因 scene_id 不匹配而判定「无存档」→ 场景从头重启。
		var ids: Array = []
		for c in _watson_obs.get_recorded_clues(): ids.append(c.get("id",""))
		for c in _messenger_obs.get_recorded_clues(): ids.append(c.get("id",""))
		await SaveSystem.request_save("scene1", Phase.COMPLETE, {"clue_ids": ids})
		_create_notification("进度已保存")
	else: _create_notification("注册后可解锁云端存档")
	await get_tree().create_timer(2.0).timeout
	get_tree().change_scene_to_file("res://scenes/scene2.tscn")

# === 笔记、证物 ===

func _open_notebook() -> void:
	var items: Array = []
	for c in _watson_obs.get_recorded_clues():
		items.append({"name":c["name"], "desc":c["desc"], "src":"华生"})
	for c in _messenger_obs.get_recorded_clues():
		items.append({"name":c["name"], "desc":c["desc"], "src":"信使"})
	_popup("侦探笔记", items)

func _open_evidence() -> void:
	var items := []
	for e in [{"t":"热带日晒痕迹","d":"长期烈日暴露留下肤色分界线"},{"t":"军医特征","d":"军人纪律+医生观察力双重特征"},{"t":"阿富汗战争","d":"第二次英阿战争(1878-1880)"},{"t":"锚形文身","d":"水手/海军经典标志"},{"t":"军人仪态","d":"长期训练形成挺直脊柱等特征"}]:
		items.append({"name":"✦ "+e["t"], "desc":e["d"]})
	_popup("证据库", items)

func _popup(title: String, items: Array) -> void:
	var p = Control.new(); p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); p.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(p)
	var dim = ColorRect.new(); dim.color = Color(0,0,0,0.65); dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE; p.add_child(dim)
	var f = Panel.new(); f.size = Vector2(700, 600); f.position = Vector2(610, 240)
	f.add_theme_stylebox_override("panel", _sb(Color(0.13,0.10,0.07,0.97), Color(0.78,0.62,0.28), 3, 8))
	p.add_child(f)
	var t = Label.new(); t.text = title; t.add_theme_font_size_override("font_size", 28)
	t.add_theme_color_override("font_color", Color(0.92,0.82,0.45)); t.position = Vector2(30,20); t.size = Vector2(640,40)
	f.add_child(t)
	var sep = ColorRect.new(); sep.color = Color(0.55,0.42,0.20,0.5); sep.position = Vector2(30,68); sep.size = Vector2(640,1)
	f.add_child(sep)
	if items.is_empty():
		var e = Label.new(); e.text = "尚无记录"; e.add_theme_font_size_override("font_size",18)
		e.add_theme_color_override("font_color", Color(0.55,0.50,0.40)); e.position = Vector2(30,95); e.size = Vector2(640,80); e.horizontal_alignment=1
		f.add_child(e)
	else:
		var sc = ScrollContainer.new(); sc.position = Vector2(20,80); sc.size = Vector2(660,440); f.add_child(sc)
		var vb = VBoxContainer.new(); vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.add_theme_constant_override("separation",8); sc.add_child(vb)
		for i in items.size():
			var it = items[i]
			var c = Panel.new(); c.size = Vector2(640,90)
			c.add_theme_stylebox_override("panel", _sb(Color(0.18,0.14,0.09,0.95), Color(0.50,0.38,0.18), 1, 6))
			var nl = Label.new(); nl.text = str(i+1)+". "+it["name"]; nl.add_theme_font_size_override("font_size",16)
			nl.add_theme_color_override("font_color", Color(0.88,0.80,0.55)); nl.position = Vector2(12,8); nl.size = Vector2(610,24)
			c.add_child(nl)
			if it.has("desc"):
				var dl = Label.new(); dl.text = it["desc"]; dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				dl.add_theme_font_size_override("font_size",13); dl.add_theme_color_override("font_color", Color(0.65,0.60,0.50))
				dl.position = Vector2(12,34); dl.size = Vector2(610,50); c.add_child(dl)
			vb.add_child(c)
	var cb = Button.new(); cb.text = "关闭"; cb.position = Vector2(220,535); cb.size = Vector2(260,45)
	cb.add_theme_font_size_override("font_size",20); cb.add_theme_color_override("font_color", Color(0.92,0.84,0.55))
	cb.add_theme_stylebox_override("normal", _sb(Color(0.20,0.15,0.10,0.95), Color(0.60,0.48,0.25), 2, 4))
	cb.pressed.connect(func(): p.queue_free())
	f.add_child(cb)

func _input(event: InputEvent) -> void:
	if not _dm or not _dm.is_active(): return
	if event is InputEventMouseButton and event.pressed: _dm.advance(); return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_SPACE or event.keycode == KEY_E: _dm.advance()
