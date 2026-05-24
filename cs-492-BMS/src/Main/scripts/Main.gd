extends Control

@onready var page_title:  Label         = $RootLayout/MainArea/TopBar/TopBarLayout/PageTitle
@onready var pages:       Control       = $RootLayout/MainArea/PageContainer/Pages
@onready var nav_buttons: VBoxContainer = $RootLayout/Sidebar/SidebarLayout/NavButtons
@onready var footer_btn:  Button        = $RootLayout/Sidebar/SidebarLayout/FooterBtn
@onready var user_label:  Label         = $RootLayout/MainArea/TopBar/TopBarLayout/UserLabel

# Shared ButtonGroup so nav buttons behave as a radio set, matching the
# toggle_mode / button_group setup that was in the scene.
var _nav_group := ButtonGroup.new()

# Tracks which page key is currently shown — used to restore button state
# after a rebuild.
var _active_key := ""


func _ready() -> void:
	footer_btn.pressed.connect(_open_login_dialog)
	Auth.session_changed.connect(_on_session_changed)

	# Nothing is accessible without an account; build an empty sidebar and
	# open the login dialog straight away.
	_rebuild_nav_and_pages()
	_open_login_dialog()


# ── Session ───────────────────────────────────────────────────────────────────

func _on_session_changed(account: Dictionary) -> void:
	if account.is_empty():
		user_label.text  = "Guest"
		footer_btn.text  = "v1.0  ·  Log in"
		_rebuild_nav_and_pages()
		_open_login_dialog()
		return

	var role := Auth.get_role()
	user_label.text = "%s  👤" % Auth.get_account_name()
	if Auth.is_guest():
		footer_btn.text = "v1.0  ·  Guest  ·  Sign in"
	else:
		footer_btn.text = "v1.0  ·  %s  ·  %s" % [Auth.get_account_name(), role.capitalize()]

	_rebuild_nav_and_pages()

	# Navigate to the first permitted page for this role.
	var permitted := Auth.get_permitted_pages()
	if permitted.size() > 0:
		_navigate(permitted[0])


# ── Build ─────────────────────────────────────────────────────────────────────

func _rebuild_nav_and_pages() -> void:
	# ── Tear down previous session's nodes ────────────────────────────────────
	for child in nav_buttons.get_children():
		child.queue_free()
	for child in pages.get_children():
		child.queue_free()

	_active_key = ""
	page_title.text = ""

	# ── Build only the pages this role is permitted to see ────────────────────
	var permitted := Auth.get_permitted_pages()

	for key in permitted:
		if not PageDB.PAGES.has(key):
			push_warning("Main._rebuild: key '%s' is in Auth permissions but missing from PageDB.PAGES" % key)
			continue

		var info: Dictionary = PageDB.PAGES[key]

		# Page node
		var packed := load(info["scene"]) as PackedScene
		if packed == null:
			push_error("Main._rebuild: could not load scene for '%s': %s" % [key, info["scene"]])
			continue

		var page := packed.instantiate() as Control
		page.name    = key
		page.visible = false
		# Match the full-rect anchor layout used in the original scene.
		page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pages.add_child(page)

		# Nav button
		var btn        := Button.new()
		btn.name        = "Nav_" + key
		btn.text        = info["nav"]
		btn.toggle_mode = true
		btn.button_group = _nav_group
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_navigate.bind(key))
		nav_buttons.add_child(btn)


# ── Navigation ────────────────────────────────────────────────────────────────

func _navigate(key: String) -> void:
	if not Auth.has_permission(key):
		push_warning("Main._navigate: role '%s' does not have permission for '%s'" % [Auth.get_role(), key])
		return

	if not PageDB.PAGES.has(key):
		push_warning("Main._navigate: unknown page key '%s'" % key)
		return

	# Hide all pages, show the target.
	for child in pages.get_children():
		child.visible = false

	var target := pages.get_node_or_null(key) as Control
	if target:
		target.visible = true
	else:
		push_error("Main._navigate: page node '%s' not found — was it built?" % key)
		return

	page_title.text = PageDB.PAGES[key]["title"]
	_active_key     = key

	# Keep the matching nav button pressed.
	var btn := nav_buttons.get_node_or_null("Nav_" + key) as Button
	if btn:
		btn.button_pressed = true


# Public entry point used by child pages that need to trigger navigation
# (e.g. "Go to Catalog" links inside Dashboard).
func navigate_to(key: String) -> void:
	_navigate(key)


# ── Login dialog ──────────────────────────────────────────────────────────────

const LoginDialogScene := preload("res://src/Main/scenes/notpages/LoginDialog.tscn")

func _open_login_dialog() -> void:
	if get_node_or_null("LoginDialog"):
		return
	var dialog := LoginDialogScene.instantiate()
	dialog.name = "LoginDialog"
	add_child(dialog)
	dialog.popup_centered()
