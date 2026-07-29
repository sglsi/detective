extends Node
class_name ClueObserver

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

func _create_buttons() -> void:
	for hs in _hotspots:
		var btn = Button.new()
		btn.text = hs["label"]
		btn.position = Vector2(hs["x"], hs["y"])
		btn.size = Vector2(hs["w"], hs["h"])
		btn.add_theme_font_size_override("font_size", 15 if _hotspots.size() > 4 else 16)
		btn.add_theme_color_override("font_color", Color(0.85, 0.75, 0.45))
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
			hs_data = {"id": hs["id"], "name": hs["label"], "desc": hs.get("desc", ""), "correct": hs.get("correct", true)}
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

	# 放大的肖像图
	var img = TextureRect.new()
	img.name = "obs_img"
	img.position = Vector2(260, 60); img.size = Vector2(700, 950)
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	if _portrait_texture:
		img.texture = _portrait_texture
	_parent.add_child(img)

	# 标题
	var parts = {"wrist":"手腕","arm":"左臂","face":"面色","pose":"站姿",
		"tattoo":"手背","beard":"胡须","posture":"站姿","manner":"神态",
		"sleeve":"袖口","limp":"跛行","ring":"戒指","shoes":"鞋"}
	var title = Label.new()
	title.text = "Step 2 放大: " + parts.get(clue_id, clue_id)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.85, 0.75, 0.45))
	title.position = Vector2(260, 20); title.size = Vector2(700, 40)
	title.name = "obs_title"
	_parent.add_child(title)

	# 描述文本
	var dl = Label.new()
	dl.text = desc; dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dl.add_theme_font_size_override("font_size", 16)
	dl.add_theme_color_override("font_color", Color(0.8, 0.78, 0.68))
	dl.position = Vector2(1000, 100); dl.size = Vector2(850, 220)
	dl.name = "obs_desc"
	_parent.add_child(dl)

	# Step 3 记录按钮
	var cf = Button.new()
	cf.text = "Step 3 记录"
	cf.position = Vector2(1000, 360); cf.size = Vector2(240, 55)
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
	for name in ["obs_dim", "obs_img", "obs_title", "obs_desc", "obs_confirm"]:
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
			hs_data = {"id": hs["id"], "name": hs["label"], "desc": hs.get("desc", ""), "correct": hs.get("correct", true)}
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
