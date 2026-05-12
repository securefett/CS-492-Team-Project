extends ScrollContainer

@onready var title_input:     LineEdit     = $Content/InfoSection/InfoGrid/TitleInput
@onready var author_input:    LineEdit     = $Content/InfoSection/InfoGrid/AuthorInput
@onready var isbn_input:      LineEdit     = $Content/InfoSection/InfoGrid/ISBNInput
@onready var genre_option:    OptionButton = $Content/InfoSection/InfoGrid/GenreOption
@onready var publisher_input: LineEdit     = $Content/InfoSection/InfoGrid/PublisherInput
@onready var year_input:      LineEdit     = $Content/InfoSection/InfoGrid/YearInput
@onready var desc_input:      TextEdit     = $Content/InfoSection/DescInput
@onready var price_input:     LineEdit     = $Content/PricingSection/PricingGrid/PriceInput
@onready var cost_input:      LineEdit     = $Content/PricingSection/PricingGrid/CostInput
@onready var stock_input:     LineEdit     = $Content/PricingSection/PricingGrid/StockInput
@onready var alert_input:     LineEdit     = $Content/PricingSection/PricingGrid/AlertInput
@onready var save_btn:        Button       = $Content/Actions/SaveBtn
@onready var cancel_btn:      Button       = $Content/Actions/CancelBtn
@onready var page_heading:    Label        = $Content/InfoSection/InfoTitle
@onready var error_label:     Label        = $Content/ErrorLabel

const GENRES := ["Fiction", "Non-fiction", "Science", "Biography", "Children"]

# When this is > 0 we are editing an existing book, otherwise adding new
var _edit_id: int = -1


func _ready() -> void:
	for g in GENRES:
		genre_option.add_item(g)

	save_btn.pressed.connect(_on_save)
	cancel_btn.pressed.connect(_on_cancel)

	# Hide the error label until needed
	error_label.visible = false


# ── Called by Catalog when navigating here ────────────────────────────────────

# Pass an empty dict {} to add a new book, or a full book dict to edit one
func load_book(data: Dictionary) -> void:
	# Wait until the scene is ready before touching nodes
	if not is_node_ready():
		await ready

	error_label.visible = false

	if data.is_empty():
		_edit_id = -1
		page_heading.text = "Add New Book"
		_clear_form()
	else:
		_edit_id = data.get("id", -1)
		page_heading.text = "Edit Book"
		_populate(data)


# ── Form helpers ──────────────────────────────────────────────────────────────

func _clear_form() -> void:
	title_input.text     = ""
	author_input.text    = ""
	isbn_input.text      = ""
	publisher_input.text = ""
	year_input.text      = ""
	desc_input.text      = ""
	price_input.text     = ""
	cost_input.text      = ""
	stock_input.text     = "0"
	alert_input.text     = "5"
	genre_option.selected = 0


func _populate(data: Dictionary) -> void:
	title_input.text     = data.get("title", "")
	author_input.text    = data.get("author", "")
	isbn_input.text      = data.get("isbn", "")
	publisher_input.text = data.get("publisher", "")
	year_input.text      = str(data.get("year", ""))
	desc_input.text      = data.get("description", "")
	price_input.text     = "%.2f" % data.get("price", 0.0)
	cost_input.text      = "%.2f" % data.get("cost", 0.0)
	stock_input.text     = str(data.get("stock", 0))
	alert_input.text     = str(data.get("low_stock_alert", 5))

	# Select the matching genre in the dropdown
	var genre: String = data.get("genre", "")
	var idx := GENRES.find(genre)
	genre_option.selected = idx if idx >= 0 else 0


# ── Validation ────────────────────────────────────────────────────────────────

func _validate() -> String:
	if title_input.text.strip_edges().is_empty():
		return "Title is required."
	if author_input.text.strip_edges().is_empty():
		return "Author is required."
	if price_input.text.strip_edges().is_empty() or not price_input.text.is_valid_float():
		return "Price must be a valid number."
	if not stock_input.text.is_valid_int():
		return "Stock must be a whole number."
	if not alert_input.text.is_valid_int():
		return "Low stock alert must be a whole number."
	return ""


# ── Save / Cancel ─────────────────────────────────────────────────────────────

func _on_save() -> void:
	var err := _validate()
	if err != "":
		error_label.text    = err
		error_label.visible = true
		return

	error_label.visible = false

	var data := {
		"title":           title_input.text.strip_edges(),
		"author":          author_input.text.strip_edges(),
		"isbn":            isbn_input.text.strip_edges(),
		"genre":           genre_option.get_item_text(genre_option.selected),
		"publisher":       publisher_input.text.strip_edges(),
		"year":            int(year_input.text) if year_input.text.is_valid_int() else 0,
		"description":     desc_input.text.strip_edges(),
		"price":           float(price_input.text),
		"cost":            float(cost_input.text) if cost_input.text.is_valid_float() else 0.0,
		"stock":           int(stock_input.text),
		"low_stock_alert": int(alert_input.text),
	}

	if _edit_id >= 0:
		BookStore.update_book(_edit_id, data)
	else:
		BookStore.add_book(data)

	_on_cancel()


func _on_cancel() -> void:
	get_owner().navigate_to("catalog")
