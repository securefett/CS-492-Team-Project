extends Node

# ══════════════════════════════════════════════════════════════════════════════
#  BookStore.gd  —  Autoload Singleton
#  Handles all database access for the Bookstore Management System.
# ══════════════════════════════════════════════════════════════════════════════

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
	# Books, possible improvements to replace the primary key id with the ISBN, which is unique and required
	db.query("""
		CREATE TABLE IF NOT EXISTS books (
			id          INTEGER PRIMARY KEY AUTOINCREMENT,
			title       TEXT    NOT NULL,
			author      TEXT    NOT NULL,
			isbn        TEXT    UNIQUE,
			genre       TEXT,
			publisher   TEXT,
			year        INTEGER,
			description TEXT,
			price       REAL    NOT NULL DEFAULT 0.0,
			cost        REAL    NOT NULL DEFAULT 0.0,
			stock       INTEGER NOT NULL DEFAULT 0,
			low_stock_alert INTEGER NOT NULL DEFAULT 5,
			created_at  TEXT    DEFAULT (datetime('now'))
		);
	""")

	# Customers
	db.query("""
		CREATE TABLE IF NOT EXISTS customers (
			id         INTEGER PRIMARY KEY AUTOINCREMENT,
			name       TEXT NOT NULL,
			email      TEXT UNIQUE,
			phone      TEXT,
			notes      TEXT,
			created_at TEXT DEFAULT (datetime('now'))
		);
	""")

	# Sales (one row per transaction)
	db.query("""
		CREATE TABLE IF NOT EXISTS sales (
			id             INTEGER PRIMARY KEY AUTOINCREMENT,
			customer_id    INTEGER REFERENCES customers(id) ON DELETE SET NULL,
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
			sale_id  INTEGER NOT NULL REFERENCES sales(id)  ON DELETE CASCADE,
			book_id  INTEGER NOT NULL REFERENCES books(id)  ON DELETE RESTRICT,
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
	# Pass a negative delta to reduce stock (e.g. after a sale)
	db.query_with_bindings(
		"UPDATE books SET stock = stock + ? WHERE id = ?;",
		[delta, book_id]
	)


# ══════════════════════════════════════════════════════════════════════════════
#  CUSTOMERS
# ══════════════════════════════════════════════════════════════════════════════

func get_all_customers() -> Array:
	db.query("""
		SELECT
			c.*,
			COUNT(s.id)   AS total_sales,
			COALESCE(SUM(s.total), 0.0) AS total_spent
		FROM customers c
		LEFT JOIN sales s ON s.customer_id = c.id
		GROUP BY c.id
		ORDER BY c.name ASC;
	""")
	return db.query_result


func search_customers(query: String) -> Array:
	var q := "%" + query + "%"
	db.query_with_bindings("""
		SELECT
			c.*,
			COUNT(s.id) AS total_sales,
			COALESCE(SUM(s.total), 0.0) AS total_spent
		FROM customers c
		LEFT JOIN sales s ON s.customer_id = c.id
		WHERE c.name LIKE ? OR c.email LIKE ?
		GROUP BY c.id
		ORDER BY c.name ASC;
	""", [q, q])
	return db.query_result


func get_customer(id: int) -> Dictionary:
	db.query_with_bindings("SELECT * FROM customers WHERE id = ?;", [id])
	return db.query_result[0] if db.query_result.size() > 0 else {}


func add_customer(data: Dictionary) -> int:
	db.query_with_bindings("""
		INSERT INTO customers (name, email, phone, notes)
		VALUES (?, ?, ?, ?);
	""", [
		data.get("name", ""),
		data.get("email", ""),
		data.get("phone", ""),
		data.get("notes", ""),
	])
	return db.last_insert_rowid


func update_customer(id: int, data: Dictionary) -> void:
	db.query_with_bindings("""
		UPDATE customers SET
			name  = ?,
			email = ?,
			phone = ?,
			notes = ?
		WHERE id = ?;
	""", [
		data.get("name", ""),
		data.get("email", ""),
		data.get("phone", ""),
		data.get("notes", ""),
		id,
	])


func delete_customer(id: int) -> void:
	db.query_with_bindings("DELETE FROM customers WHERE id = ?;", [id])


# ══════════════════════════════════════════════════════════════════════════════
#  SALES
# ══════════════════════════════════════════════════════════════════════════════

# cart_items: Array of { "book_id": int, "qty": int, "price": float }
func complete_sale(cart_items: Array, payment_method: String, customer_id: int = -1) -> int:
	var subtotal := 0.0
	for item in cart_items:
		subtotal += item["price"] * item["qty"]
	var tax   := subtotal * 0.08
	var total := subtotal + tax

	# Insert the sale header
	db.query_with_bindings("""
		INSERT INTO sales (customer_id, payment_method, subtotal, tax, total)
		VALUES (?, ?, ?, ?, ?);
	""", [
		customer_id if customer_id > 0 else null,
		payment_method,
		subtotal,
		tax,
		total,
	])
	var sale_id: int = db.last_insert_rowid

	# Insert each line item and decrement stock
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
			c.name AS customer_name
		FROM sales s
		LEFT JOIN customers c ON c.id = s.customer_id
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
	# Total revenue this month
	db.query("""
		SELECT COALESCE(SUM(total), 0.0) AS revenue
		FROM sales
		WHERE strftime('%Y-%m', created_at) = strftime('%Y-%m', 'now');
	""")
	var revenue: float = db.query_result[0]["revenue"] if db.query_result.size() > 0 else 0.0

	# Books sold this month
	db.query("""
		SELECT COALESCE(SUM(si.qty), 0) AS books_sold
		FROM sale_items si
		JOIN sales s ON s.id = si.sale_id
		WHERE strftime('%Y-%m', s.created_at) = strftime('%Y-%m', 'now');
	""")
	var books_sold: int = db.query_result[0]["books_sold"] if db.query_result.size() > 0 else 0

	# Total inventory
	db.query("SELECT COALESCE(SUM(stock), 0) AS inventory, COUNT(*) AS titles FROM books;")
	var inventory: int = db.query_result[0]["inventory"] if db.query_result.size() > 0 else 0
	var titles: int    = db.query_result[0]["titles"]    if db.query_result.size() > 0 else 0

	# Total customers
	db.query("SELECT COUNT(*) AS total FROM customers;")
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
			COALESCE(SUM(total), 0.0) AS total_revenue,
			COUNT(*) AS total_sales,
			COALESCE(AVG(total), 0.0) AS average_order_value
		FROM sales;
	""")
	
	var row: Dictionary = db.query_result[0] if db.query_result.size() > 0 else {}

	db.query("""
		SELECT COALESCE(SUM(qty), 0) AS books_sold
		FROM sale_items;
	""")
	
	var books_sold: int = db.query_result[0]["books_sold"] if db.query_result.size() > 0 else 0

	return {
		"total_revenue": row.get("total_revenue", 0.0),
		"total_sales": row.get("total_sales", 0),
		"books_sold": books_sold,
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
