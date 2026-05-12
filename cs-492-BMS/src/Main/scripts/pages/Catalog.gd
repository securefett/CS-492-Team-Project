extends VBoxContainer

signal edit_book_requested(book_data: Dictionary)

@onready var search_box: LineEdit      = $Toolbar/SearchBox
@onready var genre_filter: OptionButton = $Toolbar/GenreFilter
@onready var add_book_btn: Button      = $Toolbar/AddBookBtn
@onready var book_table: GridContainer = $TableScroll/BookTable

const HEADERS := ["Title", "Author", "Genre", "Price", "Stock", "Status"]
const GENRES  := ["All Genres", "Fiction", "Non-fiction", "Science", "Biography", "Children"]

# Replace with your data autoload later
var all_books := [
	{ "title": "The Midnight Library", "author": "Matt Haig",         "genre": "Fiction",       "price": 14.99, "stock": 23 },
	{ "title": "Atomic Habits",        "author": "James Clear",       "genre": "Non-fiction",   "price": 16.99, "stock": 11 },
	{ "title": "Project Hail Mary",    "author": "Andy Weir",         "genre": "Science",       "price": 13.99, "stock": 4  },
	{ "title": "Dune",                 "author": "Frank Herbert",     "genre": "Fiction",       "price": 12.99, "stock": 0  },
	{ "title": "The Alchemist",        "author": "Paulo Coelho",      "genre": "Fiction",       "price": 11.99, "stock": 18 },
	{ "title": "Sapiens",              "author": "Yuval Noah Harari", "genre": "Non-fiction",   "price": 17.99, "stock": 7  },
]

func _ready() -> void:
	for g in GENRES:
		genre_filter.add_item(g)
	search_box.text_changed.connect(_on_filter_changed)
	genre_filter.item_selected.connect(_on_filter_changed.unbind(1))
	add_book_btn.pressed.connect(_on_add_book)
	_rebuild_table(all_books)

func _on_filter_changed(_v = null) -> void:
	var query  := search_box.text.to_lower()
	var genre  := genre_filter.get_item_text(genre_filter.selected)
	var filtered := all_books.filter(func(b):
		var match_search = query.is_empty() or b["title"].to_lower().contains(query) or b["author"].to_lower().contains(query)
		var match_genre  = genre == "All Genres" or b["genre"] == genre
		return match_search and match_genre
	)
	_rebuild_table(filtered)

func _rebuild_table(books: Array) -> void:
	for child in book_table.get_children():
		child.queue_free()
	# Headers
	for h in HEADERS:
		var lbl := Label.new()
		lbl.text = h
		book_table.add_child(lbl)
	# Rows
	for book in books:
		var stock: int = book["stock"]
		var status := "In Stock" if stock > 5 else ("Low Stock" if stock > 0 else "Out of Stock")
		var row_data := [book["title"], book["author"], book["genre"], "$%.2f" % book["price"], str(stock), status]
		for cell_text in row_data:
			var lbl := Label.new()
			lbl.text = cell_text
			book_table.add_child(lbl)

func _on_add_book() -> void:
	# Tell Main to navigate to Add/Edit page
	get_parent().get_parent().get_parent().get_parent().get_parent().navigate_to("NavAddBook")
