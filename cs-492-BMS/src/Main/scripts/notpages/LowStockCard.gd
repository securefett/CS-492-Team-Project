extends PanelContainer

# ══════════════════════════════════════════════════════════════════════════════
#  LowStockCard.gd
#  Self-contained low stock alerts card. Populates itself on _ready().

# ══════════════════════════════════════════════════════════════════════════════

@onready var list: VBoxContainer = $Layout/List

var _label_style: StyleBoxTexture


func _ready() -> void:
	_label_style = _make_label_style()
	var alerts: Array = BookStore.get_low_stock_alerts()

	if alerts.is_empty():
		var lbl := Label.new()
		lbl.text = "All titles are well stocked."
		list.add_child(lbl)
	else:
		for item in alerts:
			var row      := HBoxContainer.new()
			var left_lbl := Label.new()
			var right_lbl := Label.new()
			left_lbl.text  = item.get("title", "Unknown")
			right_lbl.text = "%d left" % item.get("stock", 0)
			left_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			left_lbl.add_theme_stylebox_override("normal", _label_style)
			row.add_child(left_lbl)
			row.add_child(right_lbl)
			list.add_child(row)


func _make_label_style() -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load("res://src/Main/themes/textures/popup_menu_panel.png")
	sb.texture_margin_left   = 10.0
	sb.texture_margin_top    = 10.0
	sb.texture_margin_right  = 10.0
	sb.texture_margin_bottom = 10.0
	return sb
