extends Window

# ── Email tab ─────────────────────────────────────────────────────────────────
@onready var email_input:          LineEdit = $Margin/Layout/Tabs/Email/EmailInput
@onready var email_password_input: LineEdit = $Margin/Layout/Tabs/Email/EmailPasswordInput
@onready var email_sign_in_btn:    Button   = $Margin/Layout/Tabs/Email/EmailSignInBtn

# ── Username tab ──────────────────────────────────────────────────────────────
@onready var username_input:          LineEdit = $Margin/Layout/Tabs/Username/UsernameInput
@onready var username_password_input: LineEdit = $Margin/Layout/Tabs/Username/UsernamePasswordInput
@onready var username_sign_in_btn:    Button   = $Margin/Layout/Tabs/Username/UsernameSignInBtn

# ── Guest tab ─────────────────────────────────────────────────────────────────
@onready var guest_sign_in_btn: Button = $Margin/Layout/Tabs/Guest/GuestSignInBtn

# ── Shared ────────────────────────────────────────────────────────────────────
@onready var error_label: Label  = $Margin/Layout/ErrorLabel
@onready var logout_btn:  Button = $Margin/Layout/LogoutBtn


func _ready() -> void:
	# Show Log Out only when switching accounts
	logout_btn.visible = Auth.is_logged_in()

	# Email tab
	email_sign_in_btn.pressed.connect(_on_email_sign_in)
	email_input.text_submitted.connect(func(_t): _on_email_sign_in())
	email_password_input.text_submitted.connect(func(_t): _on_email_sign_in())

	# Username tab
	username_sign_in_btn.pressed.connect(_on_username_sign_in)
	username_input.text_submitted.connect(func(_t): _on_username_sign_in())
	username_password_input.text_submitted.connect(func(_t): _on_username_sign_in())

	# Guest tab
	guest_sign_in_btn.pressed.connect(_on_guest_sign_in)

	# Shared
	logout_btn.pressed.connect(_on_logout)
	close_requested.connect(_on_close_requested)

	# Default focus on email input
	email_input.grab_focus()


# ── Email login ───────────────────────────────────────────────────────────────

func _on_email_sign_in() -> void:
	_clear_error()
	var err := Auth.login(email_input.text, email_password_input.text)
	if err != "":
		_show_error(err)
		email_password_input.clear()
		email_password_input.grab_focus()
	else:
		queue_free()


# ── Username login ────────────────────────────────────────────────────────────

func _on_username_sign_in() -> void:
	_clear_error()
	var err := Auth.login_with_username(username_input.text, username_password_input.text)
	if err != "":
		_show_error(err)
		username_password_input.clear()
		username_password_input.grab_focus()
	else:
		queue_free()


# ── Guest login ───────────────────────────────────────────────────────────────

func _on_guest_sign_in() -> void:
	Auth.login_guest()
	queue_free()


# ── Logout ────────────────────────────────────────────────────────────────────

func _on_logout() -> void:
	Auth.logout()
	queue_free()


# ── Close guard ───────────────────────────────────────────────────────────────

func _on_close_requested() -> void:
	# Only allow closing if already logged in (switching accounts flow)
	if Auth.is_logged_in():
		queue_free()


# ── Helpers ───────────────────────────────────────────────────────────────────

func _show_error(msg: String) -> void:
	error_label.text    = "⚠ " + msg
	error_label.visible = true


func _clear_error() -> void:
	error_label.visible = false
