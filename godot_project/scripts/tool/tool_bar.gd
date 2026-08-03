extends Control
class_name ToolBar

const ClueImageAnchors = preload("res://data/clue_image_anchors.gd")
const _WindowDrag = preload("res://scripts/ui/window_drag.gd")

## ToolBar v2 — 侦探工具栏（根节点为 Control，挂到任意场景）
##
## 按 §4.3.4 实现真实主动操作：
##   放大镜：移动镜片发现细节  |  卷尺：拖拽测量读数
##   化学试剂盒/黄页等：弹出交互面板
##
## 使用方式：在 DetectiveScene._build_ui() 中实例化并 add_child。
##   var tb = ToolBar.new(); add_child(tb)
##   tb.tool_activated.connect(_on_tool_activated)
##
## 关键（2026-08-02 钉死，已 headless 诊断实测验证）：
##   根节点必须是标准 `Control` + 铺满全屏 `mouse_filter=IGNORE`。
##   - IGNORE 只跳过自身命中，不阻止子 `Control(STOP)` 接收点击；
##     子 STOP 按钮在命中栈首位，图标可正常点击（旧传言"IGNORE 吞子按钮"已被证伪）。
##   - 切忌改 `extends Node` 根 + 面板 `z_index=150`：该非标准组合在 Web 运行时
##     输入命中异常，导致图标点不动（这是最初 bug 的真实根因，已修）。
##   - Node 根无 `show()/hide()`；用子 `_panel.visible` 控制显隐。

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
var _magnifier_active: bool = false            # 放大镜交互进行中（由 _input 驱动）
var _buttons: Dictionary = {}                   # tool_id -> TextureButton
var _panel: PanelContainer
var _lens_overlay: Control                     # 放大镜镜头覆盖层
var _tape_overlay: Control                     # 卷尺拖拽层
var _interaction_popup: AcceptDialog           # 化学试剂/黄页弹窗
var _current_target_id: String = ""            # 当前操作的目标热点 ID

func _ready() -> void:
	# 根节点为标准 Control，铺满全屏但 mouse_filter=IGNORE：
	#   - IGNORE 只跳过自身命中，不阻止子 Control(STOP) 接收点击（已实测验证）；
	#   - 铺满全屏只是作为定位容器，让内部面板的 PRESET_CENTER_BOTTOM 能基于正确父尺寸计算；
	#   - 子面板(mouse_filter=STOP) 在工具栏区域正常接收点击，按钮优先于面板。
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_panel()
	_build_lens_overlay()
	_build_tape_overlay()
	_build_interaction_popup()
	_set_toolbar_visible(false)

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

	# PanelContainer 只允许一个子节点 → 用 VBox 再分「标题条(拖拽手柄) + 按钮行」，
	# 二者纵向堆叠、互不重叠。切勿把拖拽手柄直接加进 PanelContainer 当第二子节点：
	# Godot 会把多子节点都撑满面板，导致手柄盖住按钮、吞掉所有点击（初版 bug 根因）。
	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 4)
	_panel.add_child(vbox)

	# 拖拽手柄：仅顶部标题条作拖拽区，绝不覆盖下方按钮行（2026-07-02 实测：
	# 手柄铺满面板会拦截全部按钮按下事件 → 工具栏能拖动但图标点不动）。
	var tb_drag := Control.new()
	tb_drag.name = "TbDragHandle"
	tb_drag.custom_minimum_size = Vector2(0, 24)
	tb_drag.mouse_filter = Control.MOUSE_FILTER_PASS   # make_draggable 内部会置为 STOP
	vbox.add_child(tb_drag)
	var title_lbl := Label.new()
	title_lbl.text = "🔧 工具栏"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 13)
	title_lbl.add_theme_color_override("font_color", Color(0.85, 0.80, 0.65))
	title_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	tb_drag.add_child(title_lbl)

	var hbox := HBoxContainer.new()
	hbox.name = "HBox"
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 8)
	hbox.add_theme_constant_override("margin_left", 10)
	hbox.add_theme_constant_override("margin_right", 10)
	hbox.add_theme_constant_override("margin_top", 4)
	hbox.add_theme_constant_override("margin_bottom", 6)
	vbox.add_child(hbox)

	for def in TOOL_DEFS:
		var btn := TextureButton.new()
		btn.name = "Btn_" + def["id"]
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn.custom_minimum_size = Vector2(48, 48)
		btn.ignore_texture_size = true   # 关键：不让 256x256 贴图把按钮撑大到 256，否则工具条超高、底部越界
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

	# 面板定位：底部居中。加高以容纳标题条(24) + 按钮行(48) + 内边距。
	# 抬到对话栏（_dialogue_bar，占 y=850~1080，DIALOGUE_H=230）之上（y≈742~838）避免被盖住。
	_panel.z_index = 150  # 高于 SceneFramework 对话栏，保证画在最上层且可点击
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_panel.offset_left = 0
	_panel.offset_right = 0
	_panel.offset_top = -338
	_panel.offset_bottom = -242

	_WindowDrag.make_draggable(_panel, tb_drag)

func _build_lens_overlay() -> void:
	_lens_overlay = Control.new()
	_lens_overlay.name = "LensOverlay"
	_lens_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lens_overlay.z_index = 200
	_lens_overlay.visible = false
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
	glass.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
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
	_tape_overlay.visible = false
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

## 给 AcceptDialog 弹窗加拖拽（标题栏区域作手柄）
func _make_popup_draggable(popup: AcceptDialog) -> void:
	# 等待一帧让弹窗布局完成
	await get_tree().process_frame
	# 找标题 Label 作排除区（关闭按钮不触发拖拽）
	var title_lbl: Control = null
	for c in popup.get_children():
		if c is Label:
			title_lbl = c
			break
	var drag_h := Control.new()
	drag_h.name = "PopupDrag"
	drag_h.custom_minimum_size = Vector2(200, 32)
	drag_h.mouse_filter = Control.MOUSE_FILTER_PASS
	popup.add_child(drag_h)
	# 把拖拽手柄移到最底层（覆盖标题区）
	popup.move_child(drag_h, 0)
	var exclude: Array[Control] = []
	# 排除标题文字和按钮（让它们保持可点击/可选）
	if title_lbl:
		exclude.append(title_lbl)
	for c in popup.get_children():
		if c is Button:
			exclude.append(c)
	_WindowDrag.make_draggable(popup, drag_h, exclude)

# ==================== 公开接口 ====================

func _set_toolbar_visible(v: bool) -> void:
	is_active = v
	if _panel:
		_panel.visible = v

func show_toolbar(target_hotspot_id: String = "") -> void:
	_set_toolbar_visible(true)
	_current_target_id = target_hotspot_id
	# 默认不选中任何工具，等玩家选择
	if selected_tool_id != "":
		_highlight_tool(selected_tool_id)
	# 提示：当前线索可用哪些道具（微亮）
	if _current_target_id != "":
		_highlight_applicable_tools(_current_target_id)

func hide_toolbar() -> void:
	_set_toolbar_visible(false)
	selected_tool_id = ""
	_cancel_any_overlay()
	_highlight_tool("")  # 取消高亮

func set_target(target_id: String) -> void:
	_current_target_id = target_id
	_highlight_applicable_tools(target_id)

# ==================== 内部逻辑 ====================

func _on_tool_button_pressed(tool_id: String) -> void:
	if not ToolSystem.is_unlocked(tool_id):
		UIManager.show_notification("该工具尚未解锁")
		return

	# 同一工具再点 = 关闭当前交互（点一次出现，再点一次关闭）
	if selected_tool_id == tool_id and _is_overlay_active():
		_cancel_tool()
		return

	selected_tool_id = tool_id
	_highlight_tool(tool_id)
	tool_activated.emit(tool_id)

	# 切换到非放大镜工具时，先收起放大镜交互（避免镜片残留跟随）
	if _magnifier_active and tool_id != "magnifier":
		_magnifier_active = false
		_lens_overlay.hide()

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

## 微亮提示：当前线索可用哪些道具（有线索↔道具关联的工具按钮调亮）
func _highlight_applicable_tools(clue_id: String) -> void:
	if not ToolSystem:
		return
	for tid in _buttons:
		var btn: TextureButton = _buttons[tid]
		var rev: Dictionary = ToolSystem.get_clue_tool_reveal(clue_id, tid)
		if not rev.is_empty():
			btn.modulate = Color(1.0, 1.15, 0.9)
		else:
			btn.modulate = Color(1, 1, 1)

## 当前是否有交互覆盖层处于显示中（放大镜/卷尺/弹窗）。
func _is_overlay_active() -> bool:
	return (_lens_overlay and _lens_overlay.visible) \
		or (_tape_overlay and _tape_overlay.visible) \
		or (_interaction_popup and _interaction_popup.visible)

# ---- 放大镜交互（§4.3.4：移动镜片发现细节）----

var _magnifier_timer: float = 0.0
const MAG_DISCOVER_TIME := 2.5  # 停留秒数触发发现

func _start_magnifier() -> void:
	_lens_overlay.visible = true
	_magnifier_timer = 0.0
	var glass: TextureRect = _lens_overlay.get_node_or_null("Glass")
	if glass: glass.texture = null  # 清空旧纹理
	var hint: Label = _lens_overlay.get_node_or_null("HintLabel")
	if hint: hint.text = "移动镜片寻找细节..."
	# 镜片跟随与发现改由 ToolBar._input 驱动（镜头层 mouse_filter=IGNORE 收不到 gui_input）。
	_magnifier_active = true

## 放大镜交互由 _input 驱动：镜头层为 mouse_filter=IGNORE（不挡热点点击），
## 故不能靠自身 gui_input，改为在 ToolBar 节点上接收全局输入并跟随光标。
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

## 放大镜的全局输入入口：镜头层 mouse_filter=IGNORE 无法接收 gui_input，
## 故在此跟随光标并判定发现。不 consume 事件，热点点击仍会下发到观察器。
func _input(event: InputEvent) -> void:
	if not _magnifier_active:
		return
	if event is InputEventMouseMotion:
		_lens_overlay.position = event.position
		_magnifier_timer += get_process_delta_time()
		if _magnifier_timer >= MAG_DISCOVER_TIME:
			_discover_with_magnifier()
	elif event is InputEventMouseButton and event.pressed:
		if _magnifier_timer > 0.5:
			_discover_with_magnifier()

## 取当前观察线索对某道具的关联 reveal（来自 ToolSystem.get_clue_tool_reveal）。
## 无关联（或当前无目标线索）返回空字典，调用方走通用兜底。
func _clue_reveal_for(tool_id: String) -> Dictionary:
	if ToolSystem and _current_target_id != "":
		return ToolSystem.get_clue_tool_reveal(_current_target_id, tool_id)
	return {}

func _discover_with_magnifier() -> void:
	_lens_overlay.visible = false
	_magnifier_active = false
	if _lens_overlay.gui_input.is_connected(_on_lens_gui_input):
		_lens_overlay.gui_input.disconnect(_on_lens_gui_input)
	# 关联线索的「放大镜看图片」：打开图片查看器而非通用无发现
	var rev: Dictionary = _clue_reveal_for("magnifier")
	if not rev.is_empty() and rev.get("kind", "") == "image":
		selected_tool_id = ""
		_show_clue_image_viewer(rev)
		return
	var result := ""
	if ToolSystem:
		result = ToolSystem.use_tool_on("magnifier", _current_target_id)
	if result == "":
		result = "通过放大镜仔细观察了该区域，未发现异常特征。"
	tool_completed.emit("magnifier", _current_target_id, result)
	_show_observation_result("🔍 放大镜观察", result)
	selected_tool_id = ""

# ---- 放大镜：线索图片查看器（kind=="image" 关联时启用）----

func _show_clue_image_viewer(rev: Dictionary) -> void:
	_clear_clue_viewer()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.name = "ClueImgDim"
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var img_path: String = rev.get("image", "")
	var tex: Texture2D = null
	if img_path != "" and ResourceLoader.exists(img_path):
		tex = load(img_path)
	var img := TextureRect.new()
	img.name = "ClueImg"
	img.texture = tex
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.position = Vector2(360, 90)
	img.size = Vector2(560, 560)
	add_child(img)

	var crop: Dictionary = rev.get("crop", {})
	# 优先用统一锚点表（reveal 里写 "anchor" 名称），缺失则回退手工 crop
	var anchor_name: String = rev.get("anchor", "")
	var anchor: Dictionary = {}
	if anchor_name != "" and img_path != "":
		anchor = ClueImageAnchors.get_anchor(img_path, anchor_name)
	if not anchor.is_empty() and tex != null:
		_add_clue_anchor_marker(Vector2(360, 90), Vector2(560, 560), tex, anchor, rev.get("title", ""))
	elif not crop.is_empty() and tex != null:
		var hr := ColorRect.new()
		hr.name = "ClueImgCrop"
		hr.color = Color(0, 0, 0, 0)
		var hs := StyleBoxFlat.new()
		hs.border_color = Color(0.95, 0.80, 0.35, 1)
		hs.border_width_left = 3; hs.border_width_right = 3
		hs.border_width_top = 3; hs.border_width_bottom = 3
		hs.set_corner_radius_all(6)
		hr.add_theme_stylebox_override("panel", hs)
		hr.position = Vector2(360 + float(crop.get("x", 0)) * 560, 90 + float(crop.get("y", 0)) * 560)
		hr.size = Vector2((float(crop.get("cx", 1)) - float(crop.get("x", 0))) * 560,
		                  (float(crop.get("cy", 1)) - float(crop.get("y", 0))) * 560)
		add_child(hr)

	var title := Label.new()
	title.name = "ClueImgTitle"
	title.text = "🔍 " + rev.get("title", "")
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.92, 0.84, 0.55))
	title.position = Vector2(360, 56)
	title.size = Vector2(820, 40)
	add_child(title)

	var cap := Label.new()
	cap.name = "ClueImgCap"
	cap.text = rev.get("detail", "")
	cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cap.add_theme_font_size_override("font_size", 16)
	cap.add_theme_color_override("font_color", Color(0.82, 0.80, 0.70))
	cap.position = Vector2(960, 110)
	cap.size = Vector2(720, 280)
	add_child(cap)

	var rec := Button.new()
	rec.name = "ClueImgRec"
	rec.text = "记录线索"
	rec.position = Vector2(960, 410)
	rec.size = Vector2(220, 52)
	rec.add_theme_font_size_override("font_size", 20)
	rec.add_theme_color_override("font_color", Color(0.92, 0.84, 0.55))
	var rsb := StyleBoxFlat.new()
	rsb.bg_color = Color(0.45, 0.10, 0.10, 0.95)
	rsb.border_color = Color(0.85, 0.65, 0.25)
	rsb.border_width_left = 2; rsb.border_width_right = 2
	rsb.border_width_top = 2; rsb.border_width_bottom = 2
	rsb.set_corner_radius_all(4)
	rec.add_theme_stylebox_override("normal", rsb)
	rec.pressed.connect(func(): _on_clue_viewer_record(rev))
	add_child(rec)

	var close := Button.new()
	close.name = "ClueImgClose"
	close.text = "✕"
	close.position = Vector2(1660, 56)
	close.size = Vector2(40, 40)
	close.pressed.connect(_clear_clue_viewer)
	add_child(close)

func _on_clue_viewer_record(rev: Dictionary) -> void:
	var detail: String = rev.get("detail", "")
	tool_completed.emit("magnifier", _current_target_id, detail)
	_show_observation_result("🔍 放大镜观察：" + rev.get("title", ""), detail)
	_clear_clue_viewer()
	selected_tool_id = ""

## 在图片查看器里按锚点画金框 + 标签（考虑 KEEP_ASPECT_CENTERED 留边，像素级准确）
func _add_clue_anchor_marker(img_pos: Vector2, img_size: Vector2, tex: Texture2D, anchor: Dictionary, label: String) -> void:
	var tw: float = float(tex.get_width())
	var th: float = float(tex.get_height())
	var s: float = min(img_size.x / tw, img_size.y / th)
	var dw: float = tw * s
	var dh: float = th * s
	var dr_x: float = img_pos.x + (img_size.x - dw) / 2.0
	var dr_y: float = img_pos.y + (img_size.y - dh) / 2.0
	var cx: float = dr_x + float(anchor["cx"]) * dw
	var cy: float = dr_y + float(anchor["cy"]) * dh
	var bw: float = float(anchor["w"]) * dw
	var bh: float = float(anchor["h"]) * dh
	var hr := ColorRect.new()
	hr.name = "ClueImgCrop"
	hr.color = Color(0, 0, 0, 0)
	var hs := StyleBoxFlat.new()
	hs.border_color = Color(0.95, 0.80, 0.35, 1)
	hs.border_width_left = 3; hs.border_width_right = 3
	hs.border_width_top = 3; hs.border_width_bottom = 3
	hs.set_corner_radius_all(6)
	hr.add_theme_stylebox_override("panel", hs)
	hr.position = Vector2(cx - bw / 2.0, cy - bh / 2.0)
	hr.size = Vector2(bw, bh)
	add_child(hr)
	var lab := Label.new()
	lab.name = "ClueImgCropLabel"
	lab.text = "📍 " + label
	lab.add_theme_font_size_override("font_size", 15)
	lab.add_theme_color_override("font_color", Color(0.98, 0.88, 0.5))
	lab.position = Vector2(cx - bw / 2.0, cy - bh / 2.0 - 26)
	lab.size = Vector2(max(bw, 200), 24)
	add_child(lab)

func _clear_clue_viewer() -> void:
	for n in ["ClueImgDim", "ClueImg", "ClueImgCrop", "ClueImgCropLabel", "ClueImgTitle", "ClueImgCap", "ClueImgRec", "ClueImgClose"]:
		var node = get_node_or_null(n)
		if node:
			node.queue_free()

# ---- 卷尺交互（§4.3.4：拖拽测量读数）----

var _tape_start: Vector2 = Vector2.ZERO
var _tape_measuring: bool = false

func _start_tape() -> void:
	_tape_overlay.visible = true
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
	_tape_overlay.visible = false
	_tape_overlay.gui_input.disconnect(_on_tape_gui_input)
	# 关联线索的「卷尺测量」：直接显示测量读数，无需拖拽
	var rev: Dictionary = _clue_reveal_for("tape")
	if not rev.is_empty() and rev.get("kind", "") == "measure":
		var val: String = rev.get("value", "")
		var txt := "测量读数 %s：%s" % [val, rev.get("detail", "")]
		tool_completed.emit("tape", _current_target_id, txt)
		_show_observation_result("📏 卷尺测量：" + rev.get("title", ""), txt)
		selected_tool_id = ""
		return
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
	_make_popup_draggable(_interaction_popup)

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
	# 关联线索的「黄页查阅地址」：直接显示登记结果，无需手输关键词
	var rev: Dictionary = _clue_reveal_for("directory")
	if not rev.is_empty() and rev.get("kind", "") == "directory":
		_show_directory_result(rev)
		return
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
	_make_popup_draggable(_interaction_popup)

## 关联线索的「黄页查阅地址」结果面板（kind=="directory" 关联时启用）
func _show_directory_result(rev: Dictionary) -> void:
	_interaction_popup.title = "📖 " + rev.get("title", "")
	var vb := VBoxContainer.new()
	vb.name = "Content"
	var lbl := Label.new()
	lbl.text = rev.get("result", "")
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(lbl)
	var det := Label.new()
	det.text = rev.get("detail", "")
	det.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(det)
	for c in _interaction_popup.get_children():
		if c.name != "OK" and c.name != "Cancel" and c.name != "Content":
			c.queue_free()
		if c.name == "Content":
			c.queue_free()
	_interaction_popup.add_child(vb)
	_interaction_popup.popup_centered()
	_make_popup_draggable(_interaction_popup)
	var txt: String = rev.get("result", "")
	tool_completed.emit("directory", _current_target_id, txt)
	_show_observation_result("📖 黄页检索：" + rev.get("title", ""), txt)
	selected_tool_id = ""

# ---- 其他工具直接完成 ----

func _tool_def(tool_id: String) -> Dictionary:
	var idx = TOOL_DEFS.find(func(d): return d["id"] == tool_id)
	if idx >= 0:
		return TOOL_DEFS[idx]
	return {}

func _complete_immediate(tool_id: String) -> void:
	var result := ""
	if ToolSystem:
		result = ToolSystem.use_tool_on(tool_id, _current_target_id)
	var def = _tool_def(tool_id)
	if result == "":
		result = "使用了 %s，无特殊发现。" % def.get("name", tool_id)
	tool_completed.emit(tool_id, _current_target_id, result)
	_show_observation_result("%s %s" % [def.get("icon", ""), def.get("name", tool_id)], result)
	selected_tool_id = ""

# ---- 弹窗回调 ----

func _on_popup_confirmed() -> void:
	pass  # 由各面板自行处理

func _on_popup_cancelled() -> void:
	pass

# ---- 观察结果显示 ----

## 取当前场景的线索来源名（garden/indoor/scene5...）。
## ToolBar 是独立 Control 节点，自身无 clue_source()，需经当前场景转发。
func _current_clue_source() -> String:
	var sc = get_tree().current_scene
	if sc and sc.has_method("clue_source"):
		return sc.clue_source()
	return "default"

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
			_current_clue_source(),
			2
		)

# ---- 取消/清理 ----

func _cancel_tool() -> void:
	_cancel_any_overlay()
	tool_cancelled.emit()
	selected_tool_id = ""
	_highlight_tool("")

func _cancel_any_overlay() -> void:
	if _lens_overlay:
		_lens_overlay.visible = false
	if _tape_overlay:
		_tape_overlay.visible = false
	if _interaction_popup:
		_interaction_popup.hide()
	_magnifier_timer = 0.0
	_magnifier_active = false
	_tape_measuring = false
