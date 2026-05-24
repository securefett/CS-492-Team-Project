extends VBoxContainer

@onready var search_box:       LineEdit     = $Toolbar/SearchBox
@onready var genre_filter:     OptionButton = $Toolbar/GenreFilter
@onready var add_book_btn:     Button       = $Toolbar/AddBookBtn
@onready var content_split:    HBoxContainer                   = $ContentSplit
@onready var book_list:        VBoxContainer                   = $ContentSplit/ListScroll/BookList
@onready var detail_panel:     VBoxContainer                   = $ContentSplit/DetailScroll/DetailPanel
@onready var empty_label:      Label         = $EmptyLabel
@onready var no_results_label: Label         = $NoResultsLabel
@onready var detail_actions:   HBoxContainer = $ContentSplit/DetailScroll/DetailPanel/DetailActions
@onready var edit_btn:         Button        = $ContentSplit/DetailScroll/DetailPanel/DetailActions/EditBtn
@onready var delete_btn:       Button        = $ContentSplit/DetailScroll/DetailPanel/DetailActions/DeleteBtn
@onready var cart_btn:         Button        = $ContentSplit/DetailScroll/DetailPanel/DetailActions/AddToCartBtn

const GENRES := ["All Genres", "Fiction", "Non-Fiction", "Sci-Fi", "Biography", "Children"]

var _selected_id: int = -1


func _ready() -> void:
	for g in GENRES:
		genre_filter.add_item(g)
	search_box.text_changed.connect(_on_filter_changed)
	genre_filter.item_selected.connect(_on_filter_changed.unbind(1))
	add_book_btn.pressed.connect(_on_add_book)

	# Scene-node action buttons — signals connected once here.
	edit_btn.pressed.connect(_on_edit_book_pressed)
	delete_btn.pressed.connect(_on_delete_book_pressed)
	cart_btn.pressed.connect(_on_add_to_cart_pressed)

	Auth.session_changed.connect(_on_session_changed)
	_apply_role_visibility()
	_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		_apply_role_visibility()
		_refresh()


func _apply_role_visibility() -> void:
	var role  := Auth.get_role()
	var staff := role == "admin" or role == "employee"
	add_book_btn.visible = staff
	edit_btn.visible     = staff
	delete_btn.visible   = staff


func _on_session_changed(_account: Dictionary) -> void:
	_apply_role_visibility()


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
	detail_actions.visible = false
	for child in detail_panel.get_children():
		if child != detail_actions:
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
	
	#Theme creation for created labels
	var labelbox = StyleBoxTexture.new()
	labelbox.texture = load("res://src/Main/themes/textures/popup_menu_panel.png")
	labelbox.texture_margin_top = 10
	labelbox.texture_margin_bottom = 10
	labelbox.texture_margin_left = 10
	labelbox.texture_margin_right = 10
	
	for child in detail_panel.get_children():
		if child != detail_actions:
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
	title_lbl.add_theme_stylebox_override("normal", labelbox)
	detail_panel.add_child(title_lbl)

	# Author sub-heading
	var author_lbl := Label.new()
	author_lbl.text = "by %s" % book["author"]		
	author_lbl.add_theme_stylebox_override("normal", labelbox)
	detail_panel.add_child(author_lbl)

	detail_panel.add_child(HSeparator.new())

	for pair in fields:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var key_lbl := Label.new()
		
		key_lbl.text                  = pair[0] + ":"
		key_lbl.custom_minimum_size   = Vector2(90, 0)
		key_lbl.add_theme_stylebox_override("normal", labelbox)
		row.add_child(key_lbl)

		var val_lbl := Label.new()
		val_lbl.text                  = pair[1]
		val_lbl.autowrap_mode         = TextServer.AUTOWRAP_WORD_SMART
		val_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(val_lbl)

		detail_panel.add_child(row)

	detail_panel.add_child(HSeparator.new())

	# Move the persistent action bar to the bottom of the detail panel.
	detail_panel.move_child(detail_actions, -1)
	cart_btn.disabled = stock <= 0
	detail_actions.visible = true


# ── Actions ───────────────────────────────────────────────────────────────────

func _on_add_book() -> void:
	get_tree().current_scene.open_add_edit_book({})


func _on_edit_book_pressed() -> void:
	if _selected_id < 0:
		return
	var book := BookStore.get_book(_selected_id)
	if book.is_empty():
		return
	get_tree().current_scene.open_add_edit_book(book)


func _on_delete_book_pressed() -> void:
	if _selected_id < 0:
		return
	var book := BookStore.get_book(_selected_id)
	if book.is_empty():
		return
	var book_id    := _selected_id
	var book_title = book["title"]
	var dialog := AcceptDialog.new()
	dialog.title = "Delete Book"
	dialog.dialog_text = "Delete \"%s\"? This cannot be undone." % book_title
	dialog.get_ok_button().text = "Delete"
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func():
		BookStore.delete_book(book_id)
		_selected_id = -1
		_refresh()
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())


func _on_add_to_cart_pressed() -> void:
	if _selected_id < 0:
		return
	var book := BookStore.get_book(_selected_id)
	if book.is_empty():
		return
	get_tree().current_scene.add_book_to_cart(book)
