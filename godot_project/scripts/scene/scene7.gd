extends DetectiveScene
## Scene 7 — 郝黎代旅馆（第二被害人 · 综合勘查）
## 抵达（血迹门缝+脸上RACHE，雷斯垂德困惑"手法变了"）→ 三单元自由调查
## （A 尸体/房间勘查 + B 目击证人·送牛奶孩子 + C 物证检验·药丸实验高潮）→
## 推理墙（矛盾标记：两种杀人方式）→ 紧迫感 + 双钩子（两种杀人方式谜题）转场景八。
##
## ⚠️ 分支说明（根因）：框架 DialogueManager 的 trigger=="choice" 未被 SceneFramework 渲染，
## 故步骤选择（药丸实验 / 下一步方向）一律用自定义选项面板，安全不卡死（同 scene4/5/6）。
##
## 设计依据：02_血字的研究_场景设计与流程 §15（v3.16.0）+ 08_血字的研究_对话台词库 场景七（v3.16.0）

enum Phase { ARRIVAL, DETECTIVE_DIALOGUE, OBSERVE, REASONING, TRANSITION }

# 热点权重用 "wt"（"w" 为矩形宽度）。关键10/重要5/一般2/沉默2。
const HOTSPOTS = [
	{"id":"C_SOTCB_701","label":"斯特兰森尸体","name":"斯特兰森尸体","x":320,"y":150,"w":220,"h":46,"wt":10,
	 "desc":"斯特兰森侧卧窗边，睡衣蜷曲。身体左侧一道深刀伤，从肋骨下刺入直抵心脏——与德雷伯服毒死法截然不同。","tool":"none","correct":true},
	{"id":"C_SOTCB_702","label":"脸上血字RACHE","name":"脸上血字RACHE","x":560,"y":150,"w":220,"h":46,"wt":5,
	 "desc":"死者右脸颊用血写着 RACHE，字迹与第一案墙上相似——两案共同铁证之一。","tool":"none","correct":true},
	{"id":"C_SOTCB_703","label":"窗户与窗台脚印","name":"窗户与窗台脚印","x":810,"y":150,"w":220,"h":46,"wt":5,
	 "desc":"窗户大开，窗台湿脚印、窗沿摩擦痕——凶手翻窗进出，不走正门。","tool":"none","correct":true},
	{"id":"C_SOTCB_704","label":"木匣两粒药丸","name":"木匣两粒药丸","x":320,"y":560,"w":220,"h":46,"wt":5,
	 "desc":"窗台木匣两格，一格空、一格有灰色半透明小药丸（味苦）——与德雷伯毒杀推测吻合。可用化学试剂盒检验。","tool":"none","correct":true},
	{"id":"C_SOTCB_706","label":"J.H.现欧洲电报","name":"J.H.现欧洲电报","x":860,"y":560,"w":240,"h":46,"wt":5,
	 "desc":"桌上黄皮电报：J.H.现欧洲。一个月前克利夫兰发来，无署名——J.H.=杰弗森·霍普？","tool":"none","correct":true},
	{"id":"C_SOTCB_707","label":"钱袋80镑","name":"钱袋80镑分文不少","x":320,"y":760,"w":220,"h":46,"wt":5,
	 "desc":"床头柜钱袋属德雷伯，80多镑分文不少——再次排除谋财害命。","tool":"none","correct":true},
	{"id":"C_SOTCB_710","label":"地毯缝隙第二粒药丸","name":"第二粒药丸","x":600,"y":760,"w":240,"h":46,"wt":5,
	 "desc":"地毯与墙缝里发现第二粒药丸，外观与木匣中相同——凶手带了两粒，逃走时掉落。","tool":"none","correct":true},
	{"id":"C_SOTCB_711","label":"床头柜安眠药瓶","name":"D4 安眠药瓶","x":860,"y":760,"w":240,"h":46,"wt":2,
	 "desc":"床头柜安眠药瓶已吃大半，标签泛黄——斯特兰森最近睡不安稳。沉默线索，洞察之星奖励。","tool":"none","correct":true},
]

# 对话授予线索（非观察热点）：送牛奶孩子证词 / 药丸实验结果（实验高潮）
const DIALOGUE_CLUES = {
	"C_SOTCB_708": {"id":"C_SOTCB_708","name":"送牛奶孩子证词","desc":"送奶工见一大个子、红脸、穿棕色长外衣的人从梯子爬窗而下、从容如木匠做活——与第一案醉汉特征完全吻合。","correct":true,"w":5},
	"C_SOTCB_705": {"id":"C_SOTCB_705","name":"药丸一毒一无毒","desc":"化学实验证明：木匣两粒药丸一粒含生物碱剧毒、一粒无毒——凶手的「上帝裁决」式选择。","correct":true,"w":10},
}

func scene_id() -> String: return "scene7"
func clue_source() -> String: return "scene7"
func hotspots() -> Array: return HOTSPOTS
func scene_title() -> String: return "郝黎代旅馆"
func scene_time_text() -> String: return "DAY 2 深夜"
func scene_background() -> Texture2D: return load("res://assets/scenes/sc_07_hotel.jpg")

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
func _magnifier_msg() -> String: return "🔍 放大镜就绪 — 细看尸体与电报"
func _hotspot_tip(tool: String) -> String:
	match tool:
		"放大镜": return "\n\n[🔍 使用放大镜仔细查看 — 初始工具]"
		"化学试剂盒": return "\n\n[🧪 使用化学试剂盒检验 — 场景三解锁工具]"
	return ""

func _npc_talk_text(gc: int) -> String:
	match gc:
		0,1: return "雷斯垂德：\"又是RACHE……可上次是毒死，这次是刀刺——这是同一个人干的吗？\""
		2,3: return "福尔摩斯：\"同一个人，不同的手法。霍普在'裁决'——一毒一刃，都出自同一只手。\""
		4,5: return "葛莱森：\"卡彭蒂耶不可能牵连第二桩案子了——看来你的推断是对的，两案是同一个人。\""
		_: return "福尔摩斯：\"屋里的证据够了。把线索摆上推理墙，串起第二桩命案。\""

func _no_evidence_msg() -> String: return "尚未发现任何证据。请先勘查室内。"
func _journal_empty_hint() -> String: return "去室内勘查尸体、窗户、药丸与电报"

func _on_observe_complete() -> void:
	_ui.set_dialogue("华生", "福尔摩斯，旅馆的线索都记下了——斯特兰森被刀杀、窗户可入、木匣两粒药丸、J.H.电报、钱袋分文不少……霍普的手法变了，人却还是同一个。")
	await get_tree().create_timer(2.0).timeout
	_witness_dialogue()

func reasoning_hypothesis() -> Dictionary:
	return {
		"title": "斯特兰森亦被杰弗森·霍普所杀，两案为同一凶手（矛盾标记：两种杀人方式）",
		"description": "斯特兰森死于利刃（与德雷伯服毒不同手法），但窗户非常规进出、木匣两粒药丸（一毒一无毒的「上帝裁决」）、J.H.电报、送奶工目击（大个子红脸棕外衣）与德雷伯案同源。\n\n活跃假设：\n· H7-01 斯特兰森死于刀伤，非服毒（强：致命伤口+无药丸痕迹）\n· H7-02 药丸一毒一无毒（上帝裁决）（中强：实验结果+两粒外观一致）\n· H7-03 两起案件为同一凶手（强：体貌+红脸+高个+马车夫+血字 RACHE）\n· H7-04 凶手=杰弗森·霍普（强：J.H.电报+美国背景+复仇动机+马车夫）\n\n矛盾标记：\n· C7-01 事实矛盾：德雷伯服毒 vs 斯特兰森被刀杀（同一凶手，为何两种手法？→ 斯特兰森拒选药丸，被迫动刀）\n· C7-02 逻辑矛盾：凶手谨慎缜密 vs 留下血字 RACHE（血字是复仇宣言/仪式，非失误）\n· C7-03 证据矛盾：钱袋80镑分文不少 vs 谋财害命（推翻谋财，确认复仇动机）\n· C7-04 证据矛盾：雷斯垂德找到斯特兰森 vs 找到的是尸体（方向对但慢一步）",
		"battlefield": {
			"hypotheses": [
				{"id":"H7-01","text":"斯特兰森死于刀伤，非服毒","correct":true},
				{"id":"H7-02","text":"药丸一毒一无毒（上帝裁决）","correct":true},
				{"id":"H7-03","text":"两起案件为同一凶手","correct":true},
				{"id":"H7-04","text":"凶手=杰弗森·霍普","correct":true}
			],
			"contradictions": [
				{"id":"C7-01","text":"服毒 vs 刀杀（两种杀人方式）","correct":true},
				{"id":"C7-02","text":"谨慎缜密 vs 留血字RACHE","correct":true},
				{"id":"C7-03","text":"钱袋80镑未失 vs 谋财","correct":true},
				{"id":"C7-04","text":"雷斯垂德找到 vs 找到的是尸体","correct":true}
			],
		}
	}

func map_locations() -> Array:
	return [
		{"t":"贝克街221B", "d":"福尔摩斯寓所"},
		{"t":"劳瑞斯顿花园街3号", "d":"德雷伯尸体现场"},
		{"t":"郝黎代旅馆", "d":"斯特兰森命案 — 当前场景"},
	]

func casebook_steps() -> Array:
	return ["进入旅馆现场", "听取警长说明", "勘查尸体/药丸/电报", "药丸实验", "推理墙验证"]
func casebook_done_flags() -> Array:
	return [_phase >= Phase.DETECTIVE_DIALOGUE, _phase >= Phase.OBSERVE, _clues.size() >= (HOTSPOTS.size() + DIALOGUE_CLUES.size()), _phase >= Phase.REASONING]

func inventory_items() -> Array:
	return ["🔍 放大镜（初始）", "📏 卷尺（场景二解锁）", "🧪 化学试剂盒（场景三解锁）", "📖 黄页（场景五解锁）"]

func options_lines() -> Array:
	return [
		"难度：" + ["简单","普通","困难"][_difficulty],
		"操作：点击观察→放大镜/化学检验→记录→送奶工证词→药丸实验→推理墙",
		"🧪 化学试剂盒：检验木匣药丸毒性（高潮）",
		"💡 J.H.电报 + 送奶工「红脸棕外衣」是锁定霍普的关键",
	]

# ===================== 流程：抵达 → 警长说明 → 观察 → 送奶工 → 药丸实验 → 推理 → 双钩子 =====================

func _enter_arrival() -> void:
	_phase = Phase.ARRIVAL
	# 对齐 08 稿 场景七·阶段0（L3651-3695）：血迹门缝 + 脸上RACHE + 雷斯垂德困惑"手法变了"
	_start_dialogue([
		_mk_node("i0","系统","（场景切换：小乔治街·郝黎代旅馆三楼）一道曲曲弯弯的血迹由302房门下流出，流过走道，汇集在对面墙脚。血还未凝固。","guide",["i1"]),
		_mk_node("i1","雷斯垂德警长","（倒吸凉气）我的天……快，撞开房门！","click",["i2"]),
		_mk_node("i2","系统","（房门反锁，合力撞开）屋里窗户大开，窗边躺着一具穿睡衣的男尸，蜷曲成一团，早已断气。死者脸上——用血写着 RACHE。","guide",["i3"]),
		_mk_node("i3","福尔摩斯","（蹲下身，声音低沉）我们来晚了一步。这是斯特兰森……凶手没有放过他。","click",["i4"]),
		_mk_node("i4","雷斯垂德警长","（脸色苍白）又是RACHE……可是上次是毒死的，这次是刀刺——这是同一个人干的吗？","click",["i5"]),
		_mk_node("i5","华生","（倒吸凉气）难道——还有另一个凶手？","click",["end"]),
	], "i0", _on_arrival_ended)

func _on_arrival_ended() -> void:
	_show_detective_dialogue()

func _show_detective_dialogue() -> void:
	_phase = Phase.DETECTIVE_DIALOGUE
	# 对齐 08 稿 阶段0 末 + 阶段1 引导（L3686-3720）
	_start_dialogue(_make_nodes([
		["j0","福尔摩斯","（目光扫过房间）先别急着下结论，华生。斯特兰森是刀伤，德雷伯是服毒——手法不同，但别的或许一样。把屋子每样东西都看一遍。"],
		["j1","雷斯垂德","窗户虚掩着，凶手多半从那儿溜的。和头一桩空屋案一个路数。可死法不一样啊……"],
		["j2","福尔摩斯","同一只手，可以换刀子。华生，戴上放大镜——尸体、窗户、那两粒药丸、还有电报，一处都别漏。"]]), "j0", _on_detective_ended)

func _on_detective_ended() -> void:
	_phase = Phase.OBSERVE
	_obs.show()
	_ui.set_dialogue("提示", "🔍 观察模式已开启。点击屋内的标记点开始勘查（共 " + str(HOTSPOTS.size()) + " 处）。\n左侧 LOOK 可重新激活标记；收集完全部线索后听取送奶工证词、再做药丸实验。")

func _witness_dialogue() -> void:
	# 对齐 08 稿 阶段1·单元B（L4079-4109）：送牛奶孩子目击（大个子/红脸/棕外衣/梯子爬窗）
	if StarRatingSystem:
		StarRatingSystem.add_insight(0.5)
	_start_dialogue([
		_mk_node("w0","系统","（走廊外，一个十二三岁、脸上带雀斑的送奶工凑上前来）","guide",["w1"]),
		_mk_node("w1","送奶工","（抢着说）我看到了！我看到凶手了！旅馆后巷，梯子竖起来靠着三楼开着的窗户——一个人不慌不忙、从从容容地爬了下来！","click",["w2"]),
		_mk_node("w2","送奶工","我还以为是木匠做活呢。那人是个大个子，红红的脸，身上穿着一件长长的棕色外衣——跟我家隔壁马车夫穿的颜色一模一样！","clue",["w3"],[DIALOGUE_CLUES["C_SOTCB_708"]]),
		_mk_node("w3","福尔摩斯","（与华生对视）大个子、红脸、棕色长外衣——和兰斯在奥德利大院看到的醉汉，一字不差。是同一只手。","click",["end"]),
	], "w0", _pill_experiment_choice)

func _pill_experiment_choice() -> void:
	# 对齐 08 稿 阶段1·单元C Step6 药丸实验（高潮，L4376-4541）
	_show_choice_panel("关键物证检验 · 下一步", [
		{"text":"⚗ 进行药丸实验（高潮）— 用化学试剂盒检验木匣药丸", "cb": Callable(self, "_pill_experiment")},
		{"text":"先跳过，直接上推理墙", "cb": Callable(self, "_enter_reasoning")},
	])

func _pill_experiment() -> void:
	# 08 药丸实验：第一粒无反应 → 福尔摩斯顿悟「上帝裁决」→ 第二粒剧烈反应 → VERIFIED
	_start_dialogue([
		_mk_node("e0","福尔摩斯","（取出木匣中那粒灰色药丸，用小刀切半，放入试管加试剂）看吧，华生——如果它就是杀死德雷伯的毒药，两案就是同一个人干的。","click",["e1"]),
		_mk_node("e1","系统","（试管中毫无反应，液体依然透明）","guide",["e2"]),
		_mk_node("e2","雷斯垂德警长","（松口气）看来不是毒药嘛。我就说，两起案子手法差这么多，怎么可能是同一个人——","click",["e3"]),
		_mk_node("e3","福尔摩斯","（眉头紧锁，踱步）这绝不可能仅仅是巧合！木匣里两粒药丸……一粒是烈性毒药，另一粒完全无毒！上帝的审判——让命运来选择！","click",["e4"]),
		_mk_node("e4","系统","（玩家在地毯缝隙找到第二粒药丸，切半入试管加试剂——剧烈反应！液体瞬间化为深黑，冒着泡，嘶嘶作响）","guide",["e5"]),
		_mk_node("e5","福尔摩斯","（长吁一口气）对！就是它！一粒有毒、一粒无毒——斯特兰森拒绝选择，凶手才被迫动刀。这解释了为什么手法变了：人没变，裁决的方式变了。","clue",["e6"],[DIALOGUE_CLUES["C_SOTCB_705"]]),
		_mk_node("e6","福尔摩斯","（转向雷斯垂德）血字RACHE、11英寸鞋码、六英尺身高、红脸棕外衣、从容心理素质、同一种罕见毒药——六条线索同时指向同一个人。你告诉我，这概率有多大？","click",["end"]),
	], "e0", _enter_reasoning)

func _enter_reasoning() -> void:
	_phase = Phase.REASONING; _wall_auto = true
	_sync_clues()
	_ui.set_dialogue("福尔摩斯", "华生，证据齐了：斯特兰森死于刀、窗户可入、木匣两粒药丸（一毒一无毒）、J.H.电报、送奶工的红脸棕外衣。把这若干条摆上推理墙——同一种罕见毒药出现在两个现场，便是铁证。", "自信")
	await get_tree().create_timer(2.5).timeout; _open_wall()

func _enter_transition() -> void:
	_phase = Phase.TRANSITION
	_award()
	# 紧迫感机制 + 双钩子（08 §9 / §12；02 §15 §9/§12）：霍普可能逃走 + 两种杀人方式谜题 → 场景八
	_start_dialogue([
		_mk_node("z0","福尔摩斯","（站起身）两案是同一个人。红脸、高个、棕外衣、马车夫、两粒药丸——碎片正在拼成完整的图像。","click",["z1"]),
		_mk_node("z1","分队小孩","（气喘吁吁跑上楼）先生！打听到了——霍普今天出车了，但行踪飘忽，一上午换了三个区，像在躲什么人。","click",["z2"]),
		_mk_node("z2","福尔摩斯","（脸色微变）不好——他可能听到风声了。若今晚离开伦敦，我们就再也抓不到他。必须在今晚之前把他引出来。","click",["z3"]),
		_mk_node("z3","华生","（思索）同一个凶手……可为什么德雷伯下毒、斯特兰森动刀？这说不通啊。","click",["z4"]),
		_mk_node("z4","福尔摩斯","（赞赏）好问题，华生。一个人手法通常稳定——变了，一定有原因。答案就在那两粒药丸里：斯特兰森不肯选，凶手才拔了刀。回贝克街，设下圈套，让他自己找上门来。","click",["end"]),
	], "z0", _go_to_next_scene)

func _award() -> void:
	if StarRatingSystem:
		StarRatingSystem.add_observation(ClueSystem.total_weight(clue_source()) if ClueSystem else 0)  # 按线索分级权重累加
		StarRatingSystem.add_reasoning(1)
		StarRatingSystem.add_insight(1)

func _go_to_next_scene() -> void:
	if GameManager and not GameManager.is_guest and SaveManager:
		var ids: Array = []
		for c in _clues: ids.append(c.get("id", ""))
		await SaveSystem.request_save("scene7", Phase.TRANSITION, {"clue_ids": ids})
	SceneLoader.transition_to("res://scenes/scene8.tscn")

# ===================== 自定义选项面板（安全分支） =====================
func _show_choice_panel(title_txt: String, options: Array) -> void:
	if _modal_panel and is_instance_valid(_modal_panel):
		_modal_panel.queue_free(); _modal_panel = null
	var o := Panel.new()
	o.position = Vector2(460, 180); o.size = Vector2(1000, 640); o.z_index = 100
	o.add_theme_stylebox_override("panel", _sb(Color(0.08, 0.06, 0.04, 0.97), Color(0.78, 0.62, 0.28), 2, 6))
	var tt := Label.new(); tt.text = title_txt; tt.position = Vector2(30, 20); tt.add_theme_font_size_override("font_size", 26)
	tt.add_theme_color_override("font_color", Color(0.85, 0.75, 0.45)); o.add_child(tt)
	var y := 84
	for opt in options:
		var b := Button.new()
		b.text = opt["text"]
		b.position = Vector2(40, y); b.size = Vector2(920, 70)
		b.add_theme_font_size_override("font_size", 20)
		b.add_theme_color_override("font_color", Color(0.92, 0.85, 0.65))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var bs := StyleBoxFlat.new(); bs.bg_color = Color(0.14, 0.10, 0.06, 0.95); bs.border_color = Color(0.55, 0.42, 0.20)
		bs.border_width_left = 2; bs.border_width_right = 2; bs.border_width_top = 2; bs.border_width_bottom = 2; bs.set_corner_radius_all(4)
		b.add_theme_stylebox_override("normal", bs)
		var bsh := StyleBoxFlat.new(); bsh.bg_color = Color(0.25, 0.16, 0.08, 0.95); bsh.border_color = Color(0.80, 0.68, 0.38)
		bsh.border_width_left = 2; bsh.border_width_right = 2; bsh.border_width_top = 2; bsh.border_width_bottom = 2; bsh.set_corner_radius_all(4)
		b.add_theme_stylebox_override("hover", bsh)
		var cb_callable: Callable = opt["cb"]
		b.pressed.connect(func(): _close_modal(); cb_callable.call())
		o.add_child(b); y += 80
	add_child(o); _register_modal(o, "choice_" + title_txt)

func _do_save(slot: int = -1) -> void:
	var ids: Array = []
	for c in _clues: ids.append(c.get("id", ""))
	if ids.is_empty() and ClueSystem:
		for cid in ClueSystem.get_collected_ids(clue_source()): ids.append(cid)
	print("[SAVE scene7] _phase=", _phase, " ids=", ids)
	await SaveSystem.request_save("scene7", _phase, {"clue_ids": ids}, slot)
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
			if _clues.size() >= (HOTSPOTS.size() + DIALOGUE_CLUES.size()):
				_enter_reasoning(); return true
			_ui.restore_observer(_obs, ss.get("clue_ids", []), _owned_ids())
			_ui.set_dialogue("提示", "已恢复进度 — 室内勘查阶段（已收集 " + str(_clues.size()) + "/" + str(HOTSPOTS.size() + DIALOGUE_CLUES.size()) + " 条）")
			return true
		Phase.REASONING: _phase = Phase.REASONING; _wall_auto = true; _sync_clues(); _open_wall(); return true
		Phase.TRANSITION: _enter_transition(); return true
	return false
