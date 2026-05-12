extends HBoxContainer

@onready var book_search:    LineEdit      = $CartPanel/SearchBar/BookSearch
@onready var add_btn:        Button        = $CartPanel/SearchBar/AddBtn
@onready var search_results: VBoxContainer = $CartPanel/SearchResults
@onready var cart_items:     VBoxContainer = $CartPanel/CartScroll/CartItems
@onready var empty_label:    Label         = $CartPanel/CartScroll/EmptyLabel
@onready var subtotal_val:   Label         = $SummaryPanel/SummaryLayout/SubtotalRow/SubtotalValue
@onready var tax_val:        Label         = $SummaryPanel/SummaryLayout/TaxRow/TaxValue
@onready var total_val:      Label         = $SummaryPanel/SummaryLayout/TotalRow/TotalValue
@onready var pay_card:       Button        = $SummaryPanel/SummaryLayout/PaymentOptions/PayCard
@onready var pay_cash:       Button        = $SummaryPanel/SummaryLayout/PaymentOptions/PayCash
@onready var customer_option: OptionButton = $SummaryPanel/SummaryLayout/CustomerOption
@onready var checkout_btn:   Button        = $SummaryPanel/SummaryLayout/CheckoutBtn
@onready var error_label:    Label         = $SummaryPanel/SummaryLayout/ErrorLabel

const TAX_RATE := 0.08

# Each entry: { "book": {id, title, author, price, stock}, "qty": int }
var cart: Array = []
var _customers: Array = []


func _ready() -> void:
	book_search.text_changed.connect(_on_search_changed)
	book_search.focus_exited.connect(_hide_results)
	add_btn.pressed.connect(_on_add_pressed)
	checkout_btn.pressed.connect(_on_checkout)

	# Default payment to Card
	pay_card.button_pressed = true

	search_results.visible = false
	error_label.visible    = false
	empty_label.visible    = true

	_load_customers()
	_refresh_totals()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		_load_customers()


# ── Customer dropdown ─────────────────────────────────────────────────────────

func _load_customers() -> void:
	_customers = BookStore.get_all_customers()
	customer_option.clear()
	customer_option.add_item("No customer / Walk-in")
	for c in _customers:
		customer_option.add_item(c["name"])


# ── Book search dropdown ──────────────────────────────────────────────────────

func _on_search_changed(query: String) -> void:
	for child in search_results.get_children():
		child.queue_free()

	if query.strip_edges().length() < 2:
		search_results.visible = false
		return

	var results := BookStore.search_books(query)
	if results.is_empty():
		search_results.visible = false
		return

	for book in results:
		var btn := Button.new()
		var stock_note := " (out of stock)" if book["stock"] <= 0 else " — stock: %d" % book["stock"]
		btn.text = "%s  ·  %s%s" % [book["title"], book["author"], stock_note]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.disabled = book["stock"] <= 0
		btn.pressed.connect(_on_result_selected.bind(book))
		search_results.add_child(btn)

	search_results.visible = true


func _on_result_selected(book: Dictionary) -> void:
	_hide_results()
	book_search.clear()
	_add_to_cart(book)


func _on_add_pressed() -> void:
	# Pressing Add confirms the first enabled result if one is showing
	for child in search_results.get_children():
		if child is Button and not child.disabled:
			child.pressed.emit()
			return


func _hide_results() -> void:
	# Small delay so a result button click registers before the list disappears
	await get_tree().create_timer(0.15).timeout
	search_results.visible = false
	for child in search_results.get_children():
		child.queue_free()


# ── Cart ──────────────────────────────────────────────────────────────────────

func _add_to_cart(book: Dictionary) -> void:
	# If already in cart, increment — but don't exceed available stock
	for entry in cart:
		if entry["book"]["id"] == book["id"]:
			if entry["qty"] >= book["stock"]:
				_show_error("No more stock available for \"%s\"." % book["title"])
				return
			entry["qty"] += 1
			_refresh_cart()
			return

	cart.append({ "book": book, "qty": 1 })
	_refresh_cart()


func _refresh_cart() -> void:
	for child in cart_items.get_children():
		child.queue_free()

	empty_label.visible = cart.is_empty()
	error_label.visible = false

	for entry in cart:
		cart_items.add_child(_make_cart_row(entry))

	_refresh_totals()


func _make_cart_row(entry: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Book info
	var info       := VBoxContainer.new()
	var title_lbl  := Label.new()
	var author_lbl := Label.new()
	title_lbl.text  = entry["book"]["title"]
	author_lbl.text = entry["book"]["author"]
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(title_lbl)
	info.add_child(author_lbl)

	# Qty controls
	var minus_btn := Button.new()
	minus_btn.text = "−"
	minus_btn.pressed.connect(_on_qty_changed.bind(entry, -1))

	var qty_lbl      := Label.new()
	qty_lbl.text      = str(entry["qty"])
	qty_lbl.custom_minimum_size.x = 24

	var plus_btn  := Button.new()
	plus_btn.text  = "+"
	plus_btn.pressed.connect(_on_qty_changed.bind(entry, 1))
	plus_btn.disabled = entry["qty"] >= entry["book"]["stock"]

	# Line total
	var price_lbl      := Label.new()
	price_lbl.text      = "$%.2f" % (entry["book"]["price"] * entry["qty"])
	price_lbl.custom_minimum_size.x = 56

	# Remove button
	var remove_btn  := Button.new()
	remove_btn.text  = "✕"
	remove_btn.pressed.connect(_on_remove_item.bind(entry))

	row.add_child(info)
	row.add_child(minus_btn)
	row.add_child(qty_lbl)
	row.add_child(plus_btn)
	row.add_child(price_lbl)
	row.add_child(remove_btn)
	return row


func _on_qty_changed(entry: Dictionary, delta: int) -> void:
	var new_qty = entry["qty"] + delta
	if new_qty <= 0:
		cart.erase(entry)
	else:
		if new_qty > entry["book"]["stock"]:
			_show_error("Only %d in stock." % entry["book"]["stock"])
			return
		entry["qty"] = new_qty
	_refresh_cart()


func _on_remove_item(entry: Dictionary) -> void:
	cart.erase(entry)
	_refresh_cart()


func _refresh_totals() -> void:
	var subtotal := 0.0
	for entry in cart:
		subtotal += entry["book"]["price"] * entry["qty"]
	var tax   := subtotal * TAX_RATE
	var total := subtotal + tax
	subtotal_val.text = "$%.2f" % subtotal
	tax_val.text      = "$%.2f" % tax
	total_val.text    = "$%.2f" % total


# ── Checkout ──────────────────────────────────────────────────────────────────

func _on_checkout() -> void:
	if cart.is_empty():
		_show_error("Add at least one book before checking out.")
		return

	var payment := "card" if pay_card.button_pressed else "cash"

	# Resolve optional customer ID (-1 = walk-in)
	var customer_id := -1
	var selected_idx := customer_option.selected
	if selected_idx > 0:
		customer_id = _customers[selected_idx - 1]["id"]

	# Build the items array expected by BookStore.complete_sale()
	var items: Array = []
	for entry in cart:
		items.append({
			"book_id": entry["book"]["id"],
			"qty":     entry["qty"],
			"price":   entry["book"]["price"],
		})

	var sale_id := BookStore.complete_sale(items, payment, customer_id)

	_show_receipt(sale_id)
	cart.clear()
	_refresh_cart()
	customer_option.selected = 0


func _show_receipt(sale_id: int) -> void:
	var sale_items := BookStore.get_sale_items(sale_id)

	var dialog   := AcceptDialog.new()
	dialog.title  = "Sale Complete  ✓"

	var lines := ["Receipt — Sale #%d\n" % sale_id]
	for item in sale_items:
		lines.append("  %s  ×%d  —  $%.2f" % [item["book_title"], item["qty"], item["price"] * item["qty"]])
	lines.append("\nSubtotal : %s" % subtotal_val.text)
	lines.append("Tax      : %s" % tax_val.text)
	lines.append("Total    : %s" % total_val.text)

	dialog.dialog_text = "\n".join(lines)
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())


# ── Error display ─────────────────────────────────────────────────────────────

func _show_error(msg: String) -> void:
	error_label.text    = msg
	error_label.visible = true
