extends VBoxContainer

# ══════════════════════════════════════════════════════════════════════════════
#  AccountSettings.gd  —  Page Script
#  Lets a logged-in customer view and edit their account information.
# ══════════════════════════════════════════════════════════════════════════════

# ── Profile section ───────────────────────────────────────────────────────────
@onready var name_input:     LineEdit = $Scroll/Sections/Profile/Card/Fields/NameInput
@onready var email_input:    LineEdit = $Scroll/Sections/Profile/Card/Fields/EmailInput
@onready var username_input: LineEdit = $Scroll/Sections/Profile/Card/Fields/UsernameInput
@onready var profile_error:  Label    = $Scroll/Sections/Profile/Card/ProfileError
@onready var profile_ok:     Label    = $Scroll/Sections/Profile/Card/ProfileOk
@onready var save_profile_btn: Button = $Scroll/Sections/Profile/Card/SaveProfileBtn

# ── Password section ──────────────────────────────────────────────────────────
@onready var current_pw_input:  LineEdit = $Scroll/Sections/Password/Card/Fields/CurrentPwInput
@onready var new_pw_input:      LineEdit = $Scroll/Sections/Password/Card/Fields/NewPwInput
@onready var confirm_pw_input:  LineEdit = $Scroll/Sections/Password/Card/Fields/ConfirmPwInput
@onready var password_error:    Label    = $Scroll/Sections/Password/Card/PasswordError
@onready var password_ok:       Label    = $Scroll/Sections/Password/Card/PasswordOk
@onready var save_password_btn: Button   = $Scroll/Sections/Password/Card/SavePasswordBtn


func _ready() -> void:
	_populate_profile()
	Auth.session_changed.connect(_on_session_changed)
	save_profile_btn.pressed.connect(_on_save_profile)
	save_password_btn.pressed.connect(_on_save_password)

	# Allow submitting with Enter from the last field in each section.
	username_input.text_submitted.connect(func(_t): _on_save_profile())
	confirm_pw_input.text_submitted.connect(func(_t): _on_save_password())

	# Dismiss feedback labels when the user starts typing again.
	for field in [name_input, email_input, username_input]:
		field.text_changed.connect(func(_t): _clear_profile_feedback())
	for field in [current_pw_input, new_pw_input, confirm_pw_input]:
		field.text_changed.connect(func(_t): _clear_password_feedback())


func _on_session_changed(_account: Dictionary) -> void:
	_populate_profile()
	_clear_profile_feedback()
	_clear_password_feedback()
	current_pw_input.clear()
	new_pw_input.clear()
	confirm_pw_input.clear()


func _populate_profile() -> void:
	var acc := Auth.get_current_account()
	name_input.text     = acc.get("name",     "")
	email_input.text    = acc.get("email",    "") if acc.get("email",    null) != null else ""
	username_input.text = acc.get("username", "") if acc.get("username", null) != null else ""


# ── Handlers ──────────────────────────────────────────────────────────────────

func _on_save_profile() -> void:
	_clear_profile_feedback()
	var account_id: int = Auth.get_current_account().get("id", -1)
	var err := Auth.update_account(
		account_id,
		name_input.text,
		email_input.text,
		username_input.text
	)
	if err != "":
		profile_error.text    = err
		profile_error.visible = true
	else:
		profile_ok.visible = true


func _on_save_password() -> void:
	_clear_password_feedback()
	var account_id: int = Auth.get_current_account().get("id", -1)
	var err := Auth.update_password(
		account_id,
		current_pw_input.text,
		new_pw_input.text,
		confirm_pw_input.text
	)
	if err != "":
		password_error.text    = err
		password_error.visible = true
	else:
		password_ok.visible = true
		current_pw_input.clear()
		new_pw_input.clear()
		confirm_pw_input.clear()


# ── Helpers ───────────────────────────────────────────────────────────────────

func _clear_profile_feedback() -> void:
	profile_error.visible = false
	profile_ok.visible    = false


func _clear_password_feedback() -> void:
	password_error.visible = false
	password_ok.visible    = false
