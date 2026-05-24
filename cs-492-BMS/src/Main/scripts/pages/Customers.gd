extends VBoxContainer

@onready var search_box: LineEdit      = $Toolbar/SearchBox
@onready var add_btn:    Button        = $Toolbar/AddCustomerBtn
@onready var card_grid:  GridContainer = $Scroll/CardGrid

var _all_customers: Array = []

# ── Lifecycle ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	search_box.text_changed.connect(_on_search)
	add_btn.pressed.connect(_on_add)

	# Refresh whenever the DB changes (add / update / delete).
	BookStore.customers_changed.connect(_load_customers)

	# Refresh whenever this page becomes visible (e.g. tab switch).
	visibility_changed.connect(_on_visibility_changed)

	_load_customers()

# ── Data ───────────────────────────────────────────────────────────────────────

func _load_customers() -> void:
	_all_customers = BookStore.get_all_customers()
	# Re-apply any active search filter instead of blindly showing everything.
	var q := search_box.text.strip_edges()
	if q.is_empty():
		_build_cards(_all_customers)
	else:
		_build_cards(BookStore.search_customers(q))

func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		_load_customers()

# ── Search ─────────────────────────────────────────────────────────────────────

func _on_search(query: String) -> void:
	if query.strip_edges().is_empty():
		_build_cards(_all_customers)
	else:
		_build_cards(BookStore.search_customers(query))

# ── Card grid ─────────────────────────────────────────────────────────────────

func _build_cards(customers: Array) -> void:
	for child in card_grid.get_children():
		child.queue_free()
	for c in customers:
		card_grid.add_child(_make_card(c))

func _make_card(c: Dictionary) -> PanelContainer:
	var card   := PanelContainer.new()
	var layout := VBoxContainer.new()

	var parts    := (c.get("name", "?") as String).split(" ")
	var initials := "?"
	if parts.size() >= 2:
		initials = (parts[0][0] + parts[1][0]).to_upper()
	elif parts.size() == 1 and parts[0].length() > 0:
		initials = parts[0][0].to_upper()

	var avatar     := Label.new()
	avatar.text     = initials
	avatar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var name_lbl    := Label.new()
	name_lbl.text    = c.get("name", "Unknown")

	var email_lbl   := Label.new()
	email_lbl.text   = c.get("email", "—")

	var phone_lbl   := Label.new()
	phone_lbl.text   = c.get("phone", "")
	phone_lbl.visible = phone_lbl.text != ""

	var since_year := "—"
	var created_at: String = c.get("created_at", "")
	if created_at.length() >= 4:
		since_year = created_at.substr(0, 4)

	var stats := HBoxContainer.new()
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	for pair in [
		["Purchases", str(c.get("total_sales", 0))],
		["Spent",     "$%.2f" % c.get("total_spent", 0.0)],
		["Since",     since_year],
	]:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var key := Label.new()
		key.text = pair[0]
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var val := Label.new()
		val.text = pair[1]
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(key)
		col.add_child(val)
		stats.add_child(col)

	layout.add_child(avatar)
	layout.add_child(name_lbl)
	layout.add_child(email_lbl)
	layout.add_child(phone_lbl)
	layout.add_child(stats)
	card.add_child(layout)
	card.custom_minimum_size = Vector2(200, 0)
	return card

# ── Actions ────────────────────────────────────────────────────────────────────

func _on_add() -> void:
	# TODO: open an Add Customer dialog or sub-page.
	# No manual _load_customers() call needed here — BookStore will emit
	# customers_changed after add_customer(), which triggers it automatically.
	print("Add customer pressed")
