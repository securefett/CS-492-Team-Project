extends VBoxContainer

@onready var search_box:       LineEdit     = $Toolbar/SearchBox
@onready var genre_filter:     OptionButton = $Toolbar/GenreFilter
@onready var add_book_btn:     Button       = $Toolbar/AddBookBtn
@onready var content_split:    HBoxContainer                   = $ContentSplit
@onready var book_list:        VBoxContainer                   = $ContentSplit/ListScroll/BookList
@onready var detail_panel:     VBoxContainer                   = $ContentSplit/DetailScroll/DetailPanel
@onready var empty_label:      Label        = $EmptyLabel
@onready var no_results_label: Label        = $NoResultsLabel

const GENRES := ["All Genres", "Fiction", "Non-Fiction", "Sci-Fi", "Biography", "Children"]

var _selected_id: int = -1


func _ready() -> void:
	for g in GENRES:
		genre_filter.add_item(g)
	search_box.text_changed.connect(_on_filter_changed)
	genre_filter.item_selected.connect(_on_filter_changed.unbind(1))
	add_book_btn.pressed.connect(_on_add_book)
	_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		_refresh()


# ── Data ──────────────────────────────────────────────────────────────────────

func _refresh() -> void:
	var query := search_box.text if is_node_ready() else ""
	var genre := genre_filter.get_item_text(genre_filter.selected) if is_node_ready() else ""
	var books := BookStore.search_books(query, genre)
	_rebuild_list(books)


func _on_filter_changed(_v = null) -> void:
	_refresh()


# ── List (left panel) ─────────────────────────────────────────────────────────

func _rebuild_list(books: Array) -> void:
	for child in book_list.get_children():
		child.queue_free()

	var is_filtering := search_box.text.strip_edges() != "" \
		or (genre_filter.get_item_text(genre_filter.selected) != "All Genres")

	if books.is_empty():
		if is_filtering:
			empty_label.hide()
			no_results_label.show()
		else:
			no_results_label.hide()
			empty_label.show()
		content_split.hide()
		_clear_detail()
		return

	empty_label.hide()
	no_results_label.hide()
	content_split.show()

	# If the previously selected book is no longer in the result set, deselect.
	var ids := books.map(func(b): return b["id"])
	if not ids.has(_selected_id):
		_selected_id = -1
		_clear_detail()

	for book in books:
		var btn := Button.new()
		btn.text          = "%s\n%s" % [book["title"], book["author"]]
		btn.alignment     = HORIZONTAL_ALIGNMENT_LEFT
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.toggle_mode   = true
		btn.button_pressed = (book["id"] == _selected_id)
		btn.pressed.connect(_on_book_selected.bind(book))
		book_list.add_child(btn)


# ── Detail (right panel) ──────────────────────────────────────────────────────

func _clear_detail() -> void:
	for child in detail_panel.get_children():
		child.queue_free()

	var placeholder := Label.new()
	placeholder.text               = "Select a book to see details"
	placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placeholder.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	placeholder.size_flags_vertical  = Control.SIZE_EXPAND_FILL
	detail_panel.add_child(placeholder)


func _on_book_selected(book: Dictionary) -> void:
	_selected_id = book["id"]

	# Sync toggle states so only the pressed button stays highlighted.
	for btn in book_list.get_children():
		if btn is Button:
			btn.set_pressed_no_signal(false)
	# Re-press the one that was just clicked.
	for btn in book_list.get_children():
		if btn is Button and btn.text.begins_with(book["title"]):
			btn.set_pressed_no_signal(true)
			break

	_populate_detail(book)


func _populate_detail(book: Dictionary) -> void:
	for child in detail_panel.get_children():
		child.queue_free()

	var stock: int = book["stock"]
	var status := "In Stock" if stock > book["low_stock_alert"] \
				  else ("Low Stock" if stock > 0 else "Out of Stock")

	var fields := [
		["Genre",      book.get("genre", "—")],
		["ISBN",       book.get("isbn", "—")],
		["Publisher",  book.get("publisher", "—")],
		["Year",       str(book.get("year", "—"))],
		["Price",      "$%.2f" % book["price"]],
		["Cost",       "$%.2f" % book["cost"]],
		["Stock",      "%d  (%s)" % [stock, status]],
		["Description", book.get("description", "—")],
	]

	# Title heading
	var title_lbl := Label.new()
	title_lbl.text               = book["title"]
	title_lbl.autowrap_mode      = TextServer.AUTOWRAP_WORD_SMART
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.add_child(title_lbl)

	# Author sub-heading
	var author_lbl := Label.new()
	author_lbl.text = "by %s" % book["author"]
	detail_panel.add_child(author_lbl)

	detail_panel.add_child(HSeparator.new())

	for pair in fields:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var key_lbl := Label.new()
		key_lbl.text                  = pair[0] + ":"
		key_lbl.custom_minimum_size   = Vector2(90, 0)
		row.add_child(key_lbl)

		var val_lbl := Label.new()
		val_lbl.text                  = pair[1]
		val_lbl.autowrap_mode         = TextServer.AUTOWRAP_WORD_SMART
		val_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(val_lbl)

		detail_panel.add_child(row)

	detail_panel.add_child(HSeparator.new())

	# Action buttons
	var actions := HBoxContainer.new()

	var edit_btn := Button.new()
	edit_btn.text = "Edit"
	edit_btn.pressed.connect(_on_edit_book.bind(book["id"]))

	var del_btn := Button.new()
	del_btn.text = "Delete"
	del_btn.pressed.connect(_on_delete_book.bind(book["id"], book["title"]))

	var cart_btn := Button.new()
	cart_btn.text     = "Add to Cart"
	cart_btn.disabled = stock <= 0
	cart_btn.pressed.connect(_on_add_to_cart.bind(book["id"]))

	actions.add_child(edit_btn)
	actions.add_child(del_btn)
	actions.add_child(cart_btn)
	detail_panel.add_child(actions)


# ── Actions ───────────────────────────────────────────────────────────────────

func _on_add_book() -> void:
	var main := get_owner()
	var add_edit_page := main.get_node("RootLayout/MainArea/PageContainer/Pages/AddEditBook")
	add_edit_page.load_book({})
	main.navigate_to("addbook")


func _on_edit_book(book_id: int) -> void:
	var book := BookStore.get_book(book_id)
	if book.is_empty():
		return
	var main := get_owner()
	var add_edit_page := main.get_node("RootLayout/MainArea/PageContainer/Pages/AddEditBook")
	add_edit_page.load_book(book)
	main.navigate_to("addbook")


func _on_delete_book(book_id: int, book_title: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Delete Book"
	dialog.dialog_text = "Delete \"%s\"? This cannot be undone." % book_title
	dialog.get_ok_button().text = "Delete"
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func():
		BookStore.delete_book(book_id)
		if _selected_id == book_id:
			_selected_id = -1
		_refresh()
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())


func _on_add_to_cart(book_id: int) -> void:
	var book := BookStore.get_book(book_id)
	if book.is_empty():
		return
	var main  := get_owner()
	var sales := main.get_node("RootLayout/MainArea/PageContainer/Pages/Sales")
	sales.add_book_to_cart(book)
	#main.navigate_to("sales")
