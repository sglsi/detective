extends DetectiveScene
## Scene 8 — 贝克街221B起居室（最终对决 · 真相闭环）
## 抓捕演出（维金斯通报/皮箱机关/霍普被铐/跳窗未遂）→ 三段式自白
## （盐湖城往事 / 复仇之路 / 作案细节）→ 勘查霍普（衣领马虱卵=马车夫铁证）→
## 推理墙（全案验证）→ 双钩子（善恶升华 + 四签名预告）→ 结局评定。
##
## ⚠️ 分支说明（根因）：框架 DialogueManager 的 trigger=="choice" 未被 SceneFramework 渲染，
## 故自白追问方向、结案走向一律用自定义选项面板，安全不卡死（同 scene4-7）。
##
## 设计依据：02_血字的研究_场景设计与流程 §16（v3.16.0）+ 08_血字的研究_对话台词库 场景八（v3.16.0）
##
## 红线修正（根因，非表面）：旧实现把线索 803「霍普太阳穴血管跳动」标为 correct=false（误导项）。
## 但 02 §16 自白 A-4 明确「凶手患有某种疾病 → VERIFIED（主动脉瘤）」，08 亦将其判为真实症状。
## 太阳穴青筋突跳是霍普主动脉瘤的真实体征，并非误导——旧实现误读。故按 02/08 权威改为 correct=true。

enum Phase { ARRIVAL, OBSERVE, REASONING, TRANSITION }

# 热点权重用 "wt"（"w" 为矩形宽度）；对话线索用 "w"。关键10/重要5/一般2/误导0。
const HOTSPOTS = [
	{"id":"C_SOTCB_801","label":"手背血迹","name":"霍普手背有血","x":700,"y":340,"w":160,"h":48,"wt":5,
	 "desc":"霍普手背沾着干涸血迹，证实他确实到过命案现场、搏斗中割破。","tool":"none","correct":true},
	{"id":"C_SOTCB_802","label":"衣领马虱卵","name":"霍普衣领马虱卵","x":820,"y":270,"w":160,"h":46,"wt":10,
	 "desc":"霍普衣领里嵌着马虱卵——长期与马相伴，马车夫职业的铁证。这是场景八的决定性证据。","tool":"放大镜","correct":true},
]

const DIALOGUE_CLUES = {
	"C_SOTCB_803": {"id":"C_SOTCB_803","name":"霍普太阳穴青筋","desc":"霍普太阳穴青筋突跳、神情亢奋——实为主动脉瘤症状（真实特征，非误导），他自述过不了几天血瘤就要破裂。","correct":true,"w":5},
	"C_SOTCB_804": {"id":"C_SOTCB_804","name":"霍普自白动机","desc":"霍普自白：十八年前犹他荒漠，费里尔父女被摩门教迫害，他立誓复仇——真相闭环。","correct":true,"w":10},
	"C_SOTCB_805": {"id":"C_SOTCB_805","name":"戒指归还","desc":"福尔摩斯将那枚'L·F'戒指交还霍普——物证闭环，呼应场景三核心线索。","correct":true,"w":5},
	"C_SOTCB_806": {"id":"C_SOTCB_806","name":"上帝裁决（药丸选择）","desc":"霍普自白：让德雷伯在兩粒药丸中挑一粒（一粒毒一粒无毒），'让上帝裁决'——斯特兰森拒选才被迫动刀。","correct":true,"w":5},
	"C_SOTCB_807": {"id":"C_SOTCB_807","name":"血字RACHE是复仇宣言","desc":"霍普自白：墙上RACHE是蘸自己鼻血写的，既为复仇宣言，也是为把警察引入歧途的'恶作剧'。","correct":true,"w":2},
}

var _confessed: Dictionary = {}   # 已听取的自白段落（A作案/B动机/C细节）

func scene_id() -> String: return "scene8"
func clue_source() -> String: return "scene8"
func hotspots() -> Array: return HOTSPOTS
func scene_title() -> String: return "贝克街221B 起居室"
func scene_time_text() -> String: return "DAY 3 凌晨"
func scene_background() -> Texture2D: return load("res://assets/scenes/sc_08_finale.jpg")

func _phase_name(p: int) -> String:
	match p:
		Phase.ARRIVAL: return "霍普现身自白"
		Phase.OBSERVE: return "勘查霍普"
		Phase.REASONING: return "推理验证"
		Phase.TRANSITION: return "结案"
		_: return "未知阶段"

func _in_observe_phase() -> bool: return _phase == Phase.OBSERVE
func _in_reasoning_phase() -> bool: return _phase == Phase.REASONING
func _in_dialogue_phase() -> bool: return _phase == Phase.ARRIVAL or _phase == Phase.TRANSITION

func _observe_locked_msg() -> String: return "请先听完霍普的自白"
func _observe_open_msg() -> String: return "🔍 观察模式 — 点击霍普身上的标记点"
func _magnifier_msg() -> String: return "🔍 放大镜就绪 — 细看衣领马虱卵"
func _hotspot_tip(tool: String) -> String:
	match tool:
		"放大镜": return "\n\n[🔍 使用放大镜仔细查看 — 初始工具]"
		"化学试剂盒": return "\n\n[🧪 使用化学试剂盒检验 — 场景三解锁工具]"
	return ""

func _npc_talk_text(gc: int) -> String:
	match gc:
		0,1: return "霍普：\"你们想知道为什么？那就听我把话说完——这桩事，憋了快二十年。\""
		2,3: return "福尔摩斯：\"手背的血、衣领里的马虱卵，都替你说了。先让我看个仔细。\""
		4,5: return "霍普：\"那枚戒指，是她的。还给我吧——这趟我了无牵挂了。\""
		_: return "福尔摩斯：\"证据齐了。把这桩复仇的来龙去脉，摆上推理墙。\""

func _no_evidence_msg() -> String: return "尚未勘查霍普。"
func _journal_empty_hint() -> String: return "听霍普自白、再观察他身上的痕迹"

func _on_observe_complete() -> void:
	_ui.set_dialogue("华生", "福尔摩斯，霍普的动机、血迹、还有衣领里那枚马虱卵——一件件都对上了。这是场跨越十八年的复仇。")
	await get_tree().create_timer(2.5).timeout
	_enter_reasoning()

func reasoning_hypothesis() -> Dictionary:
	return {
		"title": "真相闭环：杰弗森·霍普为费里尔父女复仇，连杀德雷伯与斯特兰森",
		"description": "霍普自白动机（十八年前费里尔父女被摩门教迫害，立誓复仇）；手背血迹证其到过现场；衣领马虱卵是马车夫职业铁证；戒指归还完成物证闭环；上帝裁决解释两种杀人方式。\n\n活跃假设（全案最终确认）：\n· H8-01 凶手=杰弗森·霍普（极强：自白+物证+人证）\n· H8-02 复仇动机（露茜·费里尔）（极强：自白+戒指+背景）\n· H8-03 凶手是马车夫（强：车轮印+马蹄印+无马鞭+跳上马车+马虱卵）\n\n矛盾解决总览（全案21组矛盾清零）：\n· C8-01 老太婆=霍普伪装 vs 霍普本人（已验证：跳上马车+换装+自白）\n· C8-02 血字RACHE=复仇宣言 vs 误导警方（实为双重含义，皆成立）\n· C8-03 卡彭蒂耶中尉=排除 vs 动机吻合（体貌+不在场证明+尸体无伤三重排除）",
		"battlefield": {
			"hypotheses": [
				{"id":"H8-01","text":"凶手=杰弗森·霍普","correct":true},
				{"id":"H8-02","text":"复仇动机（露茜·费里尔）","correct":true},
				{"id":"H8-03","text":"凶手是马车夫","correct":true}
			],
		"contradictions": [
			{"id":"C8-01","text":"老太婆伪装 vs 霍普本人","correct":true},
			{"id":"C8-02","text":"血字RACHE=复仇 vs 误导","correct":true},
			{"id":"C8-03","text":"卡彭蒂耶动机吻合 vs 排除","correct":true}
		],
		"milestones": [
			{"id":"S8-1","text":"凶手=杰弗森·霍普"},
			{"id":"S8-2","text":"复仇动机（露茜·费里尔）"},
			{"id":"S8-3","text":"凶手是马车夫"},
			{"id":"S8-4","text":"完整作案过程：毒杀德雷伯 + 刀杀斯特兰森"},
		],
	},
	# v4.0 三星评价：声明本推理链（逐链离散制）
	"chain_id": scene_id(),
	"expected_clues": HOTSPOTS.size() + DIALOGUE_CLUES.size(),  # 本链应收集线索总数（观察之星缺失条数分母）
	"insight_bonus": 0,   # 场景八无额外隐藏线索加成（洞察之星基础来自战场命中）
	}

func map_locations() -> Array:
	return [
		{"t":"贝克街221B", "d":"福尔摩斯寓所 — 当前场景"},
		{"t":"劳瑞斯顿花园街3号", "d":"德雷伯尸体现场"},
		{"t":"郝黎代旅馆", "d":"斯特兰森命案"},
	]

func casebook_steps() -> Array:
	return ["听霍普自白", "勘查霍普痕迹", "推理墙验证", "结案"]
func casebook_done_flags() -> Array:
	return [_phase >= Phase.OBSERVE, _clues.size() >= (HOTSPOTS.size() + DIALOGUE_CLUES.size()), _phase >= Phase.REASONING, _phase >= Phase.TRANSITION]

func inventory_items() -> Array:
	return ["🔍 放大镜（初始）", "📏 卷尺（场景二解锁）", "🧪 化学试剂盒（场景三解锁）", "📖 黄页（场景五解锁）"]

func options_lines() -> Array:
	return [
		"难度：" + ["简单","普通","困难"][_difficulty],
		"操作：抓捕演出 → 三段自白 → 观察 → 推理墙 → 结案",
		"💡 衣领马虱卵是场景八决定性证据（马车夫铁证）",
		"💡 太阳穴青筋是主动脉瘤真实症状（非误导）",
	]

# ===================== 流程：抓捕演出 → 三段自白 → 观察 → 推理 → 双钩子 =====================

func _enter_arrival() -> void:
	_phase = Phase.ARRIVAL
	# 对齐 08 稿 场景八·抓捕演出（L4699-4750 分支A）+ 自白总起（L4844-4872）
	_start_dialogue([
		_mk_node("c0","系统","（贝克街221B·雨夜）维金斯在楼下叫到马车。福尔摩斯把一只旅行皮箱摆在门边，箱扣松着。","guide",["c1"]),
		_mk_node("c1","维金斯","（门外）先生，马车喊到了，就在下边！","click",["c2"]),
		_mk_node("c2","福尔摩斯","（高声）好孩子！让车夫上来帮我搬箱子。（低声）准备好——他来了。","click",["c3"]),
		_mk_node("c3","系统","（门推开。一个身材魁梧、肤色黝黑的马车夫走进来，目光扫过房间，微微一怔）","guide",["c4"]),
		_mk_node("c4","福尔摩斯","（头也不抬摆弄皮箱）车夫，帮我扣好这个皮带扣。","click",["c5"]),
		_mk_node("c5","系统","（咔嗒——手铐锁死。霍普怒吼挣脱，向窗子冲去，撞碎木框玻璃；葛莱森、雷斯垂德一拥而上，激烈搏斗后将其制伏）","guide",["c6"]),
		_mk_node("c6","福尔摩斯","（喘着气，微笑）他的马车就在下面——就用他的马车送他去苏格兰场吧。在走之前，你有什么要说的吗？","click",["c7"]),
		_mk_node("c7","霍普","（平静地笑了笑）我也许永远不会受到审讯了——我得了主动脉瘤症，过不了几天血瘤就要破裂。我愿意在死前把这件事交代明白。","clue",["c8"],[DIALOGUE_CLUES["C_SOTCB_803"]]),
		_mk_node("c8","福尔摩斯","（拉过椅子坐下）霍普先生，我建议你从头讲起。你想问什么就问吧——他的时间不多了。","click",["end"]),
	], "c0", _show_confession_panel)

func _show_confession_panel() -> void:
	# 对齐 08 稿 自白环节·追问方向选择（L4866-4872）：A 作案经过 / B 动机背景 / C 作案细节（统一基类）
	var questions := [
		{"id":"a","text":"🗡 作案经过 —— 德雷伯怎么死的？", "cb": Callable(self, "_confess_a")},
		{"id":"b","text":"💔 动机背景 —— 你为什么恨他们？", "cb": Callable(self, "_confess_b")},
		{"id":"c","text":"⚗ 作案细节 —— 药丸与血字", "cb": Callable(self, "_confess_c")},
	]
	_render_investigate_panel("霍普的自白 · 选择追问方向", questions, _confessed, Callable(self, "_enter_observe"))

func _confess_a() -> void:
	_confessed["a"] = true
	_start_dialogue([
		_mk_node("a0","霍普","（闭眼）德雷伯……第一个。那天我在陶尔魁里一带徘徊，看见他和斯特兰森上了马车，远远跟着。在尤斯顿车站，德雷伯说有点私事要去办，十一点前回月台。","click",["a1"]),
		_mk_node("a1","霍普","他醉醺醺回来，坐了我的车。到劳瑞斯顿花园街三号那所空宅，我点亮蜡烛，把脸凑近他：'伊诺克·德雷伯，现在你看看我是谁！'他认出我，吓得面如土色。","click",["a2"]),
		_mk_node("a2","霍普","我让他挑一粒药丸——'让上帝裁决'。他吞下毒的那粒，惨叫一声倒地。临死前，我用露茜的戒指举到他眼前。","clue",["a3"],[DIALOGUE_CLUES["C_SOTCB_805"]]),
		_mk_node("a3","霍普","（耸肩）墙上那个RACHE？蘸着我自己的鼻血写的——既是复仇的宣告，也算把警察引入歧途的小把戏。","clue",["a4"],[DIALOGUE_CLUES["C_SOTCB_807"]]),
		_mk_node("a4","华生","（低声）二十年的追踪，竟是以这样的方式收场……","click",["end"]),
	], "a0", _show_confession_panel)

func _confess_b() -> void:
	_confessed["b"] = true
	_start_dialogue([
		_mk_node("b0","霍普","（目光穿过墙壁）你们不懂盐湖城。我父亲是最早的拓荒者，老约翰·费里尔是我最好的朋友，露茜是他女儿——我在荒野里看着她长大。","click",["b1"]),
		_mk_node("b1","霍普","我和露茜相爱了，约定等她十八岁就结婚。可摩门教长老把女人当财产，德雷伯是长老的侄子、教里'明日之星'。他们逼婚，露茜宁死不从，和她父亲都死在了那些人手里。","click",["b2"]),
		_mk_node("b2","霍普","（声音低沉）我立誓：踏遍两大洲，也要让德雷伯看着这只戒指毙命。这一追，就是二十年。","clue",["b3"],[DIALOGUE_CLUES["C_SOTCB_804"]]),
		_mk_node("b3","福尔摩斯","（轻声）所以斯特兰森——是他先认出了你，还是你先找到了他？","click",["end"]),
	], "b0", _show_confession_panel)

func _confess_c() -> void:
	_confessed["c"] = true
	_start_dialogue([
		_mk_node("e0","霍普","斯特兰森比德雷伯还阴毒。我爬梯子从窗户进他房里，本想也让他挑药丸——可这厮不肯选。","click",["e1"]),
		_mk_node("e1","霍普","他拒不就范，我只好拔了刀。毒杀也好、刀刺也好，人都是同一个。两粒药丸，一粒毒一粒无毒——上帝的裁决，由不得他挑。","clue",["e2"],[DIALOGUE_CLUES["C_SOTCB_806"]]),
		_mk_node("e2","华生","（倒吸凉气）所以手法变了，是因为斯特兰森不肯接受'赌命'……","click",["end"]),
	], "e0", _show_confession_panel)

func _enter_observe() -> void:
	_phase = Phase.OBSERVE
	_obs.show()
	_ui.set_dialogue("提示", "🔍 观察模式已开启。点击霍普身上的标记点（共 " + str(HOTSPOTS.size()) + " 处）。\n左侧 LOOK 可重新激活标记；收集完全部线索后打开推理墙。")

func _enter_reasoning() -> void:
	_phase = Phase.REASONING; _wall_auto = true
	_sync_clues()
	_prompt_think("福尔摩斯", "华生，动机、血迹、马虱卵、戒指、上帝裁决——都齐了。把这五条摆上推理墙，给这桩跨越十八年的复仇收尾。", "自信")

func _enter_transition() -> void:
	_phase = Phase.TRANSITION
	_award()
	# 双钩子（08 §12；02 §16 §12）：案件完结升华（善恶灰色）+ 四签名预告
	_start_dialogue([
		_mk_node("z0","福尔摩斯","（点燃烟斗，望着窗外的雨）华生，你看——这就是人性。一个人可以为了复仇横跨半个世界，也可以因为一个女孩的死变成魔鬼。","click",["z1"]),
		_mk_node("z1","华生","那他……是好人还是坏人？","click",["z2"]),
		_mk_node("z2","福尔摩斯","这不是我们能评判的。我们只负责找出真相。","click",["z3"]),
		_mk_node("z3","系统","（画面渐暗。黑屏白字）几个月后——贝克街221B。一位年轻女士的来访：'福尔摩斯先生，我父亲失踪了。'《四签名》· 敬请期待。","guide",["z4"]),
		_mk_node("z4","葛莱森警长","（喃喃）杰弗森·霍普……马车夫……我怎么就没想到呢。","click",["end"]),
	], "z0", _go_to_next_scene)

func _award() -> void:
	# v4.0：三星由推理墙在评星时通过 StarRatingSystem.submit_chain() 逐链提交，本场景不再累加。
	# （保留空实现以兼容 _enter_transition 的调用约定）
	pass

func _go_to_next_scene() -> void:
	if GameManager and not GameManager.is_guest and SaveManager:
		var ids := ClueSystem.get_collected_ids(clue_source()) if ClueSystem else []
		await SaveSystem.request_save("scene8", Phase.TRANSITION, {"clue_ids": ids})
	if GameManager:
		GameManager.end_case("completed")
	_create_notification("案件告破 — 结局已评定")
	await get_tree().create_timer(2.5).timeout
	SceneLoader.transition_to("res://scenes/main_menu.tscn")

# ===================== 自定义选项面板（安全分支） =====================

func _do_save(slot: int = -1) -> void:
	var ids: Array = []
	for c in _clues: ids.append(c.get("id", ""))
	if ids.is_empty() and ClueSystem:
		for cid in ClueSystem.get_collected_ids(clue_source()): ids.append(cid)
	print("[SAVE scene8] _phase=", _phase, " ids=", ids)
	await SaveSystem.request_save("scene8", _phase, {"clue_ids": ids}, slot)
	_ui.show_notification("✅ 进度已保存")

func _restore_saved_state() -> bool:
	var ss = SaveSystem.take_save_state("scene8")
	if ss.is_empty(): return false
	var sp := int(ss.get("phase", 0))
	_phase = sp
	_restore_clues_from_ids(ss.get("clue_ids", []))
	_ui.show_notification("✅ 读档成功 — 已恢复至「" + _phase_name(sp) + "」")
	match sp:
		Phase.ARRIVAL: _enter_arrival(); return true
		Phase.OBSERVE:
			_phase = Phase.OBSERVE
			if _clues.size() >= (HOTSPOTS.size() + DIALOGUE_CLUES.size()):
				_enter_reasoning(); return true
			_ui.restore_observer(_obs, ss.get("clue_ids", []), _owned_ids())
			_ui.set_dialogue("提示", "已恢复进度 — 勘查霍普阶段（已收集 " + str(_clues.size()) + "/" + str(HOTSPOTS.size() + DIALOGUE_CLUES.size()) + " 条）")
			return true
		Phase.REASONING: _phase = Phase.REASONING; _wall_auto = true; _sync_clues(); _open_wall(); return true
		Phase.TRANSITION: _enter_transition(); return true
	return false
