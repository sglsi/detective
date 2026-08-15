extends Node
class_name ClueObserver

const ClueImageAnchors = preload("res://data/clue_image_anchors.gd")
const ClueHighlightCircle = preload("res://scripts/ui/clue_highlight_circle.gd")
const CLUE_HINT_RADIUS: float = 26.0   # 线索提示圆圈统一半径（与锚点框大小无关，仅作提示，避免大小不一）

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
# M2.x：摄像机世界层（地点类线索命中区/提示圈挂此，随缩放平移变换）与
# 「场景根→世界局部」偏移（=_scene_area.position），用于坐标换算。
var _world_layer: Control = null
var _world_offset: Vector2 = Vector2.ZERO

# 放大观察弹窗状态（Q4：点击部位 -> 弹放大图+底部说明文字 -> 再点/按键退出并才记录）
var _zoomed := false
var _zoom_popup: Control = null
var _zoom_clue_id := ""
var _zoom_desc := ""

func setup(parent: Control, text_lbl: Label, speaker_lbl: Label,
			hotspots: Array, portrait_tex: Texture2D = null,
			portrait_ctrl: Control = null, portrait_img_path: String = "",
			world_layer: Control = null, world_offset: Vector2 = Vector2.ZERO) -> void:
	_parent = parent
	_text_lbl = text_lbl
	_speaker_lbl = speaker_lbl
	_hotspots = hotspots
	_portrait_texture = portrait_tex
	_portrait_ctrl = portrait_ctrl
	_portrait_img_path = portrait_img_path
	_world_layer = world_layer
	_world_offset = world_offset
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
	# 可点击命中区与「高亮圆圈」同处立绘控件(_portrait_ctrl)之上、用同一锚点数学定位，
	# 让玩家点击圆圈（人物部位）即触发观察 —— 解决此前「圆圈在立绘、命中区在视口别处」的错位。
	# 按钮透明无文字，仅作命中区域；视觉提示统一交给圆圈。无立绘锚点时退化为视口坐标按钮。
	var style := _transparent_btn_style()
	for hs in _hotspots:
		var btn = Button.new()
		btn.text = ""
		btn.flat = true
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("focus", style)
		btn.add_theme_stylebox_override("pressed", style)
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.visible = false
		btn.pressed.connect(_on_hotspot.bind(hs["id"], hs["desc"]))
		if _portrait_ctrl != null:
			_portrait_ctrl.add_child(btn)
		else:
			# 地点类：命中区挂入摄像机世界层(_world)，随缩放/平移与背景一起变换，
			# 使「缩放后也能精准点地点类线索」。热点坐标定义在场景根系，减 _world_offset
			# 转世界局部系，scale=1 时屏幕位置与改动前完全一致（无回归）。
			btn.position = Vector2(float(hs.get("x", 0.0)), float(hs.get("y", 0.0))) - _world_offset
			btn.size = Vector2(float(hs.get("w", 0.0)), float(hs.get("h", 0.0)))
			if _world_layer != null:
				_world_layer.add_child(btn)
			else:
				# 兜底：无世界层时（非摄像机场景）退化为原视口坐标按钮
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
	# 把可点击命中区定位到立绘上的锚点部位（与高亮圆圈同一坐标），
	# 确保玩家点击圆圈即命中 —— 这是「点击圆圈无反应」的根治点。
	if _portrait_ctrl != null:
		_position_buttons()
	# 进入观察即按难度在立绘上画出高亮圆圈（简单=亮圈、普通=淡圈、困难=无），
	# 作为「这里有条线索」的提示，玩家点击高亮部位才弹放大图 + 说明文字。
	_draw_initial_hints()

## 仅点亮线索提示圆圈（按难度），不激活观察、不开放点击、不显示命中按钮。
## 通用能力：供场景在「剧情尚未正式进入观察」时先给出视觉提示（如信使被介绍身份后），
## 真正的点击观察留到对话结束由 show() 激活。圆圈本身 mouse_filter=IGNORE，不拦截鼠标。
## （场景一信使时序修复：m3 福尔摩斯介绍其为海军军士后点亮，对话结束才 show() 开放点击）
func reveal_hints() -> void:
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
	# 防御：线索必须在当前观察器热点内（难度过滤可能已移除该线索，
	# 避免读旧难度存档时把不存在的线索计入，导致计数虚增）
	var _found := false
	for hs in _hotspots:
		if hs["id"] == clue_id:
			_found = true
			break
	if not _found:
		return
	_recorded_ids.append(clue_id)
	_recorded += 1
	for hs in _hotspots:
		if hs["id"] == clue_id:
			if not hs.get("silent", false):
				_required_recorded += 1
			break
	hide_button_by_id(clue_id)
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
	if _has_mark(clue_id):
		return
	if _portrait_ctrl != null and _portrait_img_path != "":
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
		# 圆圈半径：统一为固定小半径，仅作提示（不再随锚点框大小变化，避免大小不一）
		var r: float = CLUE_HINT_RADIUS
		var col := Color(0.98, 0.82, 0.30, 1.0) if intensity >= 2 else Color(0.98, 0.82, 0.30, 0.5)
		var circle = ClueHighlightCircle.new()
		circle.setup(Vector2(cx, cy), r, col)
		circle.name = "hl_" + clue_id
		_portrait_ctrl.add_child(circle)
		return
	# 地点类：在 _world 层热点中心画小金圈（与命中区重合，随相机缩放/平移一起变换）
	if _world_layer == null:
		return
	var hs_d: Dictionary = {}
	for hs in _hotspots:
		if hs["id"] == clue_id:
			hs_d = hs
			break
	if hs_d.is_empty():
		return
	var cx0 := float(hs_d.get("x", 0.0)) - _world_offset.x + float(hs_d.get("w", 0.0)) * 0.5
	var cy0 := float(hs_d.get("y", 0.0)) - _world_offset.y + float(hs_d.get("h", 0.0)) * 0.5
	var col2 := Color(0.98, 0.82, 0.30, 1.0) if intensity >= 2 else Color(0.98, 0.82, 0.30, 0.5)
	var circle2 = ClueHighlightCircle.new()
	circle2.setup(Vector2(cx0, cy0), CLUE_HINT_RADIUS, col2)
	circle2.name = "hl_" + clue_id
	_world_layer.add_child(circle2)

## 某线索的高亮圆圈是否已存在（角色立绘层 或 世界层任一）
func _has_mark(cid: String) -> bool:
	if _portrait_ctrl != null and _portrait_ctrl.has_node("hl_" + cid):
		return true
	if _world_layer != null and _world_layer.has_node("hl_" + cid):
		return true
	return false

## 移除某线索的高亮圆圈（线索被收集后调用，提示圆圈即消失）。
## 同时清理角色立绘层(_portrait_ctrl)与世界层(_world_layer)两处，覆盖地点类分支。
func _remove_clue_circle(clue_id: String) -> void:
	for parent in [_portrait_ctrl, _world_layer]:
		if parent == null:
			continue
		var c = parent.get_node_or_null("hl_" + clue_id)
		if c != null:
			c.queue_free()

## 计算某锚点对应人物部位在立绘控件(_portrait_ctrl)局部坐标系中的矩形（命中区/圆圈共用）。
## 与 _mark_clue_at_anchor 完全一致的坐标推导，确保「可点击区」与「高亮圆圈」重合。
func _anchor_local_rect(anchor_name: String) -> Rect2:
	if _portrait_ctrl == null or _portrait_img_path == "":
		return Rect2()
	var a: Dictionary = ClueImageAnchors.get_anchor(_portrait_img_path, anchor_name)
	if a.is_empty():
		return Rect2()
	var tex: Texture2D = load(_portrait_img_path)
	if tex == null:
		return Rect2()
	var tw := float(tex.get_width())
	var th := float(tex.get_height())
	var box := _portrait_ctrl.size - Vector2(12, 12)
	if box.x <= 0 or box.y <= 0:
		return Rect2()
	var sc: float = min(box.x / tw, box.y / th)
	var dw: float = tw * sc
	var dh: float = th * sc
	var img_pos := Vector2(6, 6) + (box - Vector2(dw, dh)) * 0.5
	var img_size := Vector2(dw, dh)
	var cx := img_pos.x + float(a["cx"]) * img_size.x
	var cy := img_pos.y + float(a["cy"]) * img_size.y
	var rx := float(a["w"]) * img_size.x * 0.5
	var ry := float(a["h"]) * img_size.y * 0.5
	var r: float = max(rx, ry) * 1.12
	# 命中区略大于圆圈，便于点击（半径至少 30px）
	var half: float = max(r, 30.0)
	return Rect2(cx - half, cy - half, half * 2.0, half * 2.0)

## 返回某线索对应人物部位在「世界层」局部坐标系中的中心点（供摄像机点线索推近）。
## 与 _mark_clue_at_anchor 完全一致的坐标推导；返回立绘控件在 _world 中的位置 + 部位中心。
## 找不到则返回 Vector2.ZERO。
func get_clue_world_point(clue_id: String) -> Vector2:
	if _portrait_ctrl != null and _portrait_img_path != "":
		var anchor_name: String = ""
		for hs in _hotspots:
			if hs["id"] == clue_id:
				anchor_name = hs.get("anchor", "")
				break
		var a: Dictionary = ClueImageAnchors.get_anchor(_portrait_img_path, anchor_name)
		if a.is_empty():
			return Vector2.ZERO
		var tex: Texture2D = load(_portrait_img_path)
		if tex == null:
			return Vector2.ZERO
		var tw := float(tex.get_width()); var th := float(tex.get_height())
		var box := _portrait_ctrl.size - Vector2(12, 12)
		var sc: float = min(box.x / tw, box.y / th)
		var dw: float = tw * sc; var dh: float = th * sc
		var img_pos := Vector2(6, 6) + (box - Vector2(dw, dh)) * 0.5
		var cx := img_pos.x + float(a["cx"]) * dw
		var cy := img_pos.y + float(a["cy"]) * dh
		# _portrait_ctrl 是 _world 的子节点，其 position 即世界层局部坐标
		return _portrait_ctrl.position + Vector2(cx, cy)
	# 地点类：热点中心 → _world 局部系（供摄像机点线索推近，与命中区同一坐标）
	if _world_layer == null:
		return Vector2.ZERO
	var hs_d: Dictionary = {}
	for hs in _hotspots:
		if hs["id"] == clue_id:
			hs_d = hs
			break
	if hs_d.is_empty():
		return Vector2.ZERO
	var cx0 := float(hs_d.get("x", 0.0)) - _world_offset.x + float(hs_d.get("w", 0.0)) * 0.5
	var cy0 := float(hs_d.get("y", 0.0)) - _world_offset.y + float(hs_d.get("h", 0.0)) * 0.5
	return Vector2(cx0, cy0)

## 把每个热点按钮定位到立绘上的锚点部位（与高亮圆圈同一局部坐标），
## 使「可点击命中区」与「视觉高亮」重合。仅在 _portrait_ctrl 有效时调用（show 时尺寸已就绪）。
func _position_buttons() -> void:
	for i in _hotspots.size():
		if i >= _btns.size(): break
		var rect := _anchor_local_rect(_hotspots[i].get("anchor", ""))
		if rect.size.x > 0 and rect.size.y > 0:
			_btns[i].position = rect.position
			_btns[i].size = rect.size

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
## 线索说明文字统一收进弹出框内的滚动面板（不再写入底部对话框，便于阅读）。
## 玩家再次点击画面任意处 / 按 Enter/Space/Esc 关闭放大图，关闭时才把该线索正式记入推理墙
## （Q4 确认：记录发生在「退出放大图」时刻，而非点开时刻）。
## 所有难度都弹放大图 + 展示说明文字（那是观察结果，不是提示；提示仅指「难度分级的部位高亮」）。
## 统一机制：场景一（人物立绘，有锚点→裁切部位）、场景二/三（地点背景，有锚点→裁切区域；
## 无锚点如场景三→整图放大兜底），三场景共用同一套弹出框，文案与交互完全一致。
func _vp_size() -> Vector2:
	var vp = get_viewport()
	if vp != null:
		return vp.size
	return Vector2(1920, 1080)

## 地点类线索「上下文放大裁切」：以锚点中心向外扩张到至少 MIN_FRAC 图幅的方形区域，
## 框住线索周围上下文，便于放大后辨认（区分于角色立绘类，后者裁切框本身已足够大）。
## 区域超出图像边界时 clamp 到 [0,1]，绝不越界（避免 AtlasTexture 取黑边/报错）。
func _zoom_crop_region(img_path: String, a: Dictionary) -> Rect2:
	var tex: Texture2D = load(img_path)
	if tex == null:
		return Rect2()
	var tw := float(tex.get_width()); var th := float(tex.get_height())
	var acx := float(a["cx"]); var acy := float(a["cy"])
	var aw := float(a["w"]); var ah := float(a["h"])
	var half: float = max(aw, ah) * 1.7
	half = max(half, 0.18)
	var x0: float = clampf(acx - half, 0.0, 1.0)
	var y0: float = clampf(acy - half, 0.0, 1.0)
	var x1: float = clampf(acx + half, 0.0, 1.0)
	var y1: float = clampf(acy + half, 0.0, 1.0)
	return Rect2(x0 * tw, y0 * th, (x1 - x0) * tw, (y1 - y0) * th)

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
	# 放大图统一使用「屏上立绘 / 场景背景」同一张图 + 同一套锚点（与高亮圆圈一致）。
	var img_path: String = _portrait_img_path if _portrait_img_path != "" else hs_d.get("image", "")
	# 锚点兜底：热点未显式写 anchor 时，以线索 id 作为锚点名（场景三热点只写了 image、未写 anchor）。
	var anchor_name: String = hs_d.get("anchor", "")
	if anchor_name == "":
		anchor_name = clue_id
	var title: String = hs_d.get("label", clue_id)
	var vp := _vp_size()

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

	# 部位放大图：有锚点数据 → AtlasTexture 截取锚点区域（场景一/二）；
	# 无锚点数据（地点类缺锚点，如场景三）→ 整图放大兜底，保证弹出框始终有可视内容。
	var side: float = min(vp.x * 0.42, 500.0)
	var img_x: float = (vp.x - side) / 2.0
	var img_y: float = 60.0
	var img_pos := Vector2(img_x, img_y)
	if img_path != "" and ResourceLoader.exists(img_path):
		var tex: Texture2D = load(img_path)
		if tex != null:
			var img := TextureRect.new()
			img.expand_mode = 2
			img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			img.size = Vector2(side, side)
			img.position = img_pos
			img.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var a: Dictionary = ClueImageAnchors.get_anchor(img_path, anchor_name) if anchor_name != "" else {}
			if not a.is_empty():
				var tw := float(tex.get_width()); var th := float(tex.get_height())
				var at := AtlasTexture.new()
				at.atlas = tex
				# 地点类背景（/scenes/）上的线索是「大图里的小细节」：原始锚点框往往仅几十像素，
				# 直接裁切后放大几乎不可辨认（表现为「图片框空白」）。故对地点类做「以线索为中心向外
				# 扩张到至少 0.18 图幅」的上下文裁切再放大显示；角色立绘类（场景一）保持原裁切不变。
				if img_path.contains("/scenes/"):
					at.region = _zoom_crop_region(img_path, a)
				else:
					at.region = Rect2((float(a["cx"]) - float(a["w"]) / 2.0) * tw,
									  (float(a["cy"]) - float(a["h"]) / 2.0) * th,
									  float(a["w"]) * tw, float(a["h"]) * th)
				img.texture = at
			else:
				img.texture = tex
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
	lab.position = Vector2(0, 20)
	lab.size = Vector2(vp.x, 40)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.add_child(lab)

	# 线索说明：统一收进弹出框内（不再写入底部对话框，便于阅读），长文可滚动。
	var tool: Variant = hs_d.get("tool", "")
	var full_text := desc
	if tool != null and str(tool) != "" and str(tool) != "none":
		full_text += "\n\n（🔧 可用工具：" + str(tool) + "）"
	# 文本框字号 = 24（用户指定）；行高/框高随字号自动推导，其它样式不变。
	var FONT_SIZE: int = 24
	# 先建 RichTextLabel 以取主题字体的真实行高
	var rl := RichTextLabel.new()
	rl.bbcode_enabled = false
	rl.fit_content = true
	rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rl.add_theme_font_size_override("font_size", FONT_SIZE)
	rl.add_theme_color_override("default_color", Color(0.93, 0.89, 0.79))
	rl.text = full_text
	rl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 行高按放大后字号估算（含行间距），文本框高度 = 3 × 行高
	var line_h: float = float(FONT_SIZE) * 1.3
	# 文本框高度 = 3 × 放大后行高；超出此高度的内容在框内滚动。
	var box_w: float = side
	var box_h: float = 3.0 * line_h
	var box_x: float = img_x
	var box_y: float = img_y + side + 10.0
	var desc_panel := Panel.new()
	desc_panel.position = Vector2(box_x, box_y)
	desc_panel.size = Vector2(box_w, box_h)
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.06, 0.05, 0.07, 0.82)
	psb.border_color = Color(0.95, 0.80, 0.35, 1)   # 与图片框金边一致
	psb.border_width_left = 3; psb.border_width_right = 3
	psb.border_width_top = 3; psb.border_width_bottom = 3
	psb.set_corner_radius_all(8)                     # 与图片框圆角一致
	desc_panel.add_theme_stylebox_override("panel", psb)
	desc_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.add_child(desc_panel)
	var sc := ScrollContainer.new()
	sc.position = Vector2(10, 10); sc.size = Vector2(box_w - 20.0, box_h - 20.0)
	# PASS：滚轮可在框内滚动文字；点击穿透到 popup 关闭（滚轮 pressed=false 不会误关）
	sc.mouse_filter = Control.MOUSE_FILTER_PASS
	desc_panel.add_child(sc)
	# ⚠️ 关键：RichTextLabel 必须在 ScrollContainer 内横向撑满(SIZE_EXPAND_FILL)，
	# 否则其宽度塌缩为 1px，文字逐字换行、整块不可读（此前「弹出框无文字」的根因）。
	rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(rl)

	# 底部提示
	var hint := Label.new()
	hint.text = "（点击任意处 / 按 Enter 关闭，并记录此线索）"
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.7, 0.66, 0.55))
	hint.position = Vector2(0, box_y + box_h + 12.0)
	hint.size = Vector2(vp.x, 28)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.add_child(hint)

	popup.gui_input.connect(_on_zoom_input)
	(_parent if _parent else get_tree().current_scene).add_child(popup)
	_zoom_popup = popup
	# 抢焦点以捕获键盘 Enter/Space/Esc
	popup.grab_focus()

## 放大图输入处理：再次点击画面 / 按 Enter/Space/Esc/E 关闭并记录
## ⚠️ 滚轮(上/下/左/右)也是 InputEventMouseButton 且 pressed=true，但只用于框内滚动文字，
## 必须排除，否则滚轮滑动会误触发关闭。
func _on_zoom_input(event: InputEvent) -> void:
	if not _zoomed: return
	var close := false
	if event is InputEventMouseButton and event.pressed:
		var b: int = event.button_index
		if b != MOUSE_BUTTON_WHEEL_UP and b != MOUSE_BUTTON_WHEEL_DOWN \
				and b != MOUSE_BUTTON_WHEEL_LEFT and b != MOUSE_BUTTON_WHEEL_RIGHT:
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
	# 线索已收集：移除该部位的高亮圆圈（点击后不再提示），并正式记录
	_remove_clue_circle(cid)
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

	# ⚠️ 统一：线索说明已完整呈现在放大弹出框内（见 _open_zoom），不再写入底部对话框。
	# 记录进度反馈由场景 _on_clue_recorded → show_notification 统一处理，避免与叙事对话框打架。

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
