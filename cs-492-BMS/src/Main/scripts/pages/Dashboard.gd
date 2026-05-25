extends ScrollContainer

# ══════════════════════════════════════════════════════════════════════════════
#  Dashboard.gd
#  Role-aware dashboard entry point.
#
#    admin / employee  →  stat cards with locked dropdowns and inline bar
#                         graphs, top books, genre breakdown, low stock card
#    customer          →  CustomerDashboard scene instantiated into Content
#    guest             →  not permitted
# ══════════════════════════════════════════════════════════════════════════════

# ── Existing scene nodes ──────────────────────────────────────────────────────
@onready var tab_container:   TabContainer  = $Content/TabContainer
@onready var sales_value:     Label         = $Content/TabContainer/CardSales/CardSalesLayout/SalesValue
@onready var sales_delta:     Label         = $Content/TabContainer/CardSales/CardSalesLayout/SalesDelta
@onready var books_value:     Label         = $Content/TabContainer/CardBooks/CardBooksLayout/BooksValue
@onready var books_delta:     Label         = $Content/TabContainer/CardBooks/CardBooksLayout/BooksDelta
@onready var inventory_value: Label         = $Content/TabContainer/CardInventory/CardInventoryLayout/InventoryValue
@onready var inventory_delta: Label         = $Content/TabContainer/CardInventory/CardInventoryLayout/InventoryDelta
@onready var customers_value: Label         = $Content/TabContainer/CardCustomers/CardCustomersLayout/CustomersValue
@onready var customers_delta: Label         = $Content/TabContainer/CardCustomers/CardCustomersLayout/CustomersDelta
@onready var bottom_row:      HBoxContainer = $Content/BottomRow
@onready var top_books_list:  VBoxContainer = $Content/BottomRow/TopBooksCard/TopBooksLayout/TopBooksList
@onready var genre_list:      VBoxContainer = $Content/BottomRow/GenreCard/GenreLayout/GenreList

# ── Child scenes ──────────────────────────────────────────────────────────────
const CustomerDashboardScene := preload("res://src/Main/scenes/notpages/CustomerDashboard.tscn")
const LowStockCardScene      := preload("res://src/Main/scenes/notpages/LowStockCard.tscn")

# ── Staff state ───────────────────────────────────────────────────────────────
var _dropdowns:     Array[OptionButton]
var _graphs:        Array   # [Control, Control, null, Control]
var _series:        Array   # [Array,   Array,   null, Array  ]
var _current_range: String = "month"

var _label_style: StyleBoxTexture

const RANGE_KEYS   := ["today", "month", "6months", "year", "alltime"]
const RANGE_LABELS := ["Today", "This Month", "Last 6 Months", "This Year", "All Time"]
const CARD_METRICS := ["revenue", "books_sold", null, "new_customers"]


func _ready() -> void:
	_label_style = _make_label_style()

	match Auth.get_role():
		"admin":
			_build_staff_view(true)
		"employee":
			_build_staff_view(true)
		"customer":
			_build_customer_view()
		_:
			tab_container.visible = false
			bottom_row.visible    = false


# ══════════════════════════════════════════════════════════════════════════════
#  STAFF / ADMIN VIEW
# ══════════════════════════════════════════════════════════════════════════════

func _build_staff_view(show_low_stock: bool) -> void:
	tab_container.visible = true
	bottom_row.visible    = true

	var card_layouts: Array = [
		$Content/TabContainer/CardSales/CardSalesLayout,
		$Content/TabContainer/CardBooks/CardBooksLayout,
		$Content/TabContainer/CardInventory/CardInventoryLayout,
		$Content/TabContainer/CardCustomers/CardCustomersLayout,
	]

	for i in card_layouts.size():
		var layout: VBoxContainer = card_layouts[i]
		var metric: Variant       = CARD_METRICS[i]

		var dd := OptionButton.new()
		for j in RANGE_KEYS.size():
			dd.add_item(RANGE_LABELS[j], j)
		dd.selected = RANGE_KEYS.find(_current_range)
		dd.item_selected.connect(_on_dropdown_changed.bind(i))
		layout.add_child(dd)
		layout.move_child(dd, 0)
		_dropdowns.append(dd)

		if metric != null:
			var graph := Control.new()
			graph.custom_minimum_size    = Vector2(0, 100)
			graph.size_flags_horizontal  = Control.SIZE_EXPAND_FILL
			var slot := i
			graph.draw.connect(func(): _draw_graph(slot))
			layout.add_child(graph)
			_graphs.append(graph)
			_series.append([])
		else:
			_graphs.append(null)
			_series.append(null)

	_refresh_staff("month")
	_refresh_bottom_row()

	if show_low_stock:
		var card := LowStockCardScene.instantiate()
		bottom_row.add_child(card)


func _on_dropdown_changed(index: int, slot: int) -> void:
	var key = RANGE_KEYS[index]
	if key == _current_range:
		return
	_current_range = key

	for i in _dropdowns.size():
		if i != slot:
			_dropdowns[i].item_selected.disconnect(_on_dropdown_changed)
			_dropdowns[i].selected = index
			_dropdowns[i].item_selected.connect(_on_dropdown_changed.bind(i))

	_refresh_staff(key)


func _refresh_staff(range_key: String) -> void:
	var m: Dictionary = BookStore.get_dashboard_metrics_for(range_key)

	sales_value.text     = "$%s" % _fmt_currency(m.get("revenue", 0.0))
	sales_delta.text     = _delta_str(m.get("revenue", 0.0), m.get("prev_revenue", 0.0))
	books_value.text     = "%d"  % m.get("books_sold", 0)
	books_delta.text     = _delta_str(m.get("books_sold", 0), m.get("prev_books_sold", 0))
	inventory_value.text = "%d"  % m.get("inventory", 0)
	inventory_delta.text = "Across %d titles" % m.get("titles", 0)
	customers_value.text = "%d"  % m.get("customers", 0)
	customers_delta.text = _delta_str(
		m.get("new_customers", 0), m.get("prev_new_customers", 0), "new"
	)

	var has_graph := range_key != "today"
	for i in _graphs.size():
		if _graphs[i] == null:
			continue
		_series[i] = BookStore.get_time_series_for(range_key, CARD_METRICS[i]) if has_graph else []
		_graphs[i].queue_redraw()


func _draw_graph(slot: int) -> void:
	var data: Array    = _series[slot]
	var graph: Control = _graphs[slot]
	if data.is_empty():
		return

	var rect: Rect2 = graph.get_rect()
	var w: float    = rect.size.x
	var h: float    = rect.size.y
	var padding_l   := 48.0
	var padding_r   := 4.0
	var padding_top := 4.0
	var padding_bot := 18.0

	var max_val := 0.0
	for entry in data:
		if entry["value"] > max_val:
			max_val = entry["value"]
	if max_val == 0.0:
		max_val = 1.0

	var chart_h    := h - padding_top - padding_bot
	var chart_w    := w - padding_l - padding_r
	var count      := data.size()
	var gap_w      := chart_w / count
	var bar_w      := gap_w * 0.6
	var bar_color  := Color(0.37, 0.62, 0.95)
	var line_color := Color(1, 1, 1, 0.12)
	var text_color := Color(1, 1, 1, 0.65)
	var font       := ThemeDB.fallback_font

	for s in range(1, 4):
		var frac   : float = float(s) / 3.0
		var line_y : float = h - padding_bot - frac * chart_h
		graph.draw_line(
			Vector2(padding_l, line_y), Vector2(w - padding_r, line_y),
			line_color, 1.0
		)
		graph.draw_string(font, Vector2(0, line_y + 4),
			_short_value(max_val * frac, CARD_METRICS[slot]),
			HORIZONTAL_ALIGNMENT_LEFT, int(padding_l) - 2, 9, text_color)

	for i in count:
		var entry  : Dictionary = data[i]
		var val    : float      = entry.get("value", 0.0)
		var bar_h  : float      = (val / max_val) * chart_h
		var x      : float      = padding_l + i * gap_w + (gap_w - bar_w) * 0.5
		var y      : float      = h - padding_bot - bar_h
		graph.draw_rect(Rect2(x, y, bar_w, bar_h), bar_color)
		graph.draw_string(font,
			Vector2(x + bar_w * 0.5 - 6, h - padding_bot + 13),
			entry.get("label", ""),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, text_color)


func _refresh_bottom_row() -> void:
	var top_books: Array = BookStore.get_top_books(5)
	_clear_children(top_books_list)
	if top_books.is_empty():
		_add_placeholder(top_books_list, "No sales data yet.")
	else:
		for item in top_books:
			_add_two_column_row(
				top_books_list,
				item.get("title", "Unknown"),
				"%d sold" % item.get("total_sold", 0)
			)

	var genres: Array = BookStore.get_sales_by_genre_report()
	_clear_children(genre_list)
	if genres.is_empty():
		_add_placeholder(genre_list, "No sales data yet.")
	else:
		for item in genres:
			_add_two_column_row(
				genre_list,
				item.get("name", "Other"),
				"%d%%" % item.get("pct", 0)
			)


# ══════════════════════════════════════════════════════════════════════════════
#  CUSTOMER VIEW
# ══════════════════════════════════════════════════════════════════════════════

func _build_customer_view() -> void:
	tab_container.visible = false
	bottom_row.visible    = false

	var content: VBoxContainer = $Content
	var customer_dash := CustomerDashboardScene.instantiate()
	content.add_child(customer_dash)
	content.move_child(customer_dash, 0)


# ══════════════════════════════════════════════════════════════════════════════
#  HELPERS
# ══════════════════════════════════════════════════════════════════════════════

func _delta_str(current, previous, unit: String = "") -> String:
	if previous == 0 and current == 0:
		return "No data"
	if previous == 0:
		return "New this period" if unit == "" else "%d %s this period" % [current, unit]
	var pct   := int(round((float(current) - float(previous)) / float(previous) * 100.0))
	var arrow := "↑" if pct >= 0 else "↓"
	if unit == "":
		return "%s %d%% vs prior period" % [arrow, abs(pct)]
	var diff := int(current) - int(previous)
	return "%s%d %s vs prior period" % ["+" if diff >= 0 else "", diff, unit]


func _short_value(val: float, metric: Variant) -> String:
	if metric == "revenue":
		return "$%.1fk" % (val / 1000.0) if val >= 1000.0 else "$%d" % int(val)
	return "%.1fk" % (val / 1000.0) if val >= 1000.0 else "%d" % int(val)


func _add_two_column_row(parent: Control, left: String, right: String) -> void:
	var row       := HBoxContainer.new()
	var left_lbl  := Label.new()
	var right_lbl := Label.new()
	left_lbl.text  = left
	right_lbl.text = right
	left_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_lbl.add_theme_stylebox_override("normal", _label_style)
	row.add_child(left_lbl)
	row.add_child(right_lbl)
	parent.add_child(row)


func _add_placeholder(parent: Control, message: String) -> void:
	var lbl := Label.new()
	lbl.text = message
	parent.add_child(lbl)


func _clear_children(node: Control) -> void:
	for child in node.get_children():
		child.queue_free()


func _fmt_currency(amount: float) -> String:
	var cents   := int(round(amount * 100.0))
	var dollars := cents / 100
	var frac    := cents % 100
	var s       := str(dollars)
	var result  := ""
	var count   := 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = s[i] + result
		count += 1
	return "%s.%02d" % [result, frac]


func _make_label_style() -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load("res://src/Main/themes/textures/popup_menu_panel.png")
	sb.texture_margin_left   = 10.0
	sb.texture_margin_top    = 10.0
	sb.texture_margin_right  = 10.0
	sb.texture_margin_bottom = 10.0
	return sb
