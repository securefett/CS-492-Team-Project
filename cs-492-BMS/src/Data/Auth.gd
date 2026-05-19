extends Node

# ══════════════════════════════════════════════════════════════════════════════
#  Auth.gd  —  Autoload Singleton
#  Manages accounts, login sessions, and page-level permissions.
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
# Edit this to change what each role sees — no other file needs to change.
const ROLE_PERMISSIONS := {
	"admin": [
		"dashboard",
		"catalog",
		"addbook",
		"sales",
		"customers",
		"reports",
		"restock",
		"devtools"
	],
	"employee": [
		"dashboard",
		"catalog",
		"sales",
		"customers",
	],
	"customer": [
		"catalog",
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
	_create_table()
	_seed_accounts()


func _exit_tree() -> void:
	_db.close_db()


# ── Schema ────────────────────────────────────────────────────────────────────

func _create_table() -> void:
	_db.query("""
		CREATE TABLE IF NOT EXISTS accounts (
			id         INTEGER PRIMARY KEY AUTOINCREMENT,
			name       TEXT NOT NULL,
			email      TEXT UNIQUE,
			username   TEXT UNIQUE,
			password   TEXT NOT NULL,
			role       TEXT NOT NULL DEFAULT 'customer',
			created_at TEXT DEFAULT (datetime('now'))
		);
	""")

	# Migration: add username column if missing (older DBs)
	_db.query("PRAGMA table_info(accounts);")
	var col_names := _db.query_result.map(func(c): return c["name"])
	if not "username" in col_names:
		_db.query("ALTER TABLE accounts ADD COLUMN username TEXT UNIQUE;")

	# Migration: add customer_id column if missing (links account to customers table)
	_db.query("PRAGMA table_info(accounts);")
	var col_names2 := _db.query_result.map(func(c): return c["name"])
	if not "customer_id" in col_names2:
		_db.query("ALTER TABLE accounts ADD COLUMN customer_id INTEGER REFERENCES customers(id) ON DELETE SET NULL;")

	# Migration: make email nullable if it was created NOT NULL.
	# SQLite can't alter constraints, so we rebuild the table if needed.
	var email_not_null := false
	for col in _db.query_result:
		if col["name"] == "email" and col["notnull"] == 1:
			email_not_null = true
			break
	if email_not_null:
		_db.query("""
			BEGIN TRANSACTION;
			CREATE TABLE accounts_new (
				id         INTEGER PRIMARY KEY AUTOINCREMENT,
				name       TEXT NOT NULL,
				email      TEXT UNIQUE,
				username   TEXT UNIQUE,
				password   TEXT NOT NULL,
				role       TEXT NOT NULL DEFAULT 'customer',
				created_at TEXT DEFAULT (datetime('now'))
			);
			INSERT INTO accounts_new SELECT id, name, email, username, password, role, created_at FROM accounts;
			DROP TABLE accounts;
			ALTER TABLE accounts_new RENAME TO accounts;
			COMMIT;
		""")


func _seed_accounts() -> void:
	_db.query("SELECT COUNT(*) AS n FROM accounts;")
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

# Login with email + password. Returns "" on success or an error string.
func login(email: String, password: String) -> String:
	if email.strip_edges().is_empty():
		return "Email is required."
	if password.is_empty():
		return "Password is required."

	_db.query_with_bindings(
		"SELECT * FROM accounts WHERE email = ? AND password = ? LIMIT 1;",
		[email.strip_edges().to_lower(), password]
	)
	if _db.query_result.is_empty():
		return "Invalid email or password."

	_current_account = _db.query_result[0]
	emit_signal("session_changed", _current_account)
	return ""


# Login with username + password. Returns "" on success or an error string.
func login_with_username(username: String, password: String) -> String:
	if username.strip_edges().is_empty():
		return "Username is required."
	if password.is_empty():
		return "Password is required."

	_db.query_with_bindings(
		"SELECT * FROM accounts WHERE username = ? AND password = ? LIMIT 1;",
		[username.strip_edges().to_lower(), password]
	)
	if _db.query_result.is_empty():
		return "Invalid username or password."

	_current_account = _db.query_result[0]
	emit_signal("session_changed", _current_account)
	return ""


# Login as guest — no credentials required, customer-level permissions.
func login_guest() -> void:
	_current_account = {
		"id":       -1,
		"name":     "Guest",
		"email":    "",
		"username": "",
		"role":     "guest",
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
	return _current_account.get("name", "Guest")


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
	_db.query("SELECT id, name, email, username, role, created_at FROM accounts ORDER BY role, name;")
	return _db.query_result


func add_account(name: String, email: String, username: String, password: String, role: String) -> String:
	if name.strip_edges().is_empty():
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
		[name.strip_edges(), email_val, user_val, password, role]
	)

	# For customer accounts, create a matching entry in the customers table.
	if role == "customer":
		_db.query("SELECT last_insert_rowid() AS id;")
		var account_id: int = _db.query_result[0]["id"]
		_create_customer_for_account(account_id, name.strip_edges(), email_val)

	return ""


func delete_account(account_id: int) -> String:
	if _current_account.get("id", -1) == account_id:
		return "You cannot delete the account you are currently logged in as."
	_db.query_with_bindings("DELETE FROM accounts WHERE id = ?;", [account_id])
	return ""


# Creates a customers row for a new customer account and links it back via customer_id.
func _create_customer_for_account(account_id: int, name: String, email) -> void:
	var customer_id: int = BookStore.add_customer({
		"name":  name,
		"email": email if email != null else "",
		"phone": "",
		"notes": "",
	})
	_db.query_with_bindings(
		"UPDATE accounts SET customer_id = ? WHERE id = ?;",
		[customer_id, account_id]
	)
	# Keep the live session in sync if this account is the one logged in.
	if _current_account.get("id", -1) == account_id:
		_current_account["customer_id"] = customer_id


# Returns the customers row linked to the given account id, or an empty dict.
func get_customer_for_account(account_id: int) -> Dictionary:
	_db.query_with_bindings(
		"SELECT c.* FROM customers c JOIN accounts a ON a.customer_id = c.id WHERE a.id = ?;",
		[account_id]
	)
	return _db.query_result[0] if not _db.query_result.is_empty() else {}


# ── Self-registration (always creates a customer account) ─────────────────────

# Creates a new customer account and immediately logs in as that account.
# Returns "" on success, or a human-readable error string.
# At least one of email / username must be provided.
func register_account(name: String, email: String, username: String, password: String, confirm_password: String) -> String:
	if name.strip_edges().is_empty():
		return "Name is required."
	if email.strip_edges().is_empty() and username.strip_edges().is_empty():
		return "Please provide an email or a username."
	if password.is_empty():
		return "Password is required."
	if password != confirm_password:
		return "Passwords do not match."
	if password.length() < 6:
		return "Password must be at least 6 characters."

	# Delegate duplicate-checking and insertion to add_account with role locked to customer.
	var err := add_account(name, email, username, password, "customer")
	if err != "":
		return err

	# Auto-login with whichever credential was supplied.
	if not email.strip_edges().is_empty():
		return login(email, password)
	else:
		return login_with_username(username, password)
