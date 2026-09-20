extends RefCounted
class_name GraphViewCards

## 图谱视图 · 卡片渲染层（拆自 graph_view_controller.gd）
##
## 职责：统一三段式卡片渲染（图片区 + 标题 + 副标题）、随机纸纹、圆形头像裁剪、
## 未知剪影、线索图片区锚点裁剪、占位徽章、分隔线、金钉。
## 状态留在主控制器，本组件只读 + 通过 owner 回读；内部缓存（纸纹/头像）仅本层使用。

var owner: GraphViewController

const ClueImageAnchors = preload("res://data/clue_image_anchors.gd")

# === 卡片渲染内部缓存（仅本层使用，原控制器 _grain_tex / _avatar_cache / _unknown_avatar_tex）===
var _grain_tex: ImageTexture = null
var _avatar_cache: Dictionary = {}      # Texture2D -> 圆形头像 Texture2D
var _unknown_avatar_tex: ImageTexture = null

## 随机纸纹贴图（一次性生成、全局缓存）：128×128 透明底 + 随机散布圆点（大小/深浅带随机变化），
## 非规则平铺，模拟真实卡片颗粒感。各卡用 modulate 染成与底色对比的微弱点/亮点。
func grain_texture() -> ImageTexture:
	if _grain_tex != null:
		return _grain_tex
	var S := 128
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260917
	for _i in 240:
		var x := rng.randi_range(2, S - 3)
		var y := rng.randi_range(2, S - 3)
		var r := rng.randf_range(0.7, 2.4)
		var a := rng.randf_range(0.35, 0.9)
		var rr := int(ceil(r))
		for dy in range(-rr, rr + 1):
			for dx in range(-rr, rr + 1):
				if dx * dx + dy * dy <= r * r:
					var px := x + dx; var py := y + dy
					if px >= 0 and px < S and py >= 0 and py < S:
						img.set_pixel(px, py, Color(1, 1, 1, a))
	_grain_tex = ImageTexture.create_from_image(img)
	return _grain_tex

## 卡片背景纸纹层（置于内容之下）。深色卡→淡亮点，浅色卡→淡暗点。
func make_grain_rect(bg: Color) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = grain_texture()
	tr.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lum := 0.299 * bg.r + 0.587 * bg.g + 0.114 * bg.b
	tr.modulate = Color(1, 1, 1, 0.20) if lum < 0.4 else Color(0, 0, 0, 0.20)
	return tr

## 把任意方形头像纹理裁成圆形（居中取最小边 + 圆形 alpha 遮罩，2px 抗锯齿）。
## 缓存按源纹理；get_image 失败（如压缩纹理）则回退原矩形纹理。
func make_circular_avatar(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	if _avatar_cache.has(tex):
		return _avatar_cache[tex]
	var out_tex: Texture2D = tex
	var img: Image = tex.get_image()
	if img != null:
		var W := img.get_width(); var H := img.get_height()
		var side := mini(W, H)
		var sx := int((W - side) * 0.5); var sy := int((H - side) * 0.5)
		var S := 256
		# 先裁居中方块再缩放到 S×S（blit_rect 不缩放，大图会只取左上角）
		var sq: Image = img.get_region(Rect2i(sx, sy, side, side))
		sq.resize(S, S, Image.INTERPOLATE_LANCZOS)
		sq.convert(Image.FORMAT_RGBA8)
		var r := float(S) * 0.5
		for y in S:
			for x in S:
				var dx := float(x) - r + 0.5
				var dy := float(y) - r + 0.5
				var d := sqrt(dx * dx + dy * dy)
				if d > r:
					sq.set_pixel(x, y, Color(0, 0, 0, 0))
				elif d > r - 2.0:
					var a := (r - d) / 2.0
					var c := sq.get_pixel(x, y)
					sq.set_pixel(x, y, Color(c.r, c.g, c.b, clampf(c.a * a, 0.0, 1.0)))
		out_tex = ImageTexture.create_from_image(sq)
	_avatar_cache[tex] = out_tex
	return out_tex

## 未知人物剪影圆盘（深底 + 透明外圈），缓存。
func make_unknown_avatar() -> ImageTexture:
	if _unknown_avatar_tex != null:
		return _unknown_avatar_tex
	var S := 256
	var out := Image.create(S, S, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	var r := float(S) * 0.5 - 4.0
	for y in S:
		for x in S:
			var dx := float(x) - float(S) * 0.5 + 0.5
			var dy := float(y) - float(S) * 0.5 + 0.5
			var d := sqrt(dx * dx + dy * dy)
			if d <= r:
				var a := 1.0
				if d > r - 3.0:
					a = (r - d) / 3.0
				out.set_pixel(x, y, Color(0.13, 0.11, 0.10, a))
	_unknown_avatar_tex = ImageTexture.create_from_image(out)
	return _unknown_avatar_tex

## 圆形头像外框：PanelContainer + 圆形金边（corner_radius=半边长），内含纹理/剪影。
func make_avatar_frame(tex: Texture2D, ring_col: Color, overlay_q: bool = false) -> PanelContainer:
	var pc := PanelContainer.new()
	var av := 200.0
	pc.custom_minimum_size = Vector2(av, av)
	pc.size = Vector2(av, av)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0)
	s.border_color = ring_col
	s.border_width_left = 5; s.border_width_right = 5; s.border_width_top = 5; s.border_width_bottom = 5
	s.set_corner_radius_all(av * 0.5)
	pc.add_theme_stylebox_override("panel", s)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inner := Control.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(inner)
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(tr)
	if overlay_q:
		var q := Label.new()
		q.text = "?"
		q.add_theme_font_size_override("font_size", 110)
		q.add_theme_color_override("font_color", Color(0.96, 0.86, 0.5))
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		q.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		q.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(q)
	return pc

## 线索图片外框：深棕细边圆角 PanelContainer 包裹 TextureRect（保持比例居中）。
func make_img_frame(tr: TextureRect) -> PanelContainer:
	var pc := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.08, 0.06, 0.04, 1)
	s.border_color = Color(0.45, 0.32, 0.18)
	s.border_width_left = 3; s.border_width_right = 3; s.border_width_top = 3; s.border_width_bottom = 3
	s.set_corner_radius_all(6)
	pc.add_theme_stylebox_override("panel", s)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(tr)
	return pc

## 推断/结论/推理链等暂无示例图的占位徽章（可后续替换为按内容生成的示例图）。
func make_placeholder_frame(txt: String, col: Color) -> PanelContainer:
	var pc := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(clampf(col.r, 0, 1), clampf(col.g, 0, 1), clampf(col.b, 0, 1), 0.18)
	s.border_color = col
	s.border_width_left = 3; s.border_width_right = 3; s.border_width_top = 3; s.border_width_bottom = 3
	s.set_corner_radius_all(6)
	pc.add_theme_stylebox_override("panel", s)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lb := Label.new()
	lb.text = txt
	lb.add_theme_font_size_override("font_size", 30)
	lb.add_theme_color_override("font_color", col)
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pc.add_child(lb)
	return pc

## 分隔线（细色条）。
func make_sep_line(col: Color) -> ColorRect:
	var cr := ColorRect.new()
	cr.color = col
	cr.custom_minimum_size = Vector2(0, 2)
	cr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return cr

## 图片区：按类型返回对应内容（人物=圆形头像/剪影居中；线索=图片铺满；其余=占位徽章铺满）。
func build_image_section(nd: Dictionary, kind: String, is_person: bool, is_clue: bool,
		is_concl: bool, is_hypo: bool, is_chain: bool, style: StyleBoxFlat) -> Control:
	var sec: Control
	if is_person:
		sec = CenterContainer.new()   # 方形头像居中
	else:
		var mc := MarginContainer.new()   # 图片/占位铺满区块
		mc.add_theme_constant_override("margin_left", 4)
		mc.add_theme_constant_override("margin_top", 4)
		mc.add_theme_constant_override("margin_right", 4)
		mc.add_theme_constant_override("margin_bottom", 4)
		sec = mc
	sec.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sec.custom_minimum_size = Vector2(0, owner._CARD_IMG_H)
	if is_person:
		var masked: bool = nd.get("masked", false)
		var tex: Texture2D = null
		if not masked:
			tex = PortraitLibrary.get_portrait(nd.get("label", ""))
		if tex != null:
			sec.add_child(make_avatar_frame(make_circular_avatar(tex), owner.COL_GOLD))
		else:
			sec.add_child(make_avatar_frame(make_unknown_avatar(), Color(0.82, 0.66, 0.30), true))
	elif is_clue:
		var c: Dictionary = nd.get("data", {})
		var img_path: String = c.get("image", "")
		var tex: Texture2D = null
		if img_path != "" and ResourceLoader.exists(img_path):
			var base: Texture2D = load(img_path)
			if base != null:
				# 锚点裁剪：同场景多条线索共用一张场景图，按锚点截出该线索真实区域
				#（anchor 缺失时以线索 id 兜底查表；查不到 → 回退整图，绝不报错）。
				var anchor_name: String = str(c.get("anchor", ""))
				if anchor_name == "":
					anchor_name = str(c.get("id", ""))
				var a: Dictionary = ClueImageAnchors.get_anchor(img_path, anchor_name)
				if a.is_empty():
					tex = base
				else:
					var bsz: Vector2 = base.get_size()
					var rw: float = clampf(bsz.x * float(a.get("w", 1.0)), 8.0, bsz.x)
					var rh: float = clampf(bsz.y * float(a.get("h", 1.0)), 8.0, bsz.y)
					var rcx: float = clampf(bsz.x * float(a.get("cx", 0.5)), rw * 0.5, bsz.x - rw * 0.5)
					var rcy: float = clampf(bsz.y * float(a.get("cy", 0.5)), rh * 0.5, bsz.y - rh * 0.5)
					var at := AtlasTexture.new()
					at.atlas = base
					at.region = Rect2(rcx - rw * 0.5, rcy - rh * 0.5, rw, rh)
					tex = at
		if tex != null:
			var tr := TextureRect.new()
			tr.texture = tex
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			sec.add_child(make_img_frame(tr))
		else:
			sec.add_child(make_placeholder_frame("线索", owner.COL_CLUE_BORDER))
	else:
		var ph_txt := "推断" if is_hypo else ("结论" if is_concl else ("推理链" if is_chain else "文本"))
		var ph_col: Color = owner.COL_HYPO_BORDER if is_hypo else (Color(0.58, 0.44, 0.20) if is_concl else owner.COL_GOLD)
		sec.add_child(make_placeholder_frame(ph_txt, ph_col))
	return sec


func make_node(nd: Dictionary) -> Control:
	var kind: String = nd.kind
	var is_person: bool = kind == "person"
	var is_concl: bool = kind == "conclusion"
	var is_chain: bool = kind == "chain"
	var is_hypo: bool = kind == "hypo"
	var is_clue: bool = kind == "clue"

	var card: PanelContainer
	var is_graph_card: bool = true
	var gc = GraphCard.new()
	card = gc
	# 大小按类型给（中文文本可能变宽，故预留；字号已×2，尺寸同步放大）
	# #1 自适应：卡片尺寸随姓名文字长度增长（约 28px/字，字号28），封顶 480 后自动换行扩高
	# 位置由调用方按 _node_center - size*0.5 重新居中，边/菜单以中心为锚，连线不受影响
	var _base_w: float = 180.0; var _base_h: float = 150.0
	if is_person: _base_w = 180.0; _base_h = 170.0
	elif is_concl: _base_w = 160.0; _base_h = 160.0
	elif is_chain: _base_w = 125.0; _base_h = 120.0
	elif is_hypo: _base_w = 140.0; _base_h = 130.0
	elif is_clue: _base_w = 320.0; _base_h = 130.0   # 需求6：线索文本框宽度加倍（160→320）
	else: _base_w = 160.0; _base_h = 130.0
	# 卡片尺寸在标签建立后按真实文字测量（见文末 _size_card_to_text 调用）

	card.mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	var default_border_w: int = 2
	style.border_width_left = default_border_w; style.border_width_right = default_border_w
	style.border_width_top = default_border_w; style.border_width_bottom = default_border_w
	style.set_corner_radius_all(8)

	var text_red := false
	var dashed: bool = false
	var dashed_col: Color = owner.COL_CLUE_BORDER
	var dashed_w: float = 2.0
	var font_col: Color = owner.COL_TEXT_DARK   # 默认深色字；人物红框改用浅色字
	var sub_col: Color = owner.COL_GREY

	if is_clue:
		var c: Dictionary = nd.data
		var correct: bool = c.get("correct", true)
		var assoc: bool = c.get("associated", false)
		# P0-2 用户标记覆盖
		var cid: String = c.get("id", "")
		var excluded: bool = owner._user_excluded.has(cid)
		var pending: bool = owner._user_pending.has(cid)
		if excluded:
			# 已排除：灰底 + 暗边
			style.bg_color = Color(0.20, 0.18, 0.16, 0.85)
			style.border_color = Color(0.40, 0.38, 0.35)
			style.border_width_left = 1; style.border_width_right = 1
			style.border_width_top = 1; style.border_width_bottom = 1
			text_red = false
		elif not correct:
			# 干扰项：白底 + 实线红边 + 红字
			style.bg_color = owner.COL_CLUE_BG_DIM
			style.border_color = owner.COL_CLUE_BORDER_DISTRACT
			text_red = true
		else:
			style.bg_color = owner.COL_CLUE_BG
			if assoc:
				style.border_color = owner.COL_CLUE_BORDER_ASSOC
			else:
				# 未关联：虚线暗金边
				style.border_color = owner.COL_CLUE_BG   # 把 stylebox 边框调成 bg 色，避免与手动虚线重影
				style.border_width_left = 0; style.border_width_right = 0
				style.border_width_top = 0; style.border_width_bottom = 0
				dashed = true
				dashed_col = owner.COL_CLUE_BORDER
				dashed_w = 2.0
		# P0-2 待查标记：黄边覆盖
		if pending and not excluded:
			style.border_color = Color(0.95, 0.80, 0.25)
			style.border_width_left = 3; style.border_width_right = 3
			style.border_width_top = 3; style.border_width_bottom = 3
			dashed = false
		# 共同线索（关联≥2人物）金边覆盖
		if nd.get("common", false):
			style.border_color = owner.COL_GOLD
			style.border_width_left = 3; style.border_width_right = 3
			style.border_width_top = 3; style.border_width_bottom = 3
			dashed = false
		# P0-3 搜索匹配高亮：金色加粗外框
		if not owner._search_query.is_empty() and owner._search_match_ids.has(cid):
			style.border_color = Color(1.0, 0.90, 0.30)
			style.border_width_left = 4; style.border_width_right = 4
			style.border_width_top = 4; style.border_width_bottom = 4
	elif is_hypo:
		var h: Dictionary = nd.data
		var correct: bool = h.get("correct", true)
		if not correct:
			style.bg_color = owner.COL_HYPO_BG_DIM
			style.border_color = owner.COL_CLUE_BORDER_DISTRACT
			text_red = true
		else:
			style.bg_color = owner.COL_HYPO_BG
			if owner._edge._node_has_user_relation(nd.id):
				style.border_color = owner.COL_HYPO_BORDER
			else:
				# 未关联推断：虚线暗边
				style.border_color = owner.COL_HYPO_BG   # 同上，把 stylebox 边框调成 bg 色
				style.border_width_left = 0; style.border_width_right = 0
				style.border_width_top = 0; style.border_width_bottom = 0
				dashed = true
				dashed_col = owner.COL_HYPO_BORDER
				dashed_w = 2.0
	elif is_chain:
		style.bg_color = Color(0.16, 0.13, 0.08, 0.95)
		style.border_color = owner.COL_GOLD
	elif is_concl:
		style.bg_color = Color(0.84, 0.74, 0.56, 0.96)   # 结论=浅棕（对照华生示范）
		style.border_color = Color(0.58, 0.44, 0.20)
		style.border_width_left = 3; style.border_width_right = 3
		style.border_width_top = 3; style.border_width_bottom = 3
	elif is_person:
		style.bg_color = Color(0.66, 0.20, 0.16, 0.97)   # 人物=红框（对照华生示范）
		style.border_color = Color(0.96, 0.44, 0.34)
		style.border_width_left = 3; style.border_width_right = 3
		style.border_width_top = 3; style.border_width_bottom = 3
		font_col = Color(0.99, 0.95, 0.92)
		sub_col = Color(0.92, 0.88, 0.85)

	card.add_theme_stylebox_override("panel", style)

	# 折叠根：暗金虚线描边（提示"此节点下有收起内容"，见设计 §2.3）
	if owner._folded_nodes.has(nd.id):
		(card as GraphCard).setup_dashed(true, owner.COL_GOLD, 2)

	# 启用虚线（需要 GraphCard）
	if is_graph_card and dashed:
		(card as GraphCard).setup_dashed(true, dashed_col, dashed_w)

	# ===== 统一三段式版式（2026-09-17）：图片区 + 标题 + 副标题 =====
	# ⚠️ 装饰层全部 mouse_filter=IGNORE：否则子控件拦截鼠标 → card.gui_input 收不到
	# → 点击详情（推导/打标签）、拖拽、Shift 建边全部失效（2026-09-17 用户报）。
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(root)

	# 随机纸纹底（置于内容之下）
	var grain := make_grain_rect(style.bg_color)
	root.add_child(grain)

	# 顶部图钉圆点（对照预览版式：卡顶中央金色圆钉，骑跨上边缘）
	var pin := PanelContainer.new()
	pin.custom_minimum_size = Vector2(22, 22)
	pin.size = Vector2(22, 22)
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.93, 0.66, 0.24)
	ps.border_color = Color(0.55, 0.36, 0.10)
	ps.border_width_left = 2; ps.border_width_right = 2
	ps.border_width_top = 2; ps.border_width_bottom = 2
	ps.set_corner_radius_all(11)
	pin.add_theme_stylebox_override("panel", ps)
	pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(pin)
	pin.position = Vector2(owner._CARD_W * 0.5 - 11.0, -8.0)

	# 内容层
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", int(owner._CARD_MARGIN))
	margin.add_theme_constant_override("margin_top", int(owner._CARD_MARGIN))
	margin.add_theme_constant_override("margin_right", int(owner._CARD_MARGIN))
	margin.add_theme_constant_override("margin_bottom", int(owner._CARD_MARGIN))
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(margin)

	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 8)
	margin.add_child(vb)

	# —— 图片区 ——
	var img_sec := build_image_section(nd, kind, is_person, is_clue, is_concl, is_hypo, is_chain, style)
	vb.add_child(img_sec)
	# 分隔线
	vb.add_child(make_sep_line(style.border_color))
	# —— 标题 ——
	var lab := Label.new()
	lab.text = nd.get("label", "")
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.add_theme_font_size_override("font_size", 24)
	lab.add_theme_color_override("font_color", owner.COL_TEXT_RED if text_red else font_col)
	lab.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(lab)
	# 分隔线
	vb.add_child(make_sep_line(style.border_color))
	# —— 副标题（状态/角色）——
	var sub := Label.new()
	sub.text = nd.get("sub", "")
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_font_size_override("font_size", 18)
	sub.add_theme_color_override("font_color", sub_col)
	sub.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)

	# 固定统一尺寸（不再按文字自适应）
	card.custom_minimum_size = Vector2(owner._CARD_W, owner._CARD_H)
	card.size = Vector2(owner._CARD_W, owner._CARD_H)

	var id: String = nd.id
	var kind2: String = nd.kind
	card.gui_input.connect(owner._on_node_gui.bind(id, kind2))
	card.mouse_entered.connect(owner._on_node_hover.bind(id, true))
	card.mouse_exited.connect(owner._on_node_hover.bind(id, false))
	card.tooltip_text = owner._edge._node_tooltip(nd)
	return card
