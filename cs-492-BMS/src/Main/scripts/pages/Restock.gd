extends HBoxContainer

# ── Left panel nodes ──────────────────────────────────────────────────────────
@onready var catalogue_search: LineEdit      = $OrderPanel/SearchBar/CatalogueSearch
@onready var catalogue_list:   VBoxContainer = $OrderPanel/CatalogueScroll/CatalogueList

# ── Right panel — form nodes ──────────────────────────────────────────────────
@onready var selected_label:  Label    = $RightPanel/FormCard/FormLayout/SelectedLabel
@onready var isbn_value:      Label    = $RightPanel/FormCard/FormLayout/ISBNRow/ISBNValue
@onready var cost_value:      Label    = $RightPanel/FormCard/FormLayout/CostRow/CostValue
@onready var avail_value:     Label    = $RightPanel/FormCard/FormLayout/AvailRow/AvailValue
@onready var qty_input:       SpinBox  = $RightPanel/FormCard/FormLayout/QtyInput
@onready var notes_input:     TextEdit = $RightPanel/FormCard/FormLayout/NotesInput
@onready var total_value:     Label    = $RightPanel/FormCard/FormLayout/TotalRow/TotalValue
@onready var error_label:     Label    = $RightPanel/FormCard/FormLayout/ErrorLabel
@onready var place_order_btn: Button   = $RightPanel/FormCard/FormLayout/PlaceOrderBtn

# ── Right panel — history nodes ───────────────────────────────────────────────
@onready var history_list: VBoxContainer = $RightPanel/HistoryCard/HistoryLayout/HistoryScroll/HistoryList

# The manufacturer catalogue row the admin has clicked on
var _selected_item: Dictionary = {}
# Maps ISBN → bookstore book_id, rebuilt on every page visit
var _book_id_map: Dictionary = {}


func _ready() -> void:
	catalogue_search.text_changed.connect(_on_search_changed)
	qty_input.value_changed.connect(_on_qty_changed)
	place_order_btn.pressed.connect(_on_place_order)
	Manufacturer.order_fulfilled.connect(_on_order_fulfilled)

	_refresh_all()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		_refresh_all()


func _refresh_all() -> void:
	_build_book_id_map()
	_refresh_catalogue()
	_refresh_history()


# ── Book ID map ───────────────────────────────────────────────────────────────

func _build_book_id_map() -> void:
	_book_id_map.clear()
	for book in BookStore.get_all_books():
		if book.get("isbn", "") != "":
			_book_id_map[book["isbn"]] = book["id"]


# ── Catalogue list ────────────────────────────────────────────────────────────

func _on_search_changed(query: String) -> void:
	var results := Manufacturer.search_catalogue(query) \
				   if query.strip_edges().length() >= 1 \
				   else Manufacturer.get_catalogue()
	_rebuild_catalogue_list(results)


func _refresh_catalogue() -> void:
	_rebuild_catalogue_list(Manufacturer.get_catalogue())


func _rebuild_catalogue_list(items: Array) -> void:
	for child in catalogue_list.get_children():
		child.queue_free()

	if items.is_empty():
		var lbl := Label.new()
		lbl.text = "No results found."
		catalogue_list.add_child(lbl)
		return

	for item in items:
		catalogue_list.add_child(_make_catalogue_card(item))


func _make_catalogue_card(item: Dictionary) -> PanelContainer:
	var card   := PanelContainer.new()
	var layout := HBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Left: title + author stacked
	var info       := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var title_lbl  := Label.new()
	title_lbl.text  = item["title"]

	var author_lbl  := Label.new()
	author_lbl.text  = item["author"]

	var isbn_lbl  := Label.new()
	isbn_lbl.text  = "ISBN: %s" % item["isbn"]

	info.add_child(title_lbl)
	info.add_child(author_lbl)
	info.add_child(isbn_lbl)

	# Right: cost, availability, select button stacked
	var meta   := VBoxContainer.new()
	meta.size_flags_horizontal = Control.SIZE_SHRINK_END

	var cost_lbl  := Label.new()
	cost_lbl.text  = "$%.2f / unit" % item["unit_cost"]

	var avail_lbl  := Label.new()
	if item["available_qty"] > 0:
		avail_lbl.text = "%d available" % item["available_qty"]
	else:
		avail_lbl.text = "Out of stock"

	# Show whether this book is already in the bookstore catalog
	var in_catalog    := _book_id_map.has(item["isbn"])
	var catalog_lbl   := Label.new()
	catalog_lbl.text   = "✓ In catalog" if in_catalog else "Not in catalog"

	var select_btn         := Button.new()
	select_btn.text         = "Select"
	select_btn.disabled     = item["available_qty"] <= 0
	select_btn.pressed.connect(_on_item_selected.bind(item))

	meta.add_child(cost_lbl)
	meta.add_child(avail_lbl)
	meta.add_child(catalog_lbl)
	meta.add_child(select_btn)

	layout.add_child(info)
	layout.add_child(meta)
	card.add_child(layout)
	return card


# ── Order form ────────────────────────────────────────────────────────────────

func _on_item_selected(item: Dictionary) -> void:
	_selected_item          = item
	error_label.visible     = false
	selected_label.text     = item["title"]
	isbn_value.text         = item["isbn"]
	cost_value.text         = "$%.2f" % item["unit_cost"]
	avail_value.text        = str(item["available_qty"])
	qty_input.max_value     = item["available_qty"]
	qty_input.value         = 1
	place_order_btn.disabled = false
	_update_total()


func _on_qty_changed(_value: float) -> void:
	_update_total()


func _update_total() -> void:
	if _selected_item.is_empty():
		total_value.text = "$0.00"
		return
	total_value.text = "$%.2f" % (_selected_item["unit_cost"] * qty_input.value)


# ── Validation & submission ───────────────────────────────────────────────────

func _on_place_order() -> void:
	error_label.visible = false

	if _selected_item.is_empty():
		_show_error("Please select a book from the catalogue first.")
		return

	var qty := int(qty_input.value)
	if qty <= 0:
		_show_error("Quantity must be at least 1.")
		return
	if qty > _selected_item["available_qty"]:
		_show_error("Quantity exceeds manufacturer stock (%d available)." % _selected_item["available_qty"])
		return

	var isbn   := _selected_item["isbn"] as String
	var book_id: int = _book_id_map.get(isbn, -1)

	# Auto-add to bookstore catalog if not already present
	if book_id < 0:
		book_id = _auto_add_book(_selected_item)
		if book_id < 0:
			_show_error("Failed to add book to catalog automatically. Please add it manually.")
			return
		# Rebuild map so the new entry is included
		_build_book_id_map()

	var err := Manufacturer.place_order(book_id, isbn, qty, notes_input.text.strip_edges())
	if err != "":
		_show_error(err)
		return

	_reset_form()
	_refresh_all()
	_show_success("Order placed! The book will be restocked automatically in a few seconds.")


# Creates a bookstore catalog entry from manufacturer data and returns its new ID
func _auto_add_book(item: Dictionary) -> int:
	var data := {
		"title":           item["title"],
		"author":          item["author"],
		"isbn":            item["isbn"],
		"genre":           "",
		"publisher":       "",
		"year":            0,
		"description":     "",
		# Default sell price to 2× the unit cost as a reasonable starting point
		"price":           item["unit_cost"] * 2.0,
		"cost":            item["unit_cost"],
		# Start at zero stock — the restock order will fill it
		"stock":           0,
		"low_stock_alert": 5,
	}
	return BookStore.add_book(data)


func _reset_form() -> void:
	_selected_item           = {}
	selected_label.text      = "No book selected"
	isbn_value.text          = "—"
	cost_value.text          = "—"
	avail_value.text         = "—"
	qty_input.value          = 1
	notes_input.text         = ""
	total_value.text         = "$0.00"
	place_order_btn.disabled = true


# ── Order history ─────────────────────────────────────────────────────────────

func _refresh_history() -> void:
	for child in history_list.get_children():
		child.queue_free()

	var orders := Manufacturer.get_all_orders()
	if orders.is_empty():
		var lbl := Label.new()
		lbl.text = "No orders placed yet."
		history_list.add_child(lbl)
		return

	for order in orders:
		history_list.add_child(_make_order_row(order))


func _make_order_row(order: Dictionary) -> PanelContainer:
	var card   := PanelContainer.new()
	var layout := VBoxContainer.new()

	var top_row   := HBoxContainer.new()
	var title_lbl := Label.new()
	title_lbl.text = order["title"]
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var status_lbl := Label.new()
	status_lbl.text = "✓ Fulfilled" if order["status"] == "fulfilled" else "⏳ Pending"

	top_row.add_child(title_lbl)
	top_row.add_child(status_lbl)

	var detail_lbl := Label.new()
	detail_lbl.text = "Qty: %d  ·  Unit: $%.2f  ·  Total: $%.2f  ·  Ordered: %s" % [
		order["qty_ordered"],
		order["unit_cost"],
		order["total_cost"],
		order["created_at"],
	]
	if order["status"] == "fulfilled" and order["fulfilled_at"]:
		detail_lbl.text += "  ·  Fulfilled: %s" % order["fulfilled_at"]

	layout.add_child(top_row)
	layout.add_child(detail_lbl)

	if order.get("notes", "") != "":
		var notes_lbl  := Label.new()
		notes_lbl.text  = "Note: %s" % order["notes"]
		layout.add_child(notes_lbl)

	card.add_child(layout)
	return card


# ── Fulfilment callback ───────────────────────────────────────────────────────

func _on_order_fulfilled(_order_id: int) -> void:
	if not visible:
		return
	_refresh_history()
	_refresh_catalogue()


# ── Feedback display ──────────────────────────────────────────────────────────

func _show_error(msg: String) -> void:
	error_label.text    = "⚠ " + msg
	error_label.visible = true


func _show_success(msg: String) -> void:
	error_label.text    = "✓ " + msg
	error_label.visible = true
