extends Panel

signal buy_requested(upgrade_id)

var upgrade_rows = {}
var current_cash = 0

@onready var shop_container = $VBoxContainer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	build_rows()
	
	visibility_changed.connect(_on_visibility_changed)

func _on_visibility_changed():
	if visible:
		update_rows()

func build_rows():
	#clear
	for child in shop_container.get_children():
		child.queue_free()
	upgrade_rows.clear()
	
	var ups = UpgradeManager.get_sorted_upgrades()
	for up in ups:
		var row = HBoxContainer.new()
		var label = Label.new()
		var button = Button.new()
		label.text = up.data.display_name
		button.text = "Buy - $" + str(up.data.get_cost())
		button.pressed.connect(_on_buy_button_pressed.bind(up.id))
		row.add_child(label)
		row.add_child(button)
		shop_container.add_child(row)
		upgrade_rows[up.id] = {"label": label, "button": button}

func update_rows():
	for id in upgrade_rows:
		var data = UpgradeManager.upgrades[id]
		var level = data.current_level
		var cost = data.get_cost()
		upgrade_rows[id].label.text = data.display_name + " Lv." + str(level)
		if data.is_maxed():
			upgrade_rows[id].button.text = "MAXED"
			upgrade_rows[id].button.disabled = true
		else:
			upgrade_rows[id].button.text = "Buy - $" + str(cost)
			upgrade_rows[id].button.disabled = current_cash < cost



func refresh(cash: int):
	current_cash = cash
	if visible:
		update_rows()

func _on_buy_button_pressed(upgrade_id):
	buy_requested.emit(upgrade_id)
