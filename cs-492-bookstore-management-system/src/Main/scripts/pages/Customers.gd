extends VBoxContainer

@onready var search_box:   LineEdit      = $Toolbar/SearchBox
@onready var add_btn:      Button        = $Toolbar/AddCustomerBtn
@onready var card_grid:    GridContainer = $Scroll/CardGrid

var all_customers := [
	{ "name": "Sarah Reynolds", "email": "sarah.r@email.com",  "books": 24, "spent": 341.0, "since": 2022 },
	{ "name": "James Miller",   "email": "j.miller@email.com", "books": 17, "spent": 228.0, "since": 2023 },
	{ "name": "Amelia Lopez",   "email": "amelia.l@email.com", "books": 31, "spent": 489.0, "since": 2021 },
	{ "name": "David Kim",      "email": "d.kim@email.com",    "books": 9,  "spent": 127.0, "since": 2024 },
	{ "name": "Nina Torres",    "email": "n.torres@email.com", "books": 42, "spent": 601.0, "since": 2020 },
	{ "name": "Ryan Park",      "email": "ryan.p@email.com",   "books": 6,  "spent": 84.0,  "since": 2024 },
]

func _ready() -> void:
	search_box.text_changed.connect(_on_search)
	add_btn.pressed.connect(_on_add)
	_build_cards(all_customers)

func _on_search(query: String) -> void:
	var q := query.to_lower()
	var filtered := all_customers.filter(func(c):
		return q.is_empty() or c["name"].to_lower().contains(q) or c["email"].to_lower().contains(q)
	)
	_build_cards(filtered)

func _build_cards(customers: Array) -> void:
	for child in card_grid.get_children():
		child.queue_free()
	for c in customers:
		card_grid.add_child(_make_card(c))

func _make_card(c: Dictionary) -> PanelContainer:
	var card   := PanelContainer.new()
	var layout := VBoxContainer.new()

	var initials = (c["name"].split(" ")[0][0] + c["name"].split(" ")[1][0]).to_upper()
	var avatar   := Label.new()
	avatar.text  = initials

	var name_lbl  := Label.new()
	name_lbl.text = c["name"]
	var email_lbl := Label.new()
	email_lbl.text = c["email"]

	var stats := HBoxContainer.new()
	for pair in [["Books", str(c["books"])], ["Spent", "$%.0f" % c["spent"]], ["Since", str(c["since"])]]:
		var col := VBoxContainer.new()
		var key := Label.new(); key.text = pair[0]
		var val := Label.new(); val.text = pair[1]
		col.add_child(key)
		col.add_child(val)
		stats.add_child(col)

	layout.add_child(avatar)
	layout.add_child(name_lbl)
	layout.add_child(email_lbl)
	layout.add_child(stats)
	card.add_child(layout)
	card.custom_minimum_size = Vector2(180, 0)
	return card

func _on_add() -> void:
	# TODO: open an Add Customer dialog or sub-page
	print("Add customer pressed")
