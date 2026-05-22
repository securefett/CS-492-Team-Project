extends PanelContainer
class_name AccountCard

# ══════════════════════════════════════════════════════════════════════════════
#  AccountCard.gd  —  Single account card for the AccountsManager grid.
# ══════════════════════════════════════════════════════════════════════════════

signal edit_requested(acc: Dictionary)
signal delete_requested(account_id: int, account_display_name: String)

const ROLE_COLORS := {
	"admin":    Color(0.90, 0.40, 0.40),
	"employee": Color(0.40, 0.65, 0.90),
	"customer": Color(0.45, 0.80, 0.55),
}

@onready var role_label:  Label  = $VBox/RoleLabel
@onready var name_label:  Label  = $VBox/NameLabel
@onready var sub_label:   Label  = $VBox/SubLabel
@onready var since_label: Label  = $VBox/SinceLabel
@onready var edit_btn:    Button = $VBox/BtnRow/EditBtn
@onready var delete_btn:  Button = $VBox/BtnRow/DeleteBtn

var _acc: Dictionary = {}


func setup(acc: Dictionary, current_account_id: int) -> void:
	_acc = acc

	var role = acc.get("role", "customer")
	role_label.text = role.to_upper()
	role_label.add_theme_color_override("font_color", ROLE_COLORS.get(role, Color.WHITE))

	name_label.text = acc.get("display_name", "—")

	var sub = acc.get("email", "") if acc.get("email", null) != null else ""
	if sub == "" and acc.get("username", null) != null:
		sub = "@" + str(acc["username"])
	sub_label.text    = sub
	sub_label.visible = sub != ""

	since_label.text = "Since " + str(acc.get("created_at", "")).left(10)

	# Prevent an admin from deleting their own account.
	delete_btn.disabled = acc.get("id", -1) == current_account_id

	edit_btn.pressed.connect(func(): edit_requested.emit(_acc))
	delete_btn.pressed.connect(func(): delete_requested.emit(
		_acc.get("id", -1),
		_acc.get("display_name", "")
	))
