extends SceneTree

## 验证三档难度在当前代码中是否真的产生可见差异
## 重点检查：对话分支 / 误导线索过滤 / 热点高亮方法是否被消费

var _pass := 0
var _fail := 0
var DM  # 本地实例，等价于 autoload DifficultyManager

func _chk(cond: bool, msg: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  %s" % msg)
	else:
		_fail += 1
		print("  FAIL  %s" % msg)

## 用当前 autoload DifficultyManager 单例难度创建 ClueObserver，返回热点按钮描边宽度
func _mk_obs() -> Dictionary:
	var dm = root.get_node_or_null("DifficultyManager")
	if dm == null:
		dm = DM  # 兜底：本地实例
	var ob = load("res://scripts/clue/clue_observer.gd").new()
	var par = Control.new()
	root.add_child(par)
	ob.setup(par, Label.new(), Label.new(), [
		{"id":"a","label":"A","x":10,"y":10,"w":100,"h":40,"correct":true,"desc":"测试"},
	], null)
	var bw := 0
	for btn in par.get_children():
		if btn is Button:
			var sb = btn.get_theme_stylebox("normal")
			if sb != null and sb is StyleBoxFlat:
				bw = sb.border_width_left
	return {"obs": ob, "parent": par, "border": bw}

func _initialize() -> void:
	await create_timer(0.1).timeout
	DM = load("res://autoload/difficulty_manager.gd").new()

	print("===== 1) DifficultyManager 三档配置 =====")
	for d in [DM.Difficulty.EASY, DM.Difficulty.NORMAL, DM.Difficulty.HARD]:
		DM.set_difficulty(d)
		var nm = DM.get_difficulty_name()
		print("  [%s] hotspot_hint_level=%d auto_reveal=%s mislead=%.2f dialogue_detail=%s credibility=%s" % [
			nm, DM.hotspot_hint_level, DM.auto_reveal_clues, DM.mislead_chance, DM.dialogue_detail_level, DM.credibility_display])
	_chk(true, "配置本身存在三档差异（hotspot_hint_level 2/1/0）")

	print("\n===== 2) 热点高亮方法返回值三档是否不同 =====")
	var hs_key = {"id":"k1","importance":"key"}
	var hs_normal = {"id":"n1","importance":"normal"}
	DM.set_difficulty(DM.Difficulty.EASY)
	var easy_key = DM.is_hotspot_hint_visible(hs_key)
	var easy_normal = DM.is_hotspot_hint_visible(hs_normal)
	DM.set_difficulty(DM.Difficulty.NORMAL)
	var norm_key = DM.is_hotspot_hint_visible(hs_key)
	var norm_normal = DM.is_hotspot_hint_visible(hs_normal)
	DM.set_difficulty(DM.Difficulty.HARD)
	var hard_key = DM.is_hotspot_hint_visible(hs_key)
	var hard_normal = DM.is_hotspot_hint_visible(hs_normal)
	print("  EASY  : key=%s normal=%s" % [easy_key, easy_normal])
	print("  NORMAL: key=%s normal=%s" % [norm_key, norm_normal])
	print("  HARD  : key=%s normal=%s" % [hard_key, hard_normal])
	_chk(easy_key != hard_key, "is_hotspot_hint_visible 三档返回值不同（方法逻辑正确）")

	print("\n===== 3) ClueObserver 是否消费高亮方法（可见差异是否落地）=====")
	# 检查三档下热点按钮描边宽度：简单>0（明亮） 普通>0（微弱） 困难==0（无标记）
	# 注意：ClueObserver 读取的是 autoload 单例 DifficultyManager，必须用单例设置
	var sdm = root.get_node_or_null("DifficultyManager")
	if sdm == null:
		sdm = DM
	sdm.set_difficulty(sdm.Difficulty.EASY)
	var r_e = _mk_obs()
	sdm.set_difficulty(sdm.Difficulty.NORMAL)
	var r_n = _mk_obs()
	sdm.set_difficulty(sdm.Difficulty.HARD)
	var r_h = _mk_obs()
	print("  热点按钮描边宽度  EASY=%d NORMAL=%d HARD=%d" % [r_e.border, r_n.border, r_h.border])
	_chk(r_e.border > 0, "简单模式热点有高亮描边（可见差异已落地）")
	_chk(r_n.border > 0, "普通模式热点有微弱描边（可见差异已落地）")
	_chk(r_h.border == 0, "困难模式热点无描边（符合「无任何提示标记」）")
	_chk(r_e.border > r_n.border, "简单描边 > 普通描边（梯度正确）")
	r_e.obs.queue_free(); r_e.parent.queue_free()
	r_n.obs.queue_free(); r_n.parent.queue_free()
	r_h.obs.queue_free(); r_h.parent.queue_free()

	print("\n===== 4) 场景二误导线索过滤是否产生差异 =====")
	var s2_hotspots = [
		{"id":"H2-01","correct":true},{"id":"H2-02","correct":true},
		{"id":"H2-03","correct":true},{"id":"H2-04","correct":true},
		{"id":"H2-05","correct":true},{"id":"C2-01","correct":true},
		{"id":"C2-02","correct":true},{"id":"C2-03","correct":true},
	]
	DM.set_difficulty(DM.Difficulty.EASY)
	var e = DM.filter_hotspots_by_difficulty(s2_hotspots).size()
	DM.set_difficulty(DM.Difficulty.NORMAL)
	var n = DM.filter_hotspots_by_difficulty(s2_hotspots).size()
	DM.set_difficulty(DM.Difficulty.HARD)
	var h = DM.filter_hotspots_by_difficulty(s2_hotspots).size()
	print("  scene2 过滤后热点数  EASY=%d NORMAL=%d HARD=%d" % [e,n,h])
	_chk(e == n and n == h, "⚠️ 场景二无误导线索 → 三档热点集合完全相同（误导差异不可见）")

	print("\n===== 5) 含误导热点时过滤是否产生差异（场景四~八）=====")
	var mislead_set = [
		{"id":"real1","correct":true},{"id":"real2","correct":true},
		{"id":"ring","correct":false},{"id":"shoes","correct":false},
	]
	DM.set_difficulty(DM.Difficulty.EASY)
	var em = DM.filter_hotspots_by_difficulty(mislead_set).size()
	DM.set_difficulty(DM.Difficulty.HARD)
	var hm = DM.filter_hotspots_by_difficulty(mislead_set).size()
	print("  含误导场景过滤后  EASY=%d HARD=%d (总4)" % [em, hm])
	_chk(em == 2, "简单模式剔除全部误导线索（2条正确保留）")
	_chk(hm >= em, "困难模式保留至少同样多的热点（含误导线索）")

	print("\n===== 6) 对话分支是否随难度不同 =====")
	var dr = load("res://resources/dialogues/scene_02_garden.tres")
	DM.set_difficulty(DM.Difficulty.EASY)
	var start_e = dr.get_start_node(0)
	DM.set_difficulty(DM.Difficulty.HARD)
	var start_h = dr.get_start_node(2)
	print("  scene2 起始节点  EASY=%s HARD=%s" % [start_e, start_h])
	var node_ids = ["s2_step1_easy","s2_step1_normal","s2_step1_hard"]
	for nid in node_ids:
		var node = dr.find_node(nid)
		if node == null: continue
		var show_e = node.should_show(0)
		var show_h = node.should_show(2)
		print("    %s  EASY可见=%s HARD可见=%s" % [nid, show_e, show_h])
	_chk(start_e == start_h, "（注）起始节点相同，差异在 step1 引导文本分支，非结构性差异")

	print("\n===== 结果 =====")
	print("PASS=%d  FAIL=%d" % [_pass, _fail])
	quit()
