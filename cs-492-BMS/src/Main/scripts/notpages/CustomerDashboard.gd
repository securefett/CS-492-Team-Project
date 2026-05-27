extends VBoxContainer

# ══════════════════════════════════════════════════════════════════════════════
#  CustomerDashboard.gd
#  Handles the entire customer-facing dashboard: greeting, monthly spend bar
#  graph, and the stats / purchase history cards side by side.
# ══════════════════════════════════════════════════════════════════════════════

@onready var greeting_label: Label         = $GreetingLabel
@onready var bar_graph:      Control       = $GraphCard/GraphLayout/BarGraph
@onready var stats_label:    Label         = $SideBySide/StatsCard/StatsLayout/StatsLabel
@onready var history_list:   VBoxContainer = $SideBySide/HistoryCard/HistoryLayout/HistoryList

var _monthly_data: Array
var _label_style:  StyleBoxTexture


func _ready() -> void:
	_label_style = _make_label_style()
	var account_id: int = Auth.get_current_account().get("id", -1)
	greeting_label.text = "Welcome back, %s!" % Auth.get_account_name()
	_monthly_data = _get_customer_monthly_spend(account_id)
	bar_graph.draw.connect(_draw_graph)
	_populate(account_id)


func _populate(account_id: int) -> void:
	# ── Lifetime stats ────────────────────────────────────────────────────────
	var all_customers: Array = BookStore.get_all_customers()
	var my_row: Dictionary   = {}
	for row in all_customers:
		if row.get("id", -1) == account_id:
			my_row = row
			break

	var total_sales: int   = my_row.get("total_sales", 0)
	var total_spent: float = my_row.get("total_spent", 0.0)

	if total_sales == 0:
		stats_label.text = "No purchases yet.\nBrowse the catalog to get started!"
	else:
		stats_label.text = "%d purchase%s\n$%s spent in total" % [
			total_sales,
			"s" if total_sales != 1 else "",
			_fmt_currency(total_spent),
		]

	# ── Purchase history grouped by day ───────────────────────────────────────
	var sales: Array = BookStore.get_customer_sales(account_id)
	_clear_children(history_list)

	if sales.is_empty():
		_add_placeholder(history_list, "No purchases on record.")
		return

	var days: Dictionary = {}
	for sale in sales:
		var date: String = sale.get("created_at", "").left(10)
		var sale_id: int = sale.get("id", -1)
		var total: float = sale.get("total", 0.0)

		if not days.has(date):
			days[date] = { "total": 0.0, "books": [] }
		days[date]["total"] += total

		for si in BookStore.get_sale_items(sale_id):
			var title: String = si.get("book_title", "Unknown")
			var qty: int      = si.get("qty", 1)
			var found := false
			for entry in days[date]["books"]:
				if entry["title"] == title:
					entry["qty"] += qty
					found = true
					break
			if not found:
				days[date]["books"].append({ "title": title, "qty": qty })

	var day_keys: Array = days.keys()
	var shown := mini(day_keys.size(), 10)
	for i in shown:
		var date: String    = day_keys[i]
		var day: Dictionary = days[date]

		var day_header := Label.new()
		day_header.text = "%s  —  $%s" % [date, _fmt_currency(day["total"])]
		day_header.add_theme_stylebox_override("normal", _label_style)
		history_list.add_child(day_header)

		for entry in day["books"]:
			var book_line := Label.new()
			book_line.text = "    • %s  ×%d" % [entry["title"], entry["qty"]]
			history_list.add_child(book_line)


func _get_customer_monthly_spend(account_id: int) -> Array:
	var sales: Array        = BookStore.get_customer_sales(account_id)
	var buckets: Dictionary = {}
	for sale in sales:
		var month: String = sale.get("created_at", "").substr(5, 2)
		if month == "":
			continue
		if not buckets.has(month):
			buckets[month] = 0.0
		buckets[month] += sale.get("total", 0.0)

	var result: Array = []
	for month in buckets.keys():
		result.append({ "label": month, "value": buckets[month] })
	result.sort_custom(func(a, b): return a["label"] < b["label"])
	return result


func _draw_graph() -> void:
	if _monthly_data.is_empty():
		return

	var rect: Rect2 = bar_graph.get_rect()
	var w: float    = rect.size.x
	var h: float    = rect.size.y
	var padding_l   := 56.0
	var padding_r   := 8.0
	var padding_top := 8.0
	var padding_bot := 24.0
	var grid_steps  := 4
	var font_size   := 10

	var max_val := 0.0
	for entry in _monthly_data:
		if entry["value"] > max_val:
			max_val = entry["value"]
	if max_val == 0.0:
		max_val = 1.0

	var chart_h    := h - padding_top - padding_bot
	var chart_w    := w - padding_l - padding_r
	var count      := _monthly_data.size()
	var gap_w      := chart_w / count
	var bar_w      := gap_w * 0.6
	var bar_color  := Color(0.37, 0.62, 0.95)
	var line_color := Color(1, 1, 1, 0.15)
	var text_color := Color(1, 1, 1, 0.7)
	var font       := ThemeDB.fallback_font

	for s in range(1, grid_steps + 1):
		var frac   : float = float(s) / float(grid_steps)
		var line_y : float = h - padding_bot - frac * chart_h
		bar_graph.draw_line(
			Vector2(padding_l, line_y), Vector2(w - padding_r, line_y),
			line_color, 1.0
		)
		bar_graph.draw_string(font, Vector2(0, line_y + 4),
			"$%s" % _fmt_currency(max_val * frac),
			HORIZONTAL_ALIGNMENT_LEFT, int(padding_l) - 2, font_size, text_color)

	for i in count:
		var entry  : Dictionary = _monthly_data[i]
		var val    : float      = entry.get("value", 0.0)
		var bar_h  : float      = (val / max_val) * chart_h
		var x      : float      = padding_l + i * gap_w + (gap_w - bar_w) * 0.5
		var y      : float      = h - padding_bot - bar_h

		bar_graph.draw_rect(Rect2(x, y, bar_w, bar_h), bar_color)
		bar_graph.draw_string(font,
			Vector2(x + bar_w * 0.5 - 6, h - padding_bot + 16),
			entry.get("label", ""),
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)


# ── Helpers ───────────────────────────────────────────────────────────────────

func _clear_children(node: Control) -> void:
	for child in node.get_children():
		child.queue_free()


func _add_placeholder(parent: Control, message: String) -> void:
	var lbl := Label.new()
	lbl.text = message
	parent.add_child(lbl)


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
