extends VBoxContainer

@onready var search_box:    LineEdit      = $Toolbar/SearchBox
@onready var customer_list: VBoxContainer = $Body/LeftPanel/Scroll/CustomerList

# Detail panel nodes
@onready var placeholder:    Label         = $Body/DetailPanel/DetailContent/Placeholder
@onready var customer_info:  VBoxContainer = $Body/DetailPanel/DetailContent/CustomerInfo
@onready var name_label:     Label         = $Body/DetailPanel/DetailContent/CustomerInfo/Header/NameLabel
@onready var email_val:      Label         = $Body/DetailPanel/DetailContent/CustomerInfo/Tabs/Account_Info/EmailRow/EmailVal
@onready var phone_val:      Label         = $Body/DetailPanel/DetailContent/CustomerInfo/Tabs/Account_Info/PhoneRow/PhoneVal
@onready var since_val:      Label         = $Body/DetailPanel/DetailContent/CustomerInfo/Tabs/Account_Info/SinceRow/SinceVal
@onready var notes_val:      Label         = $Body/DetailPanel/DetailContent/CustomerInfo/Tabs/Account_Info/NotesRow/NotesVal
@onready var purchases_val:  Label         = $Body/DetailPanel/DetailContent/CustomerInfo/Tabs/Account_Info/StatsRow/PurchasesCol/PurchasesVal
@onready var spent_val:      Label         = $Body/DetailPanel/DetailContent/CustomerInfo/Tabs/Account_Info/StatsRow/SpentCol/SpentVal
@onready var order_list:     VBoxContainer = $Body/DetailPanel/DetailContent/CustomerInfo/Tabs/Order_History/OrderScroll/OrderList
@onready var no_orders_label: Label        = $Body/DetailPanel/DetailContent/CustomerInfo/Tabs/Order_History/NoOrdersLabel

var _all_customers: Array = []
var _button_group:  ButtonGroup = ButtonGroup.new()

# ── Lifecycle ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	search_box.text_changed.connect(_on_search)
	BookStore.accounts_changed.connect(_load_customers)
	visibility_changed.connect(_on_visibility_changed)
	_load_customers()

# ── Data ───────────────────────────────────────────────────────────────────────

func _load_customers() -> void:
	_all_customers = BookStore.get_all_customers()
	var q := search_box.text.strip_edges()
	_build_list(BookStore.search_customers(q) if not q.is_empty() else _all_customers)

func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		_load_customers()

# ── Search ─────────────────────────────────────────────────────────────────────

func _on_search(query: String) -> void:
	_build_list(BookStore.search_customers(query) if not query.strip_edges().is_empty() else _all_customers)

# ── Helpers ────────────────────────────────────────────────────────────────────

# Dictionary.get() only falls back to the default when the key is missing,
# not when the value is null. This helper covers both cases.
func _str(value) -> String:
	return "" if value == null else str(value)

func _flt(value, default: float = 0.0) -> float:
	return default if value == null else float(value)

func _int(value, default: int = 0) -> int:
	return default if value == null else int(value)

# ── Customer list ──────────────────────────────────────────────────────────────

func _build_list(customers: Array) -> void:
	for child in customer_list.get_children():
		child.queue_free()

	for c in customers:
		var btn := Button.new()
		btn.text                  = _str(c.get("name")) if c.get("name") != null else "Unknown"
		btn.toggle_mode           = true
		btn.button_group          = _button_group
		btn.alignment             = HORIZONTAL_ALIGNMENT_LEFT
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.set_meta("customer", c)
		btn.pressed.connect(_on_customer_pressed.bind(btn))
		customer_list.add_child(btn)

func _on_customer_pressed(btn: Button) -> void:
	_show_customer(btn.get_meta("customer"))

# ── Detail panel ───────────────────────────────────────────────────────────────

func _show_customer(c: Dictionary) -> void:
	placeholder.visible   = false
	customer_info.visible = true

	name_label.text    = _str(c.get("name"))
	email_val.text     = _str(c.get("email"))
	phone_val.text     = _str(c.get("phone"))
	notes_val.text     = _str(c.get("notes"))
	purchases_val.text = str(_int(c.get("total_sales")))
	spent_val.text     = "$%.2f" % _flt(c.get("total_spent"))

	var created_at := _str(c.get("created_at"))
	since_val.text = created_at.substr(0, 10) if created_at.length() >= 10 else created_at

	_load_orders(_int(c.get("id"), -1))

func _load_orders(account_id: int) -> void:
	for child in order_list.get_children():
		child.queue_free()

	if account_id < 0:
		no_orders_label.visible = true
		return

	var orders := BookStore.get_customer_sales(account_id)

	if orders.is_empty():
		no_orders_label.visible = true
		return

	no_orders_label.visible = false

	for sale in orders:
		var row := HBoxContainer.new()

		var date_lbl  := Label.new()
		var total_lbl := Label.new()
		var pay_lbl   := Label.new()
		var items_lbl := Label.new()

		var date_str := _str(sale.get("created_at"))
		date_lbl.text  = date_str.substr(0, 10) if date_str.length() >= 10 else date_str
		total_lbl.text = "$%.2f" % _flt(sale.get("total"))
		pay_lbl.text   = _str(sale.get("payment_method"))
		items_lbl.text = "%d item(s)" % _int(sale.get("item_count"))

		date_lbl.size_flags_horizontal  = Control.SIZE_EXPAND_FILL
		total_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pay_lbl.size_flags_horizontal   = Control.SIZE_EXPAND_FILL
		items_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		row.add_child(date_lbl)
		row.add_child(total_lbl)
		row.add_child(pay_lbl)
		row.add_child(items_lbl)
		order_list.add_child(row)
