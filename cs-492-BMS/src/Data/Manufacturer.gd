extends Node

# ══════════════════════════════════════════════════════════════════════════════
#  Manufacturer.gd  —  Autoload Singleton
#  Simulates a manufacturer/supplier database and purchase order system.
#
#  Setup:
#    Project → Project Settings → Autoload
#    → Add this file as "Manufacturer"
#    (Must be listed AFTER BookStore in the autoload list)
# ══════════════════════════════════════════════════════════════════════════════

var db: SQLite

const DB_PATH := "user://manufacturer.db"

# Simulated processing times in seconds (faked with a timer)
const MIN_FULFIL_SECONDS := 5.0
const MAX_FULFIL_SECONDS := 15.0

# Emitted when a pending order is auto-fulfilled by the simulation timer
signal order_fulfilled(order_id: int)


func _ready() -> void:
	db = SQLite.new()
	db.path = DB_PATH
	db.verbosity_level = SQLite.QUIET
	db.open_db()
	_create_tables()
	_seed_catalogue()
	_resume_pending_orders()


func _exit_tree() -> void:
	db.close_db()


# ── Schema ────────────────────────────────────────────────────────────────────

func _create_tables() -> void:
	# The manufacturer's catalogue of titles they can supply
	db.query("""
		CREATE TABLE IF NOT EXISTS manufacturer_catalogue (
			id            INTEGER PRIMARY KEY AUTOINCREMENT,
			isbn          TEXT    UNIQUE NOT NULL,
			title         TEXT    NOT NULL,
			author        TEXT    NOT NULL,
			unit_cost     REAL    NOT NULL DEFAULT 0.0,
			available_qty INTEGER NOT NULL DEFAULT 0
		);
	""")

	# Purchase orders placed by the bookstore
	db.query("""
		CREATE TABLE IF NOT EXISTS purchase_orders (
			id           INTEGER PRIMARY KEY AUTOINCREMENT,
			book_id      INTEGER NOT NULL,
			isbn         TEXT    NOT NULL,
			title        TEXT    NOT NULL,
			qty_ordered  INTEGER NOT NULL,
			unit_cost    REAL    NOT NULL,
			total_cost   REAL    NOT NULL,
			status       TEXT    NOT NULL DEFAULT 'pending',
			notes        TEXT    DEFAULT '',
			created_at   TEXT    DEFAULT (datetime('now')),
			fulfilled_at TEXT    DEFAULT NULL
		);
	""")


# ── Seed data — simulated manufacturer catalogue ───────────────────────────────

func _seed_catalogue() -> void:
	db.query("SELECT COUNT(*) AS n FROM manufacturer_catalogue;")
	if db.query_result[0]["n"] > 0:
		return  # Already seeded

	var titles := [
		{ "isbn": "978-0-525-55360-5", "title": "The Midnight Library",  "author": "Matt Haig",         "unit_cost": 7.50,  "available_qty": 200 },
		{ "isbn": "978-0-593-18921-6", "title": "Atomic Habits",         "author": "James Clear",       "unit_cost": 8.00,  "available_qty": 150 },
		{ "isbn": "978-0-593-13520-4", "title": "Project Hail Mary",     "author": "Andy Weir",         "unit_cost": 7.00,  "available_qty": 180 },
		{ "isbn": "978-0-441-01359-7", "title": "Dune",                  "author": "Frank Herbert",     "unit_cost": 6.50,  "available_qty": 300 },
		{ "isbn": "978-0-061-92943-9", "title": "The Alchemist",         "author": "Paulo Coelho",      "unit_cost": 5.50,  "available_qty": 250 },
		{ "isbn": "978-0-062-31609-7", "title": "Sapiens",               "author": "Yuval Noah Harari", "unit_cost": 9.00,  "available_qty": 120 },
		{ "isbn": "978-0-385-54734-9", "title": "The Overstory",         "author": "Richard Powers",    "unit_cost": 8.50,  "available_qty": 90  },
		{ "isbn": "978-0-525-53582-6", "title": "Normal People",         "author": "Sally Rooney",      "unit_cost": 7.00,  "available_qty": 110 },
		{ "isbn": "978-0-735-22472-2", "title": "Little Fires Everywhere","author": "Celeste Ng",       "unit_cost": 7.50,  "available_qty": 130 },
		{ "isbn": "978-1-250-30170-2", "title": "The Silent Patient",    "author": "Alex Michaelides",  "unit_cost": 7.00,  "available_qty": 160 },
	]
	for t in titles:
		db.query_with_bindings("""
			INSERT OR IGNORE INTO manufacturer_catalogue (isbn, title, author, unit_cost, available_qty)
			VALUES (?, ?, ?, ?, ?);
		""", [t["isbn"], t["title"], t["author"], t["unit_cost"], t["available_qty"]])


# ── Manufacturer catalogue ────────────────────────────────────────────────────

func get_catalogue() -> Array:
	db.query("SELECT * FROM manufacturer_catalogue ORDER BY title ASC;")
	return db.query_result


func search_catalogue(query: String) -> Array:
	var q := "%" + query + "%"
	db.query_with_bindings("""
		SELECT * FROM manufacturer_catalogue
		WHERE title LIKE ? OR author LIKE ? OR isbn LIKE ?
		ORDER BY title ASC;
	""", [q, q, q])
	return db.query_result


func get_catalogue_item(isbn: String) -> Dictionary:
	db.query_with_bindings(
		"SELECT * FROM manufacturer_catalogue WHERE isbn = ?;", [isbn]
	)
	return db.query_result[0] if db.query_result.size() > 0 else {}


# ── Purchase orders ───────────────────────────────────────────────────────────

# Returns "" on success, or an error string on validation failure
func place_order(book_id: int, isbn: String, qty: int, notes: String = "") -> String:
	# Validation
	if qty <= 0:
		return "Quantity must be at least 1."

	var item := get_catalogue_item(isbn)
	if item.is_empty():
		return "ISBN not found in manufacturer catalogue."
	if qty > item["available_qty"]:
		return "Manufacturer only has %d units available." % item["available_qty"]

	var total_cost = item["unit_cost"] * qty

	db.query_with_bindings("""
		INSERT INTO purchase_orders (book_id, isbn, title, qty_ordered, unit_cost, total_cost, notes)
		VALUES (?, ?, ?, ?, ?, ?, ?);
	""", [book_id, isbn, item["title"], qty, item["unit_cost"], total_cost, notes])

	var order_id: int = db.last_insert_rowid

	# Reduce manufacturer available stock
	db.query_with_bindings(
		"UPDATE manufacturer_catalogue SET available_qty = available_qty - ? WHERE isbn = ?;",
		[qty, isbn]
	)

	# Simulate async fulfilment with a random delay timer
	_schedule_fulfilment(order_id, book_id, qty)

	return ""  # success


func get_all_orders() -> Array:
	db.query("""
		SELECT * FROM purchase_orders
		ORDER BY created_at DESC;
	""")
	return db.query_result


func get_pending_orders() -> Array:
	db.query("SELECT * FROM purchase_orders WHERE status = 'pending' ORDER BY created_at DESC;")
	return db.query_result


# ── Simulated fulfilment ──────────────────────────────────────────────────────

func _schedule_fulfilment(order_id: int, book_id: int, qty: int) -> void:
	var delay := randf_range(MIN_FULFIL_SECONDS, MAX_FULFIL_SECONDS)
	var timer  := get_tree().create_timer(delay)
	timer.timeout.connect(_fulfil_order.bind(order_id, book_id, qty))


func _fulfil_order(order_id: int, book_id: int, qty: int) -> void:
	# Mark the order as fulfilled
	db.query_with_bindings("""
		UPDATE purchase_orders
		SET status = 'fulfilled', fulfilled_at = datetime('now')
		WHERE id = ? AND status = 'pending';
	""", [order_id])

	# Increase bookstore inventory
	BookStore.update_stock(book_id, qty)

	emit_signal("order_fulfilled", order_id)


# Re-schedule timers for any orders still pending from a previous session.
# In a real system these would already be fulfilled; here we just re-simulate.
func _resume_pending_orders() -> void:
	var pending := get_pending_orders()
	for order in pending:
		_schedule_fulfilment(order["id"], order["book_id"], order["qty_ordered"])
