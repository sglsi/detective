extends SceneTree
## 探针：验证观察层（Step2 放大面板）的控件是否落在可点击区域内。
## 背景：观察层节点挂在 scene_area(140,50 / 1780x800) 下，但坐标按 1920x1080 全屏设计，
## 底部「Step 3 记录」按钮会掉进底部对话栏(全局 y>=850, MOUSE_FILTER_STOP)被吃掉点击。

func _initialize() -> void:
	await create_timer(0.1).timeout
	var packed := load("res://scenes/scene1.tscn") as PackedScene
	var inst := packed.instantiate()
	root.add_child(inst)
	await process_frame
	await process_frame

	var ui = inst.get("_ui")
	var sa: Control = ui.get_scene_area()
	print("=== 布局 ===")
	print("scene_area  全局rect: ", _grect(sa))
	var dbar: Control = ui.find_child("dialogue_bar", true, false)
	if dbar:
		print("dialogue_bar 全局rect: ", _grect(dbar), "  mouse_filter=", dbar.mouse_filter, " (0=STOP,1=PASS,2=IGNORE)")

	# 直接触发华生 face 热点，构造观察层
	var obs = inst.get("_watson_obs")
	obs.show()
	obs._on_hotspot("face", "面色微晒黑且憔悴 -> 久病初愈")
	await process_frame

	print("\n=== 观察层控件位置 vs 可点击性 ===")
	var ok := true
	for nm in ["obs_dim", "obs_img", "obs_zoom", "obs_desc", "obs_confirm", "obs_back"]:
		var n = sa.find_child(nm, true, false)
		if n == null:
			print("  %-14s <未创建>" % nm)
			continue
		var c := n as Control
		var gr := _grect(c)
		var inside_sa := _grect(sa).encloses(gr)
		var hit_dbar := dbar != null and _grect(dbar).intersects(gr)
		var flag := ""
		if not inside_sa: flag += " ⚠越出scene_area"
		if hit_dbar: flag += " ⚠被对话栏覆盖"
		if not inside_sa or hit_dbar: ok = false
		print("  %-14s %s%s" % [nm, str(gr), flag])

	# 命中测试：obs_confirm 中心点最终会被哪个控件接收
	var cf = sa.find_child("obs_confirm", true, false)
	if cf:
		var pt: Vector2 = _grect(cf).get_center()
		var top := _topmost_at(root, pt)
		print("\n=== 点击命中测试 ===")
		print("  记录按钮中心点: ", pt)
		print("  实际接收点击的控件: ", ("<无>" if top == null else "%s (%s)" % [top.name, top.get_class()]))
		if top != cf:
			ok = false
			print("  ❌ 点击不会落到 obs_confirm —— 玩家点不动「Step 3 记录」")
		else:
			print("  ✅ 点击正常落到 obs_confirm")

	# 左侧上下文图与右侧放大图不得重叠（TextureRect 被纹理最小尺寸撑大会导致重叠）
	var ci = sa.find_child("obs_img", true, false)
	var zi = sa.find_child("obs_zoom", true, false)
	if ci != null and zi != null:
		if _grect(ci).intersects(_grect(zi)):
			ok = false
			print("  ❌ 上下文图与放大图重叠: ", _grect(ci), " ∩ ", _grect(zi))
		else:
			print("  ✅ 上下文图与放大图无重叠")

	# 「返回」按钮同样必须可点（防卡死兜底出口）
	var bk = sa.find_child("obs_back", true, false)
	if bk == null:
		ok = false
		print("  ❌ 缺少 obs_back 返回按钮（无防卡死出口）")
	else:
		var bp: Vector2 = _grect(bk).get_center()
		var btop := _topmost_at(root, bp)
		if btop != bk:
			ok = false
			print("  ❌ 返回按钮点不到，实际接收: ", ("<无>" if btop == null else btop.name))
		else:
			print("  ✅ 返回按钮可点（防卡死出口有效）")

	# 场景一背景不得再误用命案现场图（那是场景三的地点）
	var bgn = sa.find_child("scene_bg", true, false)
	if bgn != null and bgn is TextureRect and bgn.texture != null:
		var bp2: String = bgn.texture.resource_path
		print("\n=== 场景一背景 ===\n  ", bp2)
		if bp2.contains("crime_scene"):
			ok = false
			print("  ❌ 场景一误用命案现场背景（与场景三撞车）")
		else:
			print("  ✅ 背景与场景地点相符")

	print("\nPROBE_OBS_RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit()

func _grect(c: Control) -> Rect2:
	return Rect2(c.global_position, c.size)

## 按绘制顺序（后绘制者优先）找出某点最终接收鼠标的 Control
func _topmost_at(n: Node, pt: Vector2) -> Control:
	var found: Control = null
	for child in n.get_children():
		var r := _topmost_at(child, pt)
		if r != null:
			found = r
	if found != null:
		return found
	if n is Control:
		var c := n as Control
		if c.visible and c.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			if _grect(c).has_point(pt) and c.is_visible_in_tree():
				return c
	return null
