extends DetectiveScene
## Scene 6 — 卡彭蒂耶公寓（排除嫌疑型 · 人证调查）
## 葛莱森「礼帽溯源」高光 → 三对象自由调查（太太/爱莉丝/房间环境）→ 葛莱森翻车（按难度分支）
## → 中尉被捕与自证（四方向追问 + W.H. 伏笔）→ 玩家决策三方向 → 追查哈珀验证不在场证明
## → 葛莱森翻车收尾 → 推理墙（矛盾标记展示）→ 双钩子（斯特兰森悬念）转场景七。
##
## ⚠️ 分支实现说明（根因）：本框架 DialogueManager 的 trigger=="choice" 未被 SceneFramework 渲染，
## 故所有玩家分支（前往公寓 / 三对象选择 / 是否追查哈珀 / 路线 / 下一步方向）一律用自定义选项面板，
## 对话结束后弹按钮、回调驱动，安全不卡死（同 scene4/5）。
##
## 设计依据（严格对齐）：02_血字的研究_场景设计与流程 §14（v3.16.0）+ 08_血字的研究_对话台词库 场景六（v3.16.0）
##
## 红线修正（根因，非表面）：旧实现把线索 603「阿瑟中尉」标为 correct=false（误导项）。但 02 §14 将
## 「卡彭蒂耶身高（5.8英尺，与凶手矛盾）」列为【关键线索】、08 阶段6 交叉验证判定为 VERIFIED（体貌矛盾
## 排除阿瑟）。阿瑟是被排除的嫌疑人，其「体貌不符」恰恰是排除他的【正确证据】，误导项是葛莱森「阿瑟=凶手」
## 的错误结论（由推理墙矛盾标记承载）。故按 02/08 权威把 603 改为 correct=true（体貌矛盾·排除证据）。
##
## v3.16.0 对齐要点（本次重写重点）：
##  · 阶段1 礼帽溯源：补全「帽店反问 / 没去过 / 微不足道 / 伟大人物」完整对话链（08 阶段1 逐字）。
##  · 葛莱森结论：按简单/普通/困难三变体分支（08 阶段2结束）；简单模式含 v3.16.0 新增「雷斯垂德贬低」台词。
##  · 中尉证词：补全四方向追问（当晚发生 / 追出去 / 去了哪里 / 不在场证明人）+ 与航海小说 W.H. 吻合。
##  · 哈珀证词：含「印度水手」伏笔（v3.11.0 问题26）+ 维金斯在「船锚」酒吧引路。
##  · 玩家下一步方向：三选一（追查哈珀 / 追查斯特兰森 / 追查马车→场景五），对齐 08 阶段3结束 / 阶段2结束。

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
var _insight_bonus: int = 0         # v4.0 洞察星级加成（隐藏线索累计，封顶由墙处理）

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
				{"id":"H6-02","text":"威廉·哈珀证词可信","correct":true},
				{"id":"H6-03","text":"卡彭蒂耶太太在隐瞒什么","correct":true},
				{"id":"H6-04","text":"德雷伯死亡有6小时空白期","correct":true},
				{"id":"H6-05","text":"卡彭蒂耶中尉是凶手（葛莱森错误结论）","correct":false,"kind":"mislead"},
				{"id":"H6-06","text":"阿瑟追打德雷伯时失手杀人","correct":false,"kind":"mislead"},
				{"id":"H6-07","text":"德雷伯跳上的马车有问题","correct":true},
				{"id":"H6-08","text":"爱莉丝说的是真话","correct":true},
				{"id":"H6-09","text":"W.H.就是威廉·哈珀","correct":true}
			],
		"contradictions": [
			{"id":"C6-01","text":"身高5.8英尺 vs 凶手6英尺+","correct":true},
			{"id":"C6-02","text":"有动机 vs 有不在场证明","correct":true},
			{"id":"C6-03","text":"木棍「凶器」 vs 死者服毒","correct":true}
		],
		"milestones": [
			{"id":"S6-1","text":"卡彭蒂耶中尉不是凶手（已排除）"},
			{"id":"S6-2","text":"威廉·哈珀证词可信"},
			{"id":"S6-3","text":"木棍非凶器（死者服毒）"},
		],
		"conclusions": [
			{"id":"CL6-1","text":"卡彭蒂耶中尉被排除（体貌不符+不在场证明）","gate_hypo_ids":["H6-01","H6-07"]},
			{"id":"CL6-2","text":"哈珀证词坐实阿瑟不在场证明","gate_hypo_ids":["H6-02","H6-09"]},
			{"id":"CL6-3","text":"葛莱森「阿瑟=凶手」论被三组矛盾推翻","gate_hypo_ids":["H6-05","H6-06"]}
		],
		},
		# v4.0 三星评价：声明本推理链（逐链离散制）
		"chain_id": scene_id(),
		"expected_clues": CLUES.size(),  # 本链应收集线索总数（观察之星缺失条数分母）
		"insight_bonus": _insight_bonus,  # 发现沉默线索 D3 累计加成
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

# ===================== 流程：礼帽溯源 → 公寓 → 三对象 → 葛莱森翻车 → 中尉自证 → 哈珀 → 推理 → 双钩子 =====================

func _enter_arrival() -> void:
	_phase = Phase.ARRIVAL
	# 阶段1（08 阶段1 逐字）：葛莱森礼帽溯源锁定住址，得意宣布
	_start_dialogue([
		_mk_node("g0","葛莱森警长","（兴冲冲进门，搓着手）福尔摩斯先生，真是太好了，我发现了重大线索。艰苦的调查真是费了不少劲儿，可把我累坏了。体力劳动虽说不多，可是脑子绷得紧紧的。个中甘苦你肯定明白，因为咱们都是用脑子干活儿的。","click",["g1"]),
		_mk_node("g1","福尔摩斯","（不紧不慢，翻着报纸）你太过奖了。让我们听听，你是怎样获得这样一个可喜可贺的成绩的。","click",["g2"]),
		_mk_node("g2","华生","（低声对玩家说）葛莱森兴冲冲的样子……好像真有什么大发现似的。你觉得他找到的线索靠谱吗？","click",["g3"]),
		_mk_node("g3","葛莱森警长","啊，我全部告诉你们。首先必须克服的困难就是查明这个美国人的来历。有些人也许要登广告，等待人们前来报告，但我葛莱森的工作方法却不是这样的。你应该和我一样，都注意到了死者身旁的那顶帽子吧！","click",["g4"]),
		_mk_node("g4","福尔摩斯","（头也不抬）是的，那是从坎伯韦尔路一百二十九号的约翰·安德乌父子帽店买来的。","click",["g5"]),
		_mk_node("g5","葛莱森警长","（脸上立刻显出非常沮丧的神情，像泄了气的皮球）想不到你也注意到这一点了。你到那家帽店去过没有？","click",["g6"]),
		_mk_node("g6","福尔摩斯","没有。","click",["g7"]),
		_mk_node("g7","葛莱森警长","（放下心来，又挺起了胸脯）哈！有些细节，不管看起来多么微不足道，你也不应该放过它。","click",["g8"]),
		_mk_node("g8","福尔摩斯","（像引用名言似的）对一个伟大人物来说，任何事情都不是微不足道的。","click",["g9"]),
		_mk_node("g9","葛莱森警长","好，我找到了店主安德乌，问他是不是卖过一顶这么大号码、这个式样的帽子。他们查了查售货簿，很快就查到了——这顶帽子是送到一位住在陶尔魁里卡彭蒂耶公寓的住客德雷伯先生处的。这样我就找到了这个人的住址。","click",["g10"]),
		_mk_node("g10","福尔摩斯","（低声，半带调侃）漂亮，干得很漂亮！","click",["g11"]),
		_mk_node("g11","葛莱森警长","（越发得意）那就让我们一起去陶尔魁里卡彭蒂耶公寓一探究竟吧！","click",["end"]),
	], "g0", _enter_apartment_choice)

func _enter_apartment_choice() -> void:
	# 08 阶段1【玩家选择】：A. 前往卡彭蒂耶公寓 → 阶段2 / B. 不去，返回贝克街等消息
	_show_choice_panel("下一步", [
		{"text":"A. 前往卡彭蒂耶公寓调查", "cb": Callable(self, "_enter_apartment")},
		{"text":"B. 不去，继续在贝克街等消息（返回场景五）", "cb": Callable(self, "_go_scene5")},
	])

func _enter_apartment() -> void:
	_start_dialogue([
		_mk_node("a0","系统","（场景切换：卡彭蒂耶公寓·客厅）维多利亚时代中产阶级公寓，陈设整洁却略显拮据。壁炉上摆着一张合影照片，墙角有海军佩剑挂架。","guide",["a1"]),
		_mk_node("a1","卡彭蒂耶太太","（拘谨地站在客厅中央）先生们，请进。请问……有什么事吗？","click",["a2"]),
		_mk_node("a2","爱莉丝","（从里屋探出头，眼神警惕）妈妈，是谁来了？","click",["end"]),
	], "a0", _show_invest_panel)

func _show_invest_panel() -> void:
	# 阶段2（08）：三对象自由调查，玩家自由选择顺序，信息自动汇总（统一基类）
	var questions := [
		{"id":"landlady","text":"🗣 询问卡彭蒂耶太太（房东）", "cb": Callable(self, "_talk_landlady")},
		{"id":"alice","text":"🗣 询问爱莉丝（女儿）", "cb": Callable(self, "_talk_alice")},
		{"id":"room","text":"🔎 观察房间环境与物品", "cb": Callable(self, "_examine_room")},
	]
	_render_investigate_panel("自由调查 · 选择对象", questions, _investigated, Callable(self, "_gregson_conclusion"))

func _talk_landlady() -> void:
	_investigated["landlady"] = true
	# 调查对象 A（08）：品行 → 深度追问（崩溃）→ 德雷伯调戏爱莉丝（线索601）；补「八点离开 / 儿子阿瑟海军中尉」时间线
	_start_dialogue([
		_mk_node("l0","葛莱森警长","卡彭蒂耶太太，跟我们说说德雷伯先生这个人吧。他在你这儿住了多久？","click",["l1"]),
		_mk_node("l1","卡彭蒂耶太太","（低头，声音很小）差不多三个星期……他和他的秘书斯特兰森先生一直在欧洲大陆旅行，箱子上都贴着哥本哈根的标签。","click",["l2"]),
		_mk_node("l2","葛莱森警长","他这人怎么样？好相处吗？","click",["l3"]),
		_mk_node("l3","卡彭蒂耶太太","（咽了口唾沫）……就是普通的房客。话不多。","click",["l4"]),
		_mk_node("l4","葛莱森警长","（眼神锐利）太太，我劝你说实话。德雷伯的死不是小事，任何隐瞒都可能让真凶逍遥法外。","click",["l5"]),
		_mk_node("l5","卡彭蒂耶太太","（崩溃）好吧，我说！这人简直不是人——举止粗野，对我女儿爱莉丝更是言语轻佻，令人厌恶！","clue",["l6"],[CLUES["C_SOTCB_601"]]),
		_mk_node("l6","葛莱森警长","他几点离开的？","click",["l7"]),
		_mk_node("l7","卡彭蒂耶太太","八点钟。他说要赶九点一刻的火车去利物浦。我儿子阿瑟在海军服役，是个中尉，案发当晚出去了一趟……但我向您保证，阿瑟绝不会做伤害他人的事！","click",["end"]),
	], "l0", _show_invest_panel)

func _talk_alice() -> void:
	_investigated["alice"] = true
	# 调查对象 B（08）：德雷伯调戏（线索602）→ 九点返回 / 被阿瑟追打 / 跳马车逃走
	_start_dialogue([
		_mk_node("b0","玩家","爱莉丝小姐，德雷伯先生……对你做过什么吗？","click",["b1"]),
		_mk_node("b1","爱莉丝","（咬着嘴唇）他是个无耻之徒，不止一次对我胡说八道，要我跟他走。我不理他就是了。","clue",["b2"],[CLUES["C_SOTCB_602"]]),
		_mk_node("b2","爱莉丝","后来他八点走了，不到一个钟头又回来，喝醉了当着我妈妈的面要我跟他私奔……我哥哥阿瑟正好回来，一把抓住他衣领推出门，拿着木棍追了出去。","click",["b3"]),
		_mk_node("b3","爱莉丝","德雷伯跳上一辆马车逃走了。阿瑟也没追上，后来才回家。","click",["end"]),
	], "b0", _show_invest_panel)

func _examine_room() -> void:
	_investigated["room"] = true
	# 调查对象 C（08）：合影（605）→ 背面 1878 朴茨茅斯 → 比身高得体貌矛盾（603）
	_start_dialogue([
		_mk_node("c0","系统","（特写）壁炉上的银相框合影——一位穿海军制服的青年与年轻女子；青年面容清秀、身形偏瘦，比女子高出约半个头。","clue",["c1"],[CLUES["C_SOTCB_605"]]),
		_mk_node("c1","福尔摩斯","（拿起照片翻到背面）「阿瑟 & 爱莉丝，1878年春，朴茨茅斯」。阿瑟就是卡彭蒂耶中尉。","click",["c2"]),
		_mk_node("c2","福尔摩斯","（比了比身高）这青年最多五英尺八英寸，身形偏瘦——现场凶手可是六英尺以上的壮汉。这对不上。","clue",["c3"],[CLUES["C_SOTCB_603"]]),
		_mk_node("c3","华生","（点头）体貌矛盾。阿瑟看着不像凶手。房间里还有什么值得看的？","click",["end"]),
	], "c0", _room_deep_choice)

func _room_deep_choice() -> void:
	# 房间深度观察（08 操作 C-a/b/c + 沉默线索 D3）：佩剑无血迹 / 航海小说 W.H. 伏笔 / 法律书（D3）
	var opts := []
	opts.append({"text":"🗡 检查海军佩剑（旁证：无血迹、保养良好）", "cb": Callable(self, "_see_sword")})
	opts.append({"text":"📖 翻看航海小说（扉页签名 W.H.）", "cb": Callable(self, "_see_book")})
	if not _d3_seen:
		opts.append({"text":"📚 翻看书架底层法律书籍（沉默线索）", "cb": Callable(self, "_see_d3")})
	opts.append({"text":"结束房间观察，回到调查面板", "cb": Callable(self, "_show_invest_panel")})
	_show_choice_panel("房间 · 继续观察", opts)

func _see_sword() -> void:
	_start_dialogue([
		_mk_node("s0","系统","（特写）墙上挂着的海军佩剑，剑鞘保养得很好，挂钩旁有经常取放的浅痕。福尔摩斯拔出剑——剑身光亮，没有血迹，剑柄刻着缩写 A.C.。","guide",["s1"]),
		_mk_node("s1","福尔摩斯","佩剑无血迹，保养良好。这位中尉是个懂规矩的人。","click",["end"]),
	], "s0", _room_deep_choice)

func _see_book() -> void:
	# 08 操作 C-c：航海小说签名 W.H. → 与中尉证词「老战友威廉·哈珀」吻合（伏笔）
	_start_dialogue([
		_mk_node("b0","系统","（特写）书架上最上面那本《两年水手生涯》，扉页写着：「赠予我的好战友阿瑟·卡彭蒂耶，纪念地中海之行——W.H.」","guide",["b1"]),
		_mk_node("b1","福尔摩斯","W.H.……这个签名，和阿瑟提到的老战友对上了。值得追查。","click",["end"]),
	], "b0", _room_deep_choice)

func _see_d3() -> void:
	_d3_seen = true
	_insight_bonus += 1   # v4.0 洞察之星加成：发现沉默线索 D3（设计 08 D3）
	_start_dialogue([
		_mk_node("d0","系统","（特写）书架底层几本厚重的《英国法释义》，卷首都签着阿瑟的名字，书脊磨损严重，边角有批注。","guide",["d1"]),
		_mk_node("d1","福尔摩斯","这位中尉不只是个武夫，还挺懂法。这样的人，不太可能一时冲动就动手杀人。","clue",["d2"],[CLUES["C_SOTCB_606"]]),
		_mk_node("d2","华生","（若有所思）懂法、有荣誉感、体貌也对不上——葛莱森怕是抓错人了。","click",["end"]),
	], "d0", _room_deep_choice)

func _gregson_conclusion() -> void:
	# 08：玩家完成至少两个调查对象的 Step 3 记录后，才触发葛莱森结论
	if _investigated.size() < 2:
		_ui.show_notification("建议至少调查两位对象（太太 / 爱莉丝 / 房间）再下结论。")
		_show_invest_panel()
		return
	# 阶段2结束（08 阶段2结束 · 三难度变体）：葛莱森宣布破案 → 玩家判断 → 逮捕
	var nodes: Array[Resource] = []
	nodes.append(_mk_node("k0","系统","（三人走出卡彭蒂耶公寓）葛莱森警长兴奋得满脸通红。","guide",["k1"]))
	match _difficulty:
		0:   # 简单模式：v3.16.0 新增「雷斯垂德贬低」+ 福尔摩斯全程引导
			nodes.append(_mk_node("k1","葛莱森警长","太好了！案件越来越清晰了！雷斯垂德那个笨蛋还在到处找什么女人线索呢，案子已经破了。等他知道我先抓到了凶手——哼哼。","click",["k2"]))
			nodes.append(_mk_node("k2","葛莱森警长","卡彭蒂耶中尉有重大作案嫌疑——动机（保护妹妹）、凶器（木棍）、时间（外出两小时），全对上了！让我们立刻去逮捕他！","click",["k3"]))
			nodes.append(_mk_node("k3","福尔摩斯","（看向玩家）你怎么看？别急着下结论。想想我们在劳瑞斯顿花园街看到的——尸体上有什么伤口？凶手是什么样的体格？葛莱森说的这些，有哪一样是直接证据？","click",["k4"]))
		1:   # 普通模式：布瑞克斯顿路 / 木棍打心窝理论
			nodes.append(_mk_node("k1","葛莱森警长","卡彭蒂耶中尉追赶德雷伯一直到了布瑞克斯顿路。争吵之中，德雷伯狠狠挨了一棍，也许正打在心窝上，虽然送了命，却没有留下任何伤痕。当夜雨很大，附近又没有人，于是卡彭蒂耶就把尸首拖到了那所空屋里。","click",["k2"]))
			nodes.append(_mk_node("k2","葛莱森警长","这完全符合整个事件的经过！真相马上就要浮出水面了！让我们立刻去逮捕他！","click",["k3"]))
			nodes.append(_mk_node("k3","福尔摩斯","（冷静，不置可否，看向玩家）你觉得呢？","click",["k4"]))
		2:   # 困难模式：挑衅 + 华生质疑（无任何引导）
			nodes.append(_mk_node("k1","葛莱森警长","完美！一切都对上了！动机充分——妹妹被调戏，哥哥复仇。凶器在手——木棍，打在心窝不留痕迹。时间充足——出去了至少两个小时。物证链条——从卡彭蒂耶公寓到布瑞克斯顿路，正好是追逐路线。卡彭蒂耶中尉就是凶手！我们马上去抓他！","click",["k2"]))
			nodes.append(_mk_node("k2","葛莱森警长","（挑衅地看了福尔摩斯一眼）福尔摩斯先生，这次我可要抢先一步了。","click",["k3"]))
			nodes.append(_mk_node("k3","福尔摩斯","（没看葛莱森，转向玩家）你的判断？","click",["k4"]))
			nodes.append(_mk_node("k4","华生","（低声，犹豫）嗯……动机和时间确实都对上了，可是——我总觉得哪里不对。尸体上明明没有外伤啊……木棍打在心窝上不留痕迹，这可能吗？","click",["k5"]))
			nodes.append(_mk_node("k5","葛莱森警长","（握拳）走，抓他去！这小子跑不了。","click",["k6"]))
			# 困难模式概率误导（台词库·70%伪证据）：酒馆老板假证词，强化「阿瑟=凶手」误导
			if _difficulty == 2 and randf() < 0.7:
				nodes.append(_mk_node("km","酒馆老板","（从街角探出头，信誓旦旦）警长先生！昨晚半夜，我亲眼瞧见个穿海军制服的小子，鬼鬼祟祟溜回卡彭蒂耶家附近——身板硬朗，准是当兵的没错！","click",["k6"]))
			nodes.append(_mk_node("k6","系统","（葛莱森带着随从，气势汹汹出发去逮捕卡彭蒂耶中尉）","guide",["end"]))
			_start_dialogue(nodes, "k0", _arrest_interrogation)
			return
	# 简单/普通 模式共用尾部
	nodes.append(_mk_node("k4","葛莱森警长","（握拳）走，抓他去！这小子跑不了。","click",["k5"]))
	nodes.append(_mk_node("k5","系统","（葛莱森带着随从，气势汹汹出发去逮捕卡彭蒂耶中尉）","guide",["end"]))
	_start_dialogue(nodes, "k0", _arrest_interrogation)

func _arrest_interrogation() -> void:
	# 阶段3（08）：中尉被捕与自证 —— 四方向追问（当晚发生 / 追出去 / 去了哪里 / 不在场证明人）+ W.H. 吻合
	_start_dialogue([
		_mk_node("p0","葛莱森警长","（在一家酒馆里找到了卡彭蒂耶中尉）卡彭蒂耶先生，有人看见你和德雷伯先生发生了肢体冲突。跟我们走一趟吧，详细说说那天晚上的事。","click",["p1"]),
		_mk_node("p1","卡彭蒂耶中尉","（坦然）行，我跟你们走。我没什么好隐瞒的。","click",["p2"]),
		_mk_node("p2","系统","（随从从他身上搜出了那根橡木棍。葛莱森指着棍子）","guide",["p3"]),
		_mk_node("p3","葛莱森警长","这就是凶器吧？","click",["p4"]),
		_mk_node("p4","卡彭蒂耶中尉","（冷笑一声）凶器？如果我真想杀他，他就不会有机会跳上马车了。","click",["p5"]),
		_mk_node("p5","卡彭蒂耶中尉","他当着我母亲的面调戏我妹妹，我一把抓住他衣领推出门，拿着木棍追了出去。他跳上一辆马车逃走了——要不是跑得快，我一定亲手宰了他。","click",["p6"]),
		_mk_node("p6","葛莱森警长","他逃走之后呢？你又去了哪儿？","click",["p7"]),
		_mk_node("p7","卡彭蒂耶中尉","我在回家路上遇到了一位过去船上的老同事，陪他走了很久，聊了很多——聊到开始下雨才各自回家。","click",["p8"]),
		_mk_node("p8","葛莱森警长","哦？老同事？他叫什么，在哪儿能找到他？","click",["p9"]),
		_mk_node("p9","卡彭蒂耶中尉","他叫威廉·哈珀，在朴茨茅斯海军基地服役。一周前刚结束 HMS Conqueror 号地中海任务回来休假，我们那晚正好碰上了。你们可以去朴茨茅斯海军基地人事处查他。","click",["p10"]),
		_mk_node("p10","福尔摩斯","（看向玩家）阿瑟的身高、体格，和对面照片里那个清秀青年对得上——也和凶手对不上。要坐实排除，还得验证他的不在场证明。","click",["end"]),
	], "p0", _harper_choice)

func _harper_choice() -> void:
	# 玩家决策（08 阶段3结束 / 阶段2结束）：三方向 —— 哈珀(终极验证) / 斯特兰森(场景七) / 马车(场景五)
	var opts := [
		{"text":"A. 追查威廉·哈珀，验证不在场证明（推荐）", "cb": Callable(self, "_talk_harper")},
		{"text":"B. 排除卡彭蒂耶，直接追查斯特兰森（转场景七）", "cb": Callable(self, "_enter_reasoning")},
		{"text":"C. 追查马车 / 车夫线索（转场景五）", "cb": Callable(self, "_go_scene5")},
	]
	_show_choice_panel("验证方向 · 如何坐实排除阿瑟？", opts)

func _talk_harper() -> void:
	_harper_done = true
	# 阶段4（08）：哈珀不在场证明终极验证 —— 含「印度水手」伏笔 + 维金斯「船锚」酒吧引路
	_start_dialogue([
		_mk_node("h0","系统","（场景切换：朴茨茅斯·港口酒吧）人事处证实哈珀确实在休假。维金斯跑来通报，在「船锚」酒吧找到了威廉·哈珀中士。","guide",["h1"]),
		_mk_node("h1","哈珀中士","（放下啤酒杯）阿瑟？当然认识！我们在 HMS Conqueror 号上一起服役了三年。那小子就是脾气急了点。","click",["h2"]),
		_mk_node("h2","葛莱森警长","案发当晚——三日晚上——你见过他吗？","click",["h3"]),
		_mk_node("h3","哈珀中士","我从朴茨茅斯去伦敦办事，九点多在路上碰见他，聊了一个多钟头——从他妹妹聊到船上的老伙计，聊到那个印度水手，还有他那些从东方带回来的稀奇古怪的小玩意儿。后来开始下雨了，我们才各自回家。","clue",["h4"],[CLUES["C_SOTCB_604"]]),
		_mk_node("h4","哈珀中士","分开大概十点半、十一点。我差点没赶上最后一班火车回朴茨茅斯——不可能事先串供。","click",["h5"]),
		_mk_node("h5","福尔摩斯","（看向葛莱森）不在场证明、体貌不符、尸体无伤——三条线都对不上。我们的嫌疑犯是清白的。","click",["end"]),
	], "h0", _gregson_flip)

func _gregson_flip() -> void:
	# 葛莱森翻车收尾（08 阶段4 末）：震惊 → 承认 → 嘴硬 → 转向斯特兰森
	_start_dialogue([
		_mk_node("f0","葛莱森警长","（先是一愣，血色迅速褪去）什么？这不可能……动机、时间、凶器——明明都对上了……","click",["f1"]),
		_mk_node("f1","葛莱森警长","（缓缓开口，不甘却不得不承认）好吧……不在场证明，加上体貌不符，加上尸体无伤——三条线都对不上。我……方向可能错了。","click",["f2"]),
		_mk_node("f2","葛莱森警长","（嘴硬地补一句）不过——至少我们排除了一个重大嫌疑人。办案就是这样，排除法也是方法。卡彭蒂耶这条线，查清楚了反而是好事。","click",["f3"]),
		_mk_node("f3","福尔摩斯","（点头，不带嘲讽）没错。排除一个错误方向，就离正确答案近了一步。","click",["f4"]),
		_mk_node("f4","葛莱森警长","（攥紧拳头，咬着牙）卡彭蒂耶是无辜的……那真正的凶手在哪里？斯特兰森——他一定知道些什么！","click",["f5"]),
		_mk_node("f5","葛莱森警长","（合起笔记本）德雷伯的秘书斯特兰森……从一开始就很可疑。我去查他的下落。","click",["f6"]),
		_mk_node("f6","福尔摩斯","（微微一笑）看来我们想到一块去了。","click",["end"]),
	], "f0", _enter_reasoning)

func _enter_reasoning() -> void:
	_phase = Phase.REASONING; _wall_auto = true
	_sync_clues()
	_prompt_think("福尔摩斯", "华生，把证词摆上推理墙：阿瑟体貌不符、有不在场证明、死者死于服毒而非棍伤——葛莱森的「阿瑟=凶手」论会被三组矛盾同时锁死。", "自信")

func _enter_transition() -> void:
	_phase = Phase.TRANSITION
	_award()
	# 电报分支（思傅决策甲）：场景四选 C（发电报）→ 场景六末收到克利夫兰回复，直接锁定凶手=杰弗森·霍普
	if GameManager and GameManager.scene_state.get("scene4_route","") == "C":
		_play_telegraph_reply()
		return
	_start_transition_dialogue()

func _play_telegraph_reply() -> void:
	if GameManager: GameManager.scene_state["scene6_telegraph_rx"] = true
	# 线索：凶手全名 + 情敌宿怨（涉及露茜）—— 在抓到他之前就已知道姓名
	_start_dialogue([
		_mk_node("t0","系统","（一名分局信使骑马赶到，递来一封刚到的电报）","guide",["t1"]),
		_mk_node("t1","福尔摩斯","（拆阅，目光一凝）克利夫兰的回电到了。","click",["t2"]),
		_mk_node("t2","福尔摩斯","（念）『德雷伯，原名埃弗瑞兹·德雷伯，原克利夫兰人。情敌杰弗森·霍普，曾与德雷伯争夺一女子露茜，宿怨极深。霍普近踪不明，疑已赴欧。』","click",["t3"]),
		_mk_node("t3","华生","（倒吸凉气）杰弗森·霍普……所以凶手的全名，我们提前知道了？","click",["t4"]),
		_mk_node("t4","福尔摩斯","（折起电报）对。名字我们已经知道——杰弗森·霍普。剩下的，只是让他自己走到灯光下。","click",["t5"]),
		_mk_node("t5","系统","（场景六末·电报分支已触发：凶手=杰弗森·霍普，情敌宿怨涉及露茜）","guide",["end"]),
	], "t0", _start_transition_dialogue)

func _start_transition_dialogue() -> void:
	# 双钩子（08 §12 / 02 §14 §12）：华生台词悬念斯特兰森 → 转场景七
	_start_dialogue([
		_mk_node("z0","华生","（走出公寓）葛莱森这下可摔得不轻。那我们接下来找谁？","click",["z1"]),
		_mk_node("z1","福尔摩斯","斯特兰森——德雷伯的秘书。如果我没猜错的话，他已经……","click",["z2"]),
		_mk_node("z2","系统","（远处传来警笛声）","guide",["z3"]),
		_mk_node("z3","华生","（神色一紧）警笛……难道又出事了？","click",["z4"]),
		_mk_node("z4","福尔摩斯","（整了整领围）走吧，华生。郝黎代旅馆——去看看斯特兰森到底怎么了。","click",["end"]),
	], "z0", _go_to_next_scene)

func _award() -> void:
	# v4.0：三星由推理墙在评星时通过 StarRatingSystem.submit_chain() 逐链提交，本场景不再累加。
	pass

func _go_to_next_scene() -> void:
	# 过渡对话结束后弹出「侦破过程」评价面板（风格对齐场景一），点继续再存档进入下一场景
	_show_scene_rating("场景六 完成 · 侦破过程", "res://scenes/scene7.tscn", Callable(self, "_save_and_transition").bind("scene6", "res://scenes/scene7.tscn"))

func _go_scene5() -> void:
	# 08 阶段2结束 / 阶段3结束 选项 B/C 之一：追查马车线索（转场景五）
	SceneLoader.transition_to("res://scenes/scene5.tscn")

# ===================== 自定义选项面板（安全分支，不依赖对话引擎 choice） =====================

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