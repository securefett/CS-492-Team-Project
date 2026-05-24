extends VBoxContainer

# ══════════════════════════════════════════════════════════════════════════════
#  AccountsManager.gd  —  Page Script  (Admin only)
#  Displays all accounts in a card grid with search, edit, and delete.
# ══════════════════════════════════════════════════════════════════════════════

const ROLE_OPTIONS    := ["admin", "employee", "customer"]
const AccountCardScene := preload("res://src/Main/scenes/notpages/AccountCard.tscn")

@onready var search_box:    LineEdit      = $Toolbar/SearchBox
@onready var add_btn:       Button        = $Toolbar/AddAccountBtn
@onready var card_grid:     GridContainer = $Scroll/CardGrid
@onready var edit_dialog:    Window  = $EditDialog
@onready var confirm_dialog: Window  = $ConfirmDialog
@onready var confirm_label:  Label   = $ConfirmDialog/Margin/Layout/ConfirmLabel
@onready var confirm_yes_btn: Button = $ConfirmDialog/Margin/Layout/Buttons/YesBtn
@onready var confirm_no_btn:  Button = $ConfirmDialog/Margin/Layout/Buttons/NoBtn

# ── Edit dialog nodes ─────────────────────────────────────────────────────────
@onready var dialog_title:      Label    = $EditDialog/Margin/Layout/DialogTitle
@onready var d_name_input:      LineEdit = $EditDialog/Margin/Layout/Fields/NameInput
@onready var d_email_input:     LineEdit = $EditDialog/Margin/Layout/Fields/EmailInput
@onready var d_username_input:  LineEdit = $EditDialog/Margin/Layout/Fields/UsernameInput
@onready var d_role_option:     OptionButton = $EditDialog/Margin/Layout/Fields/RoleOption
@onready var d_password_input:  LineEdit = $EditDialog/Margin/Layout/Fields/PasswordInput
@onready var d_confirm_input:   LineEdit = $EditDialog/Margin/Layout/Fields/ConfirmInput
@onready var d_pw_section:      Label    = $EditDialog/Margin/Layout/PwSectionLabel
@onready var d_error_label:     Label    = $EditDialog/Margin/Layout/ErrorLabel
@onready var d_save_btn:        Button   = $EditDialog/Margin/Layout/Buttons/SaveBtn
@onready var d_cancel_btn:      Button   = $EditDialog/Margin/Layout/Buttons/CancelBtn

var _editing_id:          int    = -1   # -1 means creating a new account
var _pending_delete_id:   int    = -1
var _pending_delete_name: String = ""


func _ready() -> void:
	_build_role_options()
	search_box.text_changed.connect(_on_search_changed)
	add_btn.pressed.connect(_on_add_pressed)
	d_save_btn.pressed.connect(_on_dialog_save)
	d_cancel_btn.pressed.connect(_close_dialog)
	edit_dialog.close_requested.connect(_close_dialog)
	confirm_yes_btn.pressed.connect(_on_confirm_delete)
	confirm_no_btn.pressed.connect(_close_confirm)
	confirm_dialog.close_requested.connect(_close_confirm)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree():
		_refresh()


# ── Card grid ─────────────────────────────────────────────────────────────────

func _refresh(filter: String = "") -> void:
	for child in card_grid.get_children():
		child.queue_free()

	var accounts := Auth.get_all_accounts()
	var q := filter.strip_edges().to_lower()

	for acc in accounts:
		if q != "" and not (acc["display_name"].to_lower().contains(q)
				or str(acc.get("email",    "")).to_lower().contains(q)
				or str(acc.get("username", "")).to_lower().contains(q)):
			continue
		_make_card(acc)


func _make_card(acc: Dictionary) -> PanelContainer:
	var card: AccountCard = AccountCardScene.instantiate()
	card_grid.add_child(card)
	card.setup(acc, Auth.get_current_account().get("id", -2))
	card.edit_requested.connect(_on_edit_pressed)
	card.delete_requested.connect(_on_delete_pressed)
	return card


# ── Dialog ────────────────────────────────────────────────────────────────────

func _build_role_options() -> void:
	d_role_option.clear()
	for r in ROLE_OPTIONS:
		d_role_option.add_item(r.capitalize())


func _open_dialog_for_new() -> void:
	_editing_id             = -1
	dialog_title.text       = "Add Account"
	d_name_input.text       = ""
	d_email_input.text      = ""
	d_username_input.text   = ""
	d_password_input.text   = ""
	d_confirm_input.text    = ""
	d_pw_section.text       = "Password"
	d_password_input.placeholder_text = "Required"
	d_role_option.selected  = ROLE_OPTIONS.find("customer")
	d_error_label.visible   = false
	edit_dialog.popup_centered()
	d_name_input.grab_focus()


func _open_dialog_for_edit(acc: Dictionary) -> void:
	_editing_id            = acc.get("id", -1)
	dialog_title.text      = "Edit Account"
	d_name_input.text      = acc.get("display_name", "")
	d_email_input.text     = acc.get("email",    "") if acc.get("email",    null) != null else ""
	d_username_input.text  = acc.get("username", "") if acc.get("username", null) != null else ""
	d_password_input.text  = ""
	d_confirm_input.text   = ""
	d_pw_section.text      = "New Password (leave blank to keep current)"
	d_password_input.placeholder_text = "Leave blank to keep current"
	var role_idx := ROLE_OPTIONS.find(acc.get("role", "customer"))
	d_role_option.selected = role_idx if role_idx >= 0 else 0
	d_error_label.visible  = false
	edit_dialog.popup_centered()
	d_name_input.grab_focus()
	# TODO: if you want admins to edit phone/notes for customer-role accounts,
	# add PhoneInput and NotesInput fields to the EditDialog scene and wire them
	# up here, then pass them through to a new Auth.update_account_details()
	# function or directly via BookStore.update_customer().


func _close_dialog() -> void:
	edit_dialog.hide()


# ── Handlers ──────────────────────────────────────────────────────────────────

func _on_search_changed(text: String) -> void:
	_refresh(text)


func _on_add_pressed() -> void:
	_open_dialog_for_new()


func _on_edit_pressed(acc: Dictionary) -> void:
	_open_dialog_for_edit(acc)


func _on_delete_pressed(account_id: int, account_name: String) -> void:
	_pending_delete_id   = account_id
	_pending_delete_name = account_name
	confirm_label.text   = "Delete account \"" + account_name + "\"? This cannot be undone."
	confirm_dialog.popup_centered()


func _on_confirm_delete() -> void:
	var err := Auth.delete_account(_pending_delete_id)
	if err != "":
		push_warning("AccountsManager: delete failed — " + err)
	_pending_delete_id   = -1
	_pending_delete_name = ""
	_close_confirm()
	_refresh(search_box.text)


func _close_confirm() -> void:
	confirm_dialog.hide()


func _on_dialog_save() -> void:
	d_error_label.visible = false
	var name     := d_name_input.text
	var email    := d_email_input.text
	var username := d_username_input.text
	var password := d_password_input.text
	var confirm  := d_confirm_input.text
	var role: String = ROLE_OPTIONS[d_role_option.selected]

	var err := ""

	if _editing_id == -1:
		# ── Create ────────────────────────────────────────────────────────────
		if password != confirm:
			err = "Passwords do not match."
		else:
			err = Auth.add_account(name, email, username, password, role)
	else:
		# ── Update profile ────────────────────────────────────────────────────
		err = Auth.update_account(_editing_id, name, email, username)
		# Update role separately (guarded inside Auth against self-demotion).
		if err == "":
			err = Auth.update_account_role(_editing_id, role)
		# Update password only if the admin typed something.
		if err == "" and password != "":
			if password != confirm:
				err = "Passwords do not match."
			elif password.length() < 6:
				err = "Password must be at least 6 characters."
			else:
				# Admin override: bypass current-password check.
				Auth._db.query_with_bindings(
					"UPDATE accounts SET password = ? WHERE id = ?;",
					[password, _editing_id]
				)

	if err != "":
		d_error_label.text    = err
		d_error_label.visible = true
	else:
		_close_dialog()
		_refresh(search_box.text)
