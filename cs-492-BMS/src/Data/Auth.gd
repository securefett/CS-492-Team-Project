extends Node

# ══════════════════════════════════════════════════════════════════════════════
#  Auth.gd  —  Autoload Singleton
#  Manages accounts, login sessions, and page-level permissions.
#
#  The `accounts` table is now the single source of truth for both auth and
#  customer data. Customer rows are simply accounts with role = 'customer'.
#
#  Setup:
#    Project → Project Settings → Autoload
#    → Add this file as "Auth"  (list it FIRST, before BookStore)
#
#  Default accounts (all passwords are "password" for development):
#    admin@bookstore.com     / username: admin     — Admin
#    employee@bookstore.com  / username: employee  — Employee
#    customer@bookstore.com  / username: customer  — Customer
#
#  Guest login requires no credentials and has Customer-level permissions.
# ══════════════════════════════════════════════════════════════════════════════

signal session_changed(account: Dictionary)

# ── Permission map ────────────────────────────────────────────────────────────
const ROLE_PERMISSIONS := {
	"admin": [
		"dashboard",
		"catalog",
		"addbook",
		"sales",
		"customers",
		"accounts",
		"reports",
		"restock",
		"accountmanager",
		"accountsettings",
		"devtools"
	],
	"employee": [
		"dashboard",
		"catalog",
		"sales",
		"customers",
		"accountsettings",
	],
	"customer": [
		"catalog",
		"accountsettings",
	],
	"guest": [
		"catalog",
	],
}

# ── State ─────────────────────────────────────────────────────────────────────

var _current_account: Dictionary = {}
var _db: SQLite


func _ready() -> void:
	_db = SQLite.new()
	_db.path = "user://bookstore.db"
	_db.verbosity_level = SQLite.QUIET
	_db.open_db()
	_ensure_schema()
	_seed_accounts()


func _exit_tree() -> void:
	_db.close_db()


# ── Schema ────────────────────────────────────────────────────────────────────
# BookStore.gd owns CREATE TABLE for `accounts`; Auth only runs additive
# migrations to avoid a race on first launch.

func _ensure_schema() -> void:
	# Add any columns that older DBs may be missing.
	_db.query("PRAGMA table_info(accounts);")
	var cols := _db.query_result.map(func(c): return c["name"])

	if not "username" in cols:
		_db.query("ALTER TABLE accounts ADD COLUMN username TEXT UNIQUE;")
	if not "password" in cols:
		_db.query("ALTER TABLE accounts ADD COLUMN password TEXT NOT NULL DEFAULT '';")
	if not "role" in cols:
		_db.query("ALTER TABLE accounts ADD COLUMN role TEXT NOT NULL DEFAULT 'customer';")
	if not "phone" in cols:
		_db.query("ALTER TABLE accounts ADD COLUMN phone TEXT;")
	if not "notes" in cols:
		_db.query("ALTER TABLE accounts ADD COLUMN notes TEXT;")


func _seed_accounts() -> void:
	# Only seed if there are no staff accounts yet (avoids re-seeding on every launch).
	_db.query("SELECT COUNT(*) AS n FROM accounts WHERE role IN ('admin','employee');")
	if _db.query_result[0]["n"] > 0:
		return

	var defaults := [
		{ "name": "Admin User",    "email": "admin@bookstore.com",    "username": "admin",    "password": "password", "role": "admin"    },
		{ "name": "Employee User", "email": "employee@bookstore.com", "username": "employee", "password": "password", "role": "employee" },
		{ "name": "Customer User", "email": "customer@bookstore.com", "username": "customer", "password": "password", "role": "customer" },
	]
	for acc in defaults:
		_db.query_with_bindings(
			"INSERT OR IGNORE INTO accounts (name, email, username, password, role) VALUES (?, ?, ?, ?, ?);",
			[acc["name"], acc["email"], acc["username"], acc["password"], acc["role"]]
		)


# ── Session ───────────────────────────────────────────────────────────────────

func login(email: String, password: String) -> String:
	if email.strip_edges().is_empty():
		return "Email is required."
	if password.is_empty():
		return "Password is required."

	_db.query_with_bindings(
		"SELECT id, name AS display_name, email, username, password, role, phone, notes, created_at FROM accounts WHERE email = ? AND password = ? LIMIT 1;",
		[email.strip_edges().to_lower(), password]
	)
	if _db.query_result.is_empty():
		return "Invalid email or password."

	_current_account = _db.query_result[0]
	emit_signal("session_changed", _current_account)
	return ""


func login_with_username(username: String, password: String) -> String:
	if username.strip_edges().is_empty():
		return "Username is required."
	if password.is_empty():
		return "Password is required."

	_db.query_with_bindings(
		"SELECT id, name AS display_name, email, username, password, role, phone, notes, created_at FROM accounts WHERE username = ? AND password = ? LIMIT 1;",
		[username.strip_edges().to_lower(), password]
	)
	if _db.query_result.is_empty():
		return "Invalid username or password."

	_current_account = _db.query_result[0]
	emit_signal("session_changed", _current_account)
	return ""


func login_guest() -> void:
	_current_account = {
		"id":           -1,
		"display_name": "Guest",
		"email":        "",
		"username":     "",
		"role":         "guest",
	}
	emit_signal("session_changed", _current_account)


func logout() -> void:
	_current_account = {}
	emit_signal("session_changed", _current_account)


func is_logged_in() -> bool:
	return not _current_account.is_empty()


func is_guest() -> bool:
	return _current_account.get("role", "") == "guest"


func get_current_account() -> Dictionary:
	return _current_account


func get_role() -> String:
	return _current_account.get("role", "")


func get_account_name() -> String:
	return _current_account.get("display_name", "Guest")


# ── Permissions ───────────────────────────────────────────────────────────────

func has_permission(page_key: String) -> bool:
	var role := get_role()
	if not ROLE_PERMISSIONS.has(role):
		return false
	return page_key in ROLE_PERMISSIONS[role]


func get_permitted_pages() -> Array:
	var role := get_role()
	return ROLE_PERMISSIONS.get(role, [])


# ── Account management ────────────────────────────────────────────────────────

func get_all_accounts() -> Array:
	_db.query("SELECT id, name AS display_name, email, username, role, phone, notes, created_at FROM accounts ORDER BY role, display_name;")
	return _db.query_result


func add_account(display_name: String, email: String, username: String, password: String, role: String) -> String:
	if display_name.strip_edges().is_empty():
		return "Name is required."
	if email.strip_edges().is_empty() and username.strip_edges().is_empty():
		return "Either an email or a username is required."
	if password.is_empty():
		return "Password is required."
	if role not in ROLE_PERMISSIONS or role == "guest":
		return "Invalid role."

	if email.strip_edges() != "":
		_db.query_with_bindings(
			"SELECT COUNT(*) AS n FROM accounts WHERE email = ?;",
			[email.strip_edges().to_lower()]
		)
		if _db.query_result[0]["n"] > 0:
			return "An account with that email already exists."

	if username.strip_edges() != "":
		_db.query_with_bindings(
			"SELECT COUNT(*) AS n FROM accounts WHERE username = ?;",
			[username.strip_edges().to_lower()]
		)
		if _db.query_result[0]["n"] > 0:
			return "That username is already taken."

	var email_val = email.strip_edges().to_lower() if email.strip_edges() != "" else null
	var user_val  = username.strip_edges().to_lower() if username.strip_edges() != "" else null

	_db.query_with_bindings(
		"INSERT INTO accounts (name, email, username, password, role) VALUES (?, ?, ?, ?, ?);",
		[display_name.strip_edges(), email_val, user_val, password, role]
	)
	return ""


func delete_account(account_id: int) -> String:
	if _current_account.get("id", -1) == account_id:
		return "You cannot delete the account you are currently logged in as."
	_db.query_with_bindings("DELETE FROM accounts WHERE id = ?;", [account_id])
	return ""


# ── Self-service account editing ──────────────────────────────────────────────

func update_account(account_id: int, display_name: String, email: String, username: String) -> String:
	if display_name.strip_edges().is_empty():
		return "Name is required."
	if email.strip_edges().is_empty() and username.strip_edges().is_empty():
		return "Either an email or a username is required."

	if email.strip_edges() != "":
		_db.query_with_bindings(
			"SELECT COUNT(*) AS n FROM accounts WHERE email = ? AND id != ?;",
			[email.strip_edges().to_lower(), account_id]
		)
		if _db.query_result[0]["n"] > 0:
			return "An account with that email already exists."

	if username.strip_edges() != "":
		_db.query_with_bindings(
			"SELECT COUNT(*) AS n FROM accounts WHERE username = ? AND id != ?;",
			[username.strip_edges().to_lower(), account_id]
		)
		if _db.query_result[0]["n"] > 0:
			return "That username is already taken."

	var email_val    = email.strip_edges().to_lower()    if email.strip_edges()    != "" else null
	var username_val = username.strip_edges().to_lower() if username.strip_edges() != "" else null

	_db.query_with_bindings(
		"UPDATE accounts SET name = ?, email = ?, username = ? WHERE id = ?;",
		[display_name.strip_edges(), email_val, username_val, account_id]
	)

	# Refresh the live session if this is the current account.
	if _current_account.get("id", -1) == account_id:
		_current_account["display_name"] = display_name.strip_edges()
		_current_account["email"]        = email_val
		_current_account["username"]     = username_val
		emit_signal("session_changed", _current_account)

	return ""


func update_password(account_id: int, current_password: String, new_password: String, confirm_password: String) -> String:
	if current_password.is_empty():
		return "Current password is required."
	if new_password.is_empty():
		return "New password is required."
	if new_password.length() < 6:
		return "New password must be at least 6 characters."
	if new_password != confirm_password:
		return "Passwords do not match."

	_db.query_with_bindings(
		"SELECT id FROM accounts WHERE id = ? AND password = ? LIMIT 1;",
		[account_id, current_password]
	)
	if _db.query_result.is_empty():
		return "Current password is incorrect."

	_db.query_with_bindings(
		"UPDATE accounts SET password = ? WHERE id = ?;",
		[new_password, account_id]
	)
	return ""


func update_account_role(account_id: int, new_role: String) -> String:
	if new_role not in ROLE_PERMISSIONS or new_role == "guest":
		return "Invalid role."
	if _current_account.get("id", -1) == account_id:
		return "You cannot change your own role."
	_db.query_with_bindings(
		"UPDATE accounts SET role = ? WHERE id = ?;",
		[new_role, account_id]
	)
	return ""


# ── Self-registration (always creates a customer account) ─────────────────────

func register_account(display_name: String, email: String, username: String, password: String, confirm_password: String) -> String:
	if display_name.strip_edges().is_empty():
		return "Name is required."
	if email.strip_edges().is_empty() and username.strip_edges().is_empty():
		return "Please provide an email or a username."
	if password.is_empty():
		return "Password is required."
	if password != confirm_password:
		return "Passwords do not match."
	if password.length() < 6:
		return "Password must be at least 6 characters."

	var err := add_account(display_name, email, username, password, "customer")
	if err != "":
		return err

	if not email.strip_edges().is_empty():
		return login(email, password)
	else:
		return login_with_username(username, password)
