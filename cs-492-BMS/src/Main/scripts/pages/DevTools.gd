extends VBoxContainer

# ── Node references ────────────────────────────────────────────────────────────
@onready var tab_bar:       TabBar        = $TabBar
@onready var tab_books:     VBoxContainer = $Tabs/Books
@onready var tab_customers: VBoxContainer = $Tabs/Customers
@onready var tab_sales:     VBoxContainer = $Tabs/Sales
@onready var tab_raw:       VBoxContainer = $Tabs/Raw

# Books tab
@onready var books_grid:       GridContainer = $Tabs/Books/BooksGrid
@onready var btn_seed_books:   Button        = $Tabs/Books/BooksGrid/SeedBooksBtn
@onready var btn_clear_books:  Button        = $Tabs/Books/BooksGrid/ClearBooksBtn
@onready var btn_show_books:   Button        = $Tabs/Books/BooksGrid/ShowBooksBtn
@onready var btn_low_stock:    Button        = $Tabs/Books/BooksGrid/LowStockBtn

# Customers tab
@onready var btn_seed_customers:  Button = $Tabs/Customers/CustomerGrid/SeedCustomersBtn
@onready var btn_clear_customers: Button = $Tabs/Customers/CustomerGrid/ClearCustomersBtn
@onready var btn_show_customers:  Button = $Tabs/Customers/CustomerGrid/ShowCustomersBtn

# Sales tab
@onready var btn_seed_sales:           Button = $Tabs/Sales/SalesGrid/SeedSalesBtn
@onready var btn_seed_historical_sales: Button = $Tabs/Sales/SalesGrid/SeedHistoricalSalesBtn
@onready var btn_clear_sales:          Button = $Tabs/Sales/SalesGrid/ClearSalesBtn
@onready var btn_show_sales:           Button = $Tabs/Sales/SalesGrid/ShowSalesBtn

# Raw tab
@onready var raw_input:  LineEdit = $Tabs/Raw/InputRow/RawInput
@onready var raw_run:    Button   = $Tabs/Raw/InputRow/RawRunBtn
@onready var raw_clear:  Button   = $Tabs/Raw/ClearBtn

# Shared output
@onready var output_scroll: ScrollContainer = $OutputScroll
@onready var output_label:  RichTextLabel   = $OutputScroll/OutputLabel
@onready var status_label:  Label           = $StatusLabel

var _current_tab := 0

# ── Sample data ────────────────────────────────────────────────────────────────

const SEED_BOOKS := [
	# ── In manufacturer catalogue ─────────────────────────────────────────────
	{ "title": "The Midnight Library", "author": "Matt Haig",         "isbn": "9780525553605", "genre": "Fiction",     "publisher": "Canongate",        "year": 2020, "description": "Between life and death, infinite choices.",                "price": 14.99, "cost": 7.50, "stock": 20, "low_stock_alert": 5 },
	{ "title": "Atomic Habits",        "author": "James Clear",        "isbn": "9780593189216", "genre": "Non-Fiction", "publisher": "Avery",            "year": 2018, "description": "Small habits, remarkable results.",                       "price": 16.99, "cost": 8.00, "stock": 25, "low_stock_alert": 5 },
	{ "title": "Project Hail Mary",    "author": "Andy Weir",          "isbn": "9780593135204", "genre": "Sci-Fi",      "publisher": "Ballantine Books", "year": 2021, "description": "Lone astronaut must save the solar system.",               "price": 15.99, "cost": 7.00, "stock": 3,  "low_stock_alert": 4 },
	{ "title": "The Alchemist",        "author": "Paulo Coelho",       "isbn": "9780061929439", "genre": "Fiction",     "publisher": "HarperOne",        "year": 1988, "description": "A shepherd's journey to find his destiny.",               "price": 12.99, "cost": 5.50, "stock": 30, "low_stock_alert": 5 },
	{ "title": "The Silent Patient",   "author": "Alex Michaelides",   "isbn": "9781250301702", "genre": "Fiction",     "publisher": "Celadon Books",    "year": 2019, "description": "A famous painter shoots her husband and never speaks again.", "price": 15.49, "cost": 7.00, "stock": 2,  "low_stock_alert": 4 },
	# ── Not in manufacturer catalogue ────────────────────────────────────────
	{ "title": "1984",                 "author": "George Orwell",      "isbn": "9780451524935", "genre": "Fiction",     "publisher": "Signet Classics",  "year": 1949, "description": "Dystopian surveillance state.",                           "price":  9.99, "cost": 3.50, "stock": 30, "low_stock_alert": 5 },
	{ "title": "Diary of a Wimpy Kid", "author": "Jeff Kinney",        "isbn": "9780810993136", "genre": "Children",    "publisher": "Amulet Books",     "year": 2007, "description": "Greg Heffley survives middle school one bad day at a time.", "price":  8.99, "cost": 3.00, "stock": 22, "low_stock_alert": 5 },
	{ "title": "Educated",             "author": "Tara Westover",      "isbn": "9780399590504", "genre": "Biography",   "publisher": "Random House",     "year": 2018, "description": "A memoir of self-invention against all odds.",             "price": 14.99, "cost": 6.00, "stock": 14, "low_stock_alert": 4 },
	{ "title": "Dune",                 "author": "Frank Herbert",       "isbn": "9780441013593", "genre": "Sci-Fi",      "publisher": "Ace",              "year": 1965, "description": "Epic politics and survival on a desert planet.",           "price": 14.99, "cost": 6.50, "stock": 15, "low_stock_alert": 4 },
	{ "title": "Becoming",             "author": "Michelle Obama",      "isbn": "9781524763138", "genre": "Biography",   "publisher": "Crown",            "year": 2018, "description": "Michelle Obama's journey from Chicago to the White House.", "price": 17.99, "cost": 7.50, "stock": 12, "low_stock_alert": 4 },
]

const SEED_CUSTOMERS := [
	{ "name": "Alice Mercer",  "email": "alice@example.com",  "username": "alice",  "password": "password", "phone": "555-0101", "notes": "Prefers sci-fi."        },
	{ "name": "Bob Tanaka",    "email": "bob@example.com",    "username": "bob",    "password": "password", "phone": "555-0102", "notes": "Regular customer."      },
	{ "name": "Clara Singh",   "email": "clara@example.com",  "username": "clara",  "password": "password", "phone": "555-0103", "notes": "Interested in classics." },
	{ "name": "David Osei",    "email": "david@example.com",  "username": "david",  "password": "password", "phone": "555-0104", "notes": ""                        },
	{ "name": "Eva Kowalski",  "email": "eva@example.com",    "username": "eva",    "password": "password", "phone": "555-0105", "notes": "Book club organiser."    },
]

# ── Lifecycle ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	tab_bar.tab_changed.connect(_on_tab_changed)

	btn_seed_books.pressed.connect(_seed_books)
	btn_clear_books.pressed.connect(_confirm_clear.bind("books"))
	btn_show_books.pressed.connect(_show_books)
	btn_low_stock.pressed.connect(_show_low_stock)

	btn_seed_customers.pressed.connect(_seed_customers)
	btn_clear_customers.pressed.connect(_confirm_clear.bind("customers"))
	btn_show_customers.pressed.connect(_show_customers)

	btn_seed_sales.pressed.connect(_seed_sales)
	btn_seed_historical_sales.pressed.connect(_seed_historical_sales)
	btn_clear_sales.pressed.connect(_confirm_clear.bind("sales"))
	btn_show_sales.pressed.connect(_show_sales)

	raw_run.pressed.connect(_run_raw)
	raw_clear.pressed.connect(func(): output_label.text = ""; status_label.text = "")
	raw_input.text_submitted.connect(func(_t): _run_raw())

	_set_status("Ready.")
	_on_tab_changed(0)


func _on_tab_changed(idx: int) -> void:
	_current_tab = idx
	tab_books.visible     = idx == 0
	tab_customers.visible = idx == 1
	tab_sales.visible     = idx == 2
	tab_raw.visible       = idx == 3


# ── Books ──────────────────────────────────────────────────────────────────────

func _seed_books() -> void:
	var added := 0
	for b in SEED_BOOKS:
		BookStore.add_book(b)
		added += 1
	_set_status("Seeded %d books." % added)
	_show_books()


func _show_books() -> void:
	var rows := BookStore.get_all_books()
	if rows.is_empty():
		_print_output("(no books in database)")
		return
	var headers := ["ID", "Title", "Author", "Genre", "Price", "Stock", "ISBN"]
	var data: Array = []
	for r in rows:
		data.append([
			str(r.get("id", "")),
			r.get("title", ""),
			r.get("author", ""),
			r.get("genre", ""),
			"$%.2f" % r.get("price", 0.0),
			str(r.get("stock", 0)),
			r.get("isbn", ""),
		])
	_print_table("Books (%d)" % rows.size(), headers, data)


func _show_low_stock() -> void:
	var rows := BookStore.get_low_stock_books()
	if rows.is_empty():
		_print_output("No books are at or below their low-stock alert threshold.")
		return
	var headers := ["ID", "Title", "Stock", "Alert At", "Author"]
	var data: Array = []
	for r in rows:
		data.append([
			str(r.get("id", "")),
			r.get("title", ""),
			str(r.get("stock", 0)),
			str(r.get("low_stock_alert", 5)),
			r.get("author", ""),
		])
	_print_table("Low Stock Books (%d)" % rows.size(), headers, data)


# ── Customers ─────────────────────────────────────────────────────────────────

func _seed_customers() -> void:
	var added := 0
	var skipped := 0
	for c in SEED_CUSTOMERS:
		var err := Auth.add_account(
			c["name"],
			c.get("email", ""),
			c.get("username", ""),
			c.get("password", "password"),
			"customer",
			c.get("phone", ""),
			c.get("notes", "")
		)
		if err == "":
			added += 1
		else:
			skipped += 1
			print("DevTools: skipped customer '%s': %s" % [c["name"], err])
	_set_status("Seeded %d customers (%d skipped)." % [added, skipped])
	_show_customers()


func _show_customers() -> void:
	var rows := BookStore.get_all_customers()
	if rows.is_empty():
		_print_output("(no customers in database)")
		return
	var headers := ["ID", "Name", "Email", "Phone", "Sales", "Spent"]
	var data: Array = []
	for r in rows:
		data.append([
			str(r.get("id", "")),
			r.get("name", ""),
			r.get("email", ""),
			r.get("phone", ""),
			str(r.get("total_sales", 0)),
			"$%.2f" % r.get("total_spent", 0.0),
		])
	_print_table("Customers (%d)" % rows.size(), headers, data)


# ── Sales ──────────────────────────────────────────────────────────────────────

func _seed_sales() -> void:
	var books := BookStore.get_all_books()
	if books.is_empty():
		_set_status("Seed books first before seeding sales.", true)
		return
	var customers := BookStore.get_all_customers()

	var methods := ["cash", "card"]
	var rng     := RandomNumberGenerator.new()
	rng.randomize()

	for i in 6:
		var book       = books[rng.randi() % books.size()]
		var qty        := rng.randi_range(1, 3)
		var account_id: int = -1
		if not customers.is_empty():
			account_id = customers[rng.randi() % customers.size()]["id"]
		var method = methods[rng.randi() % 2]
		BookStore.complete_sale(
			[{ "book_id": book["id"], "qty": qty, "price": book["price"] }],
			method,
			account_id
		)

	_set_status("Seeded 6 random sales.")
	_show_sales()

func _seed_historical_sales() -> void:
	var books := BookStore.get_all_books()
	if books.is_empty():
		_set_status("Seed books first before seeding sales.", true)
		return
	var customers := BookStore.get_all_customers()
	var methods   := ["cash", "card"]
	var rng       := RandomNumberGenerator.new()
	rng.randomize()

	# Generate ~120 sales spread across the past 12 months with realistic
	# day-of-month and multi-item variance for chart/report testing.
	var now       := Time.get_date_dict_from_system()
	var this_year := int(now["year"])
	var this_month := int(now["month"])

	var added := 0
	for month_offset in 12:
		# Work backwards: offset 0 = this month, 11 = 11 months ago.
		var m := this_month - month_offset
		var y := this_year
		while m <= 0:
			m += 12
			y -= 1

		# Vary sales volume per month (8–18) so the chart has natural peaks.
		var count := rng.randi_range(8, 18)
		for _i in count:
			var day := rng.randi_range(1, 28)  # 28 is safe for all months
			var hour   := rng.randi_range(9, 20)
			var minute := rng.randi_range(0, 59)
			var ts := "%04d-%02d-%02d %02d:%02d:00" % [y, m, day, hour, minute]

			# 1–3 line items per sale
			var item_count := rng.randi_range(1, 3)
			var cart: Array = []
			for _j in item_count:
				var book = books[rng.randi() % books.size()]
				cart.append({ "book_id": book["id"], "qty": rng.randi_range(1, 2), "price": book["price"] })

			var account_id: int = -1
			if not customers.is_empty() and rng.randf() > 0.25:
				account_id = customers[rng.randi() % customers.size()]["id"]
			var method: String = methods[rng.randi() % 2]

			# Insert sale header with the backdated timestamp.
			var subtotal := 0.0
			for item in cart:
				subtotal += item["price"] * item["qty"]
			var tax   := subtotal * 0.08
			var total := subtotal + tax
			BookStore.db.query_with_bindings(
				"INSERT INTO sales (account_id, payment_method, subtotal, tax, total, created_at) VALUES (?, ?, ?, ?, ?, ?);",
				[account_id if account_id > 0 else null, method, subtotal, tax, total, ts]
			)
			var sale_id: int = BookStore.db.last_insert_rowid
			for item in cart:
				BookStore.db.query_with_bindings(
					"INSERT INTO sale_items (sale_id, book_id, qty, price) VALUES (?, ?, ?, ?);",
					[sale_id, item["book_id"], item["qty"], item["price"]]
				)
			added += 1

	_set_status("Seeded %d historical sales across 12 months." % added)
	_show_sales()


func _show_sales() -> void:
	var rows := BookStore.get_recent_sales(100)
	if rows.is_empty():
		_print_output("(no sales in database)")
		return
	var headers := ["ID", "Customer", "Method", "Subtotal", "Tax", "Total", "Date"]
	var data: Array = []
	for r in rows:
		data.append([
			str(r.get("id", "")),
			r.get("account_name", "Walk-in") if r.get("account_name", "") != "" else "Walk-in",
			r.get("payment_method", ""),
			"$%.2f" % r.get("subtotal", 0.0),
			"$%.2f" % r.get("tax", 0.0),
			"$%.2f" % r.get("total", 0.0),
			r.get("created_at", ""),
		])
	_print_table("Recent Sales (%d)" % rows.size(), headers, data)


# ── Clear / confirm ────────────────────────────────────────────────────────────

func _confirm_clear(table: String) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Confirm Clear"
	dialog.dialog_text = "Delete ALL rows from [%s]?\n\nThis cannot be undone." % table
	dialog.min_size = Vector2(340, 120)
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func():
		_do_clear(table)
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())


func _do_clear(table: String) -> void:
	match table:
		"books":
			BookStore.db.query("DELETE FROM sale_items;")
			BookStore.db.query("DELETE FROM sales;")
			BookStore.db.query("DELETE FROM books;")
			BookStore.db.query("DELETE FROM sqlite_sequence WHERE name='books';")
			BookStore.db.query("DELETE FROM sqlite_sequence WHERE name='sales';")
			BookStore.db.query("DELETE FROM sqlite_sequence WHERE name='sale_items';")
			_set_status("Cleared books, sales, and sale_items (cascade).")
		"customers":
			BookStore.db.query("UPDATE sales SET account_id = NULL WHERE account_id IN (SELECT id FROM accounts WHERE role = 'customer');")
			BookStore.db.query("DELETE FROM accounts WHERE role = 'customer';")
			_set_status("Cleared customer accounts (sales unlinked).")
		"sales":
			BookStore.db.query("DELETE FROM sale_items;")
			BookStore.db.query("DELETE FROM sales;")
			BookStore.db.query("DELETE FROM sqlite_sequence WHERE name='sales';")
			BookStore.db.query("DELETE FROM sqlite_sequence WHERE name='sale_items';")
			_set_status("Cleared sales and sale_items.")
	_print_output("Table [%s] cleared." % table)


# ── Raw query ──────────────────────────────────────────────────────────────────

func _run_raw() -> void:
	var sql := raw_input.text.strip_edges()
	if sql.is_empty():
		return

	BookStore.db.query(sql)
	var result := BookStore.db.query_result

	if result.is_empty():
		_print_output("Query executed. No rows returned.")
		_set_status("OK — 0 rows.")
		return

	var headers := result[0].keys()
	var data: Array = []
	for row in result:
		var cells: Array = []
		for key in headers:
			cells.append(str(row.get(key, "")))
		data.append(cells)

	_print_table("Result (%d rows)" % result.size(), headers, data)
	_set_status("OK — %d rows." % result.size())


# ── Output helpers ─────────────────────────────────────────────────────────────

func _print_output(text: String) -> void:
	output_label.text = text


func _print_table(title: String, headers: Array, rows: Array) -> void:
	# Work out column widths
	var widths: Array = []
	for h in headers:
		widths.append(h.length())
	for row in rows:
		for i in row.size():
			widths[i] = max(widths[i], str(row[i]).length())

	var lines: PackedStringArray = []

	var sep := "+"
	for w in widths:
		sep += "-".repeat(w + 2) + "+"

	lines.append(title)
	lines.append(sep)

	var header_row := "|"
	for i in headers.size():
		header_row += " " + headers[i].rpad(widths[i]) + " |"
	lines.append(header_row)
	lines.append(sep)

	for row in rows:
		var line := "|"
		for i in row.size():
			line += " " + str(row[i]).rpad(widths[i]) + " |"
		lines.append(line)

	lines.append(sep)
	output_label.text = "\n".join(lines)


func _set_status(msg: String, is_error := false) -> void:
	status_label.text = msg
	status_label.add_theme_color_override(
		"font_color",
		Color.RED if is_error else Color.GREEN
	)
