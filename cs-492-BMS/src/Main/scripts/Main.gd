extends Control

# ── Node references ────────────────────────────────────────────────────────────
@onready var page_title: Label       = $RootLayout/MainArea/TopBar/TopBarLayout/PageTitle
@onready var pages: Control          = $RootLayout/MainArea/PageContainer/Pages

@onready var nav_buttons: VBoxContainer = $RootLayout/Sidebar/SidebarLayout/NavButtons

# Map nav button names → page node names + display titles
const PAGE_MAP := {
	"dashboard": { "node": "Dashboard",   "title": "Dashboard",          "button": "NavDashboard" },
	"catalog":   { "node": "Catalog",     "title": "Book Catalog",       "button": "NavCatalog"   },
	"addbook":   { "node": "AddEditBook", "title": "Add / Edit Book",    "button": "NavAddBook"   },
	"sales":     { "node": "Sales",       "title": "Sales & Checkout",   "button": "NavSales"     },
	"customers": { "node": "Customers",   "title": "Customers",          "button": "NavCustomers" },
	"reports":   { "node": "Reports",     "title": "Reports & Analytics","button": "NavReports"   },
}

# ── Ready ──────────────────────────────────────────────────────────────────────
func _ready() -> void:
	# Connect every nav button's pressed signal
	for btn in nav_buttons.get_children():
		if btn is Button:
			btn.pressed.connect(_on_nav_pressed.bind(btn.name))

	# Select Dashboard by default
	var default_btn := nav_buttons.get_node("NavDashboard") as Button
	default_btn.button_pressed = true
	_navigate("NavDashboard")

# ── Navigation ─────────────────────────────────────────────────────────────────
func _on_nav_pressed(btn_name: String) -> void:
	_navigate(btn_name.trim_prefix("Nav").to_lower())

func _navigate(key: String) -> void:
	if not PAGE_MAP.has(key):
		return

	var info: Dictionary = PAGE_MAP[key]

	# Hide all pages, show the target
	for child in pages.get_children():
		child.visible = false

	var target := pages.get_node(info["node"]) as Control
	if target:
		target.visible = true

	page_title.text = info["title"]

# ── Called by child pages that need to trigger navigation ─────────────────────
# e.g.  get_owner().navigate_to("addbook")  from Catalog page
func navigate_to(key: String) -> void:
	_navigate(key)

	# Sync the sidebar toggle button using the explicit button name from PAGE_MAP
	if not PAGE_MAP.has(key):
		return
	var btn_name: String = PAGE_MAP[key]["button"]
	var btn := nav_buttons.get_node_or_null(btn_name) as Button
	if btn:
		btn.button_pressed = true
