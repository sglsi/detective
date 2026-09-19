extends RefCounted

## DetailCard — 统一的「详情卡」框架（暗棕底 + 金边 + 圆角 PanelContainer）。
## 推理墙两处详情弹窗（图谱节点详情 / 左侧线索库线索详情）共用，保证视觉一致：
##   · 结构：card(PanelContainer) > vbox(VBoxContainer 唯一子节点)
##           > [title_bar(顶栏) / margin>scroll>body(内容区) / bottom_row(底部关闭行)]；
##     ⚠️ PanelContainer 会把每个直接子节点拉伸铺满整个矩形（互相重叠），
##        顶栏/内容必须经 VBox 纵向排列，否则标题被内容盖住（2026-09-19 实测踩坑）；
##   · 顶栏（标题 + 右上角 ✕）作为拖拽手柄，✕ 列入排除项不触发拖拽；
##   · 内容区 = MarginContainer > ScrollContainer > VBoxContainer（超长可滚动）；
##   · 底部「关 闭」按钮与顶栏 ✕ 共用同一 close_cb（双通道关闭）；
##   · z_index=30 盖过左侧「已收集线索」栏（z=20），低于顶栏（z=100）。
##
## build(title_text, close_cb, card_size) -> Dictionary:
##   { "card", "vbox", "body", "title_bar", "close_btn", "bottom_btn", "title" }
##   card       : PanelContainer（已加样式、z=30）
##   vbox       : VBoxContainer（卡内纵向布局容器）
##   body       : VBoxContainer（调用方往里塞内容）
##   title_bar  : HBoxContainer（拖拽手柄，已含 title + close_btn）
##   close_btn  : Button（顶栏 ✕，已 connect close_cb）
##   bottom_btn : Button（底部「关 闭」，已 connect close_cb）
##   title      : Label（顶栏标题，可后续改文字）

const BG := Color(0.102, 0.078, 0.063, 0.98)
const BORDER := Color(0.78, 0.60, 0.28)
const TITLE_COL := Color(0.85, 0.66, 0.30)
const BODY_COL := Color(0.91, 0.866, 0.784)
const CLOSE_FG := Color(0.95, 0.55, 0.45)
const CLOSE_BG := Color(0.30, 0.16, 0.14, 0.85)
const CLOSE_BORDER := Color(0.85, 0.45, 0.35)


static func _make_close_btn(txt: String, cb: Callable, min_size: Vector2, font_size: int) -> Button:
	var b := Button.new()
	b.text = txt
	b.tooltip_text = "关闭"
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", CLOSE_FG)
	var sb := StyleBoxFlat.new()
	sb.bg_color = CLOSE_BG
	sb.border_color = CLOSE_BORDER
	sb.set_corner_radius_all(5)
	b.add_theme_stylebox_override("normal", sb)
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.pressed.connect(cb)
	return b


static func build(title_text: String, close_cb: Callable, card_size := Vector2(480, 560)) -> Dictionary:
	var card := PanelContainer.new()
	card.custom_minimum_size = card_size
	card.z_index = 30
	var s := StyleBoxFlat.new()
	s.bg_color = BG
	s.border_color = BORDER
	s.border_width_left = 2; s.border_width_right = 2; s.border_width_top = 2; s.border_width_bottom = 2
	s.set_corner_radius_all(6)
	card.add_theme_stylebox_override("panel", s)

	# —— 卡内纵向布局（PanelContainer 唯一子节点，防顶栏/内容重叠）——
	var vbox := VBoxContainer.new()
	vbox.name = "CardVBox"
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	# —— 顶栏（拖拽手柄）：标题 + 右上角 ✕ ——
	var title_bar := HBoxContainer.new()
	title_bar.name = "TitleBar"
	title_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	title_bar.custom_minimum_size = Vector2(0, 46)  # 顶栏自身高度，文字不顶卡片最上沿
	title_bar.add_theme_constant_override("separation", 10)
	vbox.add_child(title_bar)

	var title := Label.new()
	title.name = "Title"
	title.text = title_text
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", TITLE_COL)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 让拖拽落到 title_bar
	title_bar.add_child(title)

	var close_btn := _make_close_btn("✕", close_cb, Vector2(34, 34), 18)
	close_btn.name = "CloseBtn"
	close_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_bar.add_child(close_btn)

	# —— 内容区：Margin > Scroll > VBox（顶部留白 12，文字不顶着顶栏书写）——
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 6)
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)

	# —— 底部关闭行：「关 闭」按钮与顶栏 ✕ 同一 close_cb ——
	var bottom_row := HBoxContainer.new()
	bottom_row.name = "BottomRow"
	bottom_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(bottom_row)
	var bottom_btn := _make_close_btn("关 闭", close_cb, Vector2(120, 36), 18)
	bottom_btn.name = "BottomCloseBtn"
	bottom_row.add_child(bottom_btn)

	return {"card": card, "vbox": vbox, "body": body, "title_bar": title_bar,
		"close_btn": close_btn, "bottom_btn": bottom_btn, "title": title}
