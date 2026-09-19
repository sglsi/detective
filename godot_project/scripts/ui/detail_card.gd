extends RefCounted

## DetailCard — 统一的「详情卡」框架（暗棕底 + 金边 + 圆角 PanelContainer）。
## 推理墙两处详情弹窗（图谱节点详情 / 左侧线索库线索详情）共用，保证视觉一致：
##   · 顶栏（标题 + 右上角 ✕）作为拖拽手柄，✕ 列入排除项不触发拖拽；
##   · 内容区 = MarginContainer > ScrollContainer > VBoxContainer（超长可滚动）；
##   · z_index=30 盖过左侧「已收集线索」栏（z=20），低于顶栏（z=100）。
##
## build(title_text, close_cb, card_size) -> Dictionary:
##   { "card", "body", "title_bar", "close_btn", "title" }
##   card      : PanelContainer（已加样式、z=30）
##   body      : VBoxContainer（调用方往里塞内容）
##   title_bar : HBoxContainer（拖拽手柄，已含 title + close_btn）
##   close_btn : Button（✕，已 connect close_cb）
##   title     : Label（顶栏标题，可后续改文字）

const BG := Color(0.102, 0.078, 0.063, 0.98)
const BORDER := Color(0.78, 0.60, 0.28)
const TITLE_COL := Color(0.85, 0.66, 0.30)
const BODY_COL := Color(0.91, 0.866, 0.784)
const CLOSE_FG := Color(0.95, 0.55, 0.45)
const CLOSE_BG := Color(0.30, 0.16, 0.14, 0.85)
const CLOSE_BORDER := Color(0.85, 0.45, 0.35)


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

	# —— 顶栏（拖拽手柄）：标题 + 右上角 ✕ ——
	var title_bar := HBoxContainer.new()
	title_bar.name = "TitleBar"
	title_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	title_bar.add_theme_constant_override("separation", 10)
	title_bar.add_theme_constant_override("padding_top", 8)
	title_bar.add_theme_constant_override("padding_bottom", 8)
	title_bar.add_theme_constant_override("padding_left", 12)
	title_bar.add_theme_constant_override("padding_right", 10)
	card.add_child(title_bar)

	var title := Label.new()
	title.name = "Title"
	title.text = title_text
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", TITLE_COL)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 让拖拽落到 title_bar
	title_bar.add_child(title)

	var close_btn := Button.new()
	close_btn.name = "CloseBtn"
	close_btn.text = "✕"
	close_btn.tooltip_text = "关闭"
	close_btn.custom_minimum_size = Vector2(34, 34)
	close_btn.add_theme_font_size_override("font_size", 18)
	close_btn.add_theme_color_override("font_color", CLOSE_FG)
	var cb := StyleBoxFlat.new()
	cb.bg_color = CLOSE_BG
	cb.border_color = CLOSE_BORDER
	cb.set_corner_radius_all(5)
	close_btn.add_theme_stylebox_override("normal", cb)
	close_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	close_btn.pressed.connect(close_cb)
	title_bar.add_child(close_btn)

	# —— 内容区：Margin > Scroll > VBox ——
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(margin)

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

	return {"card": card, "body": body, "title_bar": title_bar, "close_btn": close_btn, "title": title}
