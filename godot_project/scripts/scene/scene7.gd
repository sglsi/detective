extends DetectiveScene
## Scene 7 — 郝黎代旅馆（第二被害人斯特兰森）
## 观察驱动（同 scene3 结构）：6 处热点 701-706，含药丸工具组合(704/705)。
## 设计依据：03_关卡设计稿 §3.8 + 线索全表 C_SOTCB_701~706

enum Phase { ARRIVAL, DETECTIVE_DIALOGUE, OBSERVE, REASONING, TRANSITION }

# P3.1：wt = 线索分级权重（关键10/重要5/一般2）。注意：热点矩形宽度用 "w"，权重用 "wt" 以免冲突。
const HOTSPOTS = [
	{"id":"C_SOTCB_701","label":"斯特兰森尸体","name":"斯特兰森尸体","x":320,"y":150,"w":220,"h":46,"wt":5,
	 "desc":"斯特兰森仰面死在床上，胸口插着一刀——与德雷伯服毒而死手法截然不同。","tool":"none","correct":true},
	{"id":"C_SOTCB_702","label":"面部惊惧扭曲","name":"斯特兰森面部特征","x":560,"y":150,"w":220,"h":46,"wt":2,
	 "desc":"死者面部残留极度惊惧，似死前见了极可怕之物。用放大镜细看更明显。","tool":"放大镜","correct":true},
	{"id":"C_SOTCB_703","label":"可开启的窗户","name":"房间窗户可入","x":810,"y":150,"w":220,"h":46,"wt":2,
	 "desc":"房间窗户虚掩，凶手再次选择非常规路径进出——与空屋案呼应。","tool":"none","correct":true},
	{"id":"C_SOTCB_704","label":"两粒药丸","name":"两粒药丸","x":320,"y":560,"w":220,"h":46,"wt":5,
	 "desc":"死者手边有两粒外观相同的药丸，霍普称之为'上帝的裁决'——一粒有毒，一粒无毒。","tool":"化学试剂盒","correct":true},
	{"id":"C_SOTCB_705","label":"药丸实验结果","name":"药丸实验结果","x":600,"y":560,"w":220,"h":46,"wt":10,
	 "desc":"用化学试剂盒验出：一粒含生物碱剧毒、一粒无毒——印证霍普'裁决'手法。","tool":"化学试剂盒","correct":true},
	{"id":"C_SOTCB_706","label":"'J.H.现欧洲'电报","name":"J.H.现欧洲电报","x":860,"y":560,"w":240,"h":46,"wt":10,
	 "desc":"桌上电报写着'J.H.已赴欧洲'——一个月前霍普便离了伦敦，凶手身份再确认。","tool":"none","correct":true},
]

func scene_id() -> String: return "scene7"
func clue_source() -> String: return "scene7"
func hotspots() -> Array: return HOTSPOTS
func scene_title() -> String: return "郝黎代旅馆"
func scene_time_text() -> String: return "DAY 2 深夜23:30"
func scene_background() -> Texture2D: return null

func _phase_name(p: int) -> String:
	match p:
		Phase.ARRIVAL: return "进入旅馆命案现场"
		Phase.DETECTIVE_DIALOGUE: return "警长说明"
		Phase.OBSERVE: return "室内勘查"
		Phase.REASONING: return "推理验证"
		Phase.TRANSITION: return "过渡"
		_: return "未知阶段"

func _in_observe_phase() -> bool: return _phase == Phase.OBSERVE
func _in_reasoning_phase() -> bool: return _phase == Phase.REASONING
func _in_dialogue_phase() -> bool:
	return _phase == Phase.ARRIVAL or _phase == Phase.DETECTIVE_DIALOGUE or _phase == Phase.TRANSITION

func _observe_locked_msg() -> String: return "请先听完警长对现场的说明"
func _observe_open_msg() -> String: return "🔍 观察模式 — 点击屋内的标记点进行勘查"
func _magnifier_msg() -> String: return "🔍 放大镜就绪 — 细看尸体面部与电报"
func _hotspot_tip(tool: String) -> String:
	match tool:
		"放大镜": return "\n\n[🔍 使用放大镜仔细查看 — 初始工具]"
		"化学试剂盒": return "\n\n[🧪 使用化学试剂盒检验 — 场景三解锁工具]"
	return ""

func _npc_talk_text(gc: int) -> String:
	match gc:
		0,1: return "雷斯垂德：\"又一条人命。斯特兰森，胸口挨了一刀——和德雷伯那案子不是一个死法。\""
		2,3: return "福尔摩斯：\"同样的人，不同的手法。霍普在'裁决'——一毒一刃，都出自同一只手。\""
		4,5: return "葛莱森：\"桌上这封电报——'J.H.已赴欧洲'。一个月前他就溜了。\""
		_: return "福尔摩斯：\"屋里的证据够了。把线索摆上推理墙，串起第二桩命案。\""

func _no_evidence_msg() -> String: return "尚未发现任何证据。请先勘查室内。"
func _journal_empty_hint() -> String: return "去室内勘查尸体、窗户与药丸"

func _on_observe_complete() -> void:
	_ui.set_dialogue("华生", "福尔摩斯，旅馆的线索都记下了——斯特兰森被刀杀、窗户可入、两粒药丸一毒一无毒、还有那封赴欧电报……霍普的手法变了，人却还是同一个。")
	await get_tree().create_timer(2.5).timeout
	_enter_reasoning()

func reasoning_hypothesis() -> Dictionary:
	return {
		"title": "斯特兰森亦被霍普以不同手法毒杀，并确认霍普已赴欧",
		"description": "斯特兰森死于利刃（与德雷伯服毒不同手法），但窗户非常规进出、两粒药丸（一毒一无毒的'上帝裁决'）与德雷伯案同源；电报'J.H.已赴欧洲'再确认凶手即霍普，且行凶后已离英。"
	}

func map_locations() -> Array:
	return [
		{"t":"贝克街221B", "d":"福尔摩斯寓所"},
		{"t":"劳瑞斯顿花园街3号", "d":"德雷伯尸体现场"},
		{"t":"郝黎代旅馆", "d":"斯特兰森命案 — 当前场景"},
	]

func casebook_steps() -> Array:
	return ["进入旅馆现场", "听取警长说明", "勘查尸体与药丸", "推理墙验证"]
func casebook_done_flags() -> Array:
	return [_phase >= Phase.DETECTIVE_DIALOGUE, _phase >= Phase.OBSERVE, _clues.size() >= HOTSPOTS.size(), _phase >= Phase.REASONING]

func inventory_items() -> Array:
	return ["🔍 放大镜（初始）", "📏 卷尺（场景二解锁）", "🧪 化学试剂盒（场景三解锁）", "📖 黄页（场景五解锁）"]

func options_lines() -> Array:
	return [
		"难度：" + ["简单","普通","困难"][_difficulty],
		"操作：点击观察→放大/化学检验→记录→推理墙",
		"🧪 化学试剂盒：检验两粒药丸毒性",
		"💡 电报'J.H.赴欧'是锁定霍普的关键",
	]

func _enter_arrival() -> void:
	_start_dialogue(_make_nodes([
		["i0","雷斯垂德","又一条人命，福尔摩斯。郝黎代旅馆，斯特兰森，胸口挨了一刀。"],
		["i1","华生","（迈入屋内）煤气灯忽明忽暗，雨敲着窗。这屋子透着股邪气压人。"],
		["i2","福尔摩斯","（环视四周）同样的人，不同的手法。霍普在'裁决'——一毒一刃，都出自同一只手。"],
		["i3","葛莱森","桌上那封电报你还没看——'J.H.已赴欧洲'。一个月前他就溜了。"]]), "i0", _on_arrival_ended)

func _on_arrival_ended() -> void:
	_show_detective_dialogue()

func _show_detective_dialogue() -> void:
	_phase = Phase.DETECTIVE_DIALOGUE
	_start_dialogue(_make_nodes([
		["j0","雷斯垂德","斯特兰森死前像是见了鬼，脸扭曲得吓人。你说他是被同一个人害的？"],
		["j1","福尔摩斯","同一个人，没错。可德雷伯是服毒，这位是挨刀——霍普在换着法子'裁决'。先看窗户，再验药丸。"],
		["j2","葛莱森","窗户虚掩着，凶手多半从那儿溜的。和头一桩空屋案一个路数。"],
		["j3","福尔摩斯","华生，戴上放大镜，把屋里每样东西都看一遍：尸体、窗户、那两粒药丸、还有电报。"]]), "j0", _on_detective_ended)

func _on_detective_ended() -> void:
	_phase = Phase.OBSERVE
	_obs.show()
	_ui.set_dialogue("提示", "🔍 观察模式已开启。点击屋内的标记点开始勘查（共 " + str(HOTSPOTS.size()) + " 处）。\n左侧 LOOK 可重新激活标记；收集完全部线索后打开推理墙整理。")

func _enter_reasoning() -> void:
	_phase = Phase.REASONING; _wall_auto = true
	_sync_clues()
	_ui.set_dialogue("福尔摩斯", "华生，证据齐了。把线索摆上推理墙——谁死了、怎么死的、窗户怎么进的、药丸是什么、电报说了什么。")
	await get_tree().create_timer(2.5).timeout; _open_wall()

func _enter_transition() -> void:
	_phase = Phase.TRANSITION
	_award()
	_start_dialogue(_make_nodes([
		["k0","福尔摩斯","推理墙印证了：斯特兰森死于霍普之手，手法不同却同源；电报确认霍普已赴欧洲。"],
		["k1","华生","他赴了欧，可冤仇未了。这人迟早会回来。"],
		["k2","雷斯垂德","案子比我们想的复杂。霍普回了伦敦，就在你们眼皮底下——去贝克街，他自会现身。"]]), "k0", _go_to_next_scene)

func _award() -> void:
	if StarRatingSystem:
		StarRatingSystem.add_observation(ClueSystem.total_weight(clue_source()) if ClueSystem else 0)  # P3.1：按线索分级权重累加
		StarRatingSystem.add_reasoning(1)
		StarRatingSystem.add_insight(1)

func _go_to_next_scene() -> void:
	if GameManager and not GameManager.is_guest and SaveManager:
		var ids: Array = []
		for c in _clues: ids.append(c.get("id", ""))
		await SaveSystem.request_save("scene7", Phase.TRANSITION, {"clue_ids": ids})
	SceneLoader.transition_to("res://scenes/scene8.tscn")

func _do_save() -> void:
	if GameManager.is_guest:
		_ui.show_notification("游客模式下无法存档，请先注册账号。"); return
	var ids: Array = []
	for c in _clues: ids.append(c.get("id", ""))
	if ids.is_empty() and ClueSystem:
		for cid in ClueSystem.get_collected_ids(clue_source()): ids.append(cid)
	print("[SAVE scene7] _phase=", _phase, " ids=", ids)
	await SaveSystem.request_save("scene7", _phase, {"clue_ids": ids})
	_ui.show_notification("✅ 进度已保存")

func _restore_saved_state() -> bool:
	var ss = SaveSystem.take_save_state("scene7")
	if ss.is_empty(): return false
	var sp := int(ss.get("phase", 0))
	_phase = sp
	_restore_clues_from_ids(ss.get("clue_ids", []))
	_ui.show_notification("✅ 读档成功 — 已恢复至「" + _phase_name(sp) + "」")
	match sp:
		Phase.ARRIVAL: _enter_arrival(); return true
		Phase.DETECTIVE_DIALOGUE: _show_detective_dialogue(); return true
		Phase.OBSERVE:
			_phase = Phase.OBSERVE
			if _clues.size() >= HOTSPOTS.size():
				_enter_reasoning(); return true
			_ui.restore_observer(_obs, ss.get("clue_ids", []), _owned_ids())
			_ui.set_dialogue("提示", "已恢复进度 — 室内勘查阶段（已收集 " + str(_clues.size()) + "/" + str(HOTSPOTS.size()) + " 条）")
			return true
		Phase.REASONING: _phase = Phase.REASONING; _wall_auto = true; _sync_clues(); _open_wall(); return true
		Phase.TRANSITION: _enter_transition(); return true
	return false
