extends DetectiveScene
## Scene 4 — 奥德利大院四十六号（兰斯巡警证词）
## 人证调查类型的「六步闭环」（08 台词库场景四 v3.16.0 对齐版）：
## 入场（下午走访，兰斯值完夜班补觉）→ 沉默线索 D1 → 三选一初始追问方向
## → Step1 初始叙述（难度分层 + 概率干扰：普通 30% 时间模糊/50% 印度人闲聊；困难 70% "有个女的"/70% "瘦脸尖"）
## → Step2 六方向追问 → Step3 证词提取 8 项 → Step4 知识检索 → 推理墙（12 条假设 + 1 条误导，按证词解锁）
## → 过渡（五条线教学"三条线开始成形，五条线就是事实" + 按实际追问动态总结 + 华生"为什么凶手要回来"）
## → 行动决策 A/B/C（C 路线播完电报台词并存 scene4_route="C"，场景六/七的分支后续接入）。
##
## ⚠️ 概率干扰说明（思傅 2026-09-03 拍板）：保留 randf() 概率触发而非固定出现——
## 概率的目的是给重玩带来不确定性，固定化会减少玩家探索欲。
##
## ⚠️ 分支实现说明（根因）：本框架的 DialogueManager 虽支持 trigger=="choice"，
## 但 SceneFramework 未连接 choice_presented、不渲染选项按钮 → 直接用 choice 节点会卡死。
## 故本场景所有玩家分支（初始追问方向 / 六方向追问面板 / 行动决策 A-B-C / 沉默线索 D1）
## 一律用「自定义选项面板」(_show_choice_panel)：对话结束后弹按钮、回调驱动，安全不卡死。
##
## 设计依据：02_血字的研究_场景设计与流程 §12（v3.16.0）+ 08_血字的研究_对话台词库 场景四（v3.16.0）
##
## 红线修正（根因，非表面）：线索 403「醉汉红脸」在 03_关卡设计稿被标"误导·可能误判重病"，
## 旧实现据此把该线索整体判 correct=false。但 02 §12 将其列为【关键线索】、08 Step6 判定为
## SUPPORTED（与场景三"凶手高个红脸"画像吻合）。二者并不矛盾：红脸是凶手真实面貌特征，
## "误判为重病"才是陷阱。故按 02/08 权威改为 correct=true，描述点明"勿误判重病"。

enum Phase { ARRIVAL, REASONING, TRANSITION }

## 本场景线索权威定义（id/name/desc/correct/w）。
## 经 DialogueManager clue 触发 → ClueSystem.collect_clue_from_catalog（无 .tres 时回退内联文本）。
## 401 醉汉（必得）402 高个 403 红脸（真实关键线索）404 棕外衣 405 无马鞭（深度追问）
## 406 醉汉唱科隆比纳（其他异常）407 案发时马车经过（马车方向追问）。
const CLUES = {
	"C_SOTCB_401": {"id":"C_SOTCB_401","name":"巡警看到'醉汉'","desc":"案发当晚兰斯巡警在院外看到一个摇摇晃晃的醉汉离开——案发后有人离开现场，且就在门口。","correct":true,"w":5},
	"C_SOTCB_402": {"id":"C_SOTCB_402","name":"醉汉身高6英尺+","desc":"兰斯估摸那醉汉身高得有六英尺出头，与花园街现场留下的高大足迹吻合。","correct":true,"w":5},
	"C_SOTCB_403": {"id":"C_SOTCB_403","name":"醉汉红脸","desc":"兰斯证词：醉汉面色赤红。与场景三'凶手高个红脸'画像吻合（SUPPORTED）。但红脸是凶手天然特征（动脉瘤），切勿误判为'重病'——那才是误导陷阱。","correct":true,"w":5},
	"C_SOTCB_404": {"id":"C_SOTCB_404","name":"醉汉棕色外衣","desc":"醉汉披一件棕色外衣，是伦敦出租马车夫常见的装束。","correct":true,"w":5},
	"C_SOTCB_405": {"id":"C_SOTCB_405","name":"醉汉无马鞭","desc":"追问到深处，兰斯先说'好像有根鞭子'，又立刻改口'肯定没有，我看错了'——他犹豫了，这本身也是信息：凶手（马车夫）下车走过来的，马鞭挂在马车上。","correct":true,"w":5},
	"C_SOTCB_406": {"id":"C_SOTCB_406","name":"醉汉唱科隆比纳","desc":"兰斯说醉汉唱得响——科隆比纳那段，歌剧《宠姬》（La Favorite）的著名咏叹调。时代氛围线索，也是'行为反常'一线。","correct":true,"w":2},
	"C_SOTCB_407": {"id":"C_SOTCB_407","name":"案发时马车经过","desc":"兰斯证词：他巡夜时有一两辆出租马车路过布瑞克斯顿路——与花园街的出租马车轮印、右前蹄新蹄铁形成交叉验证。","correct":true,"w":4},
}

var _asked_directions: Dictionary = {}   # 已追问方向（用于全追问洞察加成与提示）
var _d1_seen: bool = false               # 沉默线索 D1（墙上旧照片）是否已发现
var _insight_bonus: int = 0              # v4.0 洞察星级加成（隐藏线索/全追问累计，封顶由墙处理）

func scene_id() -> String: return "scene4"
func clue_source() -> String: return "scene4"
func hotspots() -> Array: return []
func scene_title() -> String: return "奥德利大院 四十六号"
func scene_time_text() -> String: return "DAY 1 下午"
func scene_background() -> Texture2D: return load("res://assets/scenes/sc_04_police.jpg")

## 氛围遮罩已按需求移除（谜雾/灯光按钮及相关功能）。场景四为下午两点走访奥德利大院。
func wants_atmosphere() -> bool: return false

func _phase_name(p: int) -> String:
	match p:
		Phase.ARRIVAL: return "询问兰斯巡警"
		Phase.REASONING: return "推理验证"
		Phase.TRANSITION: return "过渡"
		_: return "未知阶段"

func _in_observe_phase() -> bool: return false
func _in_reasoning_phase() -> bool: return _phase == Phase.REASONING
func _in_dialogue_phase() -> bool: return _phase == Phase.ARRIVAL or _phase == Phase.TRANSITION

func _observe_locked_msg() -> String: return "本场景无线索可观察，请与兰斯巡警对话"
func _npc_talk_text(_g: int) -> String: return "兰斯警士：\"案子那天晚上，我瞅见个醉醺醺的高个子从院里晃悠出去了——门口还靠着个醉汉，唱得震天响。\""
func _no_evidence_msg() -> String: return "尚未从兰斯巡警处获得证词"
func _journal_empty_hint() -> String: return "与兰斯巡警对话收集线索"

# ===== 推理假设（台词库 §18 场景四：12 条假设按证词解锁 + 1 条困难模式误导）=====
func reasoning_hypothesis() -> Dictionary:
	return {
		"title": "醉汉=凶手（兰斯证词 · 推理战场 M1）",
		"description": "人证调查六步闭环：从兰斯的叙述中筛出有用信息、识别可能的记忆偏差，并与场景二/三的发现交叉印证。\n\n核心原则：未追问到的细节不出现在后续推理中；证词是证人说的，不是事实。\n\n推理层级（台词库 §18 场景四）：\n· VERIFIED 已证实：案发时间≈凌晨两点 / 正在下雨 / 门口有个醉汉\n· SUPPORTED 有支持待证：高个红脸 / 棕色外衣 / 醉汉=凶手 / 凶手坐马车来 / 凶手伪装醉汉逃走 / 兰斯错过凶手\n· INSUFFICIENT 证据不足：可能有马鞭 / 醉汉是同伙 / 醉汉无关路过\n· CONTRADICTORY 与证据矛盾（困难模式误导）：醉汉旁边还有个女人（现场两组男式靴印，无女式鞋印）\n\n矛盾标记：\n· C4-01 兰斯'瘦脸尖' vs 场景三'高个红脸宽脸膛'画像 → 记忆会自己补故事\n· C4-02 精心策划的复仇 vs 唱着歌被目击 → 伪装（灯下黑）\n· C4-03 无马鞭 vs 马车夫 → 马鞭挂在马车上，醉汉是下车走来的\n· C4-04 '有个女的' vs 现场两组男式靴印",
		"battlefield": {
			"hypotheses": [
				# ══ 台词库 §18 场景四 假设清单 1~12（按已获证词解锁）══
				{"id":"H4-01","text":"案发时间约凌晨两点","kind":"true","correct":true,"dir":"affirm","subject":["案发"],"object":["凌晨两点"],
				 "gate_clue_ids":["C_SOTCB_401"],
				 "adopt_desc":"VERIFIED：兰斯明确证词——两点出头、两点过十分。他在里面待了几分钟就吹了警笛，摩契他们两三分钟就到。时间线收口了。",
				 "new_clue_hint":""},
				{"id":"H4-02","text":"案发时正在下雨","kind":"true","correct":true,"dir":"affirm","subject":["案发"],"object":["下雨"],
				 "gate_clue_ids":["C_SOTCB_401"],
				 "adopt_desc":"VERIFIED：夜里一点开始下雨——兰斯巡夜全程在雨里，花园街泥地的痕迹也对得上。",
				 "new_clue_hint":""},
				{"id":"H4-03","text":"门口有个醉汉","kind":"true","correct":true,"dir":"affirm","subject":["现场"],"object":["醉汉"],
				 "gate_clue_ids":["C_SOTCB_401"],
				 "adopt_desc":"VERIFIED：兰斯亲眼看见——街灯底下，唱得震天响，站都站不住，他还提灯过去想轰走他。",
				 "new_clue_hint":""},
				{"id":"H4-04","text":"醉汉高个红脸","kind":"true","correct":true,"dir":"affirm","subject":["醉汉"],"object":["高个","红脸"],
				 "gate_clue_ids":["C_SOTCB_402","C_SOTCB_403"],
				 "adopt_desc":"SUPPORTED：街灯下、提灯照脸、一两步的距离——这份证词就可靠了。高个、红脸，和花园街'凶手高个红脸'的画像对上了。",
				 "new_clue_hint":""},
				{"id":"H4-05","text":"醉汉穿棕色外衣（马车夫装束）","kind":"true","correct":true,"dir":"affirm","subject":["醉汉"],"object":["棕色外衣","马车夫"],
				 "gate_clue_ids":["C_SOTCB_404"],
				 "adopt_desc":"SUPPORTED：提灯照着看得真真的——一件棕色外衣，是伦敦出租马车夫常见的装束。",
				 "new_clue_hint":""},
				{"id":"H4-06","text":"醉汉可能带着马鞭","kind":"true","correct":false,"dir":"affirm","subject":["醉汉"],"object":["马鞭"],
				 "gate_clue_ids":["C_SOTCB_405"],
				 "adopt_desc":"INSUFFICIENT：兰斯先说'好像有根鞭子'，又立刻改口'肯定没有'——犹豫本身也是信息，但还定不了。",
				 "reject_desc":"他没有说谎，也没有看错——马鞭本来就挂在马车上。醉汉是下车走过来的。"},
				{"id":"H4-07","text":"醉汉就是凶手","kind":"true","correct":true,"dir":"affirm","subject":["醉汉"],"object":["凶手"],
				 "gate_clue_ids":["C_SOTCB_401","C_SOTCB_402","C_SOTCB_403"],
				 "adopt_desc":"SUPPORTED：凌晨两点，一个高个红脸的男人，站在一栋空房子门口唱歌——喝醉了。嗯，这是个'巧合'。你信巧合吗？——华生，你太善良了。",
				 "new_clue_hint":""},
				{"id":"H4-08","text":"醉汉是凶手的同伙","kind":"true","correct":false,"dir":"affirm","subject":["醉汉"],"object":["同伙"],
				 "gate_clue_ids":["C_SOTCB_401"],
				 "adopt_desc":"INSUFFICIENT：目前没有任何证据指向'同伙'——只是看到'有人'就想多加一个。",
				 "reject_desc":"现场只有两组男式靴印。同伙？先有第二个'人'的痕迹再说。"},
				{"id":"H4-09","text":"醉汉只是无关路人","kind":"true","correct":false,"dir":"affirm","subject":["醉汉"],"object":["无关"],
				 "gate_clue_ids":["C_SOTCB_401"],
				 "adopt_desc":"INSUFFICIENT：……'无关'？凌晨两点。空房子门口。装作烂醉。——你觉得，'无关'这个词，用在这里合适吗？",
				 "reject_desc":"答案不是'因为他是醉汉'——答案是'他需要你相信他是醉汉'。"},
				{"id":"H4-10","text":"凶手坐马车来（案发时有马车出没）","kind":"true","correct":true,"dir":"affirm","subject":["凶手"],"object":["马车"],
				 "gate_clue_ids":["C_SOTCB_407"],
				 "adopt_desc":"SUPPORTED：花园街的出租马车轮印 + 兰斯证词'巡夜时有一两辆马车路过'——现场确实有马车出没。马鞭。马车。车夫。",
				 "new_clue_hint":""},
				{"id":"H4-11","text":"凶手伪装成醉汉逃走","kind":"true","correct":true,"dir":"affirm","subject":["凶手"],"object":["伪装","灯下黑"],
				 "gate_clue_ids":["C_SOTCB_405","C_SOTCB_407"],
				 "adopt_desc":"SUPPORTED：一个人看到屋里有尸体，第一反应是什么？是吹警笛叫人。那一刻，谁会去看门口一个唱得难听的醉汉？——'灯下黑'三个字，你今天第一次用对了地方。",
				 "new_clue_hint":""},
				{"id":"H4-12","text":"兰斯错过了凶手","kind":"true","correct":true,"dir":"affirm","subject":["兰斯"],"object":["错过"],
				 "gate_clue_ids":["C_SOTCB_401"],
				 "adopt_desc":"SUPPORTED：他进屋看见尸体，第一反应是叫人——光顾着吹警笛，没注意门口那个'醉汉'又待了多久、往哪边走了。",
				 "new_clue_hint":""},
				# ══ 困难模式强误导（概率 70% 出现，"有个女的"）══
				{"id":"H4-M1","text":"醉汉旁边还有一个女人（兰斯证词）","kind":"mislead","correct":false,"dir":"affirm","subject":["醉汉"],"object":["女人"],
				 "gate_clue_ids":["C_SOTCB_401"],
				 "adopt_desc":"CONTRADICTORY：现场两组男式靴印，一组方头、一组漆皮——没有第三组，没有任何女式鞋印。兰斯是真的看见了，还是——他需要'看见'？证人说谎，有时候不是为害人，是为了让自己在故事里更像个主角。",
				 "reject_desc":"好眼力——但记住：证人需要'看见'的时候，就会'看见'。这条先放一放，跟靴印对一对再说。"}
			],
		"conclusions": [
			{"id":"CL4-1","text":"醉汉就是凶手——一个赶着马车来的车夫","kind":"true","dir":"affirm","subject":["凶手"],"object":["马车夫"],"gate_hypo_ids":["H4-07","H4-05","H4-10"],
			 "adopt_desc":"马鞭。马车。车夫。——你把这些拼起来：一个人赶着马车，把受害人送进那栋空房子，然后自己又唱着歌走出来。但别急。我们还在猜。猜得再漂亮，也不是证据。"},
			{"id":"CL4-2","text":"凶手伪装成醉汉逃走——灯下黑","kind":"true","dir":"affirm","subject":["凶手"],"object":["伪装"],"gate_hypo_ids":["H4-07","H4-11"],
			 "adopt_desc":"最危险的地方就是最安全的地方。一个烂醉的流浪汉，谁会把他和杀人犯联系在一起？——他的表演本身就是供词。"},
			{"id":"CL4-3","text":"案发时间线：凌晨两点、下雨，兰斯错过了凶手","kind":"true","dir":"affirm","subject":["时间线"],"object":["凌晨两点"],"gate_hypo_ids":["H4-01","H4-02","H4-12"],
			 "adopt_desc":"两点十分、雨里、几分钟后才叫人——时间线收口了。而凶手，就在这几分钟里从兰斯的眼皮底下走掉了。"}
		],
		"contradictions": [
			{"id":"C4-01","text":"兰斯'瘦脸尖' vs 场景三'高个红脸宽脸膛'画像 → 记忆会自己补故事","correct":true},
			{"id":"C4-02","text":"精心策划的复仇 vs 唱着歌被目击 → 伪装（灯下黑）","correct":true},
			{"id":"C4-03","text":"无马鞭 vs 马车夫 → 马鞭挂在马车上，醉汉是下车走来的","correct":true},
			{"id":"C4-04","text":"'有个女的' vs 现场两组男式靴印（无女式鞋印）","correct":true}
		],
		"milestones": [
			{"id":"S4-1","text":"醉汉即凶手：高个红脸棕外衣，五线合一"},
			{"id":"S4-2","text":"凶手是坐马车的车夫（无马鞭=下车走来）"},
			{"id":"S4-3","text":"凶手伪装成醉汉逃走（灯下黑）"},
			{"id":"S4-4","text":"证词时间线：凌晨两点·下雨·兰斯错过凶手"},
		],
	},
	# v4.0 三星评价：声明本推理链（逐链离散制）
	"chain_id": scene_id(),
	"expected_clues": CLUES.size(),  # 本链应收集线索总数（观察之星缺失条数分母）
	"insight_bonus": _insight_bonus,  # 隐藏线索 D1 + 六方向全追问 累计加成
}

func map_locations() -> Array:
	return [
		{"t":"贝克街221B", "d":"福尔摩斯寓所 — 场景一"},
		{"t":"劳瑞斯顿花园街3号", "d":"尸体现场 — 场景三"},
		{"t":"奥德利大院四十六号", "d":"巡警宿舍 — 当前场景"},
	]

func casebook_steps() -> Array:
	return ["下午走访兰斯巡警", "初始追问+六方向追问", "推理墙验证", "阶段末小结与决策"]
func casebook_done_flags() -> Array:
	return [_phase >= Phase.ARRIVAL, _asked_directions.size() >= 6, _phase >= Phase.REASONING, _phase >= Phase.TRANSITION]

func inventory_items() -> Array:
	return ["🔍 放大镜（初始）", "📏 卷尺（场景二解锁）", "🧪 化学试剂盒（场景三解锁）", "🪙 半镑金币（敲门砖）"]

func options_lines() -> Array:
	return [
		"难度：" + ["简单","普通","困难"][_difficulty],
		"操作：对话收集线索 → 六方向追问 → 推理墙验证 → 行动决策",
		"⚠️ 红脸是凶手真实特征（动脉瘤），勿误判为'重病'",
		"📌 原则：证词是证人说的，不是事实——未追问到的细节不进推理",
		"💡 洞察：发现墙上旧照片、六方向全追问均有加成；证人证词可能带偏差",
	]

# ===================== 流程：入场 → D1 → 三选一 → Step1 → 追问面板 → Step3 → Step4 → 推理 → 小结 =====================

func _enter_arrival() -> void:
	_phase = Phase.ARRIVAL
	acquire_prop("coin", "半镑金币", "维多利亚时代半 Sovereign 金币，福尔摩斯用来「敲门砖」获取证词", "res://assets/props/coin.png")
	# 逻辑修正（#127）：
	#   1. 时间线：兰斯值夜班（22:00-6:00），下午两点在家补觉被叫起——不是"大半夜"。
	#   2. 私语位置：福尔摩斯与华生"为什么先找兰斯"的私语放在敲门之前（马车上/门外路上），
	#      不能当着兰斯的面窃窃私语（既失礼又会让证人起疑）。
	_start_dialogue([
		_mk_node("e0","系统","（演出）下午两点，去往奥德利大院的马车上。","guide",["e1"]),
		_mk_node("e1","华生","福尔摩斯，我还是不太明白——我们不是应该先去追查那枚戒指吗？为什么去找一个巡警？","click",["e2"]),
		_mk_node("e2","福尔摩斯","（微微一笑）华生，戒指是撒下去的饵。但撒饵的人，得先知道水里有什么鱼。兰斯虽然不起眼，却是第一个到现场的人——他看见的东西，可能比他自己意识到的多得多。","click",["e3"]),
		_mk_node("e3","华生","（恍然大悟，在小本子上飞快记着「追饵前，先知鱼」）原来如此……可他值的是夜班，这个点只怕正在补觉。","click",["e4"]),
		_mk_node("e4","福尔摩斯","（掂了掂口袋里的半镑金币）所以我带了敲门砖。","click",["e5"]),
		_mk_node("e5","系统","（演出）奥德利大院，四十六号。午后的阳光斜照在斑驳的门板上。福尔摩斯上前敲门。","guide",["e6"]),
		_mk_node("e6","兰斯警士","（门开一条缝，睡眼惺忪，语气不快）……谁？我值了一宿夜班，才睡下没多久。","click",["e7"]),
		_mk_node("e7","福尔摩斯","（脱帽，微微点头）下午好。福尔摩斯，这位是我的朋友华生医生。抱歉搅了你补觉——关于劳瑞斯顿花园街那件案子，想请你再说说当时的情况。是的，局里的报告——恕我直言——往往只记下了你觉得重要的东西。我想听的是，你'没觉得重要'、但事后回想觉得不太对劲的东西。","click",["e8"]),
		_mk_node("e8","兰斯警士","（愣了一下，皱眉想了想）……您这么一说，好像是有点。请进吧，先生们。","click",["end"]),
	], "e0", _on_arrival_ended)

func _on_arrival_ended() -> void:
	# 沉默线索 D1（墙上旧照片）入口：自定义选项面板（对话已结束，安全）
	_show_choice_panel("观察 · 进屋后的第一眼", [
		{"text":"🔍 扫视房间——墙上挂着一张歪斜的旧照片", "cb": Callable(self, "_see_d1_photo")},
		{"text":"跳过，直接听兰斯说", "cb": Callable(self, "_show_initial_choice")},
	])

func _see_d1_photo() -> void:
	_d1_seen = true
	_insight_bonus += 1   # v4.0 洞察之星加成：发现沉默线索 D1（设计 08 D1）
	_start_dialogue([
		_mk_node("d0","系统","（特写）一张泛黄的军队合影照片，挂在有些歪斜的钉子上。","guide",["d1"]),
		_mk_node("d1","福尔摩斯","（凑近看）一支旧式步枪团的合影——兰斯当过兵。难怪他对醉汉那副军人站姿没什么反应，见怪不怪了。","click",["d2"]),
		_mk_node("d2","华生","所以他的观察里混着'熟视无睹'……这反而提醒我们：他漏掉的，可能正是关键。","click",["d3"]),
	], "d0", _show_initial_choice)

## 台词库场景四·入场末：三选一初始追问方向（案发经过 / 当时街上有什么人 / 醉汉的细节）
func _show_initial_choice() -> void:
	_show_choice_panel("你想从哪里问起？", [
		{"text":"案发经过 —— 他是怎么发现尸体的", "cb": Callable(self, "_init_dir_case")},
		{"text":"当时街上有什么人", "cb": Callable(self, "_init_dir_street")},
		{"text":"醉汉的细节", "cb": Callable(self, "_init_dir_drunk")},
	])

func _init_dir_case() -> void:
	_start_dialogue([
		_mk_node("ia0","华生","（翻开笔记本）好，那就有劳兰斯警士从头讲——你是怎么发现尸体的。","click",["ia1"]),
		_mk_node("ia1","兰斯警士","（吸了口烟斗）好，那我从头讲。","click",["end"]),
	], "ia0", _start_step1)

func _init_dir_street() -> void:
	_start_dialogue([
		_mk_node("ib0","福尔摩斯","案发那会儿，当时街上有什么人？","click",["ib1"]),
		_mk_node("ib1","兰斯警士","街上的人？先生，那个点，布瑞克斯顿路上连条狗都没有。……哦，等等，有几辆马车。这样，我从头讲，讲到你满意为止。","click",["end"]),
	], "ib0", _start_step1)

func _init_dir_drunk() -> void:
	_start_dialogue([
		_mk_node("ic0","福尔摩斯","门口那个醉汉——他什么样子？","click",["ic1"]),
		_mk_node("ic1","兰斯警士","唱得震天响的一个家伙……这样，我从头讲，不然您听不明白前后。","click",["end"]),
	], "ic0", _start_step1)

func _start_step1() -> void:
	# Step1 观察发现 —— 证人状态与初始叙述（08 L2043-2136）
	# 线性主链（每项 [id, speaker, text, trigger, grants, mood]），循环自动串 next。
	# 概率干扰（思傅 2026-09-03 拍板：保留概率模式，制造重玩不确定性）：
	#   普通：30% 时间记忆模糊 / 50% 印度人闲聊（后续案件伏笔）
	#   困难：开场不耐烦（语速快信息密度低）+ 70% "有个女的"（强误导→H4-M1）/ 70% "瘦脸尖"（vs 场景三画像→C4-01）
	var hard: bool = _difficulty == 2
	var norm: bool = _difficulty == 1
	var chain: Array = []
	if hard:
		chain.append(["s00","兰斯警士","（不耐烦地摆手）嗨，这事我在局里全都说过了！……还有什么要问的？","click",[],"不耐烦"])
		chain.append(["s01","福尔摩斯","（不接话茬，只看着他的烟斗）从头说，兰斯警士。你值几点到几点的班？","click",[],"从容"])
	else:
		chain.append(["s00","系统","（演出）兰斯警士坐回椅子上，点了烟斗。","guide",[],""])
	chain.append(["s0","兰斯警士","我当班是晚上十点到早上六点。夜里一点开始下雨，两点多我巡逻到布瑞克斯顿路——又偏又滑，连个人影都没有，就一两辆马车路过。","click",[],""])
	if norm and randf() < 0.3:
		chain.append(["s0t","兰斯警士","（挠头）一点多……也可能是两点。嘿，谁数得清呢，先生？那鬼天气里连怀表都懒得掏。","click",[],"困惑"])
	if norm and randf() < 0.5:
		chain.append(["s0i","兰斯警士","对了，还有桩小事——巡夜时看见几个印度人在街角说话，声音压得很低，看见我就散了。……许是我多心。","click",[],""])
		chain.append(["s0i2","福尔摩斯","（不动声色）记下来。无关的事，往往过些日子就有关了。","click",[],""])
	chain.append(["s1","兰斯警士","忽然看见那所空房子窗口有灯光——怪吓人的，最后一个房客得伤寒死的，房东还不肯修阴沟。我推门进去，壁炉台上点着支红蜡烛，就看见地上躺了具尸体。","click",[],""])
	if hard and randf() < 0.7:
		chain.append(["s1w","兰斯警士","（忽然）哦对——那醉汉旁边好像还有个女的？黑衣服，站着不动。……也可能是我看错了。","click",[],""])
		chain.append(["s1w2","福尔摩斯","（不动声色，对玩家）证人需要'看见'的时候，就会'看见'。这条存疑，先标着——回头跟现场靴印对一对。","click",[],""])
	if hard and randf() < 0.7:
		chain.append(["s1f","兰斯警士","那人瘦瘦的，脸也尖。","click",[],""])
		chain.append(["s1f2","福尔摩斯","（与华生对视一眼）……'瘦脸尖'？花园街的画像可是高个红脸宽脸膛。人的记性，会自己补故事——这条先放着，留作交叉验证。","click",[],""])
	chain.append(["s2","兰斯警士","我赶紧吹警笛，摩契他们俩很快就来了。对了——我出来的时候，门口还靠着个醉汉，就在街灯底下，唱得震天响，站都站不住。我还提着灯过去想把他轰走。","clue",[CLUES["C_SOTCB_401"]],""])
	chain.append(["s3","福尔摩斯","（点头，看向玩家）他说的这些，你记下了什么？","click",[],""])
	var nodes: Array = []
	for i in chain.size():
		var row: Array = chain[i]
		var nxt: Array = [str(chain[i + 1][0])] if i < chain.size() - 1 else ["s3_e", "s3_n", "s3_h"]
		nodes.append(_mk_node(str(row[0]), str(row[1]), str(row[2]), str(row[3]), nxt, row[4], str(row[5])))
	nodes.append(_mk_node("s3_e","福尔摩斯","（低声）四点都关键：凌晨两点、下着雨、醉汉站在门口、还唱着歌。逐一追问，把每条都坐实。","click",["s3_n"],[],"指导",1))
	nodes.append(_mk_node("s3_n","福尔摩斯","四点都关键：时间、天气、醉汉、歌声。用六方向追问把它们挖出来。","click",["s3_h"],[],"指导",2))
	nodes.append(_mk_node("s3_h","福尔摩斯","（看向玩家）……他漏了什么，你自己判断。","click",["s4"],[],"从容",3))
	nodes.append(_mk_node("s4","华生","（在笔记本上飞快记着）记下了。可这些只是他'说的'，不是事实——得追问才挖得出来。","click",["s5"]))
	nodes.append(_mk_node("s5","福尔摩斯","（从口袋里摸出那枚半镑金币，在指间一转）问吧。他见了这个，话会多得很。","click",["end"]))
	_start_dialogue(nodes, "s00", _start_panel)

func _start_panel() -> void:
	# Step2 工具操作 —— 追问引导（08 L2137-2190）：六方向追问面板（统一基类 _render_investigate_panel，
	# 已问方向自动从面板消失，与场景五/六/七/八的"自由调查/自白"格式一致）
	var questions := [
		{"id":"time","text":"🕑 追问时间 —— 你具体几点发现的？待了多久？", "cb": Callable(self, "_dir_time")},
		{"id":"look","text":"🧑 追问醉汉外貌 —— 长什么样？看清了吗？", "cb": Callable(self, "_dir_look")},
		{"id":"cloth","text":"🧥 追问醉汉穿着 —— 穿什么？手里拿什么？", "cb": Callable(self, "_dir_cloth")},
		{"id":"carriage","text":"🐴 追问马车 —— 当时街上有马车吗？", "cb": Callable(self, "_dir_carriage")},
		{"id":"scene","text":"🏚 追问现场细节 —— 屋里什么样？", "cb": Callable(self, "_dir_scene")},
		{"id":"other","text":"❓ 追问其他异常 —— 还有什么不寻常的？", "cb": Callable(self, "_dir_other")},
	]
	_render_investigate_panel("追问面板 · 选择方向", questions, _asked_directions, Callable(self, "_start_step3"))

func _dir_time() -> void:
	_asked_directions["time"] = true
	_start_dialogue([
		_mk_node("t0","福尔摩斯","你具体是几点发现的？在里面待了多久？","click",["t1"]),
		_mk_node("t1","兰斯警士","两点出头吧……两点过十分？差不多。我在里面待了几分钟，吹了警笛就出来。摩契他们来得很快，也就两三分钟。","click",["t2"]),
		_mk_node("t2","福尔摩斯","（低声）两点十分，雨里。和花园街泥地的痕迹对得上。时间线收口了。","click",["end"]),
	], "t0", _start_panel)

func _dir_look() -> void:
	_asked_directions["look"] = true
	_start_dialogue([
		_mk_node("l0","福尔摩斯","案发那会儿是深夜，你怎么看清他模样的？","click",["l1"]),
		_mk_node("l1","兰斯警士","他就靠在门口那盏煤气街灯的杆子上，我又提着巡逻灯凑到他脸跟前想把他轰走——离得就一两步。高个子，肯定比我高。脸是红的——喝多了嘛。别的……胡子？好像有胡子，记不太清。","clue",["l2"],[CLUES["C_SOTCB_402"], CLUES["C_SOTCB_403"]]),
		_mk_node("l2","福尔摩斯","街灯下、提灯照脸、一两步的距离——这份证词就可靠了。高个、红脸，和花园街现场那串高大足迹、还有……（他没说下去）对上了。华生，记上。","click",["end"]),
	], "l0", _start_panel)

func _dir_cloth() -> void:
	_asked_directions["cloth"] = true
	_start_dialogue([
		_mk_node("c0","福尔摩斯","他穿什么衣服？手里拿着什么？","click",["c1"]),
		_mk_node("c1","兰斯警士","我提灯照着他那会儿看得真真的——一件棕色外衣。帽子……好像戴着顶帽子。手里？手里没拿什么吧……","clue",["c2"],[CLUES["C_SOTCB_404"]]),
		_mk_node("c2","福尔摩斯","（盯着他）你刚才顿了一下——'手里没拿什么'？再想想。","click",["c3"]),
		_mk_node("c3","兰斯警士","……你这么一说，好像有根鞭子？不对不对，肯定没有，我看错了。","clue",["c4"],[CLUES["C_SOTCB_405"]]),
		_mk_node("c4","华生","（低声）他犹豫了——这本身也是信息。鞭子，是车夫的东西。","click",["end"]),
	], "c0", _start_panel)

func _dir_carriage() -> void:
	_asked_directions["carriage"] = true
	_start_dialogue([
		_mk_node("m0","福尔摩斯","当时街上有马车吗？什么样的马车？","click",["m1"]),
		_mk_node("m1","兰斯警士","马车？我巡逻的时候有一两辆路过……哪记得清什么样的。我出来以后？没注意，光顾着吹警笛了。","clue",["m2"],[CLUES["C_SOTCB_407"]]),
		_mk_node("m2","福尔摩斯","（与玩家交换眼神）和花园街那对出租马车轮印、右前蹄新蹄铁——正好形成交叉验证点。记着。","click",["end"]),
	], "m0", _start_panel)

func _dir_scene() -> void:
	_asked_directions["scene"] = true
	_start_dialogue([
		_mk_node("r0","福尔摩斯","屋里当时什么样子？你进去看了多久？","click",["r1"]),
		_mk_node("r1","兰斯警士","就看见地上有个死人，脸吓死人。别的没细看——我第一反应是叫人。","click",["r2"]),
		_mk_node("r2","华生","屋里的细节，我们自己看过了：血字、戒指、烟灰……兰斯这边信息很少，正常。","click",["end"]),
	], "r0", _start_panel)

func _dir_other() -> void:
	_asked_directions["other"] = true
	_start_dialogue([
		_mk_node("o0","福尔摩斯","还有什么不寻常的地方吗？","click",["o1"]),
		_mk_node("o1","兰斯警士","异常……也没什么特别的。哦对了，那醉汉唱得特别响——科隆比纳那段，星光灿烂什么的。","clue",["o2"],[CLUES["C_SOTCB_406"]]),
		_mk_node("o2","福尔摩斯","（眉头一皱）科隆比纳……是歌剧《宠姬》里的角色，'星光灿烂'是那段著名咏叹调。一个醉鬼，唱得倒是讲究。","click",["end"]),
	], "o0", _start_panel)

func _start_step3() -> void:
	# Step3 数据记录 —— 证词提取（08 L2191-2220）：侦探笔记（仅列出玩家实际追问的方向 —— #147）
	# 8 项标准证词：①发现时间 ②天气 ③身高 ④脸色 ⑤穿着 ⑥马鞭 ⑦马车 ⑧进屋到叫人间隔
	if _asked_directions.size() >= 6:
		_insight_bonus += 1   # v4.0 洞察之星加成：六方向全追问
	var testimony := {
		"time": [["① 发现时间", "约凌晨两点十分（兰斯明确证词）"], ["⑧ 进屋到叫人间隔", "约两三分钟——摩契他们来得很快"]],
		"look": [["③ 醉汉身高", "六英尺出头（178cm 以上），与花园街高大足迹吻合"], ["④ 醉汉脸色", "赤红——真实特征（动脉瘤），切勿误判为'重病'"]],
		"cloth": [["⑤ 醉汉穿着", "棕色外衣 + 戴帽子（伦敦出租马车夫常见装束）"], ["⑥ 马鞭", "不确定——先说'好像有'又改口'肯定没有'，犹豫本身是信息"]],
		"carriage": [["⑦ 马车经过", "巡逻时有一两辆出租马车路过（与花园街轮印交叉验证）"]],
		"scene": [["现场细节", "兰斯进屋仅看到尸体，第一反应是叫人——信息很少"]],
		"other": [["其他异常", "醉汉唱科隆比纳（《宠姬》咏叹调）——真醉汉不会这么'有教养'地唱歌"]],
	}
	var items: Array = []
	items.append({"name": "② 天气", "desc": "下雨——夜里一点开始，兰斯全程在雨中巡逻（初始叙述，必得）"})
	for d in _asked_directions.keys():
		if testimony.has(d):
			for row in testimony[d]:
				items.append({"name": str(row[0]), "desc": str(row[1])})
	_popup("侦探笔记 · 兰斯证词（已追问 " + str(_asked_directions.size()) + " 方向 · 共 " + str(items.size()) + " 项）", items)
	_start_dialogue([
		_mk_node("n0","福尔摩斯","把证词理一理：两点十分、下雨、高个红脸醉汉、棕色外衣、马鞭他含糊——还有马车。该问的都问了，齐了。","click",["n1"]),
		_mk_node("n1","华生","（合上本子）可这些都还是'他说'。下一步该进知识库核对、再上推理墙了。","click",["end"]),
	], "n0", _start_step4)

func _start_step4() -> void:
	# Step4 知识检索（可选 · M2+，08 L2222-2230）：列出可检索领域（弹窗），由玩家自行参考
	var know := [
		{"name":"维多利亚时代巡警制度", "desc":"执勤时间、巡逻路线、发现案件后的标准流程"},
		{"name":"19 世纪伦敦出租马车", "desc":"马车类型、车夫特征、马蹄铁更换频率"},
		{"name":"证人证词可靠性", "desc":"人证记忆偏差：时间压力、情绪、事后信息干扰——证人需要'看见'的时候，就会'看见'"},
		{"name":"《宠姬》与科隆比纳", "desc":"多尼采蒂歌剧，'星光灿烂'是著名咏叹调"},
		{"name":"醉汉与犯罪者的行为模式", "desc":"犯罪者伪装醉酒是常见的反侦察手段"},
	]
	_popup("知识检索 · 可选入口", know)
	_start_dialogue([
		_mk_node("k0","福尔摩斯","（翻开随身小册）需要的话，这些都能查：巡警制度、伦敦马车、证人可靠性、那出歌剧……知识库随时为你开着。","click",["k1"]),
		_mk_node("k1","华生","（点头）先把兰斯的话和已有的线索摆上推理墙，让假设自己说话。","click",["end"]),
	], "k0", _enter_reasoning)

func _enter_reasoning() -> void:
	_phase = Phase.REASONING; _wall_auto = true
	_sync_clues()
	_prompt_think("福尔摩斯", "华生，兰斯看到的'醉汉'——六英尺出头、棕色外衣、红脸，正对上花园街那串高大足迹。把证词摆上推理墙：十二条假设，按证词解锁。记住——证词是证人说的，不是事实。", "自信")

func _enter_transition() -> void:
	_phase = Phase.TRANSITION
	_award()
	# 阶段末小结 & 行动决策（08 L2349-2420）：
	# ① 教学环节「从证人证词到凶手画像」五条线 → "三条线开始成形。五条线——就是事实。"
	# ② 动态总结：按玩家实际追问到的证词逐条念出（未追问到的不出现）
	# ③ 华生"为什么凶手要回来"扩写（"比命还重要"/"一个士兵的荣誉"）→ A/B/C 行动决策
	_start_dialogue([
		_mk_node("f0","系统","（演出）走出奥德利大院，午后的街道上。福尔摩斯走在前面，没回头。","guide",["f1"]),
		_mk_node("f1","华生","福尔摩斯，你怎么看？","click",["f2"]),
		_mk_node("f2","福尔摩斯","（停下脚步，转向玩家）我怎么看——取决于你怎么看。你先说说。不过在这之前——让我教你一课：怎么把证词'串'成推理。","click",["f3"]),
		_mk_node("f3","福尔摩斯","第一线——现场目击。兰斯亲眼看见：凌晨两点，空房子门口，一个高个红脸的男人在唱歌。这是直接证据。","click",["f4"]),
		_mk_node("f4","福尔摩斯","第二线——画像吻合。高个、红脸、棕色外衣——和我们从场景三得出的'凶手高个红脸'画像，严丝合缝。","click",["f5"]),
		_mk_node("f5","福尔摩斯","第三线——马车出没。花园街的车轮印是出租马车，兰斯又说巡夜时有一两辆马车路过——现场确实有马车。","click",["f6"]),
		_mk_node("f6","福尔摩斯","第四线——体貌与职业。醉汉的站姿带着军人气质，穿的是马车夫常见的棕色外衣；而'没有马鞭'，说明他是从马车上下来、走进现场的。","click",["f7"]),
		_mk_node("f7","福尔摩斯","第五线——行为反常。他唱的是科隆比纳咏叹调。一个真正的醉汉，不会那么'有教养'地唱歌。醉汉，是表演出来的。","click",["f8"]),
		_mk_node("f8","福尔摩斯","你看——现场目击 + 画像吻合 + 马车出没 + 体貌职业相符 + 行为反常。五条线，同时指向同一个人。这就是推理。","click",["f9"]),
		_mk_node("f9","华生","（在小本子上记）五条线……指向同一方向……","click",["f10"]),
		_mk_node("f10","福尔摩斯","（点头）对。一条线是巧合。两条线是可能。三条线开始成形。五条线——就是事实。","click",["m0"]),
		_mk_node("m0","福尔摩斯","好。现在理一理手里的牌——从兰斯的话里，我们多出了哪些？","click",["m1"]),
		_mk_node("m1","福尔摩斯",_summary_lines(),"click",["w0"]),
		_mk_node("w0","华生","（突然）福尔摩斯，我有个问题——凶手如果已经走了，干嘛还要回来？装醉躲过了兰斯，又冒一次险——图什么？","click",["w1"]),
		_mk_node("w1","福尔摩斯","（终于停下，回头看华生）华生，这个问题你问得——比大多数警察都问得准。答案只有两种。要么，他有东西忘在现场；要么，他有东西必须从现场带走。——冒险回来找的，往往比命还重要。","click",["w2"]),
		_mk_node("w2","华生","（边走边记）比命还重要……","click",["w3"]),
		_mk_node("w3","福尔摩斯","（淡淡地）华生，你想想你愿意为什么东西冒这种险？","click",["w4"]),
		_mk_node("w4","华生","（想了想，认真地）……荣誉。一个士兵的荣誉。","click",["w5"]),
		_mk_node("w5","福尔摩斯","（点头）对。每一个人都有一个'必须拿回来的东西'。我们的凶手也不例外。——下一步，我们得让他自己告诉我们，那是什么。","click",["w6"]),
		_mk_node("w6","福尔摩斯","好。现在的问题是——下一步怎么走？","click",["end"]),
	], "f0", _show_route_choice)

## 阶段末动态总结（台词库 L2374-2380）：按玩家实际追问到的证词逐条念出，未追问到的不出现。
func _summary_lines() -> String:
	var parts: Array = []
	if _asked_directions.has("time"):
		parts.append("两点左右案发，下着雨。")
	if _asked_directions.has("look") and _asked_directions.has("cloth"):
		parts.append("门口有个醉汉，高个，红脸，穿棕色外衣。")
	if _asked_directions.has("carriage"):
		parts.append("案发时有马车经过。")
	if _has_clue("C_SOTCB_402") and _has_clue("C_SOTCB_403") and _has_clue("C_SOTCB_404"):
		parts.append("醉汉很可能就是凶手——或者说，凶手伪装成醉汉逃走了。")
	if _asked_directions.has("time") and _has_clue("C_SOTCB_401"):
		parts.append("兰斯错过了他。")
	if parts.is_empty():
		return "……（追问得太少，从兰斯的话里能拿住的牌不多。）"
	var s := ""
	for p in parts:
		s += str(p)
	return s

func _has_clue(cid: String) -> bool:
	for c in _clues:
		if str(c.get("id", "")) == cid: return true
	return false

func _show_route_choice() -> void:
	# 行动决策（08 L2396-2406）：A 发布失物招领（主线）/ B 追查马车 / C 发电报查询
	_show_choice_panel("行动决策 · 下一步怎么走？", [
		{"text":"A. 发布失物招领 —— 用戒指设圈套，引凶手上钩（走场景五主线）", "cb": Callable(self, "_route_chosen").bind("A")},
		{"text":"B. 追查马车 —— 从右前蹄新换的蹄铁入手，找马车和车夫", "cb": Callable(self, "_route_chosen").bind("B")},
		{"text":"C. 发电报查询 —— 向美国克利夫兰查德雷伯背景（慢线，消耗1行动机会）", "cb": Callable(self, "_route_chosen").bind("C")},
	])

## 各路线确认台词（08 L2399-2404）+ C 路线电报段；播完再走评价面板与转场。
func _route_chosen(route: String) -> void:
	if route == "B":
		_start_dialogue([
			_mk_node("rb0","福尔摩斯","从马蹄铁查起……也有道理。伦敦的铁匠铺不多，一匹刚换了右前蹄铁的马，应该不难找。","click",["end"]),
		], "rb0", _go_to_next_scene.bind("B"))
	elif route == "C":
		# C 路线：场景四内播完福尔摩斯的电报台词（思傅 2026-09-03 拍板：场景六/七的电报分支后续接入）
		_start_dialogue([
			_mk_node("rc0","福尔摩斯","从源头查起……美国克利夫兰，德雷伯的老家。发一封电报，问问他在那边有什么仇家。","click",["rc1"]),
			_mk_node("rc1","系统","（演出）福尔摩斯在电报单上落笔：致克利夫兰——查询伊诺克·J·德雷伯其人其仇。电报费一英镑——消耗 1 个关键行动机会。","guide",["rc2"]),
			_mk_node("rc2","华生","电报往返要多久？","click",["rc3"]),
			_mk_node("rc3","福尔摩斯","快则两三天。回复到了，自然会送到贝克街。电报是一条慢线——但可能直接命中要害。这期间，我们手里的活儿也不能停。","click",["end"]),
		], "rc0", _go_to_next_scene.bind("C"))
	else:
		_start_dialogue([
			_mk_node("ra0","福尔摩斯","戒指——他回来就是为了这个。既然他冒险回来一次，就会来第二次。发布失物招领，把钓竿甩出去。","click",["end"]),
		], "ra0", _go_to_next_scene.bind("A"))

func _award() -> void:
	# v4.0：三星由推理墙在评星时通过 StarRatingSystem.submit_chain() 逐链提交，本场景不再累加。
	pass

func _go_to_next_scene(route: String = "A") -> void:
	# 过渡对话结束后弹出「侦破过程」评价面板（风格对齐场景一），点继续再存档进入下一场景
	_show_scene_rating("场景四 完成 · 侦破过程", "res://scenes/scene5.tscn", Callable(self, "_go_to_next_scene_continue").bind(route))

func _go_to_next_scene_continue(route: String = "A") -> void:
	if GameManager:
		GameManager.scene_state["scene4_route"] = route   # 供场景五分支消费（A/B 双路线 + C 电报线）
	if GameManager and not GameManager.is_guest and SaveManager:
		var ids := ClueSystem.get_collected_ids(clue_source()) if ClueSystem else []
		await SaveSystem.request_save("scene4", Phase.TRANSITION, {"clue_ids": ids, "route": route})
	SceneLoader.transition_to("res://scenes/scene5.tscn")

# ===================== 自定义选项面板：已上提到基类 DetectiveScene._show_choice_panel（统一实现） =====================

# ===================== 存 / 读档（对话授予线索，沿用基类 _restore_clues_from_ids） =====================
func _do_save(slot: int = -1) -> void:
	var ids := ClueSystem.get_collected_ids(clue_source()) if ClueSystem else []
	print("[SAVE scene4] _phase=", _phase, " ids=", ids)
	await SaveSystem.request_save("scene4", _phase, {"clue_ids": ids}, slot)
	_ui.show_notification("✅ 进度已保存")

func _restore_saved_state() -> bool:
	var ss = SaveSystem.take_save_state("scene4")
	if ss.is_empty(): return false
	var sp := int(ss.get("phase", 0))
	_phase = sp
	_restore_clues_from_ids(ss.get("clue_ids", []))
	_ui.show_notification("✅ 读档成功 — 已恢复至「" + _phase_name(sp) + "」")
	match sp:
		Phase.ARRIVAL: _enter_arrival(); return true
		Phase.REASONING: _phase = Phase.REASONING; _wall_auto = true; _sync_clues(); _open_wall(); return true
		Phase.TRANSITION: _enter_transition(); return true
	return false
