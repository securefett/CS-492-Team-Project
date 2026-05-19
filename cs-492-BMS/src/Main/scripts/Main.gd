extends Control

@onready var page_title:   Label          = $RootLayout/MainArea/TopBar/TopBarLayout/PageTitle
@onready var pages:        Control        = $RootLayout/MainArea/PageContainer/Pages
@onready var nav_buttons:  VBoxContainer  = $RootLayout/Sidebar/SidebarLayout/NavButtons
@onready var footer_btn:   Button         = $RootLayout/Sidebar/SidebarLayout/FooterBtn
@onready var user_label:   Label          = $RootLayout/MainArea/TopBar/TopBarLayout/UserLabel

const PAGE_MAP := {
	"dashboard": { "node": "Dashboard",   "title": "Dashboard",           "button": "NavDashboard" },
	"catalog":   { "node": "Catalog",     "title": "Book Catalog",        "button": "NavCatalog"   },
	"addbook":   { "node": "AddEditBook", "title": "Add / Edit Book",     "button": "NavAddBook"   },
	"sales":     { "node": "Sales",       "title": "Sales & Checkout",    "button": "NavSales"     },
	"customers": { "node": "Customers",   "title": "Customers",           "button": "NavCustomers" },
	"reports":   { "node": "Reports",     "title": "Reports & Analytics", "button": "NavReports"   },
	"restock":   { "node": "Restock",     "title": "Restock Orders",      "button": "NavRestock"   },
	"devtools":  { "node": "DevTools",    "title": "Dev Tools",          "button": "NavDevTools"   },
}

func _ready() -> void:
	for btn in nav_buttons.get_children():
		if btn is Button:
			btn.pressed.connect(_on_nav_pressed.bind(btn.name))

	footer_btn.pressed.connect(_open_login_dialog)
	Auth.session_changed.connect(_on_session_changed)

	# Show login immediately on launch — nothing is accessible without an account
	_update_sidebar_for_role()
	_open_login_dialog()


# ── Navigation ────────────────────────────────────────────────────────────────

func _on_nav_pressed(btn_name: String) -> void:
	var key := btn_name.trim_prefix("Nav").to_lower()
	if not Auth.has_permission(key):
		return
	_navigate(key)


func _navigate(key: String) -> void:
	if not PAGE_MAP.has(key):
		push_warning("Main._navigate: unknown page key '%s'" % key)
		return

	var info: Dictionary = PAGE_MAP[key]

	for child in pages.get_children():
		child.visible = false

	var target := pages.get_node(info["node"]) as Control
	if target:
		target.visible = true

	page_title.text = info["title"]


func navigate_to(key: String) -> void:
	if not Auth.has_permission(key):
		push_warning("navigate_to: role '%s' does not have permission for '%s'" % [Auth.get_role(), key])
		return
	_navigate(key)
	if not PAGE_MAP.has(key):
		return
	var btn := nav_buttons.get_node_or_null(PAGE_MAP[key]["button"]) as Button
	if btn:
		btn.button_pressed = true


# ── Session ───────────────────────────────────────────────────────────────────

func _on_session_changed(account: Dictionary) -> void:
	_update_sidebar_for_role()

	if account.is_empty():
		# Logged out — reopen login
		user_label.text    = "Guest"
		footer_btn.text    = "v1.0  ·  Log in"
		_open_login_dialog()
		return

	var role := Auth.get_role()
	user_label.text = "%s  👤" % Auth.get_account_name()
	if Auth.is_guest():
		footer_btn.text = "v1.0  ·  Guest  ·  Sign in"
	else:
		footer_btn.text = "v1.0  ·  %s  ·  %s" % [Auth.get_account_name(), role.capitalize()]

	# Navigate to the first permitted page for this role
	var permitted := Auth.get_permitted_pages()
	if permitted.size() > 0:
		var first_key: String = permitted[0]
		_navigate(first_key)
		var btn := nav_buttons.get_node_or_null(PAGE_MAP[first_key]["button"]) as Button
		if btn:
			btn.button_pressed = true


func _update_sidebar_for_role() -> void:
	var permitted := Auth.get_permitted_pages()
	for btn in nav_buttons.get_children():
		if btn is Button:
			var key := btn.name.trim_prefix("Nav").to_lower()
			btn.visible = key in permitted


const LoginDialogScene := preload("res://src/Main/scenes/notpages/LoginDialog.tscn")


# ── Login dialog ──────────────────────────────────────────────────────────────

func _open_login_dialog() -> void:
	if get_node_or_null("LoginDialog"):
		return
	var dialog := LoginDialogScene.instantiate()
	dialog.name = "LoginDialog"
	add_child(dialog)
	dialog.popup_centered()
