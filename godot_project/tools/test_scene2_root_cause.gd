extends SceneTree

## 根因验证（真实时序）：复现 DetectiveScene._ready 真实调用顺序——
##   _ui = SceneFramework.new(); add_child(_ui)   # 子节点 _ready 被 Godot 延迟，不自动跑
##   _ui.setup(...)                                # add_child 之后【同步】调用
##   _create_observers() → _ui.get_world_layer()  # 真实 bug 点：修复前此刻 _world 为 null
## 修复后 setup() 内 _ensure_world() 同步建好 _world，此处应拿到有效 world_layer，
## btn 挂到 _world、圆圈能画到 world、点击命中 btn 触发观察。

func _initialize() -> void:
	var sf = load("res://scripts/ui/scene_framework.gd").new()
	sf.name = "ui"
	root.add_child(sf)                 # 真实时序：_ready 延迟，不手动调用
	var bg = load("res://assets/scenes/sc_02_garden.png")
	sf.setup("劳瑞斯顿花园街3号", "DAY 1 上午11:15", bg)   # 修复：此处同步 _ensure_world

	var world: Control = sf.get_world_layer()
	print("[RC] setup() 后 get_world_layer() = ", (world.name if world else "null"), " => ", ("OK" if world else "❌ null（bug 仍在）"))
	if world == null:
		print("RC: FAIL (world null)"); quit()

	var obs = load("res://scripts/clue/clue_observer.gd").new()
	var txt := Label.new(); var spk := Label.new()
	root.add_child(txt); root.add_child(spk)
	var hs := [
		{"id":"c201","label":"碾轧的花草","x":180.0,"y":800.0,"w":150.0,"h":42.0,"desc":"d","image":"res://assets/scenes/sc_02_garden.png","anchor":"c201"},
		{"id":"c202","label":"平行车轮印","x":880.0,"y":660.0,"w":150.0,"h":42.0,"desc":"d","image":"res://assets/scenes/sc_02_garden.png","anchor":"c202"},
		{"id":"c203","label":"右前蹄新蹄铁","x":1200.0,"y":700.0,"w":150.0,"h":42.0,"desc":"d","image":"res://assets/scenes/sc_02_garden.png","anchor":"c203"},
		{"id":"c204","label":"马蹄印迹零乱","x":760.0,"y":790.0,"w":150.0,"h":42.0,"desc":"d","image":"res://assets/scenes/sc_02_garden.png","anchor":"c204"},
		{"id":"c205","label":"两组不同脚印","x":1000.0,"y":800.0,"w":150.0,"h":42.0,"desc":"d","image":"res://assets/scenes/sc_02_garden.png","anchor":"c205"},
		{"id":"c206","label":"步伐距离差异","x":1280.0,"y":790.0,"w":150.0,"h":42.0,"desc":"d","image":"res://assets/scenes/sc_02_garden.png","anchor":"c206"},
	]
	obs.setup(sf, txt, spk, hs, null, null, "", world, sf.get_world_offset())
	root.add_child(obs)   # 复现真实：_obs 必须入树，否则 _open_zoom 的 get_viewport() 为 null
	obs.show()
	await create_timer(0.08).timeout
	# headless 下 DifficultyManager.hotspot_hint_level 可能为 0（困难模式不画圈），
	# 手动以强度 1 画圈，验证「world_layer 非 null 时圆圈能挂到 world」（修复前为 null 不画）。
	for h in hs:
		obs._mark_clue_at_anchor(h["id"], 1)
	await create_timer(0.02).timeout

	var ok := true
	# 1) btn 全部挂 world 层（修复前落到 DetectiveScene 错乱坐标）
	for i in hs.size():
		var b = obs._btns[i]
		if b.get_parent() != world:
			print("RC: FAIL btn ", hs[i]["id"], " 父节点 = ", (b.get_parent().name if b.get_parent() else "null"))
			ok = false
	# 2) 圆圈全部画在 world 层（修复前 _world_layer==null 直接 return 不画）
	for h in hs:
		if not world.has_node("hl_" + h["id"]):
			print("RC: FAIL 圆圈未画 ", h["id"]); ok = false
	# 3) 组合公式：btn 全局中心 == 场景根热点中心（无回归，点击落点正确）
	for i in hs.size():
		var b = obs._btns[i]
		var expect := Vector2(hs[i]["x"] + hs[i]["w"] * 0.5, hs[i]["y"] + hs[i]["h"] * 0.5)
		var got: Vector2 = world.get_global_position() + b.position * world.scale + b.size * world.scale * 0.5
		if got.distance_to(expect) > 1.0:
			print("RC: FAIL 全局中心错 ", hs[i]["id"], " got=", got, " expect=", expect); ok = false

	# 4) 点击链路：emit pressed → hotspot_clicked + 放大图打开（确证「点击有反应」）
	var res := {"fired": false}
	obs.hotspot_clicked.connect(func(_id): res.fired = true)
	obs._btns[0].emit_signal("pressed")
	await create_timer(0.02).timeout
	if not res.fired:
		print("RC: FAIL 点击未触发 hotspot_clicked"); ok = false
	if not obs._zoomed:
		print("RC: FAIL 放大图未打开"); ok = false
	print("[RC] emit pressed(c201) → hotspot_clicked=", res.fired, " _zoomed=", obs._zoomed)

	# 5) 真实 GUI 输入路由：push_input 左键点击 c202 中心，验证不被吞/落空
	#    先重置 _zoomed（模拟上一次放大图已关闭），否则 _on_hotspot 的「放大中忽略后续点击」守卫会挡掉
	obs._zoomed = false
	var c0: Vector2 = world.get_global_position() + obs._btns[1].position * world.scale + obs._btns[1].size * world.scale * 0.5
	var res2 := {"fired": false}
	obs.hotspot_clicked.connect(func(_id): res2.fired = true)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT; ev.pressed = true; ev.position = c0; ev.global_position = c0
	root.push_input(ev)
	await create_timer(0.05).timeout
	print("[RC] push_input(c202) → hotspot_clicked=", res2.fired, "（headless 下 GUI 输入不分发，仅作信息；逻辑链路已由 emit pressed 确证）")

	print("[RC] ", "PASS ✅" if ok else "FAIL ❌")
	quit()
