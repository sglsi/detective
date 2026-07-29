extends DetectiveScene
## Scene 6 — 卡彭蒂耶公寓（排除嫌疑型 · 人证调查）
## 葛莱森「礼帽溯源」高光 → 三对象自由调查（太太/爱莉丝/房间环境）→ 葛莱森翻车
## → 追查威廉·哈珀验证不在场证明 → 推理墙（矛盾标记展示）→ 双钩子（斯特兰森悬念）转场景七。
##
## ⚠️ 分支实现说明（根因）：本框架 DialogueManager 的 trigger=="choice" 未被 SceneFramework 渲染，
## 故所有玩家分支（前往公寓 / 三对象选择 / 追问 / 是否追查哈珀 / 路线）一律用自定义选项面板，
## 对话结束后弹按钮、回调驱动，安全不卡死（同 scene4/5）。
##
## 设计依据：02_血字的研究_场景设计与流程 §14（v3.16.0）+ 08_血字的研究_对话台词库 场景六（v3.16.0）
##
## 红线修正（根因，非表面）：旧实现把线索 603「阿瑟中尉」标为 correct=false（误导项）。但 02 §14 将
## 「卡彭蒂耶身高（5.8英尺，与凶手矛盾）」列为【关键线索】、08 阶段6 交叉验证判定为 VERIFIED（体貌矛盾
## 排除阿瑟）。阿瑟是被排除的嫌疑人，其「体貌不符」恰恰是排除他的【正确证据】，误导项是葛莱森「阿瑟=凶手」
## 的错误结论（由推理墙矛盾标记承载）。故按 02/08 权威把 603 改为 correct=true（体貌矛盾·排除证据）。

enum Phase { ARRIVAL, REASONING, TRANSITION }

## 本场景线索权威定义（id/name/desc/correct/w）。
## 601 太太证词 / 602 爱莉丝证词 / 603 阿瑟体貌不符（修正为关键排除证据）/ 604 哈珀不在场证明
## 605 壁炉合影 / 606 D3 法律书（沉默线索）。
const CLUES = {
	"C_SOTCB_601": {"id":"C_SOTCB_601","name":"卡彭蒂耶太太证词","desc":"房东太太说，德雷伯在他家住了约三周、品行恶劣、多次调戏女儿爱莉丝。","correct":true,"w":5},
	"C_SOTCB_602": {"id":"C_SOTCB_602","name":"爱莉丝证词","desc":"爱莉丝说，德雷伯九点左右返回、当众调戏她，被哥哥阿瑟撞见追打，德雷伯跳上马车逃走。","correct":true,"w":5},
	"C_SOTCB_603": {"id":"C_SOTCB_603","name":"阿瑟中尉体貌不符","desc":"壁炉合影与证词显示：阿瑟·卡彭蒂耶身高约5.8英尺、身形偏瘦——与现场凶手「六英尺以上、体格强壮」矛盾，是排除他的重要证据（非误导项）。","correct":true,"w":10},
	"C_SOTCB_604": {"id":"C_SOTCB_604","name":"威廉·哈珀证词","desc":"海军中士哈珀证实：案发当晚九点多至十一点多与阿瑟在伦敦街头长谈，为其提供完整不在场证明。","correct":true,"w":10},
	"C_SOTCB_605": {"id":"C_SOTCB_605","name":"壁炉合影","desc":"银相框里穿海军制服的青年（阿瑟）面容清秀、身形偏瘦，约比爱莉丝高半个头（≈5.8英尺）。","correct":true,"w":5},
	"C_SOTCB_606": {"id":"C_SOTCB_606","name":"D3 法律书籍","desc":"书架底层的《英国法释义》卷首有阿瑟签名与购书日期，书脊磨损严重——这位中尉懂法，不太可能一时冲动杀人。沉默线索，洞察之星奖励。","correct":true,"w":2},
}

var _investigated: Dictionary = {}   # 已调查对象（太太/爱莉丝/房间）
var _d3_seen: bool = false          # 沉默线索 D3（法律书）是否已发现
var _harper_done: bool = false      # 是否已追查哈珀

func scene_id() -> String: return "scene6"
func clue_source() -> String: return "scene6"
func hotspots() -> Array: return []
func scene_title() -> String: return "卡彭蒂耶公寓"
func scene_time_text() -> String: return "DAY 2 上午"
func scene_background() -> Texture2D: return load("res://assets/scenes/sc_06_apartment.jpg")

func _phase_name(p: int) -> String:
	match p:
		Phase.ARRIVAL: return "走访卡彭蒂耶家"
		Phase.REASONING: return "推理验证"
		Phase.TRANSITION: return "过渡"
		_: return "未知阶段"

func _in_observe_phase() -> bool: return false
func _in_reasoning_phase() -> bool: return _phase == Phase.REASONING
func _in_dialogue_phase() -> bool: return _phase == Phase.ARRIVAL or _phase == Phase.TRANSITION

func _observe_locked_msg() -> String: return "本场景无线索可观察，请与住户及葛莱森对话"
func _npc_talk_text(_g: int) -> String: return "葛莱森警长：\"帽子从安德乌帽店查到卡彭蒂耶公寓——凶手住址，我找到了！\""
func _no_evidence_msg() -> String: return "尚未从卡彭蒂耶家获得证词"
func _journal_empty_hint() -> String: return "调查三位对象：卡彭蒂耶太太 / 爱莉丝 / 房间环境"

func reasoning_hypothesis() -> Dictionary:
	return {
		"title": "排除阿瑟·卡彭蒂耶中尉，确认其为错误嫌疑（推理战场矛盾标记展示）",
		"description": "葛莱森以「动机+木棍+时间」断定阿瑟是凶手，但三份证词 + 房间环境给出三组矛盾，将其彻底排除。\n\n活跃假设：\n· H6-01 卡彭蒂耶中尉不是凶手（强：身高矛盾 + 不在场证明 + 体格矛盾）\n· H6-02 威廉·哈珀证词可信（中强：海军中士身份 + 具体时间线）\n\n矛盾标记（推理战场「矛盾标记」功能集中展示）：\n· C6-01 事实矛盾：卡彭蒂耶身高5.8英尺 vs 凶手6英尺+（身高差4英寸，不可能同一人）\n· C6-02 逻辑矛盾：有动机杀人 vs 有完美不在场证明（案发时正与哈珀长谈）\n· C6-03 证据矛盾：木棍「凶器」 vs 死者死于服毒（葛莱森连死因都没搞清就抓人）\n\n玩家可提交假设池（9条）：卡彭蒂耶=凶手 / 太太隐瞒 / 6小时空白期 / 阿瑟失手 / 马车有问题 / 爱莉丝真话 / 体貌不符 / W.H.=哈珀 / 哈珀可作证。",
		"battlefield": {
			"hypotheses": [
				{"id":"H6-01","text":"卡彭蒂耶中尉不是凶手","correct":true},
				{"id":"H6-02","text":"威廉·哈珀证词可信","correct":true}
			],
			"contradictions": [
				{"id":"C6-01","text":"身高5.8英尺 vs 凶手6英尺+","correct":true},
				{"id":"C6-02","text":"有动机 vs 有不在场证明","correct":true},
				{"id":"C6-03","text":"木棍「凶器」 vs 死者服毒","correct":true}
			],
		}
	}

func map_locations() -> Array:
	return [
		{"t":"贝克街221B", "d":"福尔摩斯寓所 — 场景一"},
		{"t":"劳瑞斯顿花园街3号", "d":"尸体现场 — 场景三"},
		{"t":"卡彭蒂耶公寓", "d":"德雷伯旧居 — 当前场景"},
	]

func casebook_steps() -> Array:
	return ["听葛莱森礼帽溯源", "三对象自由调查", "追查哈珀验证", "推理墙验证"]
func casebook_done_flags() -> Array:
	return [_phase >= Phase.ARRIVAL, _investigated.size() >= 2, _harper_done or _clues.has(CLUES["C_SOTCB_603"]), _phase >= Phase.REASONING]

func inventory_items() -> Array:
	return ["🔍 放大镜（初始）", "📏 卷尺（场景二解锁）", "🧪 化学试剂盒（场景三解锁）", "📖 黄页（场景五解锁）"]

func options_lines() -> Array:
	return [
		"难度：" + ["简单","普通","困难"][_difficulty],
		"操作：对话收集线索 → 推理墙验证",
		"⚠️ 阿瑟中尉是【被排除】的嫌疑人，其体貌不符是排除证据（非误导项）",
		"💡 洞察：发现书架底层法律书（D3）有加成",
	]

# ===================== 流程：礼帽溯源 → 公寓 → 三对象 → 葛莱森翻车 → 哈珀 → 推理 → 双钩子 =====================

func _enter_arrival() -> void:
	_phase = Phase.ARRIVAL
	# 对齐 08 稿 场景六·阶段1（L2587-2627）：葛莱森礼帽溯源锁定住址，得意宣布
	_start_dialogue([
		_mk_node("g0","葛莱森警长","（兴冲冲进门，搓着手）福尔摩斯先生，我有了重大发现！艰苦的调查真费劲，可把我累坏了——个中甘苦你肯定明白，咱们都是用脑子干活儿的。","click",["g1"]),
		_mk_node("g1","福尔摩斯","（不紧不慢翻报纸）你太过奖了。让我们听听，你是怎么获得这样一个可喜可贺的成绩的。","click",["g2"]),
		_mk_node("g2","华生","（低声）葛莱森兴冲冲的样子……好像真有什么大发现似的。你觉得他找到的线索靠谱吗？","click",["g3"]),
		_mk_node("g3","葛莱森警长","首先得查明这美国人的来历。你们都注意到了死者身旁那顶帽子吧！我从帽店查到——这帽子送到一位住在陶尔魁里卡彭蒂耶公寓的住客德雷伯先生处。住址，我找到了！","click",["g4"]),
		_mk_node("g4","福尔摩斯","（头也不抬）是从坎伯韦尔路一百二十九号约翰·安德乌父子帽店买的。漂亮，干得很漂亮。","click",["g5"]),
		_mk_node("g5","葛莱森警长","（越发得意）那就让我们一起去卡彭蒂耶公寓一探究竟吧！","click",["end"]),
	], "g0", _enter_apartment_choice)

func _enter_apartment_choice() -> void:
	_show_choice_panel("下一步", [
		{"text":"A. 前往卡彭蒂耶公寓调查", "cb": Callable(self, "_enter_apartment")},
		{"text":"B. 先听葛莱森把线索说完", "cb": Callable(self, "_gregson_talk_more")},
	])

func _gregson_talk_more() -> void:
	_start_dialogue([
		_mk_node("m0","葛莱森警长","我跟你们说，我葛莱森的工作方法可不是登广告等报告——我直接查帽店售货簿，一查一个准！","click",["m1"]),
		_mk_node("m1","福尔摩斯","（像引用名言）对一个伟大人物来说，任何事情都不是微不足道的。走吧，去看看这位德雷伯先生。","click",["end"]),
	], "m0", _enter_apartment)

func _enter_apartment() -> void:
	_start_dialogue([
		_mk_node("a0","系统","（场景切换：卡彭蒂耶公寓·客厅）维多利亚时代中产阶级公寓，陈设整洁却略显拮据。壁炉上摆着一张合影照片，墙角有海军佩剑挂架。","guide",["a1"]),
		_mk_node("a1","卡彭蒂耶太太","（拘谨地站在客厅中央）先生们，请进。请问……有什么事吗？","click",["a2"]),
		_mk_node("a2","爱莉丝","（从里屋探出头，眼神警惕）妈妈，是谁来了？","click",["end"]),
	], "a0", _show_invest_panel)

func _show_invest_panel() -> void:
	# 三对象自由调查（08 阶段2）：玩家自由选择顺序，信息自动汇总
	var opts := []
	if not _investigated.has("landlady"):
		opts.append({"text":"🗣 询问卡彭蒂耶太太（房东）", "cb": Callable(self, "_talk_landlady")})
	if not _investigated.has("alice"):
		opts.append({"text":"🗣 询问爱莉丝（女儿）", "cb": Callable(self, "_talk_alice")})
	if not _investigated.has("room"):
		opts.append({"text":"🔎 观察房间环境与物品", "cb": Callable(self, "_examine_room")})
	opts.append({"text":"✅ 完成调查，听取葛莱森的结论", "cb": Callable(self, "_gregson_conclusion")})
	_show_choice_panel("自由调查 · 选择对象（已查 " + str(_investigated.size()) + "/3）", opts)

func _talk_landlady() -> void:
	_investigated["landlady"] = true
	_start_dialogue([
		_mk_node("l0","葛莱森警长","卡彭蒂耶太太，跟我们说说德雷伯先生这个人吧。他在你这儿住了多久？","click",["l1"]),
		_mk_node("l1","卡彭蒂耶太太","（低头，声音很小）差不多三个星期……他和他的秘书斯特兰森先生一直在欧洲大陆旅行，箱子上都贴着哥本哈根的标签。","click",["l2"]),
		_mk_node("l2","葛莱森警长","他这人怎么样？好相处吗？","click",["l3"]),
		_mk_node("l3","卡彭蒂耶太太","（咽了口唾沫）……就是普通的房客。话不多。","clue",["l4"],[CLUES["C_SOTCB_601"]]),
		_mk_node("l4","葛莱森警长","（逼问）太太，我劝你说实话。德雷伯的死不是小事。","click",["l5"]),
		_mk_node("l5","卡彭蒂耶太太","（崩溃）好吧，我说！这人简直不是人——举止粗野，对我女儿爱莉丝更是言语轻佻，令人厌恶！","click",["end"]),
	], "l0", _show_invest_panel)

func _talk_alice() -> void:
	_investigated["alice"] = true
	_start_dialogue([
		_mk_node("b0","玩家","爱莉丝小姐，德雷伯先生……对你做过什么吗？","click",["b1"]),
		_mk_node("b1","爱莉丝","（咬着嘴唇）他是个无耻之徒，不止一次对我胡说八道，要我跟他走。我不理他就是了。","clue",["b2"],[CLUES["C_SOTCB_602"]]),
		_mk_node("b2","爱莉丝","后来他八点走了，不到一个钟头又回来，喝醉了当着我妈妈的面要我跟他私奔……我哥哥阿瑟正好回来，一把抓住他衣领推出门，拿着木棍追了出去。","click",["b3"]),
		_mk_node("b3","爱莉丝","德雷伯跳上一辆马车逃走了。阿瑟也没追上，后来才回家。","click",["end"]),
	], "b0", _show_invest_panel)

func _examine_room() -> void:
	_investigated["room"] = true
	_start_dialogue([
		_mk_node("c0","系统","（特写）壁炉上的银相框合影——一位穿海军制服的青年与年轻女子；青年面容清秀、身形偏瘦，比女子高出约半个头。","clue",["c1"],[CLUES["C_SOTCB_605"]]),
		_mk_node("c1","福尔摩斯","（拿起照片翻到背面）「阿瑟 & 爱莉丝，1878年春，朴茨茅斯」。阿瑟就是卡彭蒂耶中尉。","click",["c2"]),
		_mk_node("c2","福尔摩斯","（比了比身高）这青年最多五英尺八英寸，身形偏瘦——现场凶手可是六英尺以上的壮汉。这对不上。","clue",["c3"],[CLUES["C_SOTCB_603"]]),
		_mk_node("c3","华生","（点头）体貌矛盾。阿瑟看着不像凶手。房间里还有什么值得看的？","click",["end"]),
	], "c0", _room_deep_choice)

func _room_deep_choice() -> void:
	var opts := []
	if not _d3_seen:
		opts.append({"text":"📚 翻看书架底层法律书籍（沉默线索）", "cb": Callable(self, "_see_d3")})
	opts.append({"text":"结束房间观察，回到调查面板", "cb": Callable(self, "_show_invest_panel")})
	_show_choice_panel("房间 · 继续观察", opts)

func _see_d3() -> void:
	_d3_seen = true
	if StarRatingSystem:
		StarRatingSystem.add_insight(0.5)   # 洞察之星 +0.5（设计 08 D3）
	_start_dialogue([
		_mk_node("d0","系统","（特写）书架底层几本厚重的《英国法释义》，卷首都签着阿瑟的名字，书脊磨损严重，边角有批注。","guide",["d1"]),
		_mk_node("d1","福尔摩斯","这位中尉不只是个武夫，还挺懂法。这样的人，不太可能一时冲动就动手杀人。","clue",["d2"],[CLUES["C_SOTCB_606"]]),
		_mk_node("d2","华生","（若有所思）懂法、有荣誉感、体貌也对不上——葛莱森怕是抓错人了。","click",["end"]),
	], "d0", _room_deep_choice)

func _gregson_conclusion() -> void:
	# 08 阶段2结束 + 阶段3：葛莱森翻车名场面（L3189-3301 普通/阶段3）
	_start_dialogue([
		_mk_node("k0","系统","（三人走出公寓）葛莱森警长兴奋得满脸通红。","guide",["k1"]),
		_mk_node("k1","葛莱森警长","案件破了！卡彭蒂耶中尉有重大作案嫌疑——动机（保护妹妹）、凶器（木棍）、时间（外出两小时），全对上了！我们立刻去逮捕他！","click",["k2"]),
		_mk_node("k2","福尔摩斯","（不动声色）别急。想想劳瑞斯顿花园街：尸体上有什么伤口？凶手是什么体格？葛莱森说的这些，有哪一样是直接证据？","click",["k3"]),
		_mk_node("k3","华生","（低声）可是……尸体上明明没有外伤啊。木棍打在心窝不留痕迹，这可能吗？","click",["k4"]),
		_mk_node("k4","葛莱森警长","（在酒馆找到阿瑟）卡彭蒂耶先生，有人看见你和德雷伯发生了肢体冲突，跟我们走一趟。","click",["k5"]),
		_mk_node("k5","卡彭蒂耶中尉","（坦然）行，我没什么好隐瞒的。凶器？如果我真想杀他，他就不会有机会跳上马车了。","click",["end"]),
	], "k0", _arrest_interrogation)

func _arrest_interrogation() -> void:
	_start_dialogue([
		_mk_node("p0","卡彭蒂耶中尉","那混蛋当着我母亲面调戏我妹妹，我一把抓住他衣领推出门，拿着木棍追了出去。他跳上一辆马车逃了——要不是跑得快，我一定亲手宰了他。","click",["p1"]),
		_mk_node("p1","卡彭蒂耶中尉","追出去之后，我在回家路上碰见船上的老同事，聊到下雨才各自回家。他叫威廉·哈珀，在朴茨茅斯海军基地服役——你们可以去查他。","click",["p2"]),
		_mk_node("p2","福尔摩斯","（看向玩家）阿瑟的身高、体格，和对面照片里那个清秀青年对得上——也和凶手对不上。要坐实排除，还得验证他的不在场证明。","click",["end"]),
	], "p0", _harper_choice)

func _harper_choice() -> void:
	# 08 阶段4 入口：是否追查威廉·哈珀（终极验证）
	var opts := [
		{"text":"A. 追查威廉·哈珀，验证不在场证明（关键）", "cb": Callable(self, "_talk_harper")},
		{"text":"B. 不追查，凭体貌矛盾与尸体无伤排除阿瑟", "cb": Callable(self, "_skip_harper")},
	]
	_show_choice_panel("验证方向 · 如何排除阿瑟？", opts)

func _talk_harper() -> void:
	_harper_done = true
	_start_dialogue([
		_mk_node("h0","系统","（场景切换：朴茨茅斯·港口酒吧）维金斯跑来通报，在「船锚」酒吧找到了威廉·哈珀中士。","guide",["h1"]),
		_mk_node("h1","哈珀中士","（放下啤酒杯）阿瑟？当然认识！我们在HMS Conqueror号上一起服役三年。那小子就是脾气急了点。","click",["h2"]),
		_mk_node("h2","葛莱森警长","案发当晚——三日晚上——你见过他吗？","click",["h3"]),
		_mk_node("h3","哈珀中士","我从朴茨茅斯去伦敦办事，九点多在路上碰见他，聊了一个多钟头——从他妹妹聊到船上的老伙计。后来下雨了，我们才各自回家。","clue",["h4"],[CLUES["C_SOTCB_604"]]),
		_mk_node("h4","哈珀中士","分开大概十点半、十一点。我差点没赶上最后一班火车回朴茨茅斯——不可能事先串供。","click",["h5"]),
		_mk_node("h5","福尔摩斯","（看向葛莱森）不在场证明、体貌不符、尸体无伤——三条线都对不上。我们的嫌疑犯是清白的。","click",["end"]),
	], "h0", _gregson_flip)

func _skip_harper() -> void:
	_gregson_flip.call()

func _gregson_flip() -> void:
	# 葛莱森翻车收尾（08 阶段4 末 L3511-3535）
	_start_dialogue([
		_mk_node("f0","葛莱森警长","（先是一愣，血色迅速褪去）什么？这不可能……动机、时间、凶器明明都对上了……","click",["f1"]),
		_mk_node("f1","葛莱森警长","（缓缓开口，不甘却不得不承认）好吧……不在场证明，加上体貌不符，加上尸体无伤——三条线都对不上。我……方向可能错了。","click",["f2"]),
		_mk_node("f2","福尔摩斯","（点头，不带嘲讽）排除一个错误方向，就离正确答案近了一步。那真正的凶手在哪？斯特兰森——他一定知道些什么。","click",["f3"]),
		_mk_node("f3","葛莱森警长","（合起笔记本）德雷伯的秘书斯特兰森……从一开始就很可疑。我去查他的下落。","click",["end"]),
	], "f0", _enter_reasoning)

func _enter_reasoning() -> void:
	_phase = Phase.REASONING; _wall_auto = true
	_sync_clues()
	_ui.set_dialogue("福尔摩斯", "华生，把证词摆上推理墙：阿瑟体貌不符、有不在场证明、死者死于服毒而非棍伤——葛莱森的「阿瑟=凶手」论会被三组矛盾同时锁死。", "自信")
	await get_tree().create_timer(2.0).timeout
	_open_wall()

func _enter_transition() -> void:
	_phase = Phase.TRANSITION
	_award()
	# 双钩子（08 §12 / 02 §14 §12）：华生台词悬念斯特兰森 → 转场景七
	_start_dialogue([
		_mk_node("z0","华生","（走出公寓）葛莱森这下可摔得不轻。那我们接下来找谁？","click",["z1"]),
		_mk_node("z1","福尔摩斯","斯特兰森——德雷伯的秘书。如果我没猜错的话，他已经……","click",["z2"]),
		_mk_node("z2","系统","（远处传来警笛声）","guide",["z3"]),
		_mk_node("z3","华生","（神色一紧）警笛……难道又出事了？","click",["z4"]),
		_mk_node("z4","福尔摩斯","（整了整领围）走吧，华生。郝黎代旅馆——去看看斯特兰森到底怎么了。","click",["end"]),
	], "z0", _go_to_next_scene)

func _award() -> void:
	if StarRatingSystem:
		StarRatingSystem.add_observation(ClueSystem.total_weight(clue_source()) if ClueSystem else 0)  # 按线索分级权重累加
		StarRatingSystem.add_reasoning(1)
		StarRatingSystem.add_insight(1)

func _go_to_next_scene() -> void:
	if GameManager and not GameManager.is_guest and SaveManager:
		var ids := ClueSystem.get_collected_ids(clue_source()) if ClueSystem else []
		await SaveSystem.request_save("scene6", Phase.TRANSITION, {"clue_ids": ids})
	SceneLoader.transition_to("res://scenes/scene7.tscn")

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

func _do_save(slot: int = -1) -> void:
	var ids := ClueSystem.get_collected_ids(clue_source()) if ClueSystem else []
	print("[SAVE scene6] _phase=", _phase, " ids=", ids)
	await SaveSystem.request_save("scene6", _phase, {"clue_ids": ids}, slot)
	_ui.show_notification("✅ 进度已保存")

func _restore_saved_state() -> bool:
	var ss = SaveSystem.take_save_state("scene6")
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
