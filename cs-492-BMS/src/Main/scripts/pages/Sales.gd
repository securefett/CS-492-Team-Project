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
@onready var customer_label:  Label         = $SummaryPanel/SummaryLayout/CustomerLabel
@onready var customer_option: OptionButton = $SummaryPanel/SummaryLayout/CustomerOption
@onready var checkout_btn:   Button        = $SummaryPanel/SummaryLayout/CheckoutBtn
@onready var error_label:    Label         = $SummaryPanel/SummaryLayout/ErrorLabel

# ── Card detail nodes ──────────────────────────────────────────────────────────
@onready var card_details:   VBoxContainer = $SummaryPanel/SummaryLayout/CardDetails
@onready var card_number:    LineEdit      = $SummaryPanel/SummaryLayout/CardDetails/CardNumberRow/CardNumber
@onready var card_expiry:    LineEdit      = $SummaryPanel/SummaryLayout/CardDetails/ExpiryRow/ExpiryCol/CardExpiry
@onready var card_cvv:       LineEdit      = $SummaryPanel/SummaryLayout/CardDetails/ExpiryRow/CVVCol/CardCVV
@onready var card_name:      LineEdit      = $SummaryPanel/SummaryLayout/CardDetails/CardNameRow/CardName

# ── Cash detail nodes ──────────────────────────────────────────────────────────
@onready var cash_details:   VBoxContainer = $SummaryPanel/SummaryLayout/CashDetails
@onready var cash_tendered:  LineEdit      = $SummaryPanel/SummaryLayout/CashDetails/TenderedRow/CashTendered
@onready var change_val:     Label         = $SummaryPanel/SummaryLayout/CashDetails/ChangeRow/ChangeValue

const TAX_RATE := 0.08

# Each entry: { "book": {id, title, author, price, stock}, "qty": int }
var cart: Array = []
var _customers: Array = []


func _ready() -> void:
	book_search.text_changed.connect(_on_search_changed)
	book_search.focus_exited.connect(_hide_results)
	add_btn.pressed.connect(_on_add_pressed)
	checkout_btn.pressed.connect(_on_checkout)

	# ButtonGroup handles mutual exclusion automatically; listen to toggled on
	# either button to react to the selection change.
	pay_card.toggled.connect(_on_payment_method_changed)
	pay_cash.toggled.connect(_on_payment_method_changed)

	cash_tendered.text_changed.connect(_on_cash_tendered_changed)

	# Card number: restrict to digits + spaces, format as groups of 4
	card_number.text_changed.connect(_on_card_number_changed)
	# Expiry: auto-insert slash after MM
	card_expiry.text_changed.connect(_on_expiry_changed)
	# CVV: digits only, max 4
	card_cvv.text_changed.connect(_on_cvv_changed)

	# Default payment to Card (ButtonGroup keeps the other deselected)
	pay_card.button_pressed = true
	_on_payment_method_changed(true)

	search_results.visible = false
	error_label.visible    = false
	empty_label.visible    = true

	_apply_role_visibility()
	_load_customers()
	_refresh_totals()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		_apply_role_visibility()
		_load_customers()


# ── Role-based UI visibility ───────────────────────────────────────────────────

func _apply_role_visibility() -> void:
	var role := Auth.get_role()
	var is_staff := role == "admin" or role == "employee"
	customer_label.visible  = is_staff
	customer_option.visible = is_staff


# ── Customer dropdown ──────────────────────────────────────────────────────────

func _load_customers() -> void:
	_customers = BookStore.get_all_customers()
	customer_option.clear()
	customer_option.add_item("No customer / Walk-in")
	for c in _customers:
		customer_option.add_item(c["name"])


# ── Public API — called by other pages ────────────────────────────────────────

func add_book_to_cart(book: Dictionary) -> void:
	if not is_node_ready():
		await ready
	_add_to_cart(book)


# ── Payment method toggle ─────────────────────────────────────────────────────

func _on_payment_method_changed(_pressed: bool = true) -> void:
	# ButtonGroup ensures only one button is active at a time; we only need to
	# react when a button becomes pressed (ignore the deselection callback).
	var is_card := pay_card.button_pressed
	card_details.visible = is_card
	cash_details.visible = not is_card

	if not is_card:
		_on_cash_tendered_changed(cash_tendered.text)


# ── Card input formatting ─────────────────────────────────────────────────────

func _on_card_number_changed(text: String) -> void:
	# Strip everything except digits
	var digits := ""
	for ch in text:
		if ch.is_valid_int() or ch == "0":
			digits += ch
	digits = digits.left(16)

	# Reformat into groups of 4 separated by spaces
	var formatted := ""
	for i in digits.length():
		if i > 0 and i % 4 == 0:
			formatted += " "
		formatted += digits[i]

	# Avoid recursive signal
	if card_number.text != formatted:
		card_number.set_block_signals(true)
		card_number.text = formatted
		card_number.caret_column = formatted.length()
		card_number.set_block_signals(false)


func _on_expiry_changed(text: String) -> void:
	var digits := ""
	for ch in text:
		if ch.is_valid_int() or ch == "0":
			digits += ch
	digits = digits.left(4)

	var formatted := ""
	if digits.length() > 2:
		formatted = digits.left(2) + "/" + digits.substr(2)
	else:
		formatted = digits

	if card_expiry.text != formatted:
		card_expiry.set_block_signals(true)
		card_expiry.text = formatted
		card_expiry.caret_column = formatted.length()
		card_expiry.set_block_signals(false)


func _on_cvv_changed(text: String) -> void:
	var digits := ""
	for ch in text:
		if ch.is_valid_int() or ch == "0":
			digits += ch
	digits = digits.left(4)
	if card_cvv.text != digits:
		card_cvv.set_block_signals(true)
		card_cvv.text = digits
		card_cvv.caret_column = digits.length()
		card_cvv.set_block_signals(false)


# ── Cash change calculation ───────────────────────────────────────────────────
# May be legacy
func _on_cash_tendered_changed(_text: String) -> void:
	var tendered := cash_tendered.text.to_float()
	var total    := _get_total()
	if tendered >= total and total > 0.0:
		change_val.text = "$%.2f" % (tendered - total)
	else:
		change_val.text = "—"


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
	for child in search_results.get_children():
		if child is Button and not child.disabled:
			child.pressed.emit()
			return


func _hide_results() -> void:
	await get_tree().create_timer(0.15).timeout
	search_results.visible = false
	for child in search_results.get_children():
		child.queue_free()


# ── Cart ──────────────────────────────────────────────────────────────────────

func _add_to_cart(book: Dictionary) -> void:
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

	var info       := VBoxContainer.new()
	var title_lbl  := Label.new()
	var author_lbl := Label.new()
	title_lbl.text  = entry["book"]["title"]
	author_lbl.text = entry["book"]["author"]
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(title_lbl)
	info.add_child(author_lbl)

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

	var price_lbl      := Label.new()
	price_lbl.text      = "$%.2f" % (entry["book"]["price"] * entry["qty"])
	price_lbl.custom_minimum_size.x = 56

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


func _get_total() -> float:
	var subtotal := 0.0
	for entry in cart:
		subtotal += entry["book"]["price"] * entry["qty"]
	return subtotal + subtotal * TAX_RATE


func _refresh_totals() -> void:
	var subtotal := 0.0
	for entry in cart:
		subtotal += entry["book"]["price"] * entry["qty"]
	var tax   := subtotal * TAX_RATE
	var total := subtotal + tax
	subtotal_val.text = "$%.2f" % subtotal
	tax_val.text      = "$%.2f" % tax
	total_val.text    = "$%.2f" % total

	# Refresh change display if cash is selected
	if cash_details.visible:
		_on_cash_tendered_changed(cash_tendered.text)


# ── Checkout ──────────────────────────────────────────────────────────────────

func _on_checkout() -> void:
	if cart.is_empty():
		_show_error("Add at least one book before checking out.")
		return

	var is_card := pay_card.button_pressed

	# ── Validate payment details ──────────────────────────────────────────────
	if is_card:
		var raw_number := card_number.text.replace(" ", "")
		if raw_number.length() < 13 or raw_number.length() > 16:
			_show_error("Please enter a valid card number.")
			return
		if card_expiry.text.length() != 5:
			_show_error("Please enter a valid expiry date (MM/YY).")
			return
		if not _is_expiry_valid(card_expiry.text):
			_show_error("Card expiry date has passed.")
			return
		if card_cvv.text.length() < 3:
			_show_error("Please enter a valid CVV.")
			return
		if card_name.text.strip_edges().length() < 2:
			_show_error("Please enter the name on the card.")
			return
	else:
		var tendered := cash_tendered.text.to_float()
		if tendered <= 0.0:
			_show_error("Please enter the cash amount tendered.")
			return
		if tendered < _get_total():
			_show_error("Cash tendered is less than the total due.")
			return

	var payment := "card" if is_card else "cash"

	var customer_id := -1
	var role := Auth.get_role()
	if role == "customer" or role == "guest":
		# For customer/guest accounts, attribute the sale to the logged-in account
		# (guest has id = -1, which complete_sale already handles as NULL).
		customer_id = Auth.get_current_account().get("id", -1)
	else:
		# Staff: use the dropdown selection
		var selected_idx := customer_option.selected
		if selected_idx > 0:
			customer_id = _customers[selected_idx - 1]["id"]

	var items: Array = []
	for entry in cart:
		items.append({
			"book_id": entry["book"]["id"],
			"qty":     entry["qty"],
			"price":   entry["book"]["price"],
		})

	var sale_id := BookStore.complete_sale(items, payment, customer_id)

	_show_receipt(sale_id, is_card)
	cart.clear()
	_refresh_cart()
	if customer_option.visible:
		customer_option.selected = 0
	_clear_payment_fields()


func _is_expiry_valid(expiry: String) -> bool:
	# expiry is "MM/YY"
	var parts := expiry.split("/")
	if parts.size() != 2:
		return false
	var month := parts[0].to_int()
	var year  := 2000 + parts[1].to_int()
	var now   := Time.get_date_dict_from_system()
	if year > now["year"]:
		return true
	if year == now["year"] and month >= now["month"]:
		return true
	return false


func _clear_payment_fields() -> void:
	card_number.clear()
	card_expiry.clear()
	card_cvv.clear()
	card_name.clear()
	cash_tendered.clear()
	change_val.text = "—"


func _show_receipt(sale_id: int, paid_by_card: bool) -> void:
	var sale_items := BookStore.get_sale_items(sale_id)

	var dialog   := AcceptDialog.new()
	dialog.title  = "Sale Complete  ✓"

	var lines := ["Receipt — Sale #%d\n" % sale_id]
	for item in sale_items:
		lines.append("  %s  ×%d  —  $%.2f" % [item["book_title"], item["qty"], item["price"] * item["qty"]])
	lines.append("\nSubtotal : %s" % subtotal_val.text)
	lines.append("Tax      : %s" % tax_val.text)
	lines.append("Total    : %s" % total_val.text)

	if paid_by_card:
		var last4 := card_number.text.replace(" ", "").right(4)
		lines.append("\nPaid via card ending in %s" % last4)
	else:
		var tendered := cash_tendered.text.to_float()
		var change   := tendered - _get_total()
		# After cart.clear() total will be 0, so capture before clearing
		lines.append("\nCash tendered : $%.2f" % tendered)
		lines.append("Change due    : %s" % change_val.text)

	dialog.dialog_text = "\n".join(lines)
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())


# ── Error display ──────────────────────────────────────────────────────────────

func _show_error(msg: String) -> void:
	error_label.text    = msg
	error_label.visible = true
