extends VBoxContainer

@onready var search_box:   LineEdit       = $Toolbar/SearchBox
@onready var genre_filter: OptionButton   = $Toolbar/GenreFilter
@onready var add_book_btn: Button         = $Toolbar/AddBookBtn
@onready var book_table:   GridContainer  = $TableScroll/BookTable

const HEADERS := ["Title", "Author", "Genre", "Price", "Stock", "Status", ""]
const GENRES  := ["All Genres", "Fiction", "Non-fiction", "Science", "Biography", "Children"]

func _ready() -> void:
	for g in GENRES:
		genre_filter.add_item(g)
	search_box.text_changed.connect(_on_filter_changed)
	genre_filter.item_selected.connect(_on_filter_changed.unbind(1))
	add_book_btn.pressed.connect(_on_add_book)
	_refresh()


# Called when the page becomes visible so the table is always up to date
func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		_refresh()


# ── Data ──────────────────────────────────────────────────────────────────────

func _refresh() -> void:
	var query := search_box.text if is_node_ready() else ""
	var genre := genre_filter.get_item_text(genre_filter.selected) if is_node_ready() else ""
	var books := BookStore.search_books(query, genre)
	_rebuild_table(books)


func _on_filter_changed(_v = null) -> void:
	_refresh()


# ── Table ─────────────────────────────────────────────────────────────────────

func _rebuild_table(books: Array) -> void:
	for child in book_table.get_children():
		child.queue_free()

	# Header row
	for h in HEADERS:
		var lbl := Label.new()
		lbl.text = h
		book_table.add_child(lbl)

	# Data rows
	for book in books:
		var stock: int = book["stock"]
		var status := "In Stock" if stock > book["low_stock_alert"] \
					  else ("Low Stock" if stock > 0 else "Out of Stock")

		var cells := [
			book["title"],
			book["author"],
			book["genre"],
			"$%.2f" % book["price"],
			str(stock),
			status,
		]
		for cell_text in cells:
			var lbl := Label.new()
			lbl.text = cell_text
			book_table.add_child(lbl)

		# Action buttons cell
		var actions := HBoxContainer.new()

		var edit_btn := Button.new()
		edit_btn.text = "Edit"
		edit_btn.pressed.connect(_on_edit_book.bind(book["id"]))

		var del_btn := Button.new()
		del_btn.text = "Delete"
		del_btn.pressed.connect(_on_delete_book.bind(book["id"], book["title"]))

		actions.add_child(edit_btn)
		actions.add_child(del_btn)
		book_table.add_child(actions)


# ── Actions ───────────────────────────────────────────────────────────────────

func _on_add_book() -> void:
	var main := _get_main()
	var add_edit_page := main.get_node("RootLayout/MainArea/PageContainer/Pages/AddEditBook")
	add_edit_page.load_book({})
	main.navigate_to("addbook")


func _on_edit_book(book_id: int) -> void:
	var book := BookStore.get_book(book_id)
	if book.is_empty():
		return
	var main := _get_main()
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
		_refresh()
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())


func _get_main() -> Node:
	return get_owner()
