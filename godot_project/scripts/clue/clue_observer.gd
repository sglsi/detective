extends Node
class_name ClueObserver

const ClueImageAnchors = preload("res://data/clue_image_anchors.gd")
const ClueAnchorCard = preload("res://scripts/ui/clue_anchor_card.gd")

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

func setup(parent: Control, text_lbl: Label, speaker_lbl: Label,
			hotspots: Array, portrait_tex: Texture2D = null) -> void:
	_parent = parent
	_text_lbl = text_lbl
	_speaker_lbl = speaker_lbl
	_hotspots = hotspots
	_portrait_texture = portrait_tex
	_create_buttons()
	# 计算必点总数（silent 线索不计入完成条件，仅作可选奖励）
	_required_total = 0
	for hs in _hotspots:
		if not hs.get("silent", false):
			_required_total += 1

## 根据难度生成热点按钮样式：直观体现「场景线索提示」三档梯度
##   hotspot_hint_level=2（简单）：明亮金边 + 半透明底，所有可交互点高亮
##   hotspot_hint_level=1（普通）：微弱金边（微光），关键交互点需自行辨认
##   hotspot_hint_level=0（困难）：无任何标记，玩家必须自行寻找
## 设计基线：DifficultyManager B-11.2「场景线索提示」列；此前该方法是死代码未被消费。
func _hotspot_style(level: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	if level >= 2:
		sb.bg_color = Color(0.95, 0.82, 0.35, 0.18)
		sb.border_color = Color(0.97, 0.84, 0.42, 0.95)
		sb.border_width_left = 3
		sb.border_width_right = 3
		sb.border_width_top = 3
		sb.border_width_bottom = 3
	elif level == 1:
		sb.bg_color = Color(0.95, 0.82, 0.35, 0.06)
		sb.border_color = Color(0.97, 0.84, 0.42, 0.45)
		sb.border_width_left = 2
		sb.border_width_right = 2
		sb.border_width_top = 2
		sb.border_width_bottom = 2
	else:
		sb.bg_color = Color(0, 0, 0, 0)
	sb.set_corner_radius_all(6)
	return sb

func _create_buttons() -> void:
	# 读取当前难度的提示级别（DifficultyManager 在难度选择时已 set_difficulty）
	var lvl := 0
	if DifficultyManager != null:
		lvl = DifficultyManager.hotspot_hint_level
	var style := _hotspot_style(lvl)
	for hs in _hotspots:
		var btn = Button.new()
		btn.text = hs["label"]
		btn.position = Vector2(hs["x"], hs["y"])
		btn.size = Vector2(hs["w"], hs["h"])
		btn.add_theme_font_size_override("font_size", 15 if _hotspots.size() > 4 else 16)
		btn.add_theme_color_override("font_color", Color(0.85, 0.75, 0.45))
		# 难度高亮标记：简单/普通给描边，困难无标记
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("focus", style)
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

func hide() -> void:
	_active = false
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
	# 已记录过的线索不再响应（防重复记录）
	if _recorded_ids.has(clue_id): return
	# 已有放大层打开时忽略其他热点点击（防止叠加多层遮罩——
	# _clear_observation_layer 只清一组节点，叠加层的残留 obs_dim 会
	# 全屏拦截鼠标，表现为「点哪都没反应」的卡死）
	if _parent.find_child("obs_dim", true, false): return
	hotspot_clicked.emit(clue_id)

	# 隐藏该热点按钮
	hide_button_by_id(clue_id)

	# 弹出放大观察层
	_show_observation_layer(clue_id, desc)

func _show_observation_layer(clue_id: String, desc: String) -> void:
	# 半透明遮罩
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.name = "obs_dim"
	_parent.add_child(dim)

	# 取该线索的元信息（标题 / 关联图片 / 锚点部位）
	var hs_meta: Dictionary = {}
	for hs in _hotspots:
		if hs["id"] == clue_id:
			hs_meta = hs
			break
	var disp_img: String = hs_meta.get("image", "")
	if disp_img == "" and _portrait_texture != null:
		disp_img = _portrait_texture.resource_path
	var anchor_name: String = hs_meta.get("anchor", "")
	var anchor: Dictionary = {}
	if disp_img != "" and anchor_name != "":
		anchor = ClueImageAnchors.get_anchor(disp_img, anchor_name)
	var title: String = hs_meta.get("label", clue_id)

	# 头部标题
	var head = Label.new()
	head.text = "🔍 观察线索：" + title
	head.add_theme_font_size_override("font_size", 24)
	head.add_theme_color_override("font_color", Color(0.85, 0.75, 0.45))
	head.position = Vector2(260, 20); head.size = Vector2(900, 40)
	head.name = "obs_title"
	_parent.add_child(head)

	# 左侧：整图（若有锚点则在部位上画金框），让玩家看清「这是华生的哪个部位」
	var tex: Texture2D = null
	if disp_img != "" and ResourceLoader.exists(disp_img):
		tex = load(disp_img)
	elif _portrait_texture != null:
		tex = _portrait_texture
	if tex != null:
		var full = TextureRect.new()
		full.name = "obs_img"
		var box_pos := Vector2(260, 80)
		var box_size := Vector2(360, 480)
		# 等比 contain（同 _make_portrait）：本 Godot 4.7 构建 expand_mode=2 实测会把 size 重算成正方形，
		# 故用 EXPAND_IGNORE_SIZE(=1) 让手动计算的 contain 尺寸生效。
		var tw := float(tex.get_width())
		var th := float(tex.get_height())
		var sc: float = min(box_size.x / tw, box_size.y / th)
		var dw: float = tw * sc
		var dh: float = th * sc
		full.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		full.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		full.size = Vector2(dw, dh)
		full.position = box_pos + (box_size - Vector2(dw, dh)) * 0.5
		full.texture = tex
		_parent.add_child(full)
		if not anchor.is_empty():
			ClueAnchorCard.draw_highlight(_parent, box_pos, box_size, tex, anchor, anchor_name)

	# 右侧：线索锚点卡片（部位放大裁剪 + 文字）—— 线索与身体部位同卡绑定，不再「旁边几个字」
	var card_img: String = disp_img
	if card_img == "" and _portrait_texture != null:
		card_img = _portrait_texture.resource_path
	var card = ClueAnchorCard.new()
	card.setup_card(card_img, anchor_name, title, desc, 560, 540)
	card.name = "obs_card"
	card.position = Vector2(660, 80)
	_parent.add_child(card)

	# Step 3 记录按钮
	var cf = Button.new()
	cf.text = "Step 3 记录"
	cf.position = Vector2(660, 640); cf.size = Vector2(240, 55)
	cf.add_theme_font_size_override("font_size", 22)
	cf.name = "obs_confirm"
	cf.add_theme_color_override("font_color", Color(0.92, 0.84, 0.55))
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.50, 0.10, 0.10, 0.95)
	sb.border_color = Color(0.85, 0.65, 0.25)
	sb.border_width_left = 2; sb.border_width_right = 2
	sb.border_width_top = 2; sb.border_width_bottom = 2
	sb.set_corner_radius_all(4)
	cf.add_theme_stylebox_override("normal", sb)
	cf.pressed.connect(func(): _on_record(clue_id, desc))
	_parent.add_child(cf)

func _clear_observation_layer() -> void:
	# 清掉「所有」同名残留（而非只清第一个）：若历史上曾叠加出多层观察层，
	# 残留的全屏 obs_dim 会永远拦截鼠标点击，表现为整个场景卡死。
	for name in ["obs_dim", "obs_img", "obs_title", "obs_desc", "obs_confirm",
			"obs_card", "ClueAnchorHL", "ClueAnchorHL_lab"]:
		while true:
			var n = _parent.find_child(name, true, false)
			if not n: break
			n.name = name + "_dying"  # 立即改名，防止 queue_free 生效前被重复命中
			n.queue_free()

func _on_record(clue_id: String, desc: String) -> void:
	_clear_observation_layer()
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

	# 更新底部文字（进度只统计必点线索；沉默线索为额外奖励，不计入分母）
	var parts = {0:"第一",1:"第二",2:"第三",3:"第四",4:"第五",5:"第六"}
	_text_lbl.text = "线索已记录！%s条线索 (%d/%d)" % [parts.get(_recorded-1, ""), _required_recorded, _required_total]

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
