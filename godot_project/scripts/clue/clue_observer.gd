extends Node
class_name ClueObserver

const ClueImageAnchors = preload("res://data/clue_image_anchors.gd")
const ClueHighlightCircle = preload("res://scripts/ui/clue_highlight_circle.gd")

## 可复用的线索收集模块 — 封装热点创建、放大观察、记录确认全流程
## 场景一中华生和信使两轮观察共享同一套代码，只传入不同的热点数据和回调即可

# 热点定义: {"id":"wrist","label":"手腕肤色","x":550,"y":300,"w":120,"h":50,"desc":"...","correct":true}
# correct 字段可选，默认 true（华生场景所有线索都正确）
# silent 字段可选，默认 false；silent=true 表示「沉默线索」——可选发现，不计入场景完成条件
#   （见 02 §11 沉默线索 D1：自由探索发现，给洞察奖励，但不阻塞场景推进）

signal hotspot_clicked(clue_id: String)
signal clue_recorded(clue_id: String, clue_data: Dictionary)
signal all_recorded(clues: Array)  # 全部「必点」线索记录完毕（silent 线索不触发）

var _hotspots: Array = []           # 热点定义
var _btns: Array = []               # 按钮引用
var _recorded := 0                  # 已记录数（含 silent 可选线索）
var _required_total: int = 0        # 必点热点总数（排除 silent）
var _required_recorded: int = 0     # 已记录的必点热点数
var _recorded_clues: Array = []     # 已记录的线索数据
var _recorded_ids: Array = []       # 已记录的热点 ID，用于正确隐藏
var _active := false                # 是否处于观察模式
var _all_recorded_done := false     # all_recorded 是否已发射（防越过阈值后重复发射）
var _parent: Control
var _text_lbl: Label
var _speaker_lbl: Label
var _portrait_texture: Texture2D = null
var _portrait_ctrl: Control = null        # 对应角色立绘控件（圆圈叠加其上）
var _portrait_img_path: String = ""       # 立绘图的资源路径，用于查锚点算圆圈坐标

# 放大观察弹窗状态（Q4：点击部位 -> 弹放大图+底部说明文字 -> 再点/按键退出并才记录）
var _zoomed := false
var _zoom_popup: Control = null
var _zoom_clue_id := ""
var _zoom_desc := ""

func setup(parent: Control, text_lbl: Label, speaker_lbl: Label,
			hotspots: Array, portrait_tex: Texture2D = null,
			portrait_ctrl: Control = null, portrait_img_path: String = "") -> void:
	_parent = parent
	_text_lbl = text_lbl
	_speaker_lbl = speaker_lbl
	_hotspots = hotspots
	_portrait_texture = portrait_tex
	_portrait_ctrl = portrait_ctrl
	_portrait_img_path = portrait_img_path
	_create_buttons()
	# 计算必点总数（silent 线索不计入完成条件，仅作可选奖励）
	_required_total = 0
	for hs in _hotspots:
		if not hs.get("silent", false):
			_required_total += 1

## 热点按钮改为「透明点击区」：线索的视觉提示统一用「高亮圆圈」(_mark_clue_at_anchor)，
## 不再用文字按钮框（避免「先出文字框、点框才出圆圈」的误解）。按钮仅作为人物部位的命中区域。
## 圆圈按难度分级出现：简单=亮圈、普通=淡圈、困难=无（见 _draw_initial_hints / B-11.2）。
func _transparent_btn_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.set_corner_radius_all(6)
	return sb

## 是否处于「简单模式」：设计文档 B-11.2 简单模式 = 高亮可点击区域 + 自动展示推理。
## 简单模式下点击线索后自动显示观察推理文字（与圈定部位的高亮圆圈并存）；
## 普通/困难模式不自动显示文字，仅保留圆圈标记。
func _is_simple_mode() -> bool:
	return DifficultyManager != null and DifficultyManager.current_difficulty == DifficultyManager.Difficulty.EASY

func _create_buttons() -> void:
	# 热点按钮 = 透明点击区（仅命中人物部位，不显示任何文字/边框）；
	# 视觉提示改用「高亮圆圈」，在 show() 时按难度分级直接画到立绘上。
	var style := _transparent_btn_style()
	for hs in _hotspots:
		var btn = Button.new()
		btn.text = ""
		btn.flat = true
		btn.position = Vector2(hs["x"], hs["y"])
		btn.size = Vector2(hs["w"], hs["h"])
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("focus", style)
		btn.add_theme_stylebox_override("pressed", style)
		btn.visible = false
		btn.pressed.connect(_on_hotspot.bind(hs["id"], hs["desc"]))
		_parent.add_child(btn)
		_btns.append(btn)

func show() -> void:
	_active = true
	_all_recorded_done = false
	# 只显示尚未记录的热点：LOOK/放大镜会反复调用本方法，若把已记录热点也
	# 重新显示，玩家可重复记录同一线索 → 计数虚增、all_recorded 提前/重复触发。
	for i in _hotspots.size():
		if i < _btns.size():
			_btns[i].visible = not _recorded_ids.has(_hotspots[i]["id"])
	# 进入观察即按难度在立绘上画出高亮圆圈（简单=亮圈、普通=淡圈、困难=无），
	# 作为「这里有条线索」的提示，玩家点击高亮部位才弹放大图 + 说明文字。
	_draw_initial_hints()

func hide() -> void:
	_active = false
	# 关闭可能仍打开的放大图（如玩家在放大观察时打开了推理墙）
	_zoomed = false
	if _zoom_popup != null:
		_zoom_popup.queue_free()
		_zoom_popup = null
	for btn in _btns:
		btn.visible = false

func hide_button_by_id(clue_id: String) -> void:
	for i in _hotspots.size():
		if _hotspots[i]["id"] == clue_id and i < _btns.size():
			_btns[i].visible = false
			return

## 标记某条线索为已记录状态（用于存档恢复），隐藏按钮、登记 ID、递增计数器，
## 并重建线索数据写入 _recorded_clues，确保读档后推理墙能拿到完整线索（含 correct 标志）。
## 同时维护 _required_recorded（与正常记录路径一致，避免恢复后完成判定错位）。
func mark_recorded(clue_id: String) -> void:
	if _recorded_ids.has(clue_id): return
	_recorded_ids.append(clue_id)
	_recorded += 1
	for hs in _hotspots:
		if hs["id"] == clue_id:
			if not hs.get("silent", false):
				_required_recorded += 1
			break
	hide_button_by_id(clue_id)
	# 读档即显示：恢复存档时在立绘对应部位重绘高亮圆圈（与正常观察点击路径一致），
	# 确保玩家读档后立即可见「已收集线索标在人物哪」而不必重新点击。
	_mark_clue_at_anchor(clue_id)
	var hs_data: Dictionary = {"id": clue_id, "name": clue_id, "desc": "", "correct": true}
	for hs in _hotspots:
		if hs["id"] == clue_id:
			hs_data = {"id": hs["id"], "name": hs["label"], "desc": hs.get("desc", ""),
				"correct": hs.get("correct", true),
				"image": hs.get("image", ""), "anchor": hs.get("anchor", "")}
			break
	_recorded_clues.append(hs_data)

func is_active() -> bool:
	return _active

func get_recorded() -> int:
	# 保持原语义：返回「全部已记录数」（含 silent）。场景一用此值配硬编码阈值
	# (>=4 / >=6) 做完成判定，且全为非 silent 线索，语义不变。
	return _recorded

func get_required_recorded() -> int:
	return _required_recorded

func get_recorded_clues() -> Array:
	return _recorded_clues

func needs_count() -> int:
	# 返回「必点」线索总数（排除 silent 可选线索），供进度展示使用
	return _required_total

# ── 内部回调 ──

func _on_hotspot(clue_id: String, desc: String) -> void:
	if not _active: return
	# 放大图已打开时忽略后续点击，避免重复触发
	if _zoomed: return
	# 已记录过的线索不再响应（防重复记录）
	if _recorded_ids.has(clue_id): return
	hotspot_clicked.emit(clue_id)

	# 隐藏该热点按钮
	hide_button_by_id(clue_id)

	# Q4：先弹出该部位放大图 + 底部对话框给出说明文字；记录延后到玩家关闭放大图时
	_open_zoom(clue_id, desc)

## 在对应角色立绘的相关部位画一个高亮圆圈（替代原「文字 + 文本框 / 放大卡」）。
## 圆圈叠加在 _portrait_ctrl 之上，依据立绘 contain 显示区 + 锚点（基于立绘图本身）定位，
## 与显示缩放无关；低透明不拦截鼠标。
##   intensity=2（简单/已收集）：明亮烫金圈
##   intensity=1（普通提示）：半透明淡圈（仅提示可点击区域，玩家需自行辨认）
## 已存在同 id 圆圈则跳过（show() 提示 + close_zoom 收集 只画一次，避免叠加）。
func _mark_clue_at_anchor(clue_id: String, intensity: int = 2) -> void:
	if _portrait_ctrl == null or _portrait_img_path == "":
		return
	if _portrait_ctrl.has_node("hl_" + clue_id):
		return
	# 取该线索的锚点名称
	var anchor_name: String = ""
	for hs in _hotspots:
		if hs["id"] == clue_id:
			anchor_name = hs.get("anchor", "")
			break
	var a: Dictionary = ClueImageAnchors.get_anchor(_portrait_img_path, anchor_name)
	if a.is_empty():
		return
	var tex: Texture2D = load(_portrait_img_path)
	if tex == null:
		return
	# 与 _make_portrait 一致的 contain 显示区（局部于立绘控件坐标系）
	var tw := float(tex.get_width())
	var th := float(tex.get_height())
	var box := _portrait_ctrl.size - Vector2(12, 12)
	var sc: float = min(box.x / tw, box.y / th)
	var dw: float = tw * sc
	var dh: float = th * sc
	var img_pos := Vector2(6, 6) + (box - Vector2(dw, dh)) * 0.5
	var img_size := Vector2(dw, dh)
	# 锚点中心映射到显示区（局部坐标）
	var cx := img_pos.x + float(a["cx"]) * img_size.x
	var cy := img_pos.y + float(a["cy"]) * img_size.y
	# 圆圈半径：覆盖锚点框（取显示区上半宽/半高最大值，略留白）
	var rx := float(a["w"]) * img_size.x * 0.5
	var ry := float(a["h"]) * img_size.y * 0.5
	var r: float = max(rx, ry) * 1.12
	var col := Color(0.98, 0.82, 0.30, 1.0) if intensity >= 2 else Color(0.98, 0.82, 0.30, 0.5)
	var circle = ClueHighlightCircle.new()
	circle.setup(Vector2(cx, cy), r, col)
	circle.name = "hl_" + clue_id
	_portrait_ctrl.add_child(circle)

## 进入观察时按难度在立绘上画初始高亮圆圈（提示「这里有条线索」）。
## 简单(2)=亮圈 / 普通(1)=淡圈 / 困难(0)=无提示（玩家自行找部位点击）。
## 已记录的线索与已画圆圈跳过，避免重复。
func _draw_initial_hints() -> void:
	var lvl := 0
	if DifficultyManager != null:
		lvl = DifficultyManager.hotspot_hint_level
	if lvl <= 0:
		return
	for hs in _hotspots:
		var cid = hs["id"]
		if _recorded_ids.has(cid):
			continue
		if _portrait_ctrl != null and _portrait_ctrl.has_node("hl_" + cid):
			continue
		_mark_clue_at_anchor(cid, lvl)


## 点击线索部位后弹出该部位放大图（整图 + 金框标出锚点区域，等比 contain 居中放大），
## 同时底部对话框给出该线索的说明文字。玩家再次点击画面任意处 / 按 Enter/Space/Esc 关闭放大图，
## 关闭时才把该线索正式记入推理墙（Q4 确认：记录发生在「退出放大图」时刻，而非点开时刻）。
## 所有难度都弹放大图 + 展示说明文字（那是观察结果，不是提示；提示仅指「难度分级的部位高亮」）。
func _open_zoom(clue_id: String, desc: String) -> void:
	if _zoomed: return
	_zoomed = true
	_zoom_clue_id = clue_id
	_zoom_desc = desc
	var hs_d: Dictionary = {}
	for hs in _hotspots:
		if hs["id"] == clue_id:
			hs_d = hs
			break
	var img_path: String = hs_d.get("image", "")
	var anchor_name: String = hs_d.get("anchor", "")
	var title: String = hs_d.get("label", clue_id)

	# 放大图遮罩层：FULL_RECT 覆盖整个游玩区（对话栏 z_index=150 在其之上，保持可见）
	var popup := Control.new()
	popup.name = "zoom_popup"
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.03, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.add_child(dim)

	# 部位放大图：AtlasTexture 截取锚点区域，等比 contain 居中放大（Godot 4.7 用 expand_mode=2 = contain）
	if img_path != "" and ResourceLoader.exists(img_path) and anchor_name != "":
		var tex: Texture2D = load(img_path)
		var a: Dictionary = ClueImageAnchors.get_anchor(img_path, anchor_name)
		if tex != null and not a.is_empty():
			var tw := float(tex.get_width()); var th := float(tex.get_height())
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2((float(a["cx"]) - float(a["w"]) / 2.0) * tw,
							  (float(a["cy"]) - float(a["h"]) / 2.0) * th,
							  float(a["w"]) * tw, float(a["h"]) * th)
			var side: float = min(get_viewport().size.x * 0.42, 760.0)
			var img := TextureRect.new()
			img.texture = at
			img.expand_mode = 2
			img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			img.size = Vector2(side, side)
			img.position = Vector2((get_viewport().size.x - side) / 2.0, 410.0 - side / 2.0)
			img.mouse_filter = Control.MOUSE_FILTER_IGNORE
			popup.add_child(img)
			# 金框包住放大图
			var frame := Panel.new()
			frame.position = img.position - Vector2(4, 4)
			frame.size = img.size + Vector2(8, 8)
			var fsb := StyleBoxFlat.new()
			fsb.bg_color = Color(0, 0, 0, 0)
			fsb.border_color = Color(0.95, 0.80, 0.35, 1)
			fsb.border_width_left = 3; fsb.border_width_right = 3
			fsb.border_width_top = 3; fsb.border_width_bottom = 3
			fsb.set_corner_radius_all(8)
			frame.add_theme_stylebox_override("panel", fsb)
			frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
			popup.add_child(frame)

	# 顶部标题
	var lab := Label.new()
	lab.text = "🔍 " + title
	lab.add_theme_font_size_override("font_size", 26)
	lab.add_theme_color_override("font_color", Color(0.95, 0.82, 0.45))
	lab.position = Vector2(0, 24)
	lab.size = Vector2(get_viewport().size.x, 40)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.add_child(lab)
	# 底部提示
	var hint := Label.new()
	hint.text = "（点击任意处 / 按 Enter 关闭，并记录此线索）"
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.7, 0.66, 0.55))
	hint.position = Vector2(0, 800)
	hint.size = Vector2(get_viewport().size.x, 30)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.add_child(hint)

	popup.gui_input.connect(_on_zoom_input)
	(_parent if _parent else get_tree().current_scene).add_child(popup)
	_zoom_popup = popup
	# 抢焦点以捕获键盘 Enter/Space/Esc
	popup.grab_focus()

	# 底部对话框给出说明文字（所有难度都展示——这是观察结果，不是提示）
	if _speaker_lbl != null:
		_speaker_lbl.text = "福尔摩斯"
	_text_lbl.text = desc

## 放大图输入处理：再次点击画面 / 按 Enter/Space/Esc/E 关闭并记录
func _on_zoom_input(event: InputEvent) -> void:
	if not _zoomed: return
	var close := false
	if event is InputEventMouseButton and event.pressed:
		close = true
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_SPACE or event.keycode == KEY_ESCAPE or event.keycode == KEY_E:
			close = true
	if close:
		_close_zoom()

## 关闭放大图：在部位画高亮圆圈（标记已收集），并正式记录线索到推理墙
func _close_zoom() -> void:
	if not _zoomed: return
	_zoomed = false
	var cid := _zoom_clue_id
	var desc := _zoom_desc
	if _zoom_popup != null:
		_zoom_popup.queue_free()
		_zoom_popup = null
	# 在部位画高亮圆圈（标记已收集，与读档恢复行为一致），并正式记录
	_mark_clue_at_anchor(cid)
	_record(cid, desc)

func _record(clue_id: String, desc: String) -> void:
	# 去重守卫：同一线索绝不重复计数（重复会导致 _recorded 虚增、
	# all_recorded 提前触发或重复触发，破坏场景阶段推进）
	if _recorded_ids.has(clue_id):
		return
	_recorded += 1

	# 查找热点数据
	var hs_data: Dictionary = {"id": clue_id, "name": clue_id, "desc": desc, "correct": true}
	for hs in _hotspots:
		if hs["id"] == clue_id:
			hs_data = {"id": hs["id"], "name": hs["label"], "desc": hs.get("desc", ""),
				"correct": hs.get("correct", true),
				"image": hs.get("image", ""), "anchor": hs.get("anchor", "")}
			break

	_recorded_clues.append(hs_data)
	_recorded_ids.append(clue_id)
	clue_recorded.emit(clue_id, hs_data)

	# 维护必点计数（silent 线索不计入完成条件）
	var rec_silent := false
	for hs in _hotspots:
		if hs["id"] == clue_id:
			rec_silent = hs.get("silent", false)
			break
	if not rec_silent:
		_required_recorded += 1

	# 底部文字：进度只统计必点线索；沉默线索为额外奖励，不计入分母。
	var parts = {0:"第一",1:"第二",2:"第三",3:"第四",4:"第五",5:"第六"}
	var progress := "线索已记录！%s条线索 (%d/%d)" % [parts.get(_recorded-1, ""), _required_recorded, _required_total]
	# 简单模式（设计文档 B-11.2「自动展示推理 / 对话细节补充=全部」）：点击后自动展示该线索的
	# 观察推理文字，与「圈定人物相关部位的高亮圆圈」并存，对应「高亮可点击区域 + 自动展示推理」。
	# 普通/困难模式不自动展示文字（玩家自行观察 / 无提示），仅保留圆圈标记。
	if _is_simple_mode():
		if _speaker_lbl != null:
			_speaker_lbl.text = "福尔摩斯"
		_text_lbl.text = "%s\n—— 已记录 %d/%d 条线索" % [desc, _required_recorded, _required_total]
	else:
		_text_lbl.text = progress
		if _speaker_lbl != null:
			_speaker_lbl.text = ""

	# 完成判定基于「必点」线索：silent 未点也能推进场景
	# 守卫：all_recorded 只在「跨过阈值」时发射一次；越过后再记录新必点线索不重复发射
	if not _all_recorded_done and _required_recorded >= _required_total:
		_all_recorded_done = true
		_active = false
		all_recorded.emit(_recorded_clues)
	else:
		# 继续显示未记录的热点
		for i in _hotspots.size():
			if i >= _btns.size(): continue
			_btns[i].visible = not _recorded_ids.has(_hotspots[i]["id"])
