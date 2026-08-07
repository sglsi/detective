extends Control
class_name KnowledgeBasePanel

## KnowledgeBasePanel — 推理知识库 UI 面板（按《04_推理知识库.md》v3.2 接入）
##
## 纯代码构建（无 .tscn 依赖），全屏模态浮层。单例 + toggle 由 detective_scene.gd 管理，
## 本脚本只负责内部 UI 与 KnowledgeBaseSystem 交互，关闭时发 close_requested 信号。
##
## 布局：左侧 = 检索框 + 收藏/随机按钮 + 7 大主题域树(域→子主题)；
##       右侧 = 条目列表 / 详情视图（正文 + 交叉引用 + 收藏切换 + 笔记增删）。
## 难度差异化：检索走 DifficultyManager.difficulty（HARD 仅精确匹配标题+关键词）。

signal close_requested

const COL_GOLD := Color(0.85, 0.72, 0.40)
const COL_GOLD_LIGHT := Color(0.95, 0.85, 0.55)
const COL_PANEL := Color(0.10, 0.08, 0.05, 0.98)
const COL_PANEL_2 := Color(0.14, 0.11, 0.07, 0.97)
const COL_BORDER := Color(0.78, 0.62, 0.28)
const COL_TEXT := Color(0.90, 0.84, 0.70)
const COL_SUB := Color(0.62, 0.55, 0.42)

var _kb = null   # KnowledgeBaseSystem 引用（运行时赋值）

var _left_col: VBoxContainer
var _right_col: VBoxContainer
var _breadcrumb: Label
var _right_scroll: ScrollContainer
var _right_content: VBoxContainer
var _search_input: LineEdit

var _mode := "browse"          # browse | search | detail | favorites
var _cur_domain := ""
var _cur_subdomain := ""
var _cur_entry_id := ""

func _ready() -> void:
	if KnowledgeBaseSystem != null:
		_kb = KnowledgeBaseSystem
	_build_ui()
	if _kb != null:
		_show_browse("")
	else:
		_breadcrumb.text = "知识库模块未就绪"

# ===================== UI 构建 =====================

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_STOP

	# 背景遮罩（点击关闭）
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.0, 0.0, 0.0, 0.72)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(_on_backdrop_input)
	add_child(backdrop)

	# 主面板
	var main := PanelContainer.new()
	main.name = "MainPanel"
	main.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	main.custom_minimum_size = Vector2(1240, 780)
	main.size = Vector2(1240, 780)
	# 显式居中：PRESET_CENTER 在 size 赋值前已按零尺寸算出偏移（锚点居中、偏移0），
	# 之后 size 撑大导致面板从屏幕中心向右下溢出 → 视觉上「落在右下角」。
	# 手动按真实尺寸重设偏移，确保面板真正居中（与分辨率无关）。
	main.offset_left = -main.size.x * 0.5
	main.offset_top = -main.size.y * 0.5
	main.offset_right = main.size.x * 0.5
	main.offset_bottom = main.size.y * 0.5
	var mstyle := StyleBoxFlat.new()
	mstyle.bg_color = COL_PANEL
	mstyle.border_color = COL_BORDER
	mstyle.border_width_left = 2; mstyle.border_width_right = 2
	mstyle.border_width_top = 2; mstyle.border_width_bottom = 2
	mstyle.set_corner_radius_all(12)
	main.add_theme_stylebox_override("panel", mstyle)
	add_child(main)

	var vroot := VBoxContainer.new()
	vroot.add_theme_constant_override("separation", 8)
	main.add_child(vroot)

	# 标题栏
	var title_bar := HBoxContainer.new()
	title_bar.add_theme_constant_override("separation", 12)
	vroot.add_child(title_bar)
	var title := Label.new()
	title.text = "📚 推理知识库"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", COL_GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_bar.add_child(title)
	var close_btn := Button.new()
	close_btn.text = "✕ 关闭 (Esc)"
	close_btn.custom_minimum_size = Vector2(120, 36)
	close_btn.add_theme_color_override("font_color", COL_GOLD_LIGHT)
	close_btn.pressed.connect(func(): close_requested.emit())
	title_bar.add_child(close_btn)

	var sep := HSeparator.new()
	vroot.add_child(sep)

	# 主体：左列 + 右列
	var hbody := HBoxContainer.new()
	hbody.add_theme_constant_override("separation", 10)
	vroot.add_child(hbody)

	_left_col = VBoxContainer.new()
	_left_col.custom_minimum_size = Vector2(340, 0)
	_left_col.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hbody.add_child(_left_col)

	var vsep := VSeparator.new()
	hbody.add_child(vsep)

	_right_col = VBoxContainer.new()
	_right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbody.add_child(_right_col)

	_build_left()
	_build_right()

func _build_left() -> void:
	# 检索
	var s_lbl := Label.new()
	s_lbl.text = "🔍 关键词检索（多词空格分隔）"
	s_lbl.add_theme_font_size_override("font_size", 15)
	s_lbl.add_theme_color_override("font_color", COL_GOLD_LIGHT)
	_left_col.add_child(s_lbl)

	_search_input = LineEdit.new()
	_search_input.placeholder_text = "如：肤色 马车 毒物"
	_search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_input.text_submitted.connect(func(_t): _on_search())
	_left_col.add_child(_search_input)

	var s_row := HBoxContainer.new()
	s_row.add_theme_constant_override("separation", 8)
	_left_col.add_child(s_row)
	var search_btn := Button.new()
	search_btn.text = "检索"
	search_btn.pressed.connect(_on_search)
	s_row.add_child(search_btn)
	var rand_btn := Button.new()
	rand_btn.text = "🎲 随机翻阅"
	rand_btn.pressed.connect(_on_random)
	s_row.add_child(rand_btn)
	var fav_btn := Button.new()
	fav_btn.text = "★ 收藏夹"
	fav_btn.pressed.connect(_on_favorites)
	s_row.add_child(fav_btn)

	var sep1 := HSeparator.new()
	_left_col.add_child(sep1)

	# 主题域树
	var d_lbl := Label.new()
	d_lbl.text = "📖 主题域（点击展开子主题）"
	d_lbl.add_theme_font_size_override("font_size", 15)
	d_lbl.add_theme_color_override("font_color", COL_GOLD_LIGHT)
	_left_col.add_child(d_lbl)

	var tree_scroll := ScrollContainer.new()
	tree_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree_scroll.custom_minimum_size = Vector2(0, 360)
	_left_col.add_child(tree_scroll)
	var tree_box := VBoxContainer.new()
	tree_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree_scroll.add_child(tree_box)

	if _kb == null:
		return
	for dom_id in _kb.DOMAINS.keys():
		var dom: Dictionary = _kb.DOMAINS[dom_id]
		var dom_box := VBoxContainer.new()
		dom_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tree_box.add_child(dom_box)

		var dom_btn := Button.new()
		dom_btn.text = "%s  %s" % [dom_id, dom["name"]]
		dom_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		dom_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dom_btn.add_theme_color_override("font_color", COL_GOLD)
		dom_box.add_child(dom_btn)

		var sub_box := VBoxContainer.new()
		sub_box.visible = false
		sub_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dom_box.add_child(sub_box)
		for sub in dom["subdomains"]:
			var sub_btn := Button.new()
			sub_btn.text = "  · " + str(sub)
			sub_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			sub_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sub_btn.add_theme_color_override("font_color", COL_TEXT)
			sub_btn.pressed.connect(_show_browse.bind(dom_id, str(sub)))
			sub_box.add_child(sub_btn)

		dom_btn.pressed.connect(func(d=dom_id, sb=sub_box):
			_show_browse(d, "")
			sb.visible = not sb.visible
		)

func _build_right() -> void:
	_breadcrumb = Label.new()
	_breadcrumb.add_theme_font_size_override("font_size", 18)
	_breadcrumb.add_theme_color_override("font_color", COL_GOLD_LIGHT)
	_breadcrumb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_right_col.add_child(_breadcrumb)

	var sep2 := HSeparator.new()
	_right_col.add_child(sep2)

	_right_scroll = ScrollContainer.new()
	_right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_col.add_child(_right_scroll)

	_right_content = VBoxContainer.new()
	_right_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_scroll.add_child(_right_content)

# ===================== 浏览 / 列表 =====================

func _show_browse(domain_id: String, subdomain: String = "") -> void:
	if _kb == null:
		return
	_mode = "browse"
	_cur_domain = domain_id
	_cur_subdomain = subdomain
	_cur_entry_id = ""
	var list: Array = []
	if domain_id == "":
		list = _kb.entries.duplicate()
		_breadcrumb.text = "全部知识点（%d 条）" % list.size()
	elif subdomain != "":
		list = _kb.browse_subdomain(domain_id, subdomain)
		_breadcrumb.text = "%s › %s（%d 条）" % [_kb.domain_name(domain_id), subdomain, list.size()]
	else:
		list = _kb.browse_domain(domain_id)
		_breadcrumb.text = "%s（%d 条）" % [_kb.domain_name(domain_id), list.size()]
	_build_entry_list(list)

func _build_entry_list(list: Array) -> void:
	_clear_right()
	if list.is_empty():
		var empty := Label.new()
		empty.text = "（暂无条目）"
		empty.add_theme_color_override("font_color", COL_SUB)
		_clear_right_append(empty)
		return
	for item in list:
		var e: Dictionary = item if item is Dictionary else (item.get("entry", {}) if item is Dictionary else {})
		if e.is_empty():
			continue
		var card := _make_entry_card(e)
		_clear_right_append(card)

func _make_entry_card(e: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cstyle := StyleBoxFlat.new()
	cstyle.bg_color = COL_PANEL_2
	cstyle.border_color = COL_BORDER
	cstyle.border_width_left = 1; cstyle.border_width_right = 1
	cstyle.border_width_top = 1; cstyle.border_width_bottom = 1
	cstyle.set_corner_radius_all(8)
	card.add_theme_stylebox_override("panel", cstyle)

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(vb)

	var title := Label.new()
	title.text = "• " + str(e.get("title", ""))
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", COL_GOLD_LIGHT)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(title)

	var summary := Label.new()
	summary.text = str(e.get("summary", ""))
	summary.add_theme_font_size_override("font_size", 14)
	summary.add_theme_color_override("font_color", COL_TEXT)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(summary)

	var entry_id: String = e.get("id", "")
	var fav := Button.new()
	fav.text = "★ 收藏" if (_kb != null and _kb.is_favorite(entry_id)) else "☆ 收藏"
	fav.add_theme_color_override("font_color", COL_GOLD_LIGHT)
	fav.pressed.connect(_on_entry_clicked.bind(entry_id))
	vb.add_child(fav)
	return card

# ===================== 详情 =====================

func _on_entry_clicked(entry_id: String) -> void:
	_show_detail(entry_id)

func _show_detail(entry_id: String) -> void:
	if _kb == null:
		return
	var e: Dictionary = _kb.get_entry(entry_id)
	if e.is_empty():
		return
	_mode = "detail"
	_cur_entry_id = entry_id
	_clear_right()

	var title := Label.new()
	title.text = str(e.get("title", ""))
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", COL_GOLD)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_clear_right_append(title)

	var tags := Label.new()
	tags.text = "%s › %s    [%s]" % [_kb.domain_name(e.get("domain", "")), e.get("subdomain", ""), e.get("domain", "")]
	tags.add_theme_font_size_override("font_size", 14)
	tags.add_theme_color_override("font_color", COL_SUB)
	_clear_right_append(tags)

	# 收藏切换
	var fav := Button.new()
	var is_fav: bool = _kb.is_favorite(entry_id)
	fav.text = "★ 已收藏" if is_fav else "☆ 加入收藏"
	fav.add_theme_color_override("font_color", COL_GOLD_LIGHT)
	fav.pressed.connect(_on_toggle_fav.bind(entry_id))
	_clear_right_append(fav)

	# 正文
	var body := Label.new()
	body.text = str(e.get("body", ""))
	body.add_theme_font_size_override("font_size", 16)
	body.add_theme_color_override("font_color", COL_TEXT)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_clear_right_append(body)

	# 交叉引用
	var related: Array = _kb.get_related(entry_id)
	if not related.is_empty():
		var rel_lbl := Label.new()
		rel_lbl.text = "🔗 交叉引用："
		rel_lbl.add_theme_font_size_override("font_size", 15)
		rel_lbl.add_theme_color_override("font_color", COL_GOLD_LIGHT)
		_clear_right_append(rel_lbl)
		for re in related:
			var r: Dictionary = re
			var rbtn := Button.new()
			rbtn.text = "→ " + str(r.get("title", ""))
			rbtn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			rbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rbtn.add_theme_color_override("font_color", COL_TEXT)
			rbtn.pressed.connect(_show_detail.bind(r.get("id", "")))
			_clear_right_append(rbtn)

	# 笔记
	var note_lbl := Label.new()
	note_lbl.text = "📝 我的笔记："
	note_lbl.add_theme_font_size_override("font_size", 15)
	note_lbl.add_theme_color_override("font_color", COL_GOLD_LIGHT)
	_clear_right_append(note_lbl)

	var note_row := HBoxContainer.new()
	note_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_clear_right_append(note_row)
	var note_input := LineEdit.new()
	note_input.placeholder_text = "写下你的推理笔记…"
	note_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note_row.add_child(note_input)
	var add_btn := Button.new()
	add_btn.text = "添加"
	add_btn.pressed.connect(_on_add_note.bind(entry_id, note_input))
	note_row.add_child(add_btn)

	# 已有笔记列表
	var notes: Array = _kb.get_notes()
	for i in notes.size():
		var n: Dictionary = notes[i]
		if n.get("entry_id", "") == entry_id:
			var nb := HBoxContainer.new()
			nb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var nt := Label.new()
			nt.text = "· " + str(n.get("text", ""))
			nt.add_theme_font_size_override("font_size", 14)
			nt.add_theme_color_override("font_color", COL_TEXT)
			nt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			nt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			nb.add_child(nt)
			var del := Button.new()
			del.text = "删除"
			del.pressed.connect(_on_del_note.bind(i))
			nb.add_child(del)
			_clear_right_append(nb)

# ===================== 交互回调 =====================

func _on_search() -> void:
	if _kb == null:
		return
	var q := _search_input.text.strip_edges()
	if q == "":
		return
	_mode = "search"
	_cur_entry_id = ""
	var res: Array = _kb.search(q, _diff())
	_breadcrumb.text = "检索「%s」→ %d 条（难度差异化生效）" % [q, res.size()]
	_build_entry_list_from_results(res)

func _build_entry_list_from_results(res: Array) -> void:
	_clear_right()
	if res.is_empty():
		var empty := Label.new()
		empty.text = "（无匹配条目，试试更短的关键词）"
		empty.add_theme_color_override("font_color", COL_SUB)
		_clear_right_append(empty)
		return
	for r in res:
		var e: Dictionary = r.get("entry", {})
		if e.is_empty():
			continue
		var card := _make_entry_card(e)
		_clear_right_append(card)

func _on_random() -> void:
	if _kb == null:
		return
	var e: Dictionary = _kb.random_entry()
	if e.is_empty():
		return
	_show_detail(e.get("id", ""))

func _on_favorites() -> void:
	if _kb == null:
		return
	_mode = "favorites"
	_cur_entry_id = ""
	var fav_ids: Array = _kb.get_favorites()
	var list: Array = []
	for fid in fav_ids:
		var e: Dictionary = _kb.get_entry(fid)
		if not e.is_empty():
			list.append(e)
	_breadcrumb.text = "★ 收藏夹（%d 条）" % list.size()
	_build_entry_list(list)

func _on_toggle_fav(entry_id: String) -> void:
	if _kb == null:
		return
	_kb.toggle_favorite(entry_id)
	# 刷新当前视图（收藏夹视图需即时移除）
	if _mode == "favorites":
		_on_favorites()
	else:
		_show_detail(entry_id)

func _on_add_note(entry_id: String, input: LineEdit) -> void:
	if _kb == null:
		return
	var t := input.text.strip_edges()
	if t == "":
		return
	_kb.add_note(entry_id, t)
	input.text = ""
	_show_detail(entry_id)

func _on_del_note(index: int) -> void:
	if _kb == null:
		return
	var notes: Array = _kb.get_notes()
	if index < 0 or index >= notes.size():
		return
	notes.remove_at(index)
	# 通过 KnowledgeBaseSystem 无法单独删，重建 notes
	_kb.restore_notes(notes)
	_show_detail(_cur_entry_id)

# ===================== 工具 =====================

func _diff() -> int:
	if DifficultyManager != null:
		return int(DifficultyManager.current_difficulty)
	return 1

func _clear_right() -> void:
	for c in _right_content.get_children():
		c.queue_free()

func _clear_right_append(control: Control) -> void:
	_right_content.add_child(control)

func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close_requested.emit()

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo and k.keycode == KEY_ESCAPE:
			close_requested.emit()
