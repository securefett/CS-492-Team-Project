extends Node

# ══════════════════════════════════════════════════════════════════════════════
#  BookStore.gd  —  Autoload Singleton
#  Handles all database access for the Bookstore Management System.
# ══════════════════════════════════════════════════════════════════════════════

signal accounts_changed

var db: SQLite

const DB_PATH := "user://bookstore.db"

# ── Startup ───────────────────────────────────────────────────────────────────

func _ready() -> void:
	db = SQLite.new()
	db.path = DB_PATH
	db.verbosity_level = SQLite.QUIET  # Change to VERBOSE to debug queries
	db.open_db()
	_create_tables()


func _exit_tree() -> void:
	db.close_db()


# ── Schema ────────────────────────────────────────────────────────────────────

func _create_tables() -> void:
	# Books
	db.query("""
		CREATE TABLE IF NOT EXISTS books (
			id               INTEGER PRIMARY KEY AUTOINCREMENT,
			title            TEXT    NOT NULL,
			author           TEXT    NOT NULL,
			isbn             TEXT    UNIQUE,
			genre            TEXT,
			publisher        TEXT,
			year             INTEGER,
			description      TEXT,
			price            REAL    NOT NULL DEFAULT 0.0,
			cost             REAL    NOT NULL DEFAULT 0.0,
			stock            INTEGER NOT NULL DEFAULT 0,
			low_stock_alert  INTEGER NOT NULL DEFAULT 5,
			created_at       TEXT    DEFAULT (datetime('now'))
		);
	""")

	# Unified accounts table (covers both login/auth and customer data).
	# Roles: admin, employee, customer, guest.
	# phone/notes are meaningful for customer-role rows but harmless on others.
	db.query("""
		CREATE TABLE IF NOT EXISTS accounts (
			id         INTEGER PRIMARY KEY AUTOINCREMENT,
			name       TEXT NOT NULL,
			email      TEXT UNIQUE,
			username   TEXT UNIQUE,
			password   TEXT NOT NULL DEFAULT '',
			role       TEXT NOT NULL DEFAULT 'customer',
			phone      TEXT,
			notes      TEXT,
			created_at TEXT DEFAULT (datetime('now'))
		);
	""")

	# ── Migrations (safe to run on every launch) ──────────────────────────────

	# If the old `customers` table still exists, migrate its rows into accounts
	# and re-point sales.customer_id before dropping it.
	db.query("SELECT name FROM sqlite_master WHERE type='table' AND name='customers';")
	if not db.query_result.is_empty():
		db.query("""
			BEGIN TRANSACTION;

			-- Bring over any customers that don't already have an accounts row
			-- (matched on email; unmatched rows get a blank password/role=customer).
			INSERT OR IGNORE INTO accounts (id, name, email, phone, notes, role, created_at)
			SELECT id, name, email, phone, notes, 'customer', created_at
			FROM customers
			WHERE email IS NULL OR email NOT IN (SELECT email FROM accounts WHERE email IS NOT NULL);

			-- Re-point the sales FK if the column is still called customer_id.
			-- (The rename to account_id happens below.)
			DROP TABLE customers;

			COMMIT;
		""")

	# Rename sales.customer_id → sales.account_id if not done yet.
	db.query("PRAGMA table_info(sales);")
	var sales_cols := db.query_result.map(func(c): return c["name"])
	if "customer_id" in sales_cols and not "account_id" in sales_cols:
		db.query("""
			BEGIN TRANSACTION;
			CREATE TABLE sales_new (
				id             INTEGER PRIMARY KEY AUTOINCREMENT,
				account_id     INTEGER REFERENCES accounts(id) ON DELETE SET NULL,
				payment_method TEXT    NOT NULL DEFAULT 'cash',
				subtotal       REAL    NOT NULL DEFAULT 0.0,
				tax            REAL    NOT NULL DEFAULT 0.0,
				total          REAL    NOT NULL DEFAULT 0.0,
				created_at     TEXT    DEFAULT (datetime('now'))
			);
			INSERT INTO sales_new SELECT id, customer_id, payment_method, subtotal, tax, total, created_at FROM sales;
			DROP TABLE sales;
			ALTER TABLE sales_new RENAME TO sales;
			COMMIT;
		""")

	# Add phone/notes to accounts if missing (older unified DBs).
	db.query("PRAGMA table_info(accounts);")
	var acc_cols := db.query_result.map(func(c): return c["name"])
	if not "phone" in acc_cols:
		db.query("ALTER TABLE accounts ADD COLUMN phone TEXT;")
	if not "notes" in acc_cols:
		db.query("ALTER TABLE accounts ADD COLUMN notes TEXT;")

	# Sales (one row per transaction)
	db.query("""
		CREATE TABLE IF NOT EXISTS sales (
			id             INTEGER PRIMARY KEY AUTOINCREMENT,
			account_id     INTEGER REFERENCES accounts(id) ON DELETE SET NULL,
			payment_method TEXT    NOT NULL DEFAULT 'cash',
			subtotal       REAL    NOT NULL DEFAULT 0.0,
			tax            REAL    NOT NULL DEFAULT 0.0,
			total          REAL    NOT NULL DEFAULT 0.0,
			created_at     TEXT    DEFAULT (datetime('now'))
		);
	""")

	# Sale line items (one row per book per sale)
	db.query("""
		CREATE TABLE IF NOT EXISTS sale_items (
			id       INTEGER PRIMARY KEY AUTOINCREMENT,
			sale_id  INTEGER NOT NULL REFERENCES sales(id)    ON DELETE CASCADE,
			book_id  INTEGER NOT NULL REFERENCES books(id)    ON DELETE RESTRICT,
			qty      INTEGER NOT NULL DEFAULT 1,
			price    REAL    NOT NULL DEFAULT 0.0
		);
	""")


# ══════════════════════════════════════════════════════════════════════════════
#  BOOKS
# ══════════════════════════════════════════════════════════════════════════════

func get_all_books() -> Array:
	db.query("SELECT * FROM books ORDER BY title ASC;")
	return db.query_result


func search_books(query: String, genre: String = "") -> Array:
	var q := "%" + query + "%"
	if genre == "" or genre == "All Genres":
		db.query_with_bindings("""
			SELECT * FROM books
			WHERE (title LIKE ? OR author LIKE ? OR isbn LIKE ?)
			ORDER BY title ASC;
		""", [q, q, q])
	else:
		db.query_with_bindings("""
			SELECT * FROM books
			WHERE (title LIKE ? OR author LIKE ? OR isbn LIKE ?)
			  AND genre = ?
			ORDER BY title ASC;
		""", [q, q, q, genre])
	return db.query_result


func get_book(id: int) -> Dictionary:
	db.query_with_bindings("SELECT * FROM books WHERE id = ?;", [id])
	return db.query_result[0] if db.query_result.size() > 0 else {}


func add_book(data: Dictionary) -> int:
	db.query_with_bindings("""
		INSERT INTO books
			(title, author, isbn, genre, publisher, year, description, price, cost, stock, low_stock_alert)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
	""", [
		data.get("title", ""),
		data.get("author", ""),
		data.get("isbn", ""),
		data.get("genre", ""),
		data.get("publisher", ""),
		data.get("year", 0),
		data.get("description", ""),
		data.get("price", 0.0),
		data.get("cost", 0.0),
		data.get("stock", 0),
		data.get("low_stock_alert", 5),
	])
	return db.last_insert_rowid


func update_book(id: int, data: Dictionary) -> void:
	db.query_with_bindings("""
		UPDATE books SET
			title            = ?,
			author           = ?,
			isbn             = ?,
			genre            = ?,
			publisher        = ?,
			year             = ?,
			description      = ?,
			price            = ?,
			cost             = ?,
			stock            = ?,
			low_stock_alert  = ?
		WHERE id = ?;
	""", [
		data.get("title", ""),
		data.get("author", ""),
		data.get("isbn", ""),
		data.get("genre", ""),
		data.get("publisher", ""),
		data.get("year", 0),
		data.get("description", ""),
		data.get("price", 0.0),
		data.get("cost", 0.0),
		data.get("stock", 0),
		data.get("low_stock_alert", 5),
		id,
	])


func delete_book(id: int) -> void:
	db.query_with_bindings("DELETE FROM books WHERE id = ?;", [id])


func get_low_stock_books() -> Array:
	db.query("""
		SELECT * FROM books
		WHERE stock <= low_stock_alert
		ORDER BY stock ASC;
	""")
	return db.query_result


func update_stock(book_id: int, delta: int) -> void:
	db.query_with_bindings(
		"UPDATE books SET stock = stock + ? WHERE id = ?;",
		[delta, book_id]
	)


# ══════════════════════════════════════════════════════════════════════════════
#  CUSTOMERS  (accounts with role = 'customer')
# ══════════════════════════════════════════════════════════════════════════════

func get_all_customers() -> Array:
	db.query("""
		SELECT
			a.*,
			COUNT(s.id)                 AS total_sales,
			COALESCE(SUM(s.total), 0.0) AS total_spent
		FROM accounts a
		LEFT JOIN sales s ON s.account_id = a.id
		WHERE a.role = 'customer'
		GROUP BY a.id
		ORDER BY a.name ASC;
	""")
	return db.query_result


func search_customers(query: String) -> Array:
	var q := "%" + query + "%"
	db.query_with_bindings("""
		SELECT
			a.*,
			COUNT(s.id)                 AS total_sales,
			COALESCE(SUM(s.total), 0.0) AS total_spent
		FROM accounts a
		LEFT JOIN sales s ON s.account_id = a.id
		WHERE a.role = 'customer'
		  AND (a.name LIKE ? OR a.email LIKE ?)
		GROUP BY a.id
		ORDER BY a.name ASC;
	""", [q, q])
	return db.query_result


func get_customer(id: int) -> Dictionary:
	db.query_with_bindings(
		"SELECT * FROM accounts WHERE id = ? AND role = 'customer';", [id]
	)
	return db.query_result[0] if db.query_result.size() > 0 else {}


func add_customer(data: Dictionary) -> int:
	db.query_with_bindings("""
		INSERT INTO accounts (name, email, phone, notes, role, username, password)
		VALUES (?, ?, ?, ?, 'customer', ?, ?);
	""", [
		data.get("name", ""),
		data.get("email", ""),
		data.get("phone", ""),
		data.get("notes", ""),
		data.get("username", null),
		data.get("password", ""),
	])
	var new_id: int = db.last_insert_rowid
	accounts_changed.emit()
	return new_id


func update_customer(id: int, data: Dictionary) -> void:
	db.query_with_bindings("""
		UPDATE accounts SET
			name  = ?,
			email = ?,
			phone = ?,
			notes = ?
		WHERE id = ? AND role = 'customer';
	""", [
		data.get("name", ""),
		data.get("email", ""),
		data.get("phone", ""),
		data.get("notes", ""),
		id,
	])
	accounts_changed.emit()


func update_customer_notes(id: int, notes: String) -> void:
	db.query_with_bindings("""
        UPDATE accounts SET notes = ?
        WHERE id = ? AND role = 'customer';
	""", [notes, id])
	accounts_changed.emit()


func delete_customer(id: int) -> void:
	db.query_with_bindings(
		"DELETE FROM accounts WHERE id = ? AND role = 'customer';", [id]
	)
	accounts_changed.emit()


func get_customer_sales(account_id: int) -> Array:
	db.query_with_bindings("""
		SELECT
			s.id,
			s.created_at,
			s.payment_method,
			s.subtotal,
			s.tax,
			s.total,
			COUNT(si.id) AS item_count
		FROM sales s
		LEFT JOIN sale_items si ON si.sale_id = s.id
		WHERE s.account_id = ?
		GROUP BY s.id
		ORDER BY s.created_at DESC;
	""", [account_id])
	return db.query_result


# ══════════════════════════════════════════════════════════════════════════════
#  SALES
# ══════════════════════════════════════════════════════════════════════════════

# cart_items: Array of { "book_id": int, "qty": int, "price": float }
func complete_sale(cart_items: Array, payment_method: String, account_id: int = -1) -> int:
	var subtotal := 0.0
	for item in cart_items:
		subtotal += item["price"] * item["qty"]
	var tax   := subtotal * 0.08
	var total := subtotal + tax

	db.query_with_bindings("""
		INSERT INTO sales (account_id, payment_method, subtotal, tax, total)
		VALUES (?, ?, ?, ?, ?);
	""", [
		account_id if account_id > 0 else null,
		payment_method,
		subtotal,
		tax,
		total,
	])
	var sale_id: int = db.last_insert_rowid

	for item in cart_items:
		db.query_with_bindings("""
			INSERT INTO sale_items (sale_id, book_id, qty, price)
			VALUES (?, ?, ?, ?);
		""", [sale_id, item["book_id"], item["qty"], item["price"]])
		update_stock(item["book_id"], -item["qty"])

	return sale_id


func get_recent_sales(limit: int = 50) -> Array:
	db.query_with_bindings("""
		SELECT
			s.*,
			a.name AS account_name
		FROM sales s
		LEFT JOIN accounts a ON a.id = s.account_id
		ORDER BY s.created_at DESC
		LIMIT ?;
	""", [limit])
	return db.query_result


func get_sale_items(sale_id: int) -> Array:
	db.query_with_bindings("""
		SELECT
			si.*,
			b.title  AS book_title,
			b.author AS book_author
		FROM sale_items si
		JOIN books b ON b.id = si.book_id
		WHERE si.sale_id = ?;
	""", [sale_id])
	return db.query_result


# ══════════════════════════════════════════════════════════════════════════════
#  REPORTS / DASHBOARD
# ══════════════════════════════════════════════════════════════════════════════

func get_dashboard_metrics() -> Dictionary:
	db.query("""
		SELECT COALESCE(SUM(total), 0.0) AS revenue
		FROM sales
		WHERE strftime('%Y-%m', created_at) = strftime('%Y-%m', 'now');
	""")
	var revenue: float = db.query_result[0]["revenue"] if db.query_result.size() > 0 else 0.0

	db.query("""
		SELECT COALESCE(SUM(si.qty), 0) AS books_sold
		FROM sale_items si
		JOIN sales s ON s.id = si.sale_id
		WHERE strftime('%Y-%m', s.created_at) = strftime('%Y-%m', 'now');
	""")
	var books_sold: int = db.query_result[0]["books_sold"] if db.query_result.size() > 0 else 0

	db.query("SELECT COALESCE(SUM(stock), 0) AS inventory, COUNT(*) AS titles FROM books;")
	var inventory: int = db.query_result[0]["inventory"] if db.query_result.size() > 0 else 0
	var titles: int    = db.query_result[0]["titles"]    if db.query_result.size() > 0 else 0

	db.query("SELECT COUNT(*) AS total FROM accounts WHERE role = 'customer';")
	var customers: int = db.query_result[0]["total"] if db.query_result.size() > 0 else 0

	return {
		"revenue":    revenue,
		"books_sold": books_sold,
		"inventory":  inventory,
		"titles":     titles,
		"customers":  customers,
	}


# Parameterised replacement for get_dashboard_metrics().
# Returns current-period metrics plus enough data for change-vs-prior deltas.
#
#   result = {
#     "revenue":       float,   # current period
#     "prev_revenue":  float,
#     "books_sold":    int,
#     "prev_books_sold": int,
#     "inventory":     int,     # point-in-time (no period filter)
#     "titles":        int,
#     "customers":     int,     # total registered
#     "new_customers":     int, # new in current period
#     "prev_new_customers": int,
#   }
func get_dashboard_metrics_for(range_key: String) -> Dictionary:
	var r = BookStore.date_range_for(range_key)
 
	# Revenue — current period.
	db.query_with_bindings("""
		SELECT COALESCE(SUM(total), 0.0) AS revenue
		FROM sales
		WHERE date(created_at) BETWEEN ? AND ?;
	""", [r["from"], r["to"]])
	var revenue: float = db.query_result[0]["revenue"] if db.query_result.size() > 0 else 0.0
 
	# Revenue — prior period.
	db.query_with_bindings("""
		SELECT COALESCE(SUM(total), 0.0) AS revenue
		FROM sales
		WHERE date(created_at) BETWEEN ? AND ?;
	""", [r["prev_from"], r["prev_to"]])
	var prev_revenue: float = db.query_result[0]["revenue"] if db.query_result.size() > 0 else 0.0
 
	# Books sold — current.
	db.query_with_bindings("""
		SELECT COALESCE(SUM(si.qty), 0) AS books_sold
		FROM sale_items si
		JOIN sales s ON s.id = si.sale_id
		WHERE date(s.created_at) BETWEEN ? AND ?;
	""", [r["from"], r["to"]])
	var books_sold: int = db.query_result[0]["books_sold"] if db.query_result.size() > 0 else 0
 
	# Books sold — prior.
	db.query_with_bindings("""
		SELECT COALESCE(SUM(si.qty), 0) AS books_sold
		FROM sale_items si
		JOIN sales s ON s.id = si.sale_id
		WHERE date(s.created_at) BETWEEN ? AND ?;
	""", [r["prev_from"], r["prev_to"]])
	var prev_books_sold: int = db.query_result[0]["books_sold"] if db.query_result.size() > 0 else 0
 
	# Inventory — point-in-time.
	db.query("SELECT COALESCE(SUM(stock), 0) AS inventory, COUNT(*) AS titles FROM books;")
	var inventory: int = db.query_result[0]["inventory"] if db.query_result.size() > 0 else 0
	var titles: int    = db.query_result[0]["titles"]    if db.query_result.size() > 0 else 0
 
	# Total customers — point-in-time.
	db.query("SELECT COUNT(*) AS total FROM accounts WHERE role = 'customer';")
	var customers: int = db.query_result[0]["total"] if db.query_result.size() > 0 else 0
 
	# New customers — current period.
	db.query_with_bindings("""
		SELECT COUNT(*) AS n FROM accounts
		WHERE role = 'customer' AND date(created_at) BETWEEN ? AND ?;
	""", [r["from"], r["to"]])
	var new_customers: int = db.query_result[0]["n"] if db.query_result.size() > 0 else 0
 
	# New customers — prior period.
	db.query_with_bindings("""
		SELECT COUNT(*) AS n FROM accounts
		WHERE role = 'customer' AND date(created_at) BETWEEN ? AND ?;
	""", [r["prev_from"], r["prev_to"]])
	var prev_new_customers: int = db.query_result[0]["n"] if db.query_result.size() > 0 else 0
 
	return {
		"revenue":            revenue,
		"prev_revenue":       prev_revenue,
		"books_sold":         books_sold,
		"prev_books_sold":    prev_books_sold,
		"inventory":          inventory,
		"titles":             titles,
		"customers":          customers,
		"new_customers":      new_customers,
		"prev_new_customers": prev_new_customers,
	}


# Returns a time-series Array for bar graph rendering.
# Each element: { "label": String, "value": float }
#
# metric:    "revenue" | "books_sold" | "new_customers"
# range_key: "month" | "6months" | "year" | "alltime"
#            ("today" callers should skip the graph entirely)
#
# Granularity is determined by range_key:
#   month    → one bar per day  (DD)
#   6months  → one bar per month (Mon YY)
#   year     → one bar per month (Mon)
#   alltime  → one bar per year  (YYYY)
func get_time_series_for(range_key: String, metric: String) -> Array:
	var r := BookStore.date_range_for(range_key)
 
	match range_key:
 
		"month":
			# One bar per calendar day in the current month.
			match metric:
				"revenue":
					db.query_with_bindings("""
						SELECT strftime('%d', created_at) AS lbl,
						       COALESCE(SUM(total), 0.0)  AS val
						FROM sales
						WHERE date(created_at) BETWEEN ? AND ?
						GROUP BY lbl ORDER BY lbl ASC;
					""", [r["from"], r["to"]])
				"books_sold":
					db.query_with_bindings("""
						SELECT strftime('%d', s.created_at) AS lbl,
						       COALESCE(SUM(si.qty), 0)     AS val
						FROM sale_items si JOIN sales s ON s.id = si.sale_id
						WHERE date(s.created_at) BETWEEN ? AND ?
						GROUP BY lbl ORDER BY lbl ASC;
					""", [r["from"], r["to"]])
				"new_customers":
					db.query_with_bindings("""
						SELECT strftime('%d', created_at) AS lbl,
						       COUNT(*)                   AS val
						FROM accounts
						WHERE role = 'customer' AND date(created_at) BETWEEN ? AND ?
						GROUP BY lbl ORDER BY lbl ASC;
					""", [r["from"], r["to"]])
 
		"6months":
			# One bar per month over the last 6 months, labelled "Mon YY".
			match metric:
				"revenue":
					db.query_with_bindings("""
						SELECT strftime('%Y-%m', created_at) AS lbl,
						       COALESCE(SUM(total), 0.0)     AS val
						FROM sales
						WHERE date(created_at) BETWEEN ? AND ?
						GROUP BY lbl ORDER BY lbl ASC;
					""", [r["from"], r["to"]])
				"books_sold":
					db.query_with_bindings("""
						SELECT strftime('%Y-%m', s.created_at) AS lbl,
						       COALESCE(SUM(si.qty), 0)        AS val
						FROM sale_items si JOIN sales s ON s.id = si.sale_id
						WHERE date(s.created_at) BETWEEN ? AND ?
						GROUP BY lbl ORDER BY lbl ASC;
					""", [r["from"], r["to"]])
				"new_customers":
					db.query_with_bindings("""
						SELECT strftime('%Y-%m', created_at) AS lbl,
						       COUNT(*)                      AS val
						FROM accounts
						WHERE role = 'customer' AND date(created_at) BETWEEN ? AND ?
						GROUP BY lbl ORDER BY lbl ASC;
					""", [r["from"], r["to"]])
 
		"year":
			# One bar per month in the current year, labelled "Mon".
			match metric:
				"revenue":
					db.query_with_bindings("""
						SELECT strftime('%m', created_at) AS lbl,
						       COALESCE(SUM(total), 0.0)  AS val
						FROM sales
						WHERE date(created_at) BETWEEN ? AND ?
						GROUP BY lbl ORDER BY lbl ASC;
					""", [r["from"], r["to"]])
				"books_sold":
					db.query_with_bindings("""
						SELECT strftime('%m', s.created_at) AS lbl,
						       COALESCE(SUM(si.qty), 0)     AS val
						FROM sale_items si JOIN sales s ON s.id = si.sale_id
						WHERE date(s.created_at) BETWEEN ? AND ?
						GROUP BY lbl ORDER BY lbl ASC;
					""", [r["from"], r["to"]])
				"new_customers":
					db.query_with_bindings("""
						SELECT strftime('%m', created_at) AS lbl,
						       COUNT(*)                   AS val
						FROM accounts
						WHERE role = 'customer' AND date(created_at) BETWEEN ? AND ?
						GROUP BY lbl ORDER BY lbl ASC;
					""", [r["from"], r["to"]])
 
		_:  # "alltime"
			# One bar per year.
			match metric:
				"revenue":
					db.query_with_bindings("""
						SELECT strftime('%Y', created_at) AS lbl,
						       COALESCE(SUM(total), 0.0)  AS val
						FROM sales
						WHERE date(created_at) BETWEEN ? AND ?
						GROUP BY lbl ORDER BY lbl ASC;
					""", [r["from"], r["to"]])
				"books_sold":
					db.query_with_bindings("""
						SELECT strftime('%Y', s.created_at) AS lbl,
						       COALESCE(SUM(si.qty), 0)     AS val
						FROM sale_items si JOIN sales s ON s.id = si.sale_id
						WHERE date(s.created_at) BETWEEN ? AND ?
						GROUP BY lbl ORDER BY lbl ASC;
					""", [r["from"], r["to"]])
				"new_customers":
					db.query_with_bindings("""
						SELECT strftime('%Y', created_at) AS lbl,
						       COUNT(*)                   AS val
						FROM accounts
						WHERE role = 'customer' AND date(created_at) BETWEEN ? AND ?
						GROUP BY lbl ORDER BY lbl ASC;
					""", [r["from"], r["to"]])
 
	# Convert raw query rows and pretty-print labels.
	var month_names := ["Jan","Feb","Mar","Apr","May","Jun",
						"Jul","Aug","Sep","Oct","Nov","Dec"]
	var result: Array = []
	for row in db.query_result:
		var raw_lbl: String = str(row.get("lbl", ""))
		var val: float      = float(row.get("val", 0))
		var pretty: String
 
		match range_key:
			"month":
				pretty = raw_lbl.lstrip("0")          # "01" → "1"
			"6months":
				# raw_lbl = "YYYY-MM"
				var parts := raw_lbl.split("-")
				var mi    := int(parts[1]) - 1
				var yr    := parts[0].right(2)         # last two digits
				pretty = "%s '%s" % [month_names[clamp(mi, 0, 11)], yr]
			"year":
				var mi := int(raw_lbl) - 1
				pretty = month_names[clamp(mi, 0, 11)]
			_:  # alltime
				pretty = raw_lbl                       # "2023"
 
		result.append({ "label": pretty, "value": val })
 
	return result
 

# Returns the ISO date strings that bound a named time range and its prior
# equivalent period, so callers can compute change vs previous period.
#
#   result = {
#     "from":      "YYYY-MM-DD",   # start of current period (inclusive)
#     "to":        "YYYY-MM-DD",   # end   of current period (inclusive, = today)
#     "prev_from": "YYYY-MM-DD",   # start of prior  period
#     "prev_to":   "YYYY-MM-DD",   # end   of prior  period
#   }
#
# range_key must be one of: "today" | "month" | "6months" | "year" | "alltime"
static func date_range_for(range_key: String) -> Dictionary:
	var now  := Time.get_date_dict_from_system()
	var y    = now["year"]
	var m    = now["month"]
	var d    = now["day"]
	var today := "%04d-%02d-%02d" % [y, m, d]
 
	match range_key:
		"today":
			# Prior period = yesterday.
			var yesterday := _offset_date(y, m, d, -1)
			return {
				"from":      today,
				"to":        today,
				"prev_from": yesterday,
				"prev_to":   yesterday,
			}
 
		"month":
			# Current calendar month vs the calendar month before it.
			var cur_from  := "%04d-%02d-01" % [y, m]
			var prev_y    = y if m > 1 else y - 1
			var prev_m    = m - 1 if m > 1 else 12
			var prev_from := "%04d-%02d-01" % [prev_y, prev_m]
			var prev_to   := _last_day_of_month(prev_y, prev_m)
			return {
				"from":      cur_from,
				"to":        today,
				"prev_from": prev_from,
				"prev_to":   prev_to,
			}
 
		"6months":
			# Last 180 days vs the 180 days before that.
			var from      := _offset_date(y, m, d, -179)
			var prev_to   := _offset_date(y, m, d, -180)
			var prev_from := _offset_date(y, m, d, -359)
			return {
				"from":      from,
				"to":        today,
				"prev_from": prev_from,
				"prev_to":   prev_to,
			}
 
		"year":
			# Current calendar year vs the calendar year before it.
			var cur_from  := "%04d-01-01" % y
			var prev_from := "%04d-01-01" % (y - 1)
			var prev_to   := "%04d-12-31" % (y - 1)
			return {
				"from":      cur_from,
				"to":        today,
				"prev_from": prev_from,
				"prev_to":   prev_to,
			}
 
		_:  # "alltime"
			# No meaningful prior period; use identical range so delta = 0.
			return {
				"from":      "2000-01-01",
				"to":        today,
				"prev_from": "2000-01-01",
				"prev_to":   today,
			}
 



func get_report_metrics() -> Dictionary:
	db.query("""
		SELECT
			COALESCE(SUM(total), 0.0)  AS total_revenue,
			COUNT(*)                   AS total_sales,
			COALESCE(AVG(total), 0.0)  AS average_order_value
		FROM sales;
	""")
	var row: Dictionary = db.query_result[0] if db.query_result.size() > 0 else {}

	db.query("""
		SELECT COALESCE(SUM(qty), 0) AS books_sold
		FROM sale_items;
	""")
	var books_sold: int = db.query_result[0]["books_sold"] if db.query_result.size() > 0 else 0

	return {
		"total_revenue":       row.get("total_revenue", 0.0),
		"total_sales":         row.get("total_sales", 0),
		"books_sold":          books_sold,
		"average_order_value": row.get("average_order_value", 0.0),
	}


func get_low_stock_alerts() -> Array:
	db.query("""
		SELECT title, stock
		FROM books
		WHERE stock <= low_stock_alert
		ORDER BY stock ASC;
	""")
	return db.query_result


func get_sales_by_genre_report() -> Array:
	db.query("""
		SELECT
			COALESCE(b.genre, 'Other') AS name,
			SUM(si.qty) AS sold,
			CAST(ROUND(
				(SUM(si.qty) * 100.0) /
				(SELECT COALESCE(SUM(qty), 1) FROM sale_items)
			) AS INTEGER) AS pct
		FROM sale_items si
		JOIN books b ON b.id = si.book_id
		GROUP BY b.genre
		ORDER BY sold DESC;
	""")
	return db.query_result


func get_top_books(limit: int = 5) -> Array:
	db.query_with_bindings("""
		SELECT
			b.title,
			b.author,
			COALESCE(SUM(si.qty), 0) AS total_sold
		FROM books b
		LEFT JOIN sale_items si ON si.book_id = b.id
		GROUP BY b.id
		ORDER BY total_sold DESC
		LIMIT ?;
	""", [limit])
	return db.query_result


func get_sales_by_genre() -> Array:
	db.query("""
		SELECT
			b.genre,
			COALESCE(SUM(si.qty), 0) AS total_sold
		FROM books b
		LEFT JOIN sale_items si ON si.book_id = b.id
		GROUP BY b.genre
		ORDER BY total_sold DESC;
	""")
	return db.query_result


func get_monthly_revenue(year: int = -1) -> Array:
	if year < 0:
		year = Time.get_date_dict_from_system()["year"]
	db.query_with_bindings("""
		SELECT
			strftime('%m', created_at) AS month,
			COALESCE(SUM(total), 0.0)  AS revenue
		FROM sales
		WHERE strftime('%Y', created_at) = ?
		GROUP BY month
		ORDER BY month ASC;
	""", [str(year)])
	return db.query_result


# Returns a "YYYY-MM-DD" string offset by `days` from the given date.
# Handles month/year rollovers via Unix timestamp arithmetic.
static func _offset_date(y: int, m: int, d: int, days: int) -> String:
	var unix := Time.get_unix_time_from_datetime_dict({
		"year": y, "month": m, "day": d,
		"hour": 0, "minute": 0, "second": 0
	})
	unix += days * 86400
	var dt := Time.get_datetime_dict_from_unix_time(unix)
	return "%04d-%02d-%02d" % [dt["year"], dt["month"], dt["day"]]
 
 
# Returns the last day of a given month as "YYYY-MM-DD".
static func _last_day_of_month(y: int, m: int) -> String:
	# Step to the first of the next month, then back one day.
	var next_m := m + 1 if m < 12 else 1
	var next_y := y if m < 12 else y + 1
	return _offset_date(next_y, next_m, 1, -1)
