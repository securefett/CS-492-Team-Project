extends ScrollContainer

@onready var top_books_list: VBoxContainer = $Content/BottomRow/TopBooksCard/TopBooksLayout/TopBooksList
@onready var genre_list: VBoxContainer     = $Content/BottomRow/GenreCard/GenreLayout/GenreList

#Temporary settings, will load from database, or delete this entire page we will see
var top_books := [
	{ "title": "The Midnight Library", "sold": 48 },
	{ "title": "Atomic Habits",        "sold": 41 },
	{ "title": "Project Hail Mary",    "sold": 37 },
	{ "title": "Dune",                 "sold": 29 },
	{ "title": "The Alchemist",        "sold": 24 },
]

var genres := [
	{ "name": "Fiction",     "pct": 78 },
	{ "name": "Non-fiction", "pct": 52 },
	{ "name": "Science",     "pct": 34 },
	{ "name": "Children",    "pct": 21 },
	{ "name": "Biography",   "pct": 15 },
]

func _ready() -> void:
	_build_top_books()
	_build_genres()

func _build_top_books() -> void:
	for item in top_books:
		var row := HBoxContainer.new()
		var title_lbl := Label.new()
		title_lbl.text = item["title"]
		title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sold_lbl := Label.new()
		sold_lbl.text = "%d sold" % item["sold"]
		row.add_child(title_lbl)
		row.add_child(sold_lbl)
		top_books_list.add_child(row)


func _build_genres() -> void:
	for item in genres:
		var row := HBoxContainer.new()
		var name_lbl := Label.new()
		name_lbl.text = item["name"]
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var pct_lbl := Label.new()
		pct_lbl.text = "%d%%" % item["pct"]
		row.add_child(name_lbl)
		#row.add_child(bar)
		row.add_child(pct_lbl)
		genre_list.add_child(row)
