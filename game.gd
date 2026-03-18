extends Node2D

# Node references
@onready var slot_machine = $GameSpace/GameArea/SlotMachine
@onready var spin_button = $GameSpace/GameArea/SpinButton
@onready var cashout_button = $GameSpace/GameArea/CashoutButton
@onready var cash_label = $GameSpace/GameArea/CashLabel
@onready var shop_container = $GameSpace/UpgradeShop/VBoxContainer

var cash = 10
var spin_cost = 1
var upgrade_rows = {}
var upgrades = {
	"multiplier": {"label": "Multiplier", "level": 0, "base_cost": 10, "cost_scale": 1.5},
	"pool_growth": {"label": "Pool Growth", "level": 0, "base_cost": 15, "cost_scale": 1.5},
	"symbols": {"label": "Better Symbols", "level": 0, "base_cost": 25, "cost_scale": 1.5}
}

func _ready():
	load_game()
	build_shop_ui()
	slot_machine.payout.connect(_on_payout)
	slot_machine.spin_complete.connect(_on_spin_complete)
	update_shop_ui()

func build_shop_ui():
	for key in upgrades:
		var row = HBoxContainer.new()
		var label = Label.new()
		var button = Button.new()
		label.text = upgrades[key].label + " Lv.0"
		button.text = "Buy - $" + str(get_cost(key))
		button.pressed.connect(buy_upgrade.bind(key))
		row.add_child(label)
		row.add_child(button)
		shop_container.add_child(row)
		upgrade_rows[key] = {"label": label, "button": button}

func _on_spin_complete():
	spin_button.disabled = false

func _on_spin_button_pressed():
	spin_button.disabled = true
	if cash >= spin_cost:
		cash -= spin_cost
		update_shop_ui()
		slot_machine.spin(true)
	else:
		slot_machine.spin(false)

func _on_payout(amount):
	cash += amount
	update_shop_ui()

func _on_cashout_button_pressed():
	slot_machine.cashout()
	save_game()

func get_cost(upgrade_name):
	var up = upgrades[upgrade_name]
	return int(up.base_cost * pow(up.cost_scale, up.level))

func buy_upgrade(upgrade_name):
	var cost = get_cost(upgrade_name)
	if cash >= cost:
		cash -= cost
		upgrades[upgrade_name].level += 1
		apply_upgrade(upgrade_name)
		update_shop_ui()

func apply_upgrade(upgrade_name):
	match upgrade_name:
		"multiplier":
			slot_machine.payout_mult = 1.0 + (upgrades["multiplier"].level * 0.5)
		"pool_growth":
			slot_machine.pool_per_spin = 1 + upgrades["pool_growth"].level
		"symbols":
			slot_machine.upgrade_symbols(upgrades["symbols"].level)

func update_shop_ui():
	for key in upgrades:
		var level = upgrades[key].level
		var cost = get_cost(key)
		upgrade_rows[key].label.text = upgrades[key].label + " Lv." + str(level)
		upgrade_rows[key].button.text = "Buy - $" + str(cost)
		upgrade_rows[key].button.disabled = cash < cost
	cash_label.text = "Cash: " + str(cash)
	save_game()

func save_game():
	var config = ConfigFile.new()
	config.set_value("player", "cash", cash)
	for key in upgrades:
		config.set_value("upgrades", key, upgrades[key].level)
	config.save("user://savegame.cfg")

func load_game():
	var config = ConfigFile.new()
	var err = config.load("user://savegame.cfg")
	if err != OK:
		return
	cash = config.get_value("player", "cash", 10)
	for key in upgrades:
		upgrades[key].level = config.get_value("upgrades", key, 0)
		apply_upgrade(key)
