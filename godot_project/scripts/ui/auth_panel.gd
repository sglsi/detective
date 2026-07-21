extends Control
class_name AuthPanel

## AuthPanel — 注册 / 登录面板
## 主菜单「注册 / 登录」入口的 UI，对接 AuthManager（/api/auth/* 端点）。
## 修复 Issue 3：原先 AuthManager 仅有逻辑、无 UI 入口；本面板补齐玩家侧注册/登录。

var _mode: String = "register"   # "register" 或 "login"
var _panel: Panel
var _title_label: Label
var _username_edit: LineEdit
var _email_edit: LineEdit
var _password_edit: LineEdit
var _phone_edit: LineEdit
var _submit_btn: Button
var _mode_btn: Button
var _status_label: Label

func _ready() -> void:
	_build_ui()
	_connect_auth()

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	_panel = Panel.new()
	_panel.size = Vector2(560, 540)
	_panel.position = Vector2(1920 / 2 - 280, 1080 / 2 - 270)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.08, 0.05, 0.98)
	sb.border_color = Color(0.6, 0.45, 0.2, 1.0)
	sb.border_width_left = 3
	sb.border_width_right = 3
	sb.border_width_top = 3
	sb.border_width_bottom = 3
	sb.set_corner_radius_all(12)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	_title_label = Label.new()
	_title_label.text = "📝 注册账号"
	_title_label.position = Vector2(30, 24)
	_title_label.add_theme_font_size_override("font_size", 30)
	_title_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4, 1.0))
	_panel.add_child(_title_label)

	var vbox = VBoxContainer.new()
	vbox.position = Vector2(40, 90)
	vbox.size = Vector2(480, 360)
	vbox.add_theme_constant_override("separation", 14)
	_panel.add_child(vbox)

	_username_edit = _make_field("用户名", false)
	_email_edit = _make_field("邮箱（登录账号）", false)
	_password_edit = _make_field("密码", true)
	_phone_edit = _make_field("手机号（选填）", false)
	vbox.add_child(_username_edit)
	vbox.add_child(_email_edit)
	vbox.add_child(_password_edit)
	vbox.add_child(_phone_edit)

	_status_label = Label.new()
	_status_label.text = ""
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.size = Vector2(480, 40)
	_status_label.add_theme_font_size_override("font_size", 16)
	_status_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.4, 1.0))
	vbox.add_child(_status_label)

	_submit_btn = Button.new()
	_submit_btn.text = "注册"
	_submit_btn.size = Vector2(480, 56)
	_submit_btn.add_theme_font_size_override("font_size", 22)
	_submit_btn.pressed.connect(_on_submit_pressed)
	vbox.add_child(_submit_btn)

	_mode_btn = Button.new()
	_mode_btn.text = "已有账号？去登录"
	_mode_btn.size = Vector2(480, 44)
	_mode_btn.add_theme_font_size_override("font_size", 18)
	_mode_btn.pressed.connect(_on_toggle_mode)
	vbox.add_child(_mode_btn)

	var back_btn = Button.new()
	back_btn.text = "返回主菜单"
	back_btn.position = Vector2(40, 470)
	back_btn.size = Vector2(480, 44)
	back_btn.pressed.connect(func(): queue_free())
	_panel.add_child(back_btn)

	# 依据当前 _mode 应用界面（解决 set_mode 在 _ready 前调用导致登录页显示成注册页的问题）
	_apply_mode()

func _make_field(placeholder: String, secret: bool) -> LineEdit:
	var ed = LineEdit.new()
	ed.placeholder_text = placeholder
	ed.size = Vector2(480, 48)
	ed.secret = secret
	ed.add_theme_font_size_override("font_size", 20)
	return ed

func _connect_auth() -> void:
	if AuthManager:
		AuthManager.registration_success.connect(_on_registration_success)
		AuthManager.login_success.connect(_on_login_success)
		AuthManager.login_failed.connect(_on_login_failed)
		AuthManager.registration_failed.connect(_on_registration_failed)

func _on_toggle_mode() -> void:
	if _mode == "register":
		_mode = "login"
	else:
		_mode = "register"
	_apply_mode()

## 由外部（主菜单）直接设定模式
func set_mode(m: String) -> void:
	_mode = "register" if m != "login" else "login"
	_apply_mode()

## 根据当前 _mode 刷新所有模式相关 UI
## 节点尚未创建（_ready 之前被调用）时安全跳过，_build_ui 末尾会再次调用
func _apply_mode() -> void:
	if not is_instance_valid(_title_label):
		return
	if _mode == "login":
		_title_label.text = "🔑 登录账号"
		_submit_btn.text = "登录"
		_mode_btn.text = "没有账号？去注册"
		_username_edit.visible = false
		_phone_edit.visible = false
	else:
		_title_label.text = "📝 注册账号"
		_submit_btn.text = "注册"
		_mode_btn.text = "已有账号？去登录"
		_username_edit.visible = true
		_phone_edit.visible = true
	_status_label.text = ""

func _on_submit_pressed() -> void:
	# 防止重复点击（按钮已禁用时直接返回）
	if _submit_btn.disabled:
		return
	var email = _email_edit.text.strip_edges()
	var password = _password_edit.text
	if email == "" or password == "":
		_status_label.text = "请填写邮箱与密码"
		return
	_submit_btn.disabled = true
	_status_label.text = "正在提交…"

	# 独立看门狗：网络层（HTTPRequest）在个别 Web/WASM 环境下可能既不返回成功也不返回
	# 失败回调，导致面板永久卡在“正在提交…”。这里设 18s 兜底（略大于 APIManager 内部
	# 15s 超时）——若届时状态仍是“正在提交…”，强制恢复按钮并给出可操作提示。
	var settled := false
	var watchdog = get_tree().create_timer(18.0)
	watchdog.timeout.connect(func():
		if settled:
			return
		settled = true
		_submit_btn.disabled = false
		if _status_label.text == "正在提交…":
			_status_label.text = "请求超时：请确认后端已启动，并刷新页面后重试"
	)

	# 成功/失败信号到达时解除看门狗
	var _on_done = func(_a = null, _b = null):
		settled = true
	AuthManager.registration_success.connect(_on_done, CONNECT_ONE_SHOT)
	AuthManager.registration_failed.connect(_on_done, CONNECT_ONE_SHOT)
	AuthManager.login_success.connect(_on_done, CONNECT_ONE_SHOT)
	AuthManager.login_failed.connect(_on_done, CONNECT_ONE_SHOT)

	# 网络层 fire-and-forget；按钮解禁由上面的信号/看门狗负责，确保永不卡死。
	if _mode == "register":
		var username = _username_edit.text.strip_edges()
		var phone = _phone_edit.text.strip_edges()
		if username == "":
			username = email.split("@")[0]
		AuthManager.register(username, email, password, phone)
	else:
		AuthManager.login(email, password)

func _on_registration_success(_user_id: String, username: String) -> void:
	_status_label.text = "注册成功，欢迎 " + username + "！"
	_submit_btn.disabled = false
	_show_result_and_close("✅ 注册成功：" + username)

func _on_login_success(_user_id: String, username: String) -> void:
	_status_label.text = "登录成功，欢迎回来 " + username + "！"
	_submit_btn.disabled = false
	_show_result_and_close("✅ 登录成功：" + username)

func _on_login_failed(error: String) -> void:
	_status_label.text = "操作失败：" + error
	_submit_btn.disabled = false

func _on_registration_failed(error: String) -> void:
	_status_label.text = "操作失败：" + error
	_submit_btn.disabled = false

func _show_result_and_close(msg: String) -> void:
	if UIManager:
		UIManager.show_notification(msg)
	# 稍作延迟让玩家看到成功提示，再关闭面板
	await get_tree().create_timer(1.0).timeout
	queue_free()
