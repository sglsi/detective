extends SceneTree
# Q6 契约守卫：图谱"契入让出"（_clip 几何让出顶栏/左栏，同一区域既显示又承接画布交互）不可回归。
# 守护目标（防"修一处坏一处"的死循环）：
#  - 图谱契回墙顶层，_clip 契入让出「左栏右侧、顶栏之下」的图谱交互区（clip_contents 裁剪）；
#  - 图谱交互只经 _clip/_canvas(STOP) → _on_canvas_gui 一条链：平移/缩放/空白点击/shift 建边/折叠
#    都在 clip 区内正常响应，顶栏/左栏区域天然不被图谱覆盖故可点，无需命中分离层；
#  - 契入让出区 hit_off_left/top 由推理墙单源传入，须与左栏右缘/顶栏底对齐；
#  - 手工写 _canvas.position 的锚点位（_zoom_at/fit_view）须按 _clip 原点偏移校正，保证世界坐标可换算。
var _fails: int = 0

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("Q6 OK   : " + msg)
	else:
		print("Q6 FAIL : " + msg)
		_fails += 1

func _src(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text() if f else ""

func _init() -> void:
	await process_frame
	await process_frame
	var gv = load("res://scripts/clue/graph_view_controller.gd").new()
	_check(gv.hit_off_left == 540, "契入让出区左侧=540(左栏右缘)")
	_check(gv.hit_off_top == 110, "契入让出区顶部=110(顶栏底)")

	var g := _src("res://scripts/clue/graph_view_controller.gd")
	_check(g.contains("mouse_filter = Control.MOUSE_FILTER_IGNORE"), "图谱根 mouse_filter=IGNORE(不抢UI)")
	_check(g.contains("_clip.mouse_filter = Control.MOUSE_FILTER_STOP"), "_clip STOP 同一区域即显示即交互")
	_check(g.contains("_clip.gui_input.connect(_on_canvas_gui)"), "_clip 连接画布命令(shift建边/平移/缩放走此链)")
	_check(g.contains("_clip.clip_contents = true"), "_clip 裁剪显示到图谱交互区")
	_check(g.contains("_clip.offset_left = hit_off_left"), "契入让出区左侧用 hit_off_left(非硬编码)")
	_check(g.contains("_clip.offset_top = hit_off_top"), "契入让出区顶部用 hit_off_top(非硬编码)")
	_check(g.contains("_canvas.mouse_filter = Control.MOUSE_FILTER_STOP"), "_canvas STOP 承接平移/滚轮/空白点击")
	_check(g.contains("_canvas.gui_input.connect(_on_canvas_gui)"), "_canvas 连接画布命令")
	_check(not g.contains("_hit_layer"), "已废除命中分离层 _hit_layer")
	_check(g.contains("_clip.get_global_transform().origin"), "_zoom_at/fit_view 按 _clip 原点校正坐标")

	var l := _src("res://scripts/clue/graph/graph_view_layout.gd")
	_check(g.contains("func auto_layout"), "图谱提供 auto_layout 一键整理")
	_check(g.contains("_use_rank_layout"), "图谱用 _use_rank_layout 切换规范分列布局")
	_check(l.contains("func _auto_rank_layout"), "布局组件提供严格分列+barycenter 减交叉布局")
	_check(l.contains("owner._use_rank_layout"), "_compute_layout 按 _use_rank_layout 分流到自动排列")

	var w := _src("res://scripts/clue/reasoning_wall.gd")
	_check(w.contains("自动排列") and w.contains("_on_auto_arrange_pressed"), "顶栏提供「自动排列」按钮")
	_check(not w.contains("_graph_holder.add_child"), "图谱契回墙顶层，不再契入容器")
	_check(w.contains("gv.hit_off_left = 540") and w.contains("gv.hit_off_top = 110"), "推理墙单源传入契入让出区")

	print("Q6 DONE fails=" + str(_fails))
	quit(_fails)