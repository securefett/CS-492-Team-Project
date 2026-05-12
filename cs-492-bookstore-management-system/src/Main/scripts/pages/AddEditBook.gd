extends ScrollContainer

@onready var title_input:     LineEdit    = $Content/InfoSection/InfoGrid/TitleInput
@onready var author_input:    LineEdit    = $Content/InfoSection/InfoGrid/AuthorInput
@onready var isbn_input:      LineEdit    = $Content/InfoSection/InfoGrid/ISBNInput
@onready var genre_option:    OptionButton = $Content/InfoSection/InfoGrid/GenreOption
@onready var publisher_input: LineEdit    = $Content/InfoSection/InfoGrid/PublisherInput
@onready var year_input:      LineEdit    = $Content/InfoSection/InfoGrid/YearInput
@onready var desc_input:      TextEdit    = $Content/InfoSection/DescInput
@onready var price_input:     LineEdit    = $Content/PricingSection/PricingGrid/PriceInput
@onready var cost_input:      LineEdit    = $Content/PricingSection/PricingGrid/CostInput
@onready var stock_input:     LineEdit    = $Content/PricingSection/PricingGrid/StockInput
@onready var alert_input:     LineEdit    = $Content/PricingSection/PricingGrid/AlertInput
@onready var save_btn:        Button      = $Content/Actions/SaveBtn
@onready var cancel_btn:      Button      = $Content/Actions/CancelBtn

const GENRES := ["Fiction", "Non-fiction", "Science", "Biography", "Children"]

# Set this before showing the page to pre-fill an existing book for editing
var edit_data: Dictionary = {}

func _ready() -> void:
	for g in GENRES:
		genre_option.add_item(g)
	save_btn.pressed.connect(_on_save)
	cancel_btn.pressed.connect(_on_cancel)
	if not edit_data.is_empty():
		_populate(edit_data)

func load_book(data: Dictionary) -> void:
	edit_data = data
	_populate(data)

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

func _on_save() -> void:
	var book := {
		"title":           title_input.text,
		"author":          author_input.text,
		"isbn":            isbn_input.text,
		"genre":           genre_option.get_item_text(genre_option.selected),
		"publisher":       publisher_input.text,
		"year":            int(year_input.text) if year_input.text.is_valid_int() else 0,
		"description":     desc_input.text,
		"price":           float(price_input.text),
		"cost":            float(cost_input.text),
		"stock":           int(stock_input.text) if stock_input.text.is_valid_int() else 0,
		"low_stock_alert": int(alert_input.text)  if alert_input.text.is_valid_int()  else 5,
	}
	# TODO: pass `book` to your data autoload to save/update
	print("Saved: ", book)
	_on_cancel()

func _on_cancel() -> void:
	get_parent().get_parent().get_parent().get_parent().navigate_to("catalog")
