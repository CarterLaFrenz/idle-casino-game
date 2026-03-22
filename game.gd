extends Node2D

# Node references
@onready var slot_machine = $GameSpace/GameArea/SlotMachine
@onready var spin_button = $GameSpace/GameArea/SpinButton
@onready var cashout_button = $GameSpace/GameArea/CashoutButton
@onready var hunt_button = $GameSpace/GameArea/HuntModeButton
@onready var cash_label = $GameSpace/GameArea/CashLabel
@onready var shop_container = $GameSpace/UpgradeShop/VBoxContainer
@onready var vault_label = $GameSpace/GameArea/VaultLabel
@onready var prestige_dialog = $PrestigeDialog

var cash = 10
var spin_cost = 1
var upgrade_rows = {}


#hunt variables
var spins_since_toggle: int = 3
var toggle_cooldown: int = 3

func _ready():
	load_game()
	update_vault_label()
	build_shop_ui()
	
	hunt_button.pressed.connect(_on_hunt_button_pressed)
	slot_machine.payout.connect(_on_payout)
	slot_machine.spin_complete.connect(_on_spin_complete)
	slot_machine.bust_penalty.connect(_on_bust_penalty)
	HouseManager.vault_changed.connect(_on_vault_changed)
	UpgradeManager.upgrade_purchased.connect(_on_upgrade_purchased)
	HouseManager.vault_drained.connect(_on_vault_drained)
	prestige_dialog.confirmed.connect(_on_prestige_confirmed)
	update_shop_ui()
	
	hunt_button.visible = slot_machine.hunt_mode_available
	
	var save_timer = Timer.new()
	save_timer.wait_time = 30.0
	save_timer.timeout.connect(save_game)
	add_child(save_timer)
	save_timer.start()

func _on_hunt_button_pressed():
	slot_machine.hunt_mode_active = !slot_machine.hunt_mode_active
	if slot_machine.hunt_mode_active:
		hunt_button.text = "SAFE MODE"
	else:
		hunt_button.text = "HUNT MODE"
	spins_since_toggle = 0

func _on_bust_penalty(amount):
	var amount_taken = max(0, cash - amount)
	cash -= amount_taken
	HouseManager.feed(amount_taken)
	update_shop_ui()

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()

func _on_upgrade_purchased(_upgrade_id):
	UpgradeManager.apply_all(slot_machine)
	update_shop_ui()
	hunt_button.visible = slot_machine.hunt_mode_available

func _on_vault_changed(new_amount):
	update_vault_label()

func update_vault_label():
	var amount = HouseManager.vault
	var max_vault = HouseManager.house_data[HouseManager.house_level].vault
	var pct = int((float(amount) / max_vault) * 100)
	vault_label.text = "The House: $" + str(amount) + " / $" + str(max_vault) + " (" + str(pct) + "%)"

func _on_vault_drained():
	$PrestigeDialog.dialog_text = "You drained " + HouseManager.house_name + "! Move to the next House?"
	$PrestigeDialog.popup_centered()

func _on_prestige_confirmed():
	HouseManager.prestige()
	UpgradeManager.reset_all()
	cash = 10
	slot_machine.pool = 1
	slot_machine.hunt_mode_active = false
	UpgradeManager.apply_all(slot_machine)
	build_shop_ui()
	update_shop_ui()
	update_vault_label()
	hunt_button.visible = false
	hunt_button.text = "HUNT MODE"
	save_game()

func build_shop_ui():
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
		button.pressed.connect(buy_upgrade.bind(up.id))
		row.add_child(label)
		row.add_child(button)
		shop_container.add_child(row)
		upgrade_rows[up.id] = {"label": label, "button": button}

func _on_spin_complete():
	spin_button.disabled = false

func _on_spin_button_pressed():
	spin_button.disabled = true
	var current_spin_cost = spin_cost * 3 if slot_machine.hunt_mode_active else spin_cost
	if cash >= current_spin_cost:
		cash -= current_spin_cost
		HouseManager.feed(current_spin_cost)
		update_shop_ui()
		slot_machine.spin(true)
		spins_since_toggle += 1
		if spins_since_toggle >= toggle_cooldown:
			hunt_button.disabled = false
		else:
			hunt_button.disabled = true
	else:
		slot_machine.spin(false)

func _on_payout(amount):
	cash += amount
	HouseManager.drain(amount)
	update_shop_ui()
	

func _on_cashout_button_pressed():
	slot_machine.cashout()
	save_game()


func buy_upgrade(upgrade_id):
	var result = UpgradeManager.try_buy(upgrade_id, cash)
	if result.success:
		cash -= result.cost
		update_shop_ui()
		save_game()


func update_shop_ui():
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
			upgrade_rows[id].button.disabled = cash < cost
	cash_label.text = "Cash: " + str(cash)
	

func _on_menu_button_pressed():
	save_game()
	get_tree().change_scene_to_file("res://menu.tscn")

func save_game():
	var config = ConfigFile.new()
	config.set_value("player", "cash", cash)
	UpgradeManager.save_to_config(config)
	HouseManager.save_to_config(config)
	config.save("user://savegame.cfg")

func load_game():
	var config = ConfigFile.new()
	var err = config.load("user://savegame.cfg")
	if err != OK:
		return
	cash = config.get_value("player", "cash", 10)
	UpgradeManager.load_from_config(config)
	UpgradeManager.apply_all(slot_machine)
	HouseManager.load_from_config(config)
	hunt_button.visible = slot_machine.hunt_mode_available
