extends CanvasLayer
class_name ToolBar

## ToolBar v2 — 侦探工具栏（CanvasLayer，可挂到任意场景）
##
## 按 §4.3.4 实现真实主动操作：
##   放大镜：移动镜片发现细节  |  卷尺：拖拽测量读数
##   化学试剂盒/黄页等：弹出交互面板
##
## 使用方式：在 DetectiveScene._build_ui() 中实例化并 add_child。
##   var tb = ToolBar.new(); add_child(tb)
##   tb.tool_activated.connect(_on_tool_activated)

# ===== 工具定义（与 ToolSystem.TOOLS 一致）=====
const TOOL_DEFS := [
	{"id": "magnifier", "name": "放大镜", "icon": "res://assets/tools/magnifier.png"},
	{"id": "tape",       "name": "卷尺",   "icon": "res://assets/tools/tape.png"},
	{"id": "chemistry",  "name": "化学试剂盒", "icon": "res://assets/tools/chemistry.png"},
	{"id": "directory",  "name": "黄页",     "icon": "res://assets/tools/directory.png"},
	{"id": "handcuffs",  "name": "手铐",     "icon": "res://assets/tools/handcuffs.png"},
	{"id": "rope",       "name": "绳索",     "icon": "res://assets/tools/rope.png"},
	{"id": "newspaper",  "name": "报纸",     "icon": "res://assets/tools/newspaper.png"},
	{"id": "plaster",    "name": "石膏粉",   "icon": "res://assets/tools/plaster.png"},
]

signal tool_activated(tool_id: String)          # 工具被选中
signal tool_completed(tool_id: String, target_id: String, result: String)  # 工具使用完成+结果
signal tool_cancelled()

var selected_tool_id: String = ""
var is_active: bool = false
var _buttons: Dictionary = {}                   # tool_id -> TextureButton
var _panel: PanelContainer
var _lens_overlay: Control                     # 放大镜镜头覆盖层
var _tape_overlay: Control                     # 卷尺拖拽层
var _interaction_popup: AcceptDialog           # 化学试剂/黄页弹窗
var _current_target_id: String = ""            # 当前操作的目标热点 ID

func _ready() -> void:
	layer = 128  # 在场景内容之上但低于最顶层弹窗
	_build_panel()
	_build_lens_overlay()
	_build_tape_overlay()
	_build_interaction_popup()
	hide()

# ==================== UI 构建（纯代码，无 .tscn 依赖）====================

func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.name = "ToolPanel"
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.11, 0.14, 0.94)
	style.border_width_left = 1; style.border_width_right = 1
	style.border_width_top = 1; style.border_width_bottom = 1
	style.border_color = Color(0.35, 0.32, 0.28, 0.9)
	style.set_corner_radius_all(10)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var hbox = HBoxContainer.new()
	hbox.name = "HBox"
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 8)
	_panel.add_child(hbox)

	for def in TOOL_DEFS:
		var btn := TextureButton.new()
		btn.name = "Btn_" + def["id"]
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn.custom_minimum_size = Vector2(48, 48)
		btn.tooltip_text = def["name"]
		if ResourceLoader.exists(def["icon"]):
			btn.texture_normal = load(def["icon"])
		else:
			# fallback: 用文字标签代替缺失图标
			var lbl := Label.new(); lbl.text = def["name"][0]; lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.add_theme_font_size_override("font_size", 18); btn.add_child(lbl)
		btn.pressed.connect(_on_tool_button_pressed.bind(def["id"]))
		_buttons[def["id"]] = btn
		hbox.add_child(btn)

	# 关闭按钮
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(28, 28)
	close_btn.pressed.connect(_cancel_tool)
	hbox.add_child(close_btn)

	# 面板定位：底部居中
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_top = -80
	_panel.offset_bottom = -16
	_panel.offset_left = 40
	_panel.offset_right = -40

func _build_lens_overlay() -> void:
	_lens_overlay = Control.new()
	_lens_overlay.name = "LensOverlay"
	_lens_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lens_overlay.z_index = 200
	_lens_overlay.hide()
	add_child(_lens_overlay)

	# 镜片圆环
	var ring := ColorRect.new()
	ring.name = "Ring"
	ring.size = Vector2(160, 160)
	var rs = StyleBoxFlat.new()
	rs.bg_color = Color(0, 0, 0, 0)
	rs.border_color = Color(0.78, 0.63, 0.29, 0.95)
	rs.border_width_left = 4; rs.border_width_right = 4
	rs.border_width_top = 4; rs.border_width_bottom = 4
	rs.set_corner_radius_all(80)
	ring.add_theme_stylebox_override("panel", rs)
	ring.position = Vector2(-80, -80)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lens_overlay.add_child(ring)

	# 玻璃区域（用于显示放大内容）
	var glass := TextureRect.new()
	glass.name = "Glass"
	glass.size = Vector2(148, 148)
	glass.position = Vector2(-74, -74)
	glass.stretch_mode = TextureRect.STRETCH_KEEPAspectCentered
	glass.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lens_overlay.add_child(glass)

	# 观察提示标签
	var hint := Label.new()
	hint.name = "HintLabel"
	hint.text = "移动镜片寻找细节..."
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	hint.position = Vector2(-70, 90)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lens_overlay.add_child(hint)

func _build_tape_overlay() -> void:
	_tape_overlay = Control.new()
	_tape_overlay.name = "TapeOverlay"
	_tape_overlay.mouse_filter = Control.MOUSE_FILTER_PASS
	_tape_overlay.z_index = 200
	_tape_overlay.hide()
	add_child(_tape_overlay)

	# 测量线
	var line := Line2D.new()
	line.name = "MeasureLine"
	line.width = 3
	line.default_color = Color(0.78, 0.63, 0.29)
	_tape_overlay.add_child(line)

	# 读数标签
	var lbl := Label.new()
	lbl.name = "MeasureLabel"
	lbl.text = "0.0 ft"
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	lbl.visible = false
	_tape_overlay.add_child(lbl)

	# 确认按钮
	var ok := Button.new()
	ok.name = "ConfirmBtn"
	ok.text = "确认测量"
	ok.visible = false
	ok.pressed.connect(_confirm_tape_measurement)
	_tape_overlay.add_child(ok)

func _build_interaction_popup() -> void:
	_interaction_popup = AcceptDialog.new()
	_interaction_popup.name = "ToolPopup"
	_interaction_popup.title = "工具操作"
	_interaction_popup.min_size = Vector2(340, 260)
	_interaction_popup.confirmed.connect(_on_popup_confirmed)
	_interaction_popup.canceled.connect(_on_popup_cancelled)
	add_child(_interaction_popup)

# ==================== 公开接口 ====================

func show_toolbar(target_hotspot_id: String = "") -> void:
	show()
	is_active = true
	_current_target_id = target_hotspot_id
	# 默认不选中任何工具，等玩家选择
	if selected_tool_id != "":
		_highlight_tool(selected_tool_id)

func hide_toolbar() -> void:
	hide()
	is_active = false
	selected_tool_id = ""
	_cancel_any_overlay()
	_highlight_tool("")  # 取消高亮

func set_target(target_id: String) -> void:
	_current_target_id = target_id

# ==================== 内部逻辑 ====================

func _on_tool_button_pressed(tool_id: String) -> void:
	if not ToolSystem.is_unlocked(tool_id):
		UIManager.show_notification("该工具尚未解锁")
		return

	selected_tool_id = tool_id
	_highlight_tool(tool_id)
	tool_activated.emit(tool_id)

	# 根据工具类型启动对应交互
	match tool_id:
		"magnifier":
			_start_magnifier()
		"tape":
			_start_tape()
		"chemistry":
			_show_chemistry_panel()
		"directory":
			_show_directory_panel()
		_:
			# 其他工具（手铐/绳索/报纸/石膏粉）：直接完成组合发现
			_complete_immediate(tool_id)

func _highlight_tool(tool_id: String) -> void:
	for tid in _buttons:
		var btn: TextureButton = _buttons[tid]
		if tid == tool_id:
			btn.modulate = Color(1.2, 1.1, 0.6)  # 金色高亮
		else:
			btn.modulate = Color(1, 1, 1)

# ---- 放大镜交互（§4.3.4：移动镜片发现细节）----

var _magnifier_timer: float = 0.0
const MAG_DISCOVER_TIME := 2.5  # 停留秒数触发发现

func _start_magnifier() -> void:
	_lens_overlay.show()
	_magnifier_timer = 0.0
	var glass: TextureRect = _lens_overlay.get_node_or_null("Glass")
	if glass: glass.texture = null  # 清空旧纹理
	var hint: Label = _lens_overlay.get_node_or_null("HintLabel")
	if hint: hint.text = "移动镜片寻找细节..."
	# 连接鼠标移动以跟随光标
	if not _lens_overlay.gui_input.is_connected(_on_lens_gui_input):
		_lens_overlay.gui_input.connect(_on_lens_gui_input)

func _on_lens_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_lens_overlay.position = event.position
		_magnifier_timer += get_process_delta_time()
		# 模拟"发现细节"：停留足够时间后触发
		if _magnifier_timer >= MAG_DISCOVER_TIME:
			_discover_with_magnifier()
	elif event is InputEventMouseButton and event.pressed:
		# 点击也触发发现（快捷方式）
		if _magnifier_timer > 0.5:
			_discover_with_magnifier()

func _discover_with_magnifier() -> void:
	_lens_overlay.hide()
	_lens_overlay.gui_input.disconnect(_on_lens_gui_input)
	var result := ""
	if ToolSystem:
		result = ToolSystem.use_tool_on("magnifier", _current_target_id)
	if result == "":
		result = "通过放大镜仔细观察了该区域，未发现异常特征。"
	tool_completed.emit("magnifier", _current_target_id, result)
	_show_observation_result("🔍 放大镜观察", result)
	selected_tool_id = ""

# ---- 卷尺交互（§4.3.4：拖拽测量读数）----

var _tape_start: Vector2 = Vector2.ZERO
var _tape_measuring: bool = false

func _start_tape() -> void:
	_tape_overlay.show()
	_tape_measuring = false
	_tape_start = Vector2.ZERO
	var line: Line2D = _tape_overlay.get_node_or_null("MeasureLine")
	if line: line.clear_points()
	var lbl: Label = _tape_overlay.get_node_or_null("MeasureLabel")
	if lbl: lbl.visible = false
	var ok: Button = _tape_overlay.get_node_or_null("ConfirmBtn")
	if ok: ok.visible = false
	if not _tape_overlay.gui_input.is_connected(_on_tape_gui_input):
		_tape_overlay.gui_input.connect(_on_tape_gui_input)
	UIManager.show_notification("点击起点开始测量")

func _on_tape_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var line: Line2D = _tape_overlay.get_node_or_null("MeasureLine")
		var lbl: Label = _tape_overlay.get_node_or_null("MeasureLabel")
		var ok: Button = _tape_overlay.get_node_or_null("ConfirmBtn")

		if not _tape_measuring:
			# 设起点
			_tape_start = event.position
			_tape_measuring = true
			if line: line.add_point(_tape_start)
			UIManager.show_notification("点击终点完成测量")
		else:
			# 设终点
			if line: line.add_point(event.position)
			var dist_px := _tape_start.distance_to(event.position)
			# 换算为英尺（假设 100px ≈ 1 英尺，游戏内合理比例）
			var dist_ft := dist_px / 100.0
			var dist_in := (dist_ft - int(dist_ft)) * 12.0
			if lbl:
				lbl.text = "%.1f ft (%.0f in)" % [dist_ft, dist_in]
				lbl.position = (_tape_start + event.position) / 2 - Vector2(40, 10)
				lbl.visible = true
			if ok:
				ok.position = (_tape_start + event.position) / 2 - Vector2(40, 30)
				ok.visible = true

func _confirm_tape_measurement() -> void:
	_tape_overlay.hide()
	_tape_overlay.gui_input.disconnect(_on_tape_gui_input)
	var result := ""
	if ToolSystem:
		result = ToolSystem.use_tool_on("tape", _current_target_id)
	if result == "":
		result = "测量完成，已记录距离数据。"
	tool_completed.emit("tape", _current_target_id, result)
	_show_observation_result("📏 测量记录", result)
	selected_tool_id = ""

# ---- 化学/黄页弹窗 ----

func _show_chemistry_panel() -> void:
	_interaction_popup.title = "🧪 化学试剂盒"
	var vb := VBoxContainer.new()
	vb.name = "Content"

	var lbl := Label.new()
	lbl.text = "选择检测试剂："
	vb.add_child(lbl)

	var reagents := ["血迹试剂", "粉末分析", "毒物检测"]
	for r in reagents:
		var rb := Button.new()
		rb.text = r
		rb.pressed.connect(_on_reagent_selected.bind(r))
		vb.add_child(rb)

	# 清除旧内容
	for c in _interaction_popup.get_children():
		if c.name != "OK" and c.name != "Cancel" and c.name != "Content":
			c.queue_free()
		if c.name == "Content":
			c.queue_free()
	_interaction_popup.add_child(vb)
	_interaction_popup.popup_centered()

func _on_reagent_selected(reagent: String) -> void:
	_interaction_popup.hide()
	var result := ""
	if ToolSystem:
		result = ToolSystem.use_tool_on("chemistry", _current_target_id)
	if result == "":
		result = "对 %s 进行 %s 分析中... 未检出异常反应。" % [_current_target_id, reagent]
	tool_completed.emit("chemistry", _current_target_id, result)
	_show_observation_result("🧪 化学分析", result)
	selected_tool_id = ""

func _show_directory_panel() -> void:
	_interaction_popup.title = "📖 黄页检索"
	var vb := VBoxContainer.new()
	vb.name = "Content"

	var lbl := Label.new()
	lbl.text = "输入检索关键词："
	vb.add_child(lbl)

	var le := LineEdit.new()
	le.name = "SearchInput"
	le.placeholder_text = "姓名 / 地址 / 职业..."
	vb.add_child(le)

	var search_btn := Button.new()
	search_btn.text = "检索"
	search_btn.pressed.connect(func():
		var kw := le.text.strip_edges()
		if kw.length() < 1: return
		_interaction_popup.hide()
		var result := ""
		if ToolSystem:
			result = ToolSystem.use_tool_on("directory", kw)
		if result == "":
			result = "在黄页中检索「%s」——未找到匹配条目。" % kw
		tool_completed.emit("directory", kw, result)
		_show_observation_result("📖 黄页检索", result)
		selected_tool_id = ""
	)
	vb.add_child(search_btn)

	for c in _interaction_popup.get_children():
		if c.name not in ["OK", "Cancel", "Content"]:
			c.queue_free()
		if c.name == "Content":
			c.queue_free()
	_interaction_popup.add_child(vb)
	_interaction_popup.popup_centered()

# ---- 其他工具直接完成 ----

func _complete_immediate(tool_id: String) -> void:
	var result := ""
	if ToolSystem:
		result = ToolSystem.use_tool_on(tool_id, _current_target_id)
	if result == "":
		result = "使用了 %s，无特殊发现。" % [TOOL_DEFS.find(func(d): return d["id"] == tool_id)["name"]]
	tool_completed.emit(tool_id, _current_target_id, result)
	_show_observation_result(TOOL_DEFS.find(func(d): return d["id"] == tool_id)["icon"] + " " + TOOL_DEFS.find(func(d): return d["id"] == tool_id)["name"], result)
	selected_tool_id = ""

# ---- 弹窗回调 ----

func _on_popup_confirmed() -> void:
	pass  # 由各面板自行处理

func _on_popup_cancelled() -> void:
	pass

# ---- 观察结果显示 ----

func _show_observation_result(title: String, text: String) -> void:
	# 通过 UIManager 显示观察结果通知（持久几秒）
	if UIManager:
		UIManager.show_notification("%s：%s" % [title, text], 6.0)
	# 同时写入 ClueSystem 作为观察记录（Step 3 数据记录的前置）
	if ClueSystem and _current_target_id != "":
		ClueSystem.collect_clue_from_catalog(
			"obs_%s_%s" % [selected_tool_id, _current_target_id],
			title,
			text,
			true,  # 观察默认为正确线索
			clue_source() if has_method("clue_source") else "default",
			2
		)

# ---- 取消/清理 ----

func _cancel_tool() -> void:
	_cancel_any_overlay()
	tool_cancelled.emit()
	selected_tool_id = ""
	_highlight_tool("")

func _cancel_any_overlay() -> void:
	_lens_overlay.hide()
	_tape_overlay.hide()
	_interaction_popup.hide()
	_magnifier_timer = 0.0
	_tape_measuring = false
