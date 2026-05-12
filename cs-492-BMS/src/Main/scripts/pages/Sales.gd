extends HBoxContainer

@onready var book_search:  LineEdit    = $CartPanel/SearchBar/BookSearch
@onready var add_btn:      Button      = $CartPanel/SearchBar/AddBtn
@onready var cart_items:   VBoxContainer = $CartPanel/CartScroll/CartItems
@onready var subtotal_val: Label       = $SummaryPanel/SummaryLayout/SubtotalRow/SubtotalValue
@onready var tax_val:      Label       = $SummaryPanel/SummaryLayout/TaxRow/TaxValue
@onready var total_val:    Label       = $SummaryPanel/SummaryLayout/TotalRow/TotalValue
@onready var checkout_btn: Button      = $SummaryPanel/SummaryLayout/CheckoutBtn

const TAX_RATE := 0.08

var cart: Array = []  # Array of { book, qty }

func _ready() -> void:
	add_btn.pressed.connect(_on_add_pressed)
	checkout_btn.pressed.connect(_on_checkout)

func _on_add_pressed() -> void:
	var query := book_search.text.strip_edges()
	if query.is_empty():
		return
	# TODO: look up book in your data autoload
	# For now add a placeholder
	_add_to_cart({ "title": query, "author": "Unknown", "price": 9.99 })
	book_search.clear()

func _add_to_cart(book: Dictionary) -> void:
	for entry in cart:
		if entry["book"]["title"] == book["title"]:
			entry["qty"] += 1
			_refresh_cart()
			return
	cart.append({ "book": book, "qty": 1 })
	_refresh_cart()

func _refresh_cart() -> void:
	for child in cart_items.get_children():
		child.queue_free()

	var subtotal := 0.0
	for entry in cart:
		var row := _make_cart_row(entry)
		cart_items.add_child(row)
		subtotal += entry["book"]["price"] * entry["qty"]

	var tax   := subtotal * TAX_RATE
	var total := subtotal + tax
	subtotal_val.text = "$%.2f" % subtotal
	tax_val.text      = "$%.2f" % tax
	total_val.text    = "$%.2f" % total

func _make_cart_row(entry: Dictionary) -> HBoxContainer:
	var row  := HBoxContainer.new()
	var info := VBoxContainer.new()
	var title_lbl  := Label.new()
	var author_lbl := Label.new()
	title_lbl.text  = entry["book"]["title"]
	author_lbl.text = entry["book"]["author"]
	info.add_child(title_lbl)
	info.add_child(author_lbl)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var minus_btn := Button.new()
	minus_btn.text = "−"
	minus_btn.pressed.connect(func(): _change_qty(entry, -1))

	var qty_lbl := Label.new()
	qty_lbl.text = str(entry["qty"])

	var plus_btn := Button.new()
	plus_btn.text = "+"
	plus_btn.pressed.connect(func(): _change_qty(entry, 1))

	var price_lbl := Label.new()
	price_lbl.text = "$%.2f" % (entry["book"]["price"] * entry["qty"])

	row.add_child(info)
	row.add_child(minus_btn)
	row.add_child(qty_lbl)
	row.add_child(plus_btn)
	row.add_child(price_lbl)
	return row

func _change_qty(entry: Dictionary, delta: int) -> void:
	entry["qty"] += delta
	if entry["qty"] <= 0:
		cart.erase(entry)
	_refresh_cart()

func _on_checkout() -> void:
	if cart.is_empty():
		return
	# TODO: record sale in your data autoload, print receipt, etc.
	print("Sale completed. Total: ", total_val.text)
	cart.clear()
	_refresh_cart()
