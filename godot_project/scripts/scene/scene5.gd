extends DetectiveScene
## Scene 5 — 贝克街221B会客厅（等待失主 / 伪装识别）
## 双路线入口：消费 GameManager.scene_state["scene4_route"]（场景四行动决策）
##   A = 发布失物招领 → 完整「伪装识别」六步闭环（Step1 老太婆来访 → Step2 追问 → Step3 笔记
##       → Step4 知识检索 → Step5 推理墙 → Step6 跟踪脱逃）
##   B = 追查马车（铁匠铺）→ 跳过 Step1-3，从 Step4 知识检索 / Step5 假设直接进入
##   C = 发电报查询 → 电报已发待回，同样跳到 Step4/5（回复于场景六末/七初到达）
## 架构：继承统一框架 DetectiveScene，仅覆盖内容钩子；对话节点 clue 触发走
## ClueSystem.collect_clue_from_catalog 单一漏斗（与观察器路径一致、幂等）。
##
## ⚠️ 分支实现说明（根因，同 scene4）：本框架 DialogueManager 的 trigger=="choice" 节点
## 未被 SceneFramework 连接渲染 → 直接用会卡死。故所有玩家分支（D2 壁炉架 / Step2 追问面板
## / Step6 跟踪决策 / 路线消费提示）一律用「自定义选项面板」_show_choice_panel，安全不卡死。
##
## 设计依据：02_血字的研究_场景设计与流程 §13（v3.16.0）+ 08_血字的研究_对话台词库 场景五（v3.16.0）
##
## 红线修正（根因，非表面）：旧实现按 03_关卡设计稿 §3.6 把场景五写成「黄页查马车 + 维金斯回报」，
## 与 02/08 最新稿「老太婆伪装识别 + 贝克街分队 + 苏格兰场竞争暗线」完全不符。本版按 02/08 权威重写，
## 线索 501-507 含义随之重定（501 马车公司 / 502 霍普身份 / 503 老太婆=伪装 / 504 葛莱森电报
## / 505 福尔摩斯补充电报 / 506 贝克街分队 / 507 老太婆说辞）。

enum Phase { ARRIVAL, REASONING, TRANSITION }

## 本场景线索权威定义（id/name/desc/correct/w）。经 DialogueManager clue 触发 → ClueSystem。
## 501 马车公司信息（重要）502 霍普身份（关键）503 老太婆=年轻人伪装（关键）
## 504 葛莱森电报·克利夫兰回电（重要）505 福尔摩斯补充电报（关键）
## 506 维金斯·贝克街分队（重要·可选）507 老太婆来访说辞（一般·氛围）
const CLUES = {
	"C_SOTCB_501": {"id":"C_SOTCB_501","name":"马车公司信息","desc":"出租马车公司登记显示：那辆棕色马车登记在杰弗森·霍普名下。雷斯垂德查到马车夫方向，或铁匠铺证词指向同一人。","correct":true,"w":5},
	"C_SOTCB_502": {"id":"C_SOTCB_502","name":"杰弗森·霍普身份","desc":"综合两份电报 + 伪装识破 + 美国背景，凶手身份锁定：杰弗森·霍普——为露西复仇的马车夫。","correct":true,"w":10},
	"C_SOTCB_503": {"id":"C_SOTCB_503","name":"老太婆=年轻人伪装","desc":"跟踪脱逃揭晓：所谓'老太婆'是年轻人男扮女装，上车后迅速换装逃走——伪装技术高超，且有反侦察能力。","correct":true,"w":10},
	"C_SOTCB_504": {"id":"C_SOTCB_504","name":"葛莱森电报·克利夫兰回电","desc":"葛莱森得意洋洋展示克利夫兰回电：德雷伯是美国人，背景涉仇杀。信息不完整（仅死者背景），但坐实'私人恩怨非政治'。","correct":true,"w":5},
	"C_SOTCB_505": {"id":"C_SOTCB_505","name":"福尔摩斯补充电报","desc":"福尔摩斯补发补充询问电报，收到更详细回电——德雷伯在克利夫兰有过一段婚约变故，关键身份信息补全。","correct":true,"w":10},
	"C_SOTCB_506": {"id":"C_SOTCB_506","name":"维金斯·贝克街分队","desc":"一群流浪儿听命于维金斯，灵活、隐秘，能去官方侦探去不了的地方。被委派搜寻霍普。","correct":true,"w":5},
	"C_SOTCB_507": {"id":"C_SOTCB_507","name":"老太婆来访说辞","desc":"来访者自称'索叶太太'，为女儿赛莉的结婚戒指而来：宏兹迪池区邓肯街十三号、女婿是船上乘务员。说辞细节丰富但疑点间接（地址矛盾等）。","correct":true,"w":2},
}

var _route: String = "A"                 # 场景四传来的路线（A/B/C），读档时恢复
var _asked_directions: Dictionary = {}   # 已追问方向
var _tracked: bool = false               # Step6 是否选择跟踪

func scene_id() -> String: return "scene5"
func clue_source() -> String: return "scene5"
func hotspots() -> Array: return []
func scene_title() -> String: return "贝克街 221B 会客厅"
func scene_time_text() -> String: return "DAY 1 晚 20:00-21:00"
func scene_background() -> Texture2D: return load("res://assets/scenes/sc_05_parlor.jpg")

## 氛围遮罩已按需求移除（谜雾/灯光按钮及相关功能）。
func wants_atmosphere() -> bool: return false

func _phase_name(p: int) -> String:
	match p:
		Phase.ARRIVAL: return "等待 / 识别伪装"
		Phase.REASONING: return "推理验证"
		Phase.TRANSITION: return "过渡"
		_: return "未知阶段"

func _in_observe_phase() -> bool: return false
func _in_reasoning_phase() -> bool: return _phase == Phase.REASONING
func _in_dialogue_phase() -> bool: return _phase == Phase.ARRIVAL or _phase == Phase.TRANSITION

func _observe_locked_msg() -> String: return "本场景无线索可观察，请推进对话"
func _npc_talk_text(_g: int) -> String: return "福尔摩斯：\"维金斯，去失物招领登个启事——就说捡到一枚女式结婚戒指。\""
func _no_evidence_msg() -> String: return "尚未查到出租马车与失主线索"
func _journal_empty_hint() -> String: return "查黄页、登启事、问维金斯、识破伪装"

func reasoning_hypothesis() -> Dictionary:
	return {
		"title": "老太婆是伪装，凶手=杰弗森·霍普（推理战场 M1）",
		"description": "来领戒指的'老太婆'脱逃揭晓为年轻人伪装；两份电报 + 伪装识破 + 美国背景锁定霍普。\n\n活跃假设：\n· H5-01 老太婆是年轻人男扮女装（强：马车逃走时换装目击）\n· H5-02 凶手=杰弗森·霍普（中：两份电报+伪装识破+美国背景）\n· H5-03 凶手是马车夫（升级，中强：无马鞭+出租马车+伪装跳上马车逃走）\n· H5-04 复仇动机·私人恩怨非政治（中：克利夫兰背景+戒指）\n\n矛盾标记：\n· C5-01 老太婆虚弱 vs 跳上马车敏捷（识破伪装后自动解决）\n· C5-02 凶手缜密 vs 亲自冒险取戒指（场景八揭示：戒指是露西遗物）\n· C5-03 葛莱森政治阴谋论 vs 私人恩怨背景（推翻葛莱森假设的关键）\n· C5-04 雷斯垂德马车夫方向 vs 他查的都是错的（贝克街分队找到正确的人）",
		"battlefield": {
			"hypotheses": [
				{"id":"H5-01","text":"老太婆是年轻人男扮女装","correct":true},
				{"id":"H5-02","text":"凶手=杰弗森·霍普","correct":true},
				{"id":"H5-03","text":"凶手是马车夫（升级）","correct":true},
				{"id":"H5-04","text":"复仇动机·私人恩怨非政治","correct":true}
			],
		"contradictions": [
			{"id":"C5-01","text":"老太婆虚弱 vs 跳上马车敏捷","correct":true},
			{"id":"C5-02","text":"凶手缜密 vs 亲自冒险取戒指","correct":true},
			{"id":"C5-03","text":"葛莱森政治阴谋论 vs 私人恩怨背景","correct":true},
			{"id":"C5-04","text":"雷斯垂德马车夫方向 vs 他查的都错","correct":true}
		],
		"milestones": [
			{"id":"S5-1","text":"老太婆为男扮女装"},
			{"id":"S5-2","text":"凶手=杰弗森·霍普"},
			{"id":"S5-3","text":"凶手=马车夫（升级）"},
			{"id":"S5-4","text":"复仇动机（私人恩怨非政治）"},
		],
	}
	}

func map_locations() -> Array:
	return [
		{"t":"贝克街221B", "d":"福尔摩斯寓所 — 当前场景"},
		{"t":"劳瑞斯顿花园街3号", "d":"尸体现场 — 场景三"},
		{"t":"奥德利大院四十六号", "d":"兰斯证词 — 场景四"},
		{"t":"克利夫兰（美国）", "d":"德雷伯老家 — 电报查询"},
	]

func casebook_steps() -> Array:
	return ["识破伪装 / 铁匠铺线索", "追问与记录", "知识检索", "推理墙验证"]
func casebook_done_flags() -> Array:
	return [_phase >= Phase.ARRIVAL, _asked_directions.size() >= 1, _phase >= Phase.REASONING, _phase >= Phase.TRANSITION]

func inventory_items() -> Array:
	return ["🔍 放大镜（初始）", "📏 卷尺（场景二解锁）", "🧪 化学试剂盒（场景三解锁）", "📖 黄页（场景四解锁）", "📜 电报（场景五解锁）"]

func options_lines() -> Array:
	return [
		"难度：" + ["简单","普通","困难"][_difficulty],
		"路线：" + ({"A":"发布失物招领（完整闭环）","B":"追查马车（铁匠铺）","C":"发电报查询"}[_route]),
		"操作：对话收集线索 → 推理墙验证",
		"💡 老太婆伪装逼真，来访阶段无低级破绽——靠疑点间接推理 + 跟踪验证",
	]

# ===================== 流程入口：消费 scene4_route 分派双路线 =====================

func _enter_arrival() -> void:
	_phase = Phase.ARRIVAL
	acquire_prop("ring", "结婚金戒指", "案发现场拾得的女性结婚戒指，内侧刻字「L.F.」，关键物证", "res://assets/props/ring.png")
	if GameManager and GameManager.scene_state.has("scene4_route"):
		_route = GameManager.scene_state["scene4_route"]
	match _route:
		"B": _arrival_B()
		"C": _arrival_C()
		_: _arrival_A()

# ---------- A 路线：发布失物招领（完整六步闭环） ----------

func _arrival_A() -> void:
	# 08 场景五·入场（A路线）：赫德森太太端茶 + 招领广告 + 时间流逝 + 敲门 + 老太婆来访
	_start_dialogue([
		_mk_node("a0","系统","（演出）贝克街221B，会客厅。桌上晚报的招领广告栏被圈了出来：「今晨在布瑞克斯顿路一带拾得结婚金戒指一枚，失主请于今晚八至九时向贝克街二二一号乙华生医生处洽领。」","guide",["a1"]),
		_mk_node("a1","赫德森太太","先生们，茶凉了。要不要我再去热一热？","click",["a2"]),
		_mk_node("a2","福尔摩斯","不用了，赫德森太太。今晚我们可能有客人。","click",["a3"]),
		_mk_node("a3","系统","（时间流逝：傍晚→天色渐暗→时钟指向八点）「咚、咚、咚」——敲门声。","guide",["a4"]),
		_mk_node("a4","赫德森太太","（去开门，回身）先生，是一位老太太，说是要领取什么戒指。","click",["a5"]),
		_mk_node("a5","福尔摩斯","（看向玩家）来了。记住——让她说，别打断。","click",["a6"]),
		_mk_node("a6","华生","（低声）福尔摩斯，你真觉得她和案子有关？万一她就是个普通老太太，只是来领戒指的？","click",["a7"]),
		_mk_node("a7","福尔摩斯","普通老太太不会在这个时间、用这个地址来领戒指。太巧了——巧得不正常。","click",["a8"]),
	], "a0", _enter_step1)

func _enter_step1() -> void:
	# Step1 观察发现 —— 老太婆来访（伪装逼真，无低级破绽）
	_start_dialogue([
		_mk_node("s0","老太婆","（满脸皱纹，背微驼，蹒跚挪入）我是为这件事来的，先生们。（掏出晚报指着广告）广告上说拾得一枚结婚金戒指。这是我女儿赛莉的。","click",["s1"]),
		_mk_node("s1","老太婆","她去年这个时候结的婚，丈夫在联合公司的船上当乘务员，出海在外。如果他回来发现戒指没了……谁知道会干出什么。","click",["s2"]),
		_mk_node("s2","老太婆","昨天晚上她去看马戏，应该是在路上不小心丢的。您姓——我姓索叶，女儿姓丹尼斯，女婿叫汤姆·丹尼斯，船上的乘务员。","click",["s3"]),
		_mk_node("s3","华生","（拿起铅笔）您住在哪儿？","click",["s4"]),
		_mk_node("s4","老太婆","宏兹迪池区，邓肯街十三号。离这儿远着呢。","click",["s5"]),
		_mk_node("s5","老太婆","（千恩万谢）谢谢，找到戒指，我女儿赛莉一定开心死了……（颤巍巍转身，蹒跚走向门口）","clue",["s6"],[CLUES["C_SOTCB_507"]]),
		_mk_node("s6","福尔摩斯","（低声）布瑞克斯顿路不在宏兹迪池区和马戏团之间……她怎么一口咬定是女儿的？疑点都是间接的。","click",["end"]),
	], "s0", _start_panel)



func _start_panel() -> void:
	# Step2 工具操作 —— 追问面板（08 场景五·六方向追问；老太婆回答合理、不直接露破绽）
	# 统一基类 _render_investigate_panel：已追问方向自动从面板消失，与其它场景一致
	var questions := [
		{"id":"ring","text":"🔍 追问戒指细节 —— 您能描述这枚戒指吗？", "cb": Callable(self, "_dir_ring")},
		{"id":"lost","text":"🔍 追问丢戒指经过 —— 具体什么位置？", "cb": Callable(self, "_dir_lost")},
		{"id":"family","text":"🔍 追问家庭情况 —— 您女婿什么时候回来？", "cb": Callable(self, "_dir_family")},
		{"id":"route","text":"🔍 追问路线 —— 您从宏兹迪池怎么过来？", "cb": Callable(self, "_dir_route")},
		{"id":"doubt","text":"❓ 直接质疑 —— 布瑞克斯顿路不在宏兹迪池和马戏团之间啊", "cb": Callable(self, "_dir_doubt")},
		{"id":"letgo","text":"🚪 什么也不问，直接给戒指放她走", "cb": Callable(self, "_dir_letgo")},
	]
	_render_investigate_panel("追问面板 · 选择方向", questions, _asked_directions, Callable(self, "_start_step3"))

func _dir_ring() -> void:
	_asked_directions["ring"] = true
	_start_dialogue([
		_mk_node("r0","福尔摩斯","您能描述一下这枚戒指吗？","click",["r1"]),
		_mk_node("r1","老太婆","就是只普通的结婚金戒指嘛，内侧刻了字……嗯，好像是 L.F.？老婆子记不清了，反正就是我女儿的。","click",["end"]),
	], "r0", _start_panel)

func _dir_lost() -> void:
	_asked_directions["lost"] = true
	_start_dialogue([
		_mk_node("l0","福尔摩斯","她是怎么丢的？具体在哪儿？","click",["l1"]),
		_mk_node("l1","老太婆","走路上掏手绢带出来的吧。具体哪段她说不清，夜里天黑嘛。","click",["end"]),
	], "l0", _start_panel)

func _dir_family() -> void:
	_asked_directions["family"] = true
	_start_dialogue([
		_mk_node("f0","福尔摩斯","您女儿一个人住吗？女婿什么时候回来？","click",["f1"]),
		_mk_node("f1","老太婆","一个人住，女婿出海去了，下个月才回。可怜的孩子，一个人孤单，才去看马戏散心……","click",["end"]),
	], "f0", _start_panel)

func _dir_route() -> void:
	_asked_directions["route"] = true
	_start_dialogue([
		_mk_node("o0","福尔摩斯","您从宏兹迪池过来走哪条路？","click",["o1"]),
		_mk_node("o1","老太婆","老婆子坐马车来的，哪记得清路。车夫知道怎么走。","click",["end"]),
	], "o0", _start_panel)

func _dir_doubt() -> void:
	_asked_directions["doubt"] = true
	_start_dialogue([
		_mk_node("q0","福尔摩斯","布瑞克斯顿路不在宏兹迪池和马戏团之间啊。","click",["q1"]),
		_mk_node("q1","老太婆","（愣了一下）哎哟，先生您看我老糊涂——刚才说的是我的住址。我女儿住培克罕，梅菲尔德路三号，从培克罕去马戏团，戒指可能掉路上被人捡到布瑞克斯顿路？我也搞不清这些路名。","click",["end"]),
	], "q0", _start_panel)

func _dir_letgo() -> void:
	_asked_directions["letgo"] = true
	_start_dialogue([
		_mk_node("g0","华生","（把戒指递过去）给您，索叶太太。","click",["g1"]),
		_mk_node("g1","老太婆","（千恩万谢）谢谢，太感谢了！（颤巍巍转身离去）","click",["end"]),
	], "g0", _start_panel)

func _start_step3() -> void:
	# Step3 数据记录 —— 侦探笔记（08 场景五·来访者记录 7 项，简化为确认式回顾）
	if _asked_directions.size() >= 5 and StarRatingSystem:
		StarRatingSystem.add_insight(0.5)   # 五方向全追问洞察加成
	# 侦探笔记只记录玩家「实际追问过」的方向，未问的不写进本子
	var testimony := {
		"ring": {"name":"追问 · 戒指细节", "desc":"普通结婚金戒指，内侧刻字「好像是 L.F.」——她自己都记不清"},
		"lost": {"name":"追问 · 丢失经过", "desc":"称掏手绢时带落，具体地段说不清，推给「夜里天黑」"},
		"family": {"name":"追问 · 家庭情况", "desc":"女儿赛莉独居，女婿是联合公司船员，出海下月才回"},
		"route": {"name":"追问 · 来时路线", "desc":"称坐马车来，「哪记得清路」——回避路线问题"},
		"doubt": {"name":"质疑 · 地址矛盾", "desc":"布瑞克斯顿路不在宏兹迪池与马戏团之间；被点破后临时改口女儿住培克罕"},
		"letgo": {"name":"放行 · 未作追问", "desc":"直接归还戒指放其离开，未取得任何口供"},
	}
	var items := []
	for d in _asked_directions.keys():
		if testimony.has(d):
			items.append(testimony[d])
	if items.is_empty():
		items.append({"name":"（尚未追问任何方向）", "desc":"本子上还是空白的"})
	_popup("侦探笔记 · 来访者记录（已追问 " + str(items.size()) + " 项）", items)
	_start_dialogue([
		_mk_node("n0","福尔摩斯","把问出来的话理一理——记下的只有我真正问过的那几条，剩下的都是她没说、我也没追的。","click",["n1"]),
		_mk_node("n1","华生","（合上本子）全是间接疑点，没有实锤。下一步该进知识库、再上推理墙了。","click",["end"]),
	], "n0", _start_step4)

func _start_step4() -> void:
	# Step4 知识检索（可选 · M2+，08 场景五）：列出可检索领域（弹窗）
	var know := [
		{"name":"伦敦地理·宏兹迪池区", "desc":"伦敦南区，距布瑞克斯顿路有一定距离"},
		{"name":"伦敦地理·培克罕", "desc":"伦敦南区，布瑞克斯顿路附近，去马戏团路线合理"},
		{"name":"维多利亚时代·伪装术", "desc":"假发、假胡须、化妆改年龄、改变步态——常见伪装手段"},
		{"name":"19世纪伦敦出租马车", "desc":"车夫工作性质、登记制度、常见欺诈"},
		{"name":"犯罪心理学·身份伪装", "desc":"伪装者常备完整背景故事，细节越丰富越可信"},
	]
	_popup("知识检索 · 可选入口", know)
	_start_dialogue([
		_mk_node("k0","福尔摩斯","（翻小册）需要的话，这些都能查：伦敦地理、伪装术、出租马车、犯罪心理——知识库随时开着。","click",["k1"]),
		_mk_node("k1","华生","先把'她有问题'这个念头，连同已有疑点，摆上推理墙让假设说话。","click",["end"]),
	], "k0", _enter_reasoning)

# ---------- B 路线：追查马车（铁匠铺开场，跳 Step1-3） ----------

func _arrival_B() -> void:
	_start_dialogue([
		_mk_node("b0","系统","（演出）铁匠铺，炉火通明。","guide",["b1"]),
		_mk_node("b1","铁匠","右前蹄新换的？嗯……昨天傍晚是有一辆马车来换过掌。","click",["b2"]),
		_mk_node("b2","福尔摩斯","记得车夫长什么样吗？","click",["b3"]),
		_mk_node("b3","铁匠","高个子，红脸膛——不是喝酒喝出来的红，是风吹日晒那种红。美国西部口音，嗓门大，人挺随和，跟我聊了半天淘金热。","clue",["b4"],[CLUES["C_SOTCB_501"]]),
		_mk_node("b4","铁匠","他说主要在泰晤士河北岸跑活——尤斯顿、大英博物馆、霍尔本一带，说那边美国客人多。","click",["b5"]),
		_mk_node("b5","福尔摩斯","（转向玩家）右前蹄新换的掌，红脸高个的美国马车夫，常在北岸跑活——和咱们手里的画像，对上了几张？","click",["b6"]),
		_mk_node("b6","系统","（场景切回贝克街）","guide",["b7"]),
		_mk_node("b7","福尔摩斯","可光有特征和活动范围不够。伦敦那么大，找一个马车夫如大海捞针。先进知识库、上推理墙。","click",["end"]),
	], "b0", _start_step4)

# ---------- C 路线：发电报查询（电报已发待回，跳 Step1-3） ----------

func _arrival_C() -> void:
	_start_dialogue([
		_mk_node("c0","福尔摩斯","（展开电报底稿）从源头查起——美国克利夫兰，德雷伯的老家。给那边发一封电报，问问他在本地有什么仇家。","click",["c1"]),
		_mk_node("c1","华生","电报往返要时间，这算是一条慢线。","click",["c2"]),
		_mk_node("c2","福尔摩斯","可能直接命中要害。回复大约明后天到——先不空等，把已有的线索摆上推理墙。","click",["end"]),
	], "c0", _start_step4)

# ===================== 推理墙（Step5，统一机制，验证后自动进 TRANSITION） =====================

func _enter_reasoning() -> void:
	_phase = Phase.REASONING; _wall_auto = true
	_sync_clues()
	_prompt_think("福尔摩斯", "华生，'老太婆'的说辞全是间接疑点，真正的验证在后面——但我们先把假设摆上墙：她是不是伪装？凶手是不是马车夫霍普？私人恩怨还是政治阴谋？", "自信")

# ===================== 过渡：Step6 跟踪脱逃（A路线）+ 阶段末汇合 =====================

func _enter_transition() -> void:
	_phase = Phase.TRANSITION
	_award()
	if _route == "A":
		_start_step6_tracking()
	else:
		_start_finale()

func _start_step6_tracking() -> void:
	# Step6 验证修正 —— 跟踪与脱逃（08 场景五·双视角）：玩家选择是否跟踪
	_start_dialogue([
		_mk_node("t0","福尔摩斯","（低声）我跟着她。你留这儿，别睡，等我回来。","click",["t1"]),
		_mk_node("t1","系统","（街景·夜间跟踪）老太婆没走多远就叫住一辆过路马车：「到宏兹迪池区，邓肯街十三号。」福尔摩斯跟着跳上马车后部。","guide",["t2"]),
		_mk_node("t2","系统","（双视角·街对面巷口）一个高大的棕色外衣背影在煤气灯下闪过——杰弗森·霍普的红脸隐在帽檐阴影里，冷眼看着福尔摩斯跳上马车，旋即没入更深的小巷。他早已洞悉跟踪。","guide",["t3"]),
		_mk_node("t3","系统","（脱逃揭晓）马车到邓肯街，福尔摩斯先跳下等在暗处。车门打开——车厢空空荡荡，乘客早已踪迹全无。向十三号住户打听：住的是裱糊匠凯斯维克，从没听过什么索叶或丹尼斯。","guide",["t4"]),
		_mk_node("t4","福尔摩斯","（脸色难看）什么老太婆……该死，咱们两个才是老太婆。被人结结实实耍了一回。他一定是个年轻小伙子，而且精明强干，伪装乱真。","click",["t5"]),
		_mk_node("t5","福尔摩斯","（眼神重新锐利）不过他也暴露了一件事——宁可冒险回来拿戒指，说明戒指对他非同小可。这张牌，我们没白出。","clue",["end"],[CLUES["C_SOTCB_503"]]),
	], "t0", _offer_track_choice)

func _offer_track_choice() -> void:
	# 困难模式底线触发后的补救选择（设计 08·玩家全程未怀疑时）；常规流程也允许"未跟踪"分支
	_show_choice_panel("下一步 · 老太婆已脱逃", [
		{"text":"🔍 你早就在跟踪了 —— 确认伪装识破（已记录）", "cb": Callable(self, "_on_tracked")},
		{"text":"😮 我没怀疑她 —— 福尔摩斯自己追出去核实", "cb": Callable(self, "_on_not_tracked")},
	])

func _on_tracked() -> void:
	_tracked = true
	_start_dialogue([
		_mk_node("x0","华生","（恍然）所以那'老太婆'……根本就是凶手本人伪装的？他跳上马车的动作，哪像腿脚不便的老人。","click",["end"]),
	], "x0", _start_finale)

func _on_not_tracked() -> void:
	_tracked = false
	_start_dialogue([
		_mk_node("x0","福尔摩斯","（摇头披上外套）不对劲……太不对劲了。你待着，我去看看。","click",["x1"]),
		_mk_node("x1","系统","（半小时后）福尔摩斯回来，告诉玩家老太婆脱逃了——车厢空无一人，十三号住户从没听过索叶或丹尼斯。","guide",["end"]),
	], "x0", _start_finale)

func _start_finale() -> void:
	# 阶段末汇合：动态总结 + 贝克街分队 + 葛莱森/雷斯垂德竞争暗线 + 双钩子 + 转场景六
	# A 路线授予 503（脱逃时已授）；此处统一授予 504/505/506/502，B 路线补授 501
	var grants_finale := [CLUES["C_SOTCB_504"], CLUES["C_SOTCB_505"], CLUES["C_SOTCB_506"], CLUES["C_SOTCB_502"]]
	if _route != "B":
		grants_finale.append(CLUES["C_SOTCB_501"])   # A/C 路线由雷斯垂德来访补马车公司信息
	_start_dialogue([
		_mk_node("f0","福尔摩斯","（在房里踱步）好，现在手里有什么？来领戒指的是伪装，脱逃了；他对伦敦很熟，伪装技术高。","click",["f1"]),
		_mk_node("f1","福尔摩斯","正规侦探太大张旗鼓，一露面人家就闭嘴。我们需要……更灵活的方式。","click",["f2"]),
		_mk_node("f2","系统","（门铃响，一群衣衫褴褛的孩子涌进来——贝克街分队）","guide",["f3"]),
		_mk_node("f3","福尔摩斯","（对维金斯）维金斯，帮我找一个人。身高六英尺多，红脸，马车夫，右前蹄换了新掌的那匹马，美国口音，可能叫霍普。去出租马车行、铁匠铺周围打听。","clue",["f4"],[CLUES["C_SOTCB_506"]]),
		_mk_node("f4","维金斯","（敬礼）贝克街分队保证完成任务！","click",["f5"]),
		_mk_node("f5","福尔摩斯","（给每人先令）这些小家伙，一个人的成绩比一打官方侦探还显著。官方一露面，人家就闭口；他们哪儿都能去。","click",["f6"]),
		_mk_node("f6","华生","真是人不可貌相——我原以为他们只是街上的小混混。","click",["f7"]),
		_mk_node("f7","赫德森太太","先生，葛莱森警长来了，说是有重大发现。","click",["f8"]),
		_mk_node("f8","葛莱森","（得意）福尔摩斯！我基本破案了——克利夫兰回电，德雷伯是美国人，背景涉仇杀！","clue",["f9"],[CLUES["C_SOTCB_504"]]),
		_mk_node("f9","福尔摩斯","（接过电报）死者背景是查到了，可凶手是谁你还一点头绪没有。（低声对玩家）葛莱森的政治阴谋论，站不住。","clue",["f10"],[CLUES["C_SOTCB_505"]]),
		_mk_node("f10","福尔摩斯","（不动声色）我补发了一封补充电报，更详细的回电刚到——德雷伯在克利夫兰有过一段婚约变故。雷斯垂德，你那边呢？","click",["f11"]),
		_mk_node("f11","雷斯垂德","（神神秘秘）我查到几个可疑马车夫——方向没错吧？凶手就是马车夫！","clue",["f12"],[CLUES["C_SOTCB_501"] if _route != "B" else CLUES["C_SOTCB_501"]]),
		_mk_node("f12","福尔摩斯","（似笑非笑）方向蒙对了，可惜你查的都是错的。不过——凶手是马车夫这判断，算你歪打正着。","click",["f13"]),
		_mk_node("f13","福尔摩斯","（望向玩家）老太婆到底是谁，我们清楚了；霍普的名字也锁定了。但戒指对他为何这么重要？这一手，我们还有另一手准备。","clue",["f14"],[CLUES["C_SOTCB_502"]]),
		_mk_node("f14","华生","另一手准备？","click",["end"]),
	], "f0", _go_to_next_scene)

# ===================== 评分 / 存档 / 读档 =====================

func _award() -> void:
	if StarRatingSystem:
		StarRatingSystem.add_observation(ClueSystem.total_weight(clue_source()) if ClueSystem else 0)  # 按线索分级权重累加
		StarRatingSystem.add_reasoning(1)
		StarRatingSystem.add_insight(1)

func _go_to_next_scene() -> void:
	if GameManager and not GameManager.is_guest and SaveManager:
		var ids := ClueSystem.get_collected_ids(clue_source()) if ClueSystem else []
		await SaveSystem.request_save("scene5", Phase.TRANSITION, {"clue_ids": ids, "route": _route})
	SceneLoader.transition_to("res://scenes/scene6.tscn")

# ===================== 自定义选项面板（安全分支，不依赖对话引擎 choice） =====================

# ===================== 存 / 读档（消费场景四路线，存档带回 route 供恢复） =====================
func _do_save(slot: int = -1) -> void:
	var ids := ClueSystem.get_collected_ids(clue_source()) if ClueSystem else []
	print("[SAVE scene5] _phase=", _phase, " route=", _route, " ids=", ids)
	await SaveSystem.request_save("scene5", _phase, {"clue_ids": ids, "route": _route}, slot)
	_ui.show_notification("✅ 进度已保存")

func _restore_saved_state() -> bool:
	var ss = SaveSystem.take_save_state("scene5")
	if ss.is_empty(): return false
	var sp := int(ss.get("phase", 0))
	_route = ss.get("route", _route)
	if GameManager: GameManager.scene_state["scene4_route"] = _route
	_phase = sp
	_restore_clues_from_ids(ss.get("clue_ids", []))
	_ui.show_notification("✅ 读档成功 — 已恢复至「" + _phase_name(sp) + "」（路线 " + _route + "）")
	match sp:
		Phase.ARRIVAL: _enter_arrival(); return true
		Phase.REASONING: _phase = Phase.REASONING; _wall_auto = true; _sync_clues(); _open_wall(); return true
		Phase.TRANSITION: _enter_transition(); return true
	return false
