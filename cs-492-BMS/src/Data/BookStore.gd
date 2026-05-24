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
