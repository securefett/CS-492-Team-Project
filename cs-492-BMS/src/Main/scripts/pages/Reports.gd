extends VBoxContainer

# ══════════════════════════════════════════════════════════════════════════════
#  Reports.gd
#
#  Permissions:
#    admin    — both Inventory and Sales tabs visible
#    employee — Inventory tab only; Sales tab hidden
#    others   — page hidden entirely
#
#  Inventory tab (admin + employee)
#    Stat cards → side-by-side Low Stock Alerts / Stock by Genre panels →
#    Inventory List (Title | Genre | Price | Stock, expandable rows) →
#    filters (search, genre, stock level) above the table → Download CSV
#
#  Sales tab (admin only)
#    Date range picker → stat cards →
#    side-by-side Top 5 Books / Sales by Genre →
#    Recent Transactions table with column filters → Download CSV
# ══════════════════════════════════════════════════════════════════════════════

# ── Column widths (px) used by every table so columns line up ─────────────────
const INV_COL_W  := [260, 130, 80, 60]
const TXN_COL_W  := [90, 160, 90, 50, 80, 70, 80]

# ── Inventory nodes ───────────────────────────────────────────────────────────
@onready var tabs:              TabContainer  = $Tabs
@onready var total_stock_value: Label         = $Tabs/Inventory/InvContent/InvCardRow/CardTotalStock/CardTotalStockLayout/TotalStockValue
@onready var titles_value:      Label         = $Tabs/Inventory/InvContent/InvCardRow/CardTitles/CardTitlesLayout/TitlesValue
@onready var low_stock_value:   Label         = $Tabs/Inventory/InvContent/InvCardRow/CardLowStock/CardLowStockLayout/LowStockValue
@onready var retail_value_lbl:  Label         = $Tabs/Inventory/InvContent/InvCardRow/CardRetailValue/CardRetailValueLayout/RetailValueValue
@onready var low_stock_list:    VBoxContainer = $Tabs/Inventory/InvContent/InvSideBySide/LowStockCard/LowStockLayout/LowStockList
@onready var genre_list:        VBoxContainer = $Tabs/Inventory/InvContent/InvSideBySide/GenreCard/GenreLayout/GenreList
@onready var search_box:        LineEdit      = $Tabs/Inventory/InvContent/BooksCard/BooksLayout/InvFilterRow/SearchBox
@onready var genre_filter:      OptionButton  = $Tabs/Inventory/InvContent/BooksCard/BooksLayout/InvFilterRow/GenreFilter
@onready var stock_filter:      OptionButton  = $Tabs/Inventory/InvContent/BooksCard/BooksLayout/InvFilterRow/StockFilter
@onready var books_list:        VBoxContainer = $Tabs/Inventory/InvContent/BooksCard/BooksLayout/BooksList
@onready var inv_download_btn:  Button        = $Tabs/Inventory/InvContent/InvDownloadButton

# ── Sales nodes ───────────────────────────────────────────────────────────────
@onready var sales_tab:           ScrollContainer = $Tabs/Sales
@onready var preset_dropdown:     OptionButton    = $Tabs/Sales/SalesContent/DateRangeRow/PresetDropdown
@onready var date_from_field:     LineEdit        = $Tabs/Sales/SalesContent/DateRangeRow/DateFromField
@onready var date_to_field:       LineEdit        = $Tabs/Sales/SalesContent/DateRangeRow/DateToField
@onready var apply_date_btn:      Button          = $Tabs/Sales/SalesContent/DateRangeRow/ApplyDateButton
@onready var revenue_value:       Label           = $Tabs/Sales/SalesContent/SalesCardRow/CardRevenue/CardRevenueLayout/RevenueValue
@onready var sales_count_value:   Label           = $Tabs/Sales/SalesContent/SalesCardRow/CardSalesCount/CardSalesCountLayout/SalesCountValue
@onready var aov_value:           Label           = $Tabs/Sales/SalesContent/SalesCardRow/CardAOV/CardAOVLayout/AOVValue
@onready var books_sold_value:    Label           = $Tabs/Sales/SalesContent/SalesCardRow/CardBooksSold/CardBooksSoldLayout/BooksSoldValue
@onready var tax_value:           Label           = $Tabs/Sales/SalesContent/SalesCardRow/CardTaxCollected/CardTaxCollectedLayout/TaxCollectedValue
@onready var customers_value:     Label           = $Tabs/Sales/SalesContent/SalesCardRow/CardUniqueCustomers/CardUniqueCustomersLayout/UniqueCustomersValue
@onready var top_books_list:      VBoxContainer   = $Tabs/Sales/SalesContent/SalesSideBySide/TopBooksCard/TopBooksLayout/TopBooksList
@onready var sales_genre_list:    VBoxContainer   = $Tabs/Sales/SalesContent/SalesSideBySide/SalesGenreCard/SalesGenreLayout/SalesGenreList
@onready var txn_customer_filter: OptionButton    = $Tabs/Sales/SalesContent/TxnCard/TxnLayout/TxnFilterRow/TxnCustomerFilter
@onready var txn_payment_filter:  OptionButton    = $Tabs/Sales/SalesContent/TxnCard/TxnLayout/TxnFilterRow/TxnPaymentFilter
@onready var txn_sort_dropdown:   OptionButton    = $Tabs/Sales/SalesContent/TxnCard/TxnLayout/TxnFilterRow/TxnSortDropdown
@onready var txn_list:            VBoxContainer   = $Tabs/Sales/SalesContent/TxnCard/TxnLayout/TxnList
@onready var sales_download_btn:  Button          = $Tabs/Sales/SalesContent/SalesDownloadButton

# ── Shared state ──────────────────────────────────────────────────────────────
var _all_books:      Array  = []
var _all_txns:       Array  = []
var _label_style:    StyleBoxTexture
var _is_admin:       bool   = false
var _sales_from:     String = ""
var _sales_to:       String = ""

const STOCK_FILTER_LABELS := ["All Stock Levels", "In Stock", "Low Stock", "Out of Stock"]
const PRESET_KEYS         := ["today", "month", "6months", "year", "alltime", "custom"]
const PRESET_LABELS       := ["Today", "This Month", "Last 6 Months", "This Year", "All Time", "Custom Range"]
const TXN_SORT_LABELS     := ["Sort: Date (newest)", "Sort: Date (oldest)", "Sort: Total (high)", "Sort: Total (low)"]


# ══════════════════════════════════════════════════════════════════════════════
#  READY
# ══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	var role := Auth.get_role()
	if role != "admin" and role != "employee":
		visible = false
		return

	_is_admin    = (role == "admin")
	_label_style = _make_label_style()

	# Hide Sales tab for employees — set_tab_hidden keeps the index stable.
	if not _is_admin:
		tabs.set_tab_hidden(1, true)

	# Inventory wiring.
	_populate_genre_filter()
	_populate_stock_filter()
	search_box.text_changed.connect(_on_inv_filter_changed)
	genre_filter.item_selected.connect(_on_inv_filter_changed.unbind(1))
	stock_filter.item_selected.connect(_on_inv_filter_changed.unbind(1))
	inv_download_btn.pressed.connect(_on_inv_download_pressed)

	# Sales wiring (admin only).
	if _is_admin:
		_populate_preset_dropdown()
		_populate_txn_sort()
		preset_dropdown.item_selected.connect(_on_preset_selected)
		apply_date_btn.pressed.connect(_on_apply_date_pressed)
		txn_customer_filter.item_selected.connect(_on_txn_filter_changed.unbind(1))
		txn_payment_filter.item_selected.connect(_on_txn_filter_changed.unbind(1))
		txn_sort_dropdown.item_selected.connect(_on_txn_filter_changed.unbind(1))
		sales_download_btn.pressed.connect(_on_sales_download_pressed)
		_apply_preset("month")

	_load_inv_data()


# ══════════════════════════════════════════════════════════════════════════════
#  INVENTORY — DATA
# ══════════════════════════════════════════════════════════════════════════════

func _load_inv_data() -> void:
	_all_books = BookStore.get_all_books()
	_refresh_inv_stat_cards()
	_refresh_genre_panel()
	_refresh_low_stock_panel()
	_refresh_books_list()


func _refresh_inv_stat_cards() -> void:
	var total_stock := 0
	var retail_val  := 0.0
	var low_count   := 0
	for book in _all_books:
		var stock: int   = book.get("stock", 0)
		var price: float = book.get("price", 0.0)
		total_stock += stock
		retail_val  += stock * price
		if stock <= book.get("low_stock_alert", 5):
			low_count += 1
	total_stock_value.text = "%d"  % total_stock
	titles_value.text      = "%d"  % _all_books.size()
	low_stock_value.text   = "%d"  % low_count
	retail_value_lbl.text  = "$%s" % _fmt_currency(retail_val)


func _refresh_genre_panel() -> void:
	_clear_children(genre_list)
	var totals: Dictionary = {}
	for book in _all_books:
		var g: String = book.get("genre", "") if book.get("genre", "") != "" else "Other"
		totals[g] = totals.get(g, 0) + book.get("stock", 0)
	if totals.is_empty():
		_add_placeholder(genre_list, "No books in database.")
		return
	var pairs: Array = []
	for k in totals:
		pairs.append([k, totals[k]])
	pairs.sort_custom(func(a, b): return a[1] > b[1])
	var grand := 0
	for p in pairs: grand += p[1]
	if grand == 0: grand = 1
	for pair in pairs:
		var pct := int(round(float(pair[1]) / float(grand) * 100.0))
		_add_two_col(genre_list, pair[0], "%d units (%d%%)" % [pair[1], pct])


func _refresh_low_stock_panel() -> void:
	_clear_children(low_stock_list)
	var alerts: Array = BookStore.get_low_stock_books()
	if alerts.is_empty():
		_add_placeholder(low_stock_list, "No low-stock titles.")
		return
	for book in alerts:
		_add_two_col(low_stock_list,
			book.get("title", "Unknown"),
			"%d / %d" % [book.get("stock", 0), book.get("low_stock_alert", 5)])


func _refresh_books_list() -> void:
	_clear_children(books_list)
	var filtered := _apply_inv_filters()
	if filtered.is_empty():
		_add_placeholder(books_list, "No books match the current filters.")
		return

	# Fixed-width header.
	_add_inv_header()

	for book in filtered:
		_add_inv_book_row(book)


func _add_inv_header() -> void:
	var row := HBoxContainer.new()
	var cols := ["Title", "Genre", "Price", "Stock"]
	for i in cols.size():
		var lbl              := Label.new()
		lbl.text              = cols[i]
		lbl.custom_minimum_size = Vector2(INV_COL_W[i], 0)
		lbl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		lbl.add_theme_stylebox_override("normal", _label_style)
		lbl.add_theme_font_size_override("font_size", 13)
		row.add_child(lbl)
	# Spacer for the expand button column.
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(30, 0)
	row.add_child(spacer)
	books_list.add_child(row)


func _add_inv_book_row(book: Dictionary) -> void:
	# Wrapper holds the summary row + a collapsible detail panel.
	var wrapper := VBoxContainer.new()
	books_list.add_child(wrapper)

	# Summary row: Title | Genre | Price | Stock | toggle button.
	var row := HBoxContainer.new()
	wrapper.add_child(row)

	var cells := [
		_or_dash(book.get("title",  "")),
		_or_dash(book.get("genre",  "")),
		"$%.2f" % book.get("price", 0.0),
		str(book.get("stock", 0)),
	]
	for i in cells.size():
		var lbl := Label.new()
		lbl.text = cells[i]
		lbl.custom_minimum_size    = Vector2(INV_COL_W[i], 0)
		lbl.size_flags_horizontal  = Control.SIZE_SHRINK_BEGIN
		lbl.add_theme_stylebox_override("normal", _label_style)
		row.add_child(lbl)

	# Expand / collapse button.
	var btn := Button.new()
	btn.text                 = "▶"
	btn.custom_minimum_size  = Vector2(30, 0)
	row.add_child(btn)

	# Detail panel (hidden by default).
	var detail := _build_detail_panel(book)
	detail.visible = false
	wrapper.add_child(detail)

	btn.pressed.connect(func():
		detail.visible = not detail.visible
		btn.text = "▼" if detail.visible else "▶"
	)


func _build_detail_panel(book: Dictionary) -> PanelContainer:
	var panel   := PanelContainer.new()
	var vbox    := VBoxContainer.new()
	panel.add_child(vbox)

	var fields := [
		["Author",          _or_dash(book.get("author",    ""))],
		["ISBN",            _or_dash(book.get("isbn",      ""))],
		["Publisher",       _or_dash(book.get("publisher", ""))],
		["Year",            str(book.get("year", "")) if str(book.get("year","")) != "0" else "—"],
		["Cost",            "$%.2f" % book.get("cost",  0.0)],
		["Low Stock Alert", str(book.get("low_stock_alert", 5))],
		["Description",     _or_dash(book.get("description", ""))],
	]

	for pair in fields:
		var hbox := HBoxContainer.new()
		var key_lbl := Label.new()
		key_lbl.text = pair[0] + ":"
		key_lbl.custom_minimum_size = Vector2(120, 0)
		key_lbl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		key_lbl.add_theme_stylebox_override("normal", _label_style)
		key_lbl.add_theme_font_size_override("font_size", 12)
		var val_lbl := Label.new()
		val_lbl.text = pair[1]
		val_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		val_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		val_lbl.add_theme_stylebox_override("normal", _label_style)
		hbox.add_child(key_lbl)
		hbox.add_child(val_lbl)
		vbox.add_child(hbox)

	return panel


# ══════════════════════════════════════════════════════════════════════════════
#  INVENTORY — FILTERS
# ══════════════════════════════════════════════════════════════════════════════

func _populate_genre_filter() -> void:
	genre_filter.add_item("All Genres", 0)
	var seen: Dictionary = {}
	for book in BookStore.get_all_books():
		var g: String = book.get("genre", "")
		if g != "" and not seen.has(g):
			seen[g] = true
			genre_filter.add_item(g)
	genre_filter.selected = 0


func _populate_stock_filter() -> void:
	for i in STOCK_FILTER_LABELS.size():
		stock_filter.add_item(STOCK_FILTER_LABELS[i], i)
	stock_filter.selected = 0


func _on_inv_filter_changed(_unused = null) -> void:
	_refresh_books_list()


func _apply_inv_filters() -> Array:
	var query:       String = search_box.text.strip_edges().to_lower()
	var genre_label: String = genre_filter.get_item_text(genre_filter.selected)
	var stock_idx:   int    = stock_filter.selected
	var result: Array = []
	for book in _all_books:
		if query != "":
			var t: String = book.get("title", "").to_lower()
			var g: String = book.get("genre", "").to_lower()
			if not (t.contains(query) or g.contains(query)):
				continue
		if genre_label != "All Genres":
			if book.get("genre", "") != genre_label:
				continue
		var stock: int = book.get("stock", 0)
		var alert: int = book.get("low_stock_alert", 5)
		match stock_idx:
			1: if stock <= 0: continue
			2: if not (stock > 0 and stock <= alert): continue
			3: if stock > 0: continue
		result.append(book)
	return result


# ══════════════════════════════════════════════════════════════════════════════
#  INVENTORY — CSV DOWNLOAD
# ══════════════════════════════════════════════════════════════════════════════

func _on_inv_download_pressed() -> void:
	var rows  := _apply_inv_filters()
	var lines := PackedStringArray()
	lines.append("Title,Author,Genre,ISBN,Publisher,Year,Price,Cost,Stock,Low Stock Alert,Retail Value")
	for book in rows:
		var stock: int   = book.get("stock", 0)
		var price: float = book.get("price", 0.0)
		lines.append("%s,%s,%s,%s,%s,%s,%.2f,%.2f,%d,%d,%.2f" % [
			_csv_esc(book.get("title",     "")),
			_csv_esc(book.get("author",    "")),
			_csv_esc(book.get("genre",     "")),
			_csv_esc(book.get("isbn",      "")),
			_csv_esc(book.get("publisher", "")),
			_csv_esc(str(book.get("year",  ""))),
			price, book.get("cost", 0.0), stock,
			book.get("low_stock_alert", 5), stock * price,
		])
	_write_and_open(lines, "inventory_report")


# ══════════════════════════════════════════════════════════════════════════════
#  SALES — DATE RANGE
# ══════════════════════════════════════════════════════════════════════════════

func _populate_preset_dropdown() -> void:
	for i in PRESET_LABELS.size():
		preset_dropdown.add_item(PRESET_LABELS[i], i)
	preset_dropdown.selected = 1


func _on_preset_selected(index: int) -> void:
	var key = PRESET_KEYS[index]
	if key != "custom":
		_apply_preset(key)


func _apply_preset(key: String) -> void:
	var r := BookStore.date_range_for(key)
	_sales_from          = r["from"]
	_sales_to            = r["to"]
	date_from_field.text = _sales_from
	date_to_field.text   = _sales_to
	_load_sales_data()


func _on_apply_date_pressed() -> void:
	var from_raw := date_from_field.text.strip_edges()
	var to_raw   := date_to_field.text.strip_edges()
	if not _is_valid_date(from_raw) or not _is_valid_date(to_raw):
		date_from_field.placeholder_text = "Use YYYY-MM-DD"
		date_to_field.placeholder_text   = "Use YYYY-MM-DD"
		return
	date_from_field.placeholder_text = "YYYY-MM-DD"
	date_to_field.placeholder_text   = "YYYY-MM-DD"
	_sales_from = from_raw
	_sales_to   = to_raw
	preset_dropdown.selected = PRESET_KEYS.find("custom")
	_load_sales_data()


func _is_valid_date(s: String) -> bool:
	if s.length() != 10: return false
	if s[4] != "-" or s[7] != "-": return false
	return s.substr(0,4).is_valid_int() and s.substr(5,2).is_valid_int() and s.substr(8,2).is_valid_int()


# ══════════════════════════════════════════════════════════════════════════════
#  SALES — DATA
# ══════════════════════════════════════════════════════════════════════════════

func _load_sales_data() -> void:
	_refresh_sales_stat_cards()
	_refresh_top_books_panel()
	_refresh_sales_genre_panel()
	_fetch_txns()
	_populate_txn_filters()
	_refresh_txn_list()


func _refresh_sales_stat_cards() -> void:
	BookStore.db.query_with_bindings("""
		SELECT
			COALESCE(SUM(total),    0.0) AS revenue,
			COALESCE(SUM(tax),      0.0) AS tax,
			COUNT(*)                     AS txn_count,
			COALESCE(AVG(total),    0.0) AS aov
		FROM sales WHERE date(created_at) BETWEEN ? AND ?;
	""", [_sales_from, _sales_to])
	var row: Dictionary = BookStore.db.query_result[0] if not BookStore.db.query_result.is_empty() else {}

	BookStore.db.query_with_bindings("""
		SELECT COALESCE(SUM(si.qty), 0) AS books_sold
		FROM sale_items si JOIN sales s ON s.id = si.sale_id
		WHERE date(s.created_at) BETWEEN ? AND ?;
	""", [_sales_from, _sales_to])
	var books_sold: int = BookStore.db.query_result[0].get("books_sold", 0) if not BookStore.db.query_result.is_empty() else 0

	BookStore.db.query_with_bindings("""
		SELECT COUNT(DISTINCT account_id) AS uc
		FROM sales WHERE account_id IS NOT NULL AND date(created_at) BETWEEN ? AND ?;
	""", [_sales_from, _sales_to])
	var uc: int = BookStore.db.query_result[0].get("uc", 0) if not BookStore.db.query_result.is_empty() else 0

	revenue_value.text     = "$%s" % _fmt_currency(row.get("revenue",   0.0))
	sales_count_value.text = "%d"  % row.get("txn_count",  0)
	aov_value.text         = "$%s" % _fmt_currency(row.get("aov",       0.0))
	books_sold_value.text  = "%d"  % books_sold
	tax_value.text         = "$%s" % _fmt_currency(row.get("tax",       0.0))
	customers_value.text   = "%d"  % uc


func _refresh_top_books_panel() -> void:
	_clear_children(top_books_list)
	BookStore.db.query_with_bindings("""
		SELECT b.title, b.author,
			COALESCE(SUM(si.qty), 0)            AS total_sold,
			COALESCE(SUM(si.qty * si.price), 0) AS revenue
		FROM books b
		LEFT JOIN sale_items si ON si.book_id = b.id
		LEFT JOIN sales s ON s.id = si.sale_id AND date(s.created_at) BETWEEN ? AND ?
		GROUP BY b.id ORDER BY total_sold DESC LIMIT 5;
	""", [_sales_from, _sales_to])
	var rows: Array = BookStore.db.query_result
	if rows.is_empty():
		_add_placeholder(top_books_list, "No sales data for this period.")
		return
	for row in rows:
		_add_two_col(top_books_list,
			"%s — %s" % [row.get("title", "?"), row.get("author", "?")],
			"%d sold  ($%s)" % [row.get("total_sold", 0), _fmt_currency(row.get("revenue", 0.0))])


func _refresh_sales_genre_panel() -> void:
	_clear_children(sales_genre_list)
	BookStore.db.query_with_bindings("""
		SELECT COALESCE(b.genre,'Other') AS name, SUM(si.qty) AS sold,
			COALESCE(SUM(si.qty * si.price), 0) AS revenue,
			CAST(ROUND((SUM(si.qty) * 100.0) /
				NULLIF((SELECT SUM(si2.qty) FROM sale_items si2
					JOIN sales s2 ON s2.id = si2.sale_id
					WHERE date(s2.created_at) BETWEEN ? AND ?), 0)
			) AS INTEGER) AS pct
		FROM sale_items si
		JOIN books b ON b.id = si.book_id
		JOIN sales s ON s.id = si.sale_id
		WHERE date(s.created_at) BETWEEN ? AND ?
		GROUP BY b.genre ORDER BY sold DESC;
	""", [_sales_from, _sales_to, _sales_from, _sales_to])
	var rows: Array = BookStore.db.query_result
	if rows.is_empty():
		_add_placeholder(sales_genre_list, "No sales data for this period.")
		return
	for row in rows:
		_add_two_col(sales_genre_list,
			str(row.get("name", "Other")),
			"%d sold  %d%%" % [row.get("sold", 0), row.get("pct", 0)])


# ══════════════════════════════════════════════════════════════════════════════
#  SALES — TRANSACTIONS
# ══════════════════════════════════════════════════════════════════════════════

func _fetch_txns() -> void:
	BookStore.db.query_with_bindings("""
		SELECT s.id, s.created_at, s.payment_method, s.subtotal, s.tax, s.total,
			COALESCE(a.name, 'Guest') AS customer_name,
			COUNT(si.id) AS item_count
		FROM sales s
		LEFT JOIN accounts a ON a.id = s.account_id
		LEFT JOIN sale_items si ON si.sale_id = s.id
		WHERE date(s.created_at) BETWEEN ? AND ?
		GROUP BY s.id ORDER BY s.created_at DESC LIMIT 200;
	""", [_sales_from, _sales_to])
	_all_txns = BookStore.db.query_result


func _populate_txn_filters() -> void:
	# Rebuild customer and payment filter dropdowns from the fetched data.
	txn_customer_filter.clear()
	txn_payment_filter.clear()
	txn_customer_filter.add_item("All Customers")
	txn_payment_filter.add_item("All Payment Methods")
	var seen_c: Dictionary = {}
	var seen_p: Dictionary = {}
	for row in _all_txns:
		var c: String = str(row.get("customer_name",  "Guest"))
		var p: String = str(row.get("payment_method", "")).capitalize()
		if not seen_c.has(c):
			seen_c[c] = true
			txn_customer_filter.add_item(c)
		if not seen_p.has(p):
			seen_p[p] = true
			txn_payment_filter.add_item(p)
	txn_customer_filter.selected = 0
	txn_payment_filter.selected  = 0


func _populate_txn_sort() -> void:
	for label in TXN_SORT_LABELS:
		txn_sort_dropdown.add_item(label)
	txn_sort_dropdown.selected = 0


func _on_txn_filter_changed(_unused = null) -> void:
	_refresh_txn_list()


func _apply_txn_filters() -> Array:
	var cust_label := txn_customer_filter.get_item_text(txn_customer_filter.selected)
	var pay_label  := txn_payment_filter.get_item_text(txn_payment_filter.selected)
	var sort_idx   := txn_sort_dropdown.selected

	var result: Array = []
	for row in _all_txns:
		if cust_label != "All Customers":
			if str(row.get("customer_name", "Guest")) != cust_label:
				continue
		if pay_label != "All Payment Methods":
			if str(row.get("payment_method", "")).capitalize() != pay_label:
				continue
		result.append(row)

	match sort_idx:
		0: result.sort_custom(func(a, b): return str(a.get("created_at","")) > str(b.get("created_at","")))
		1: result.sort_custom(func(a, b): return str(a.get("created_at","")) < str(b.get("created_at","")))
		2: result.sort_custom(func(a, b): return float(a.get("total", 0)) > float(b.get("total", 0)))
		3: result.sort_custom(func(a, b): return float(a.get("total", 0)) < float(b.get("total", 0)))

	return result


func _refresh_txn_list() -> void:
	_clear_children(txn_list)
	var rows := _apply_txn_filters()

	if rows.is_empty():
		_add_placeholder(txn_list, "No transactions match the current filters.")
		return

	# Fixed-width header.
	_add_txn_header()

	for row in rows:
		var raw_date: String = str(row.get("created_at", ""))
		var date_lbl: String = raw_date.substr(0, 10) if raw_date.length() >= 10 else raw_date
		_add_txn_row([
			date_lbl,
			str(row.get("customer_name",  "Guest")),
			str(row.get("payment_method", "—")).capitalize(),
			str(row.get("item_count",     0)),
			"$%.2f" % row.get("subtotal", 0.0),
			"$%.2f" % row.get("tax",      0.0),
			"$%.2f" % row.get("total",    0.0),
		])


func _add_txn_header() -> void:
	var row  := HBoxContainer.new()
	var cols := ["Date", "Customer", "Payment", "Items", "Subtotal", "Tax", "Total"]
	for i in cols.size():
		var lbl              := Label.new()
		lbl.text              = cols[i]
		lbl.custom_minimum_size = Vector2(TXN_COL_W[i], 0)
		lbl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		lbl.add_theme_stylebox_override("normal", _label_style)
		lbl.add_theme_font_size_override("font_size", 13)
		row.add_child(lbl)
	txn_list.add_child(row)


func _add_txn_row(values: Array) -> void:
	var row := HBoxContainer.new()
	for i in values.size():
		var lbl              := Label.new()
		lbl.text              = values[i]
		lbl.custom_minimum_size = Vector2(TXN_COL_W[i], 0)
		lbl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		lbl.add_theme_stylebox_override("normal", _label_style)
		row.add_child(lbl)
	txn_list.add_child(row)


# ══════════════════════════════════════════════════════════════════════════════
#  SALES — CSV DOWNLOAD
# ══════════════════════════════════════════════════════════════════════════════

func _on_sales_download_pressed() -> void:
	var rows  := _apply_txn_filters()
	var lines := PackedStringArray()
	lines.append("Sale ID,Date,Customer,Payment Method,Items,Subtotal,Tax,Total")
	for row in rows:
		var raw_date: String = str(row.get("created_at", ""))
		lines.append("%d,%s,%s,%s,%d,%.2f,%.2f,%.2f" % [
			row.get("id", 0),
			raw_date.substr(0, 10) if raw_date.length() >= 10 else raw_date,
			_csv_esc(str(row.get("customer_name",  "Guest"))),
			_csv_esc(str(row.get("payment_method", ""))),
			row.get("item_count", 0),
			row.get("subtotal",   0.0),
			row.get("tax",        0.0),
			row.get("total",      0.0),
		])
	_write_and_open(lines, "sales_report_%s_%s" % [_sales_from, _sales_to])


# ══════════════════════════════════════════════════════════════════════════════
#  UI HELPERS
# ══════════════════════════════════════════════════════════════════════════════

func _add_two_col(parent: Control, left: String, right: String) -> void:
	var row      := HBoxContainer.new()
	var lbl_l    := Label.new()
	var lbl_r    := Label.new()
	lbl_l.text    = left
	lbl_r.text    = right
	lbl_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_l.add_theme_stylebox_override("normal", _label_style)
	row.add_child(lbl_l)
	row.add_child(lbl_r)
	parent.add_child(row)


func _add_placeholder(parent: Control, msg: String) -> void:
	var lbl  := Label.new()
	lbl.text  = msg
	parent.add_child(lbl)


func _clear_children(node: Control) -> void:
	for child in node.get_children():
		child.queue_free()


# ══════════════════════════════════════════════════════════════════════════════
#  UTILITIES
# ══════════════════════════════════════════════════════════════════════════════

func _fmt_currency(amount: float) -> String:
	var cents   := int(round(amount * 100.0))
	var dollars := cents / 100
	var frac    := cents % 100
	var s       := str(dollars)
	var result  := ""
	var count   := 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = s[i] + result
		count += 1
	return "%s.%02d" % [result, frac]


func _make_label_style() -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load("res://src/Main/themes/textures/popup_menu_panel.png")
	sb.texture_margin_left   = 10.0
	sb.texture_margin_top    = 10.0
	sb.texture_margin_right  = 10.0
	sb.texture_margin_bottom = 10.0
	return sb


func _or_dash(s: String) -> String:
	return s if s != "" else "—"


func _csv_esc(value: String) -> String:
	if value.contains(",") or value.contains("\"") or value.contains("\n"):
		return "\"" + value.replace("\"", "\"\"") + "\""
	return value


func _write_and_open(lines: PackedStringArray, base_name: String) -> void:
	var now      := Time.get_date_dict_from_system()
	var filename := "%s_%04d%02d%02d.csv" % [base_name, now["year"], now["month"], now["day"]]
	var path     := "user://" + filename
	var file     := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Reports: could not write '%s'" % path)
		return
	file.store_string("\n".join(lines))
	file.close()
	OS.shell_open(ProjectSettings.globalize_path(path))
