extends ScrollContainer

@onready var revenue_chart: HBoxContainer = $Content/TopRow/RevenueCard/RevenueLayout/RevenueChart
@onready var genre_legend:  VBoxContainer = $Content/TopRow/GenreCard/GenreLayout/GenreLegend
@onready var metrics_list:  VBoxContainer = $Content/BottomRow/MetricsCard/MetricsLayout/MetricsList
@onready var stock_list:    VBoxContainer = $Content/BottomRow/StockCard/StockLayout/StockList

var monthly_revenue := [3200, 4100, 3800, 5200, 5900, 4700, 6800, 6200, 7400, 6100, 7800, 8241]
var genres := [
	{ "name": "Fiction",     "pct": 42 },
	{ "name": "Non-fiction", "pct": 23 },
	{ "name": "Science",     "pct": 17 },
	{ "name": "Other",       "pct": 18 },
]
var key_metrics := []
var low_stock := []

func _ready() -> void:
	_load_key_metrics()
	_load_low_stock()
	_build_revenue_chart()
	_build_genre_legend()
	_build_metrics()
	_build_stock_alerts()

func _load_low_stock() -> void:
	low_stock = BookStore.get_low_stock_alerts()

func _load_key_metrics() -> void:
	var metrics := BookStore.get_report_metrics()

	key_metrics = [
		{
			"label": "Total revenue",
			"value": "$%.2f" % metrics.get("total_revenue", 0.0)
		},
		{
			"label": "Total sales",
			"value": str(metrics.get("total_sales", 0))
		},
		{
			"label": "Books sold",
			"value": str(metrics.get("books_sold", 0))
		},
		{
			"label": "Avg. order value",
			"value": "$%.2f" % metrics.get("average_order_value", 0.0)
		},
	]

func _build_revenue_chart() -> void:
	var max_val: float = monthly_revenue.max()
	for val in monthly_revenue:
		var bar := ColorRect.new()
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical   = Control.SIZE_SHRINK_END
		bar.custom_minimum_size   = Vector2(0, (val / max_val) * 80)
		bar.color = Color("#378ADD")
		revenue_chart.add_child(bar)

func _build_genre_legend() -> void:
	for g in genres:
		var row := HBoxContainer.new()
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(10, 10)
		dot.color = Color("#378ADD")
		var lbl := Label.new()
		lbl.text = "%s %d%%" % [g["name"], g["pct"]]
		row.add_child(dot)
		row.add_child(lbl)
		genre_legend.add_child(row)

func _build_metrics() -> void:
	for m in key_metrics:
		var row := HBoxContainer.new()
		var key := Label.new(); key.text = m["label"]
		key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var val := Label.new(); val.text = m["value"]
		row.add_child(key)
		row.add_child(val)
		metrics_list.add_child(row)

func _build_stock_alerts() -> void:
	for item in low_stock:
		var row := HBoxContainer.new()
		var title := Label.new(); title.text = item["title"]
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var status := Label.new()
		status.text = "Out of stock" if item["stock"] == 0 else "%d left" % item["stock"]
		row.add_child(title)
		row.add_child(status)
		stock_list.add_child(row)
