# ══════════════════════════════════════════════════════════════════════════════
#  PageDB.gd  —  Static Page Registry
#
#  Single source of truth for every navigable page: its scene path, display
#  title, and nav-button label.  Main.gd reads this at login time to build the
#  sidebar and page container dynamically — no invisible nodes, no PAGE_MAP.
#
#  Adding a new page
#  ─────────────────
#  1. Add an entry here.
#  2. Add the page key to the relevant role(s) in Auth.ROLE_PERMISSIONS.
#  That's it — Main will pick it up automatically.
#
#  Entry fields
#  ────────────
#    "title"  — shown in the top bar when the page is active
#    "nav"    — label on the sidebar button  (often shorter than title)
#    "scene"  — res:// path to the page's PackedScene
# ══════════════════════════════════════════════════════════════════════════════
class_name PageDB


const PAGES: Dictionary = {
	"dashboard": {
		"title": "Dashboard",
		"nav":   "  Dashboard",
		"scene": "res://src/Main/scenes/pages/Dashboard.tscn",
	},
	"catalog": {
		"title": "Book Catalog",
		"nav":   "  Book Catalog",
		"scene": "res://src/Main/scenes/pages/Catalog.tscn",
	},
	"addbook": {
		"title": "Add / Edit Book",
		"nav":   "  Add / Edit Book",
		"scene": "res://src/Main/scenes/pages/AddEditBook.tscn",
	},
	"sales": {
		"title": "Sales & Checkout",
		"nav":   "  Sales / Checkout",
		"scene": "res://src/Main/scenes/pages/Sales.tscn",
	},
	"customers": {
		"title": "Customers",
		"nav":   "  Customers",
		"scene": "res://src/Main/scenes/pages/Customers.tscn",
	},
	"reports": {
		"title": "Reports & Analytics",
		"nav":   "  Reports",
		"scene": "res://src/Main/scenes/pages/Reports.tscn",
	},
	"restock": {
		"title": "Restock Orders",
		"nav":   "  Restock Orders",
		"scene": "res://src/Main/scenes/pages/Restock.tscn",
	},
	"accountsettings": {
		"title": "Account Settings",
		"nav":   "  Account Settings",
		"scene": "res://src/Main/scenes/pages/AccountSettings.tscn",
	},
	"accountmanager": {
		"title": "Account Manager",
		"nav":   "  Account Manager",
		"scene": "res://src/Main/scenes/pages/AccountsManager.tscn",
	},
	"devtools": {
		"title": "Dev Tools",
		"nav":   "  Dev Tools",
		"scene": "res://src/Main/scenes/pages/DevTools.tscn",
	},
}
