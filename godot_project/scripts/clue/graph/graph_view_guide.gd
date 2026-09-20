extends RefCounted
class_name GraphViewGuide

## 图谱视图 · 首入引导 / 多步骤教程层（拆自 graph_view_controller.gd）
##
## 职责：首次进入推理墙的多步骤引导弹层（欢迎 / 拖线索 / 建边 / 推导 / 折叠提交），
## 状态（_tutorial 等）自持；节点挂到 owner（GraphViewController）树下。

var owner: GraphViewController

# === 引导状态（原控制器 _tutorial / _tut_*，仅本层使用）===
var _tutorial: Control = null
var _tut_steps: Array = []           # 多步骤引导内容（title + 行）
var _tut_idx: int = 0
var _tut_title: Label = null
var _tut_body: VBoxContainer = null
var _tut_prev: Button = null
var _tut_next: Button = null

func show_tutorial() -> void:
	# 多步骤引导：教学环节首次进入强制展示；非教学仅在从未看过时展示；工具栏「?」可随时重开。
	if _tutorial and is_instance_valid(_tutorial):
		return
	_tut_steps = [
		{"t": "① 欢迎：推理墙怎么用",
		 "l": [
			"· 中心头像 = 当前焦点人物（认知锚点）",
			"· 距离核心由近及远：结论 → 推理链 → 推断 → 线索",
			"· 拖动节点 = 自由调整位置（距离自动维持排序）",
			"· 顶部可切换「人物星型 / 推理链」两种视图",
			"· 所有操作都可一键撤销，放心试",
		]},
		{"t": "② 把线索拖入画布（最关键的一步）",
		 "l": [
			"· 屏幕左侧「已收集线索栏」列出了你勘查得到的线索",
			"· 直接用鼠标把一条线索从左侧栏拖到画布空白处，它就成了一个节点",
			"· 也可右键画布上的线索节点 → 选「标注给某人」直接挂到焦点人物下",
			"· 线索不拖进来，后面的连线/推导都无从做起",
		]},
		{"t": "③ 建立关系连线",
		 "l": [
			"· 按住 Shift + 把一个节点拖到另一个节点上 = 建立证据连线（绿=支持）",
			"· 把线索/推断拖到人物头像 = 标注它和谁有关（金色归属边）",
			"· 连边后会自动按树结构重新排布，不用手动摆放",
			"· 想取消？点连线后按 Delete，或 Ctrl+Z 撤销",
		]},
		{"t": "④ 推导推断 / 结论",
		 "l": [
			"· 点任意节点打开详情卡",
			"· 线索详情卡 →「推导推断」生成推断节点并自动连线",
			"· 推断/结论详情卡 →「推导下一层结论」可继续向下推（多层链）",
			"· 顶部「＋」按钮也能手动添加文本框/推断",
		]},
		{"t": "⑤ 折叠整理 & 提交",
		 "l": [
			"· 节点上的「− / +N」圆圈 = 折叠/展开其下整棵子树（叶子可收起自身）",
			"· 结论推导出的下一层结论，折叠上层结论同样能收起整条链",
			"· 推理成型后点右上「✓ 提交验证」正式判定并推进剧情",
			"· 卡住了？点工具栏「?」随时重看本教程",
		]},
	]
	_tut_idx = 0
	_tutorial = Control.new()
	_tutorial.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tutorial.z_index = 30
	_tutorial.mouse_filter = Control.MOUSE_FILTER_STOP
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.62)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tutorial.add_child(overlay)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(920, 560)
	var _vp_size := owner.get_viewport_rect().size if owner.is_inside_tree() else Vector2(1280, 720)
	panel.position = (_vp_size - Vector2(560, 320)) / 2
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.10, 0.08, 0.06, 0.99)
	ps.border_color = owner.COL_GOLD
	ps.border_width_left = 3; ps.border_width_right = 3; ps.border_width_top = 3; ps.border_width_bottom = 3
	ps.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", ps)
	_tutorial.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	margin.add_child(vb)
	_tut_title = Label.new()
	_tut_title.add_theme_font_size_override("font_size", 38)
	_tut_title.add_theme_color_override("font_color", owner.COL_GOLD)
	vb.add_child(_tut_title)
	_tut_body = VBoxContainer.new()
	_tut_body.add_theme_constant_override("separation", 10)
	vb.add_child(_tut_body)
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 16)
	_tut_prev = Button.new(); _tut_prev.text = "上一步"
	_tut_next = Button.new(); _tut_next.text = "下一步"
	var skip := Button.new(); skip.text = "跳过 / 明白了"
	for tb: Button in [_tut_prev, _tut_next, skip]:
		tb.add_theme_font_size_override("font_size", 20)
	_tut_prev.pressed.connect(tut_goto.bind(-1))
	_tut_next.pressed.connect(tut_goto.bind(1))
	skip.pressed.connect(close_tutorial)
	nav.add_child(_tut_prev); nav.add_child(_tut_next); nav.add_child(skip)
	vb.add_child(nav)
	tut_render()
	owner.add_child(_tutorial)


func tut_render() -> void:
	if _tut_title == null or _tut_idx < 0 or _tut_idx >= _tut_steps.size():
		return
	var step: Dictionary = _tut_steps[_tut_idx]
	_tut_title.text = step.get("t", "")
	# 清空旧行
	for c in _tut_body.get_children():
		c.queue_free()
	for l in step.get("l", []):
		var lb := Label.new()
		lb.text = "· " + l if not l.begins_with("·") else l
		lb.add_theme_font_size_override("font_size", 27)
		lb.add_theme_color_override("font_color", owner.COL_GOLD_LIGHT)
		lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_tut_body.add_child(lb)
	_tut_prev.disabled = (_tut_idx <= 0)
	_tut_next.text = "下一步" if _tut_idx < _tut_steps.size() - 1 else "完成"
	_tut_next.disabled = false


func tut_goto(delta: int) -> void:
	if delta > 0 and _tut_idx >= _tut_steps.size() - 1:
		# 已在最后一步，点「完成」即关闭（最后一步内容会先渲染，按钮显示「完成」）
		close_tutorial()
		return
	_tut_idx = clampi(_tut_idx + delta, 0, _tut_steps.size() - 1)
	tut_render()


func close_tutorial() -> void:
	if _tutorial and is_instance_valid(_tutorial):
		_tutorial.queue_free()
		_tutorial = null
	_tut_title = null; _tut_body = null; _tut_prev = null; _tut_next = null
	owner._state_store["graph_tutorial_seen"] = true
	owner._persist_view()
