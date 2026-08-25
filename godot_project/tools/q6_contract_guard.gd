extends SceneTree
# Q6 契约守卫：图谱"显示/命中分离" + 契回墙顶层全屏 + 浮层命中让出区 不可回归。
# 守护目标（防"修一处坏一处"的死循环）：
#  - 图谱契回墙顶层全屏（世界原点到(0,0)，节点坐标不偏移 → 折叠/排序不偏移）；
#  - _clip/_canvas 只负责显示(Ignore)，_hit_layer(STOP) 让出顶栏/左栏区，
#    使左栏/顶栏浮层确定性可点（不赌 z_index 命中顺序）；
#  - 命中让出区 hit_off_left/top 由推理墙单源传入，须与左栏右缘/顶栏底对齐。
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
	_check(gv.hit_off_left == 540, "命中让出区左侧=540(左栏右缘)")
	_check(gv.hit_off_top == 110, "命中让出区顶部=110(顶栏底)")

	var g := _src("res://scripts/clue/graph_view_controller.gd")
	_check(g.contains("mouse_filter = Control.MOUSE_FILTER_IGNORE"), "图谱根 mouse_filter=IGNORE(不抢UI)")
	_check(g.contains("_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE"), "_clip 只显示(Ignore)")
	_check(g.contains("_clip.clip_contents = true"), "_clip 仍裁剪显示到画布")
	_check(g.contains("_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE"), "_canvas 只显示(Ignore)")
	_check(g.contains("_hit_layer.mouse_filter = Control.MOUSE_FILTER_STOP"), "_hit_layer STOP 接管画布交互")
	_check(g.contains("_hit_layer.gui_input.connect(_on_canvas_gui)"), "_hit_layer 连接画布命令")
	_check(g.contains("_hit_layer.z_index = -5"), "_hit_layer 压在节点(z=0)之下，节点优先点击/拖动")
	_check(g.contains("_hit_layer.offset_left = hit_off_left"), "命中让出区左侧用 hit_off_left(非硬编码)")
	_check(g.contains("_hit_layer.offset_top = hit_off_top"), "命中让出区顶部用 hit_off_top(非硬编码)")

	var w := _src("res://scripts/clue/reasoning_wall.gd")
	_check(not w.contains("_graph_holder.add_child"), "图谱契回墙顶层，不再契入容器")
	_check(w.contains("gv.hit_off_left = 540") and w.contains("gv.hit_off_top = 110"), "推理墙单源传入命中让出区")

	print("Q6 DONE fails=" + str(_fails))
	quit(_fails)