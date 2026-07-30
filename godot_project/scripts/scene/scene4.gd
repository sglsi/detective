extends DetectiveScene
## Scene 4 — 奥德利大院四十六号（兰斯巡警证词）
## 人证调查类型的「六步闭环」：午后走访兰斯（他值夜班白天补觉）→ 六方向追问 → 证词提取 → 知识检索
## → 推理墙验证（醉汉=凶手 / 回来找戒指 / 马车夫）→ 阶段末小结 + A/B/C 行动决策。
## 架构：继承统一框架 DetectiveScene，仅覆盖内容钩子；对话节点 clue 触发走
## ClueSystem.collect_clue_from_catalog 单一漏斗（与观察器路径一致、幂等）。
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
## 401 醉汉（必得）402 高个 403 红脸（修正为真实关键线索）404 棕外衣 405 无马鞭（深度追问）
## 406 醉汉唱科隆比纳（其他异常，氛围类）。
const CLUES = {
	"C_SOTCB_401": {"id":"C_SOTCB_401","name":"巡警看到'醉汉'","desc":"案发当晚兰斯巡警在院外看到一个摇摇晃晃的醉汉离开——案发后有人离开现场，且就在门口。","correct":true,"w":5},
	"C_SOTCB_402": {"id":"C_SOTCB_402","name":"醉汉身高6英尺+","desc":"兰斯估摸那醉汉身高得有六英尺出头，与花园街现场留下的高大足迹吻合。","correct":true,"w":5},
	"C_SOTCB_403": {"id":"C_SOTCB_403","name":"醉汉红脸","desc":"兰斯证词：醉汉面色赤红。与场景三'凶手高个红脸'画像吻合（SUPPORTED）。但红脸是凶手天然特征（动脉瘤），切勿误判为'重病'——那才是误导陷阱。","correct":true,"w":5},
	"C_SOTCB_404": {"id":"C_SOTCB_404","name":"醉汉棕色外衣","desc":"醉汉披一件棕色外衣，是伦敦出租马车夫常见的装束。","correct":true,"w":5},
	"C_SOTCB_405": {"id":"C_SOTCB_405","name":"醉汉无马鞭","desc":"追问到深处，兰斯先说'好像有根鞭子'，又立刻改口'肯定没有，我看错了'——他犹豫了，这本身也是信息：凶手（马车夫）下车走过来的，马鞭挂在马车上。","correct":true,"w":5},
	"C_SOTCB_406": {"id":"C_SOTCB_406","name":"醉汉唱科隆比纳","desc":"兰斯说醉汉唱得响——科隆比纳那段，歌剧《宠姬》（La Favorite）的著名咏叹调。时代氛围线索。","correct":true,"w":2},
}

var _asked_directions: Dictionary = {}   # 已追问方向（用于全追问洞察加成与提示）
var _d1_seen: bool = false               # 沉默线索 D1（墙上旧照片）是否已发现

func scene_id() -> String: return "scene4"
func clue_source() -> String: return "scene4"
func hotspots() -> Array: return []
func scene_title() -> String: return "奥德利大院 四十六号"
func scene_time_text() -> String: return "DAY 1 下午"
func scene_background() -> Texture2D: return load("res://assets/scenes/sc_04_police.jpg")

## 氛围遮罩：场景四为下午两点走访奥德利大院（兰斯值夜班、白天在家补觉），
## 时间线修正（原误设为"深夜"违背常识：兰斯下午被叫起不可能说"大半夜"）。
func wants_atmosphere() -> bool: return true
func atmosphere_preset() -> String: return "Day"

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

func reasoning_hypothesis() -> Dictionary:
	return {
		"title": "醉汉=凶手，且是回来找戒指的马车夫（推理战场 M1）",
		"description": "兰斯看到的高个红脸醉汉（棕色外衣、无马鞭）与花园街现场高大足迹、方头靴吻合。\n\n活跃假设：\n· H4-01 醉汉就是凶手（中强：返回现场 + 身高匹配 + 红脸特征）\n· H4-02 凶手回来找戒指（中：返回现场行为 + 现场有戒指）\n· H4-03 凶手是马车夫·升级（中：无马鞭 + 出租马车 + 方头靴）\n\n矛盾标记：\n· C4-01 凶手红脸 vs 死者死于服毒（红脸是凶手天然特征，非情绪导致）\n· C4-02 精心策划的复仇 vs 喝醉被目击（多年大仇得报，一时放松警惕）\n· C4-03 无马鞭 vs 马车夫（马鞭挂在马车上，醉汉是下车走来的）\n\n玩家可提交假设池（12 条，按已获证词解锁）：案发时间≈凌晨两点 / 正在下雨 / 门口有醉汉 / 醉汉高个红脸 / 醉汉棕外衣 / 醉汉可能有马鞭 / 醉汉=凶手 / 醉汉是同伙 / 醉汉无关 / 凶手坐马车来 / 凶手伪装醉汉逃走 / 兰斯错过凶手。",
		"battlefield": {
			"hypotheses": [
				{"id":"H4-01","text":"醉汉就是凶手","correct":true},
				{"id":"H4-02","text":"凶手回来找戒指","correct":true},
				{"id":"H4-03","text":"凶手是马车夫（升级）","correct":true}
			],
		"contradictions": [
			{"id":"C4-01","text":"凶手红脸 vs 死者死于服毒","correct":true},
			{"id":"C4-02","text":"精心策划的复仇 vs 喝醉了被目击","correct":true},
			{"id":"C4-03","text":"无马鞭 vs 马车夫","correct":true}
		],
		"milestones": [
			{"id":"S4-1","text":"醉汉即凶手"},
			{"id":"S4-2","text":"凶手折返取回戒指"},
			{"id":"S4-3","text":"凶手是马车夫"},
			{"id":"S4-4","text":"凶手红脸为动脉瘤（真实症状，非重病）"},
		],
	}
	}

func map_locations() -> Array:
	return [
		{"t":"贝克街221B", "d":"福尔摩斯寓所 — 场景一"},
		{"t":"劳瑞斯顿花园街3号", "d":"尸体现场 — 场景三"},
		{"t":"奥德利大院四十六号", "d":"巡警宿舍 — 当前场景"},
	]

func casebook_steps() -> Array:
	return ["夜访奥德利大院", "询问兰斯巡警", "六方向追问", "推理墙验证"]
func casebook_done_flags() -> Array:
	return [_phase >= Phase.ARRIVAL, _phase >= Phase.REASONING, _asked_directions.size() >= 6, _phase >= Phase.TRANSITION]

func inventory_items() -> Array:
	return ["🔍 放大镜（初始）", "📏 卷尺（场景二解锁）", "🧪 化学试剂盒（场景三解锁）"]

func options_lines() -> Array:
	return [
		"难度：" + ["简单","普通","困难"][_difficulty],
		"操作：对话收集线索 → 六方向追问 → 推理墙验证",
		"⚠️ 红脸是凶手真实特征（动脉瘤），勿误判为'重病'",
		"💡 洞察：发现墙上旧照片、六方向全追问均有加成",
	]

# ===================== 流程：入场 → D1 → Step1 → 追问面板 → Step3 → Step4 → 推理 → 小结 =====================

func _enter_arrival() -> void:
	_phase = Phase.ARRIVAL
	# 逻辑修正（#127）：
	#   1. 时间线：兰斯值夜班（22:00-6:00），下午两点在家补觉被叫起——不是"大半夜"。
	#   2. 私语位置：福尔摩斯与华生"为什么先找兰斯"的私语放在敲门之前（马车上/门外路上），
	#      不能当着兰斯的面窃窃私语（既失礼又会让证人起疑）。
	_start_dialogue([
		_mk_node("e0","系统","（演出）下午两点，去往奥德利大院的马车上。","guide",["e1"]),
		_mk_node("e1","华生","福尔摩斯，我还是不太明白——我们不是应该先去追查那枚戒指吗？为什么去找一个巡警？","click",["e2"]),
		_mk_node("e2","福尔摩斯","（微微一笑）华生，戒指是诱饵，但我们得先知道鱼长什么样。兰斯虽然不起眼，却是第一个到现场的人——他看见的东西，可能比他自己意识到的多得多。","click",["e3"]),
		_mk_node("e3","华生","（恍然大悟）原来如此……可他值的是夜班，这个点只怕正在补觉。","click",["e4"]),
		_mk_node("e4","福尔摩斯","（掂了掂口袋里的半镑金币）所以我带了敲门砖。","click",["e5"]),
		_mk_node("e5","系统","（演出）奥德利大院，四十六号。午后的阳光斜照在斑驳的门板上。福尔摩斯上前敲门。","guide",["e6"]),
		_mk_node("e6","兰斯警士","（门开一条缝，睡眼惺忪，语气不快）谁啊？我值了一宿夜班，才睡下没多久……","click",["e7"]),
		_mk_node("e7","福尔摩斯","（掏出半镑金币，在指间转了转）兰斯警士，抱歉搅了你补觉，耽误你几分钟。关于劳瑞斯顿花园街的案子，想请你再说说当时的情况。","click",["e8"]),
		_mk_node("e8","兰斯警士","（眼睛一亮，睡意去了大半）哦……当然可以，先生。请进，请进。","click",["end"]),
	], "e0", _on_arrival_ended)

func _on_arrival_ended() -> void:
	# 沉默线索 D1（墙上旧照片）入口：自定义选项面板（对话已结束，安全）
	_show_choice_panel("观察 · 进屋后的第一眼", [
		{"text":"🔍 扫视房间——墙上挂着一张歪斜的旧照片", "cb": Callable(self, "_see_d1_photo")},
		{"text":"跳过，直接听兰斯说", "cb": Callable(self, "_start_step1")},
	])

func _see_d1_photo() -> void:
	_d1_seen = true
	if StarRatingSystem:
		StarRatingSystem.add_insight(0.5)   # 洞察之星 +0.5（设计 08 D1）
	_start_dialogue([
		_mk_node("d0","系统","（特写）一张泛黄的军队合影照片，挂在有些歪斜的钉子上。","guide",["d1"]),
		_mk_node("d1","福尔摩斯","（凑近看）一支旧式步枪团的合影——兰斯当过兵。难怪他对醉汉那副军人站姿没什么反应，见怪不怪了。","click",["d2"]),
		_mk_node("d2","华生","所以他的观察里混着'熟视无睹'……这反而提醒我们：他漏掉的，可能正是关键。","click",["d3"]),
	], "d0", _start_step1)

func _start_step1() -> void:
	# Step1 观察发现 —— 证人状态与初始叙述（08 L1844-1874）
	# 4 个高亮要点：凌晨两点 / 下着雨 / 醉汉站在门口 / 唱着歌
	_start_dialogue([
		_mk_node("s0","兰斯警士","（坐下，点了烟斗）我当班是晚上十点到早上六点。夜里一点开始下雨，两点多我巡逻到布瑞克斯顿路——又偏又滑，连个人影都没有，就一两辆马车路过。","click",["s1"]),
		_mk_node("s1","兰斯警士","忽然看见那所空房子窗口有灯光——怪吓人的，最后一个房客得伤寒死的，房东还不肯修阴沟。我推门进去，壁炉台上点着支红蜡烛，就看见地上躺了具尸体。","click",["s2"]),
		_mk_node("s2","兰斯警士","我赶紧吹警笛，摩契他们俩很快就来了。对了——我出来的时候，门口还靠着个醉汉，就在街灯底下，唱得震天响，站都站不住。我还提着灯过去想把他轰走。","clue",["s3"],[CLUES["C_SOTCB_401"]]),
		_mk_node("s3","福尔摩斯","（点头，看向玩家）他说的这些，你记下了什么？——凌晨两点、下着雨、醉汉站在门口、还唱着歌。四点都关键。","click",["s4"]),
		_mk_node("s4","华生","（在笔记本上飞快记着）记下了。可这些只是他'说的'，不是事实——得追问才挖得出来。","click",["s5"]),
		_mk_node("s5","福尔摩斯","（从口袋里摸出那枚半镑金币，在指间一转）问吧。他见了这个，话会多得很。","click",["end"]),
	], "s0", _start_panel)

func _start_panel() -> void:
	# Step2 工具操作 —— 追问引导（08 L1938-1990）：六方向追问面板，金币机制已通过入场体现
	var opts := [
		{"text":"🕑 追问时间 —— 你具体几点发现的？待了多久？", "cb": Callable(self, "_dir_time")},
		{"text":"🧑 追问醉汉外貌 —— 长什么样？看清了吗？", "cb": Callable(self, "_dir_look")},
		{"text":"🧥 追问醉汉穿着 —— 穿什么？手里拿什么？", "cb": Callable(self, "_dir_cloth")},
		{"text":"🐴 追问马车 —— 当时街上有马车吗？", "cb": Callable(self, "_dir_carriage")},
		{"text":"🏚 追问现场细节 —— 屋里什么样？", "cb": Callable(self, "_dir_scene")},
		{"text":"❓ 追问其他异常 —— 还有什么不寻常的？", "cb": Callable(self, "_dir_other")},
	]
	opts.append({"text":"✅ 结束追问，整理证词", "cb": Callable(self, "_start_step3")})
	_show_choice_panel("追问面板 · 选择方向（已问 " + str(_asked_directions.size()) + "/6）", opts)

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
		_mk_node("l0","福尔摩斯","深更半夜的，你怎么看清他模样的？","click",["l1"]),
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
		_mk_node("m1","兰斯警士","马车？我巡逻的时候有一两辆路过……哪记得清什么样的。我出来以后？没注意，光顾着吹警笛了。","click",["m2"]),
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
	# Step3 数据记录 —— 证词提取（08 L1992-2021）：侦探笔记 8 项（弹窗呈现，交互表单简化为确认式回顾）
	if _asked_directions.size() >= 6 and StarRatingSystem:
		StarRatingSystem.add_insight(0.5)   # 六方向全追问洞察加成
	var items := [
		{"name":"1. 发现时间", "desc":"约凌晨两点十分（兰斯明确证词）"},
		{"name":"2. 天气", "desc":"下雨（兰斯证词 + 花园街泥泞痕迹印证）"},
		{"name":"3. 醉汉身高", "desc":"高个子，六英尺出头（与现场高大足迹吻合）"},
		{"name":"4. 醉汉脸色", "desc":"赤红（真实特征；勿误判为'重病'）"},
		{"name":"5. 醉汉穿着", "desc":"棕色外衣 + 戴帽子（马车夫常见装束）"},
		{"name":"6. 醉汉手中有无马鞭", "desc":"不确定（兰斯先说有、后否认——他犹豫了）"},
		{"name":"7. 案发时有无马车经过", "desc":"有（巡逻时有一两辆路过）"},
		{"name":"8. 兰斯进入现场到叫人间隔", "desc":"约 2-5 分钟"},
	]
	_popup("侦探笔记 · 兰斯证词（8 项）", items)
	_start_dialogue([
		_mk_node("n0","福尔摩斯","把证词理一理：两点十分、下雨、高个红脸醉汉、棕色外衣、手里拿没拿鞭子他含糊——还有马车。八项，齐了。","click",["n1"]),
		_mk_node("n1","华生","（合上本子）可这些都还是'他说'。下一步该进知识库核对、再上推理墙了。","click",["end"]),
	], "n0", _start_step4)

func _start_step4() -> void:
	# Step4 知识检索（可选 · M2+，08 L2023-2031）：列出可检索领域（弹窗），由玩家自行参考
	var know := [
		{"name":"维多利亚时代巡警制度", "desc":"执勤时间、巡逻路线、发现案件后的标准流程"},
		{"name":"19 世纪伦敦出租马车", "desc":"马车类型、车夫特征、马蹄铁更换频率"},
		{"name":"证人证词可靠性", "desc":"人证记忆偏差：时间压力、情绪、事后信息干扰"},
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
	_ui.set_dialogue("福尔摩斯", "华生，兰斯看到的'醉汉'——六英尺出头、棕色外衣、红脸，正对上花园街那串高大足迹。把这六条，连同我们的假设，摆上推理墙。", "自信")
	await get_tree().create_timer(2.0).timeout
	_open_wall()

func _enter_transition() -> void:
	_phase = Phase.TRANSITION
	_award()
	# 阶段末小结 & 行动决策（08 L2101-2166）：动态总结 + 双钩子 + A/B/C 分支
	_start_dialogue([
		_mk_node("z0","福尔摩斯","（站起来，收好金币）谢谢你，兰斯警士。你提供的信息……很有价值。","click",["z1"]),
		_mk_node("z1","系统","（走出奥德利大院，午后的街道上）","guide",["z2"]),
		_mk_node("z2","华生","福尔摩斯，你怎么看？","click",["z3"]),
		_mk_node("z3","福尔摩斯","（转向玩家）你先说说——从兰斯的话里，我们拿到了什么？两点左右案发，下着雨；门口有个醉汉，高个、红脸、穿棕色外衣；案发时有马车经过；而那醉汉，很可能就是凶手——或者说，凶手伪装成醉汉逃走了。","click",["z4"]),
		_mk_node("z4","华生","（皱眉）等等……一个醉汉，凌晨两点，在空房子门口唱歌？太巧了。而且他为什么要装成醉汉？","click",["z5"]),
		_mk_node("z5","福尔摩斯","（略带欣赏）说得好，华生。最危险的地方就是最安全的地方——一个烂醉的流浪汉，谁会把他和杀人犯联系在一起？","click",["z6"]),
		_mk_node("z6","福尔摩斯","（沉吟）可醉汉——为什么他又回来了？如果他就是凶手，他回来做什么？","click",["z7"]),
		_mk_node("z7","华生","找东西？戒指？","click",["z8"]),
		_mk_node("z8","福尔摩斯","也许。但冒着被抓的风险回来找一样东西——那东西对他一定非常重要。好，现在的问题是：下一步怎么走？","click",["end"]),
	], "z0", _show_route_choice)

func _show_route_choice() -> void:
	# 行动决策（08 L2146-2159）：A 发布失物招领（主线）/ B 追查马车 / C 发电报查询
	_show_choice_panel("行动决策 · 下一步怎么走？", [
		{"text":"A. 发布失物招领 —— 用戒指设圈套，引凶手上钩（走场景五主线）", "cb": Callable(self, "_go_to_next_scene").bind("A")},
		{"text":"B. 追查马车 —— 从右前蹄新换的蹄铁入手，找马车和车夫", "cb": Callable(self, "_go_to_next_scene").bind("B")},
		{"text":"C. 发电报查询 —— 向美国克利夫兰查德雷伯背景（慢线，消耗1行动机会）", "cb": Callable(self, "_go_to_next_scene").bind("C")},
	])

func _award() -> void:
	if StarRatingSystem:
		StarRatingSystem.add_observation(ClueSystem.total_weight(clue_source()) if ClueSystem else 0)  # 按线索分级权重累加
		StarRatingSystem.add_reasoning(1)
		StarRatingSystem.add_insight(1)

func _go_to_next_scene(route: String = "A") -> void:
	if GameManager:
		GameManager.scene_state["scene4_route"] = route   # 供场景五分支消费（#92 对齐时接线）
	if GameManager and not GameManager.is_guest and SaveManager:
		var ids := ClueSystem.get_collected_ids(clue_source()) if ClueSystem else []
		await SaveSystem.request_save("scene4", Phase.TRANSITION, {"clue_ids": ids, "route": route})
	SceneLoader.transition_to("res://scenes/scene5.tscn")

# ===================== 自定义选项面板（安全分支，不依赖对话引擎 choice） =====================
func _show_choice_panel(title_txt: String, options: Array) -> void:
	# options: Array of {"text":String, "cb":Callable}
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
