extends Node2D

# Node references
@onready var slot_machine = $UI/GameSpace/GameArea/AspectRatioContainer/SlotMachine
@onready var spin_button = $UI/GameSpace/GameArea/SpinButton
@onready var invest_button = $UI/GameSpace/GameArea/SecondRow/InvestButton
@onready var high_roll_button = $UI/GameSpace/GameArea/SecondRow/HighRollModeButton
@onready var auto_spin_button = $UI/GameSpace/GameArea/SecondRow/AutoSpinButton
@onready var cash_label = $UI/GameSpace/GameArea/CashLabel
@onready var token_label = $UI/GameSpace/GameArea/TokenLabel
@onready var vault_label = $UI/GameSpace/GameArea/VaultLabel
@onready var prestige_dialog = $PrestigeDialog
@onready var pressure_bar = $UI/GameSpace/PressureBar/Control/ProgressBar

var cash = 10

#auto spin
var auto_spin_timer: Timer


func _ready():
	load_game()
	update_vault_label()
	update_token_label()
	
	high_roll_button.pressed.connect(slot_machine.activate_high_roll)
	auto_spin_button.pressed.connect(_on_auto_spin_button_pressed)
	slot_machine.payout.connect(_on_payout)
	slot_machine.spin_complete.connect(_on_spin_complete)
	slot_machine.pressure_invested.connect(_on_pressure_invested)
	slot_machine.highroll_state_change.connect(_on_highroll_state_change)
	slot_machine.highroll_tick.connect(_on_highroll_tick)
	
	HouseManager.vault_changed.connect(_on_vault_changed)
	HouseManager.vault_drained.connect(_on_vault_drained)
	HouseManager.vault_cracked.connect(_on_vault_cracked)
	
	TokenManager.tokens_added.connect(_on_tokens_added)
	
	UpgradeManager.upgrade_purchased.connect(_on_upgrade_purchased)
	
	prestige_dialog.confirmed.connect(_on_prestige_confirmed)
	
	HouseManager.pressure_changed.connect(_on_pressure_changed)
	
	$MenuHub/PanelContainer/Layout/ContentArea/UpgradePanel.buy_requested.connect(buy_upgrade)
	
	pressure_bar.max_value = HouseManager.pressure_threshold
	pressure_bar.value = HouseManager.vault_pressure
	update_bar_color()
	
	high_roll_button.visible = true
	#auto_spin_button.visible = UpgradeManager.is_unlocked("auto_spin")
	
	var save_timer = Timer.new()
	save_timer.wait_time = 30.0
	save_timer.timeout.connect(save_game)
	add_child(save_timer)
	save_timer.start()
	
	auto_spin_timer = Timer.new()
	auto_spin_timer.wait_time = UpgradeManager.get_feature_value("auto_spin")
	auto_spin_timer.timeout.connect(_on_auto_spin_timeout)
	add_child(auto_spin_timer)
	$MenuHub/PanelContainer/Layout/ContentArea/UpgradePanel.refresh(cash)
	update_cash_label()

func _on_vault_cracked():
	$PrestigeDialog.dialog_text = "You cracked " + HouseManager.house_name + "! The vault is broken open. Move on?"
	$PrestigeDialog.popup_centered()


func _on_auto_spin_button_pressed():
	if auto_spin_timer.is_stopped():
		auto_spin_timer.wait_time = UpgradeManager.get_feature_value("auto_spin")
		auto_spin_timer.start()
		auto_spin_button.text = "Spinning"
	else:
		auto_spin_timer.stop()
		auto_spin_button.text = "Auto"


func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


func _on_vault_changed(new_amount):
	update_vault_label()

func _on_upgrade_purchased(_upgrade_id):
	UpgradeManager.apply_all(slot_machine)
	$Hub/PanelContainer/Layout/ContentArea/UpgradePanel.refresh(cash)
	high_roll_button.visible = true
	if !(auto_spin_timer.is_stopped()):
		auto_spin_timer.wait_time = UpgradeManager.get_feature_value("auto_spin")

func update_cash_label():
	cash_label.text = "Cash: " + str(cash)

func update_vault_label():
	var amount = HouseManager.vault
	var max_vault = HouseManager.get_max_vault()
	var pct = int((float(amount) / max_vault) * 100)
	vault_label.text = "The House: $" + str(amount) + " / $" + str(max_vault) + " (" + str(pct) + "%)"

func _on_vault_drained():
	$PrestigeDialog.dialog_text = "You drained " + HouseManager.house_name + "! Move to the next House?"
	$PrestigeDialog.popup_centered()

func _on_prestige_confirmed():
	HouseManager.prestige()
	UpgradeManager.reset_all()
	cash = 10
	$MenuHub/PanelContainer/Layout/ContentArea/UpgradePanel.build_rows()
	$MenuHub/PanelContainer/Layout/ContentArea/UpgradePanel.refresh(cash)
	update_cash_label()
	
	slot_machine.pool = 1
	
	UpgradeManager.apply_all(slot_machine)
	update_vault_label()
	update_token_label()
	slot_machine.high_roll_reset()
	auto_spin_timer.stop()
	auto_spin_button.visible = false
	auto_spin_button.text = "Auto"
	
	pressure_bar.max_value = HouseManager.pressure_threshold
	pressure_bar.value = HouseManager.vault_pressure
	update_bar_color()
	save_game()
	


func _on_spin_complete():
	spin_button.disabled = false

func _on_spin_button_pressed():
	spin_button.disabled = true
	slot_machine.spin()
	

func _on_auto_spin_timeout():
	if spin_button.disabled:
		return
	_on_spin_button_pressed()

func _on_payout(amount):
	cash += amount
	HouseManager.add_pressure(amount * 0.1)
	TokenManager.on_win(amount)
	update_cash_label()
	$MenuHub/PanelContainer/Layout/ContentArea/UpgradePanel.refresh(cash)
	

func _on_invest_button_pressed():
	slot_machine.invest()
	save_game()

func _on_pressure_invested(amount):
	HouseManager.add_pressure(amount)
	update_bar_color()

func buy_upgrade(upgrade_id):
	var result = UpgradeManager.try_buy(upgrade_id, cash)
	if result.success:
		cash -= result.cost
		update_cash_label()
		$MenuHub/PanelContainer/Layout/ContentArea/UpgradePanel.refresh(cash)
		save_game()


func _on_pressure_changed(new_amount):
	var tween = create_tween()
	tween.tween_property(pressure_bar, "value", new_amount, 0.3)
	update_bar_color()

func update_bar_color():
	var ratio = HouseManager.vault_pressure / HouseManager.pressure_threshold
	
	var color: Color
	if ratio >= 0.75:
		color = Color(1, 0.2, 0.2)    # red
	elif ratio >= 0.5:
		color = Color(1, 0.6, 0.1)    # orange
	else:
		color = Color(0.2, 0.6, 1)    # blue
	
	var style = StyleBoxFlat.new()
	style.bg_color = color
	pressure_bar.add_theme_stylebox_override("fill", style)

func _on_menu_button_pressed():
	$MenuHub.toggle_hub()

func _on_highroll_state_change(state):
	#ready
	if state == slot_machine.HighRollState.READY:
		high_roll_button.text = "Ready"
		high_roll_button.disabled = false
	elif state == slot_machine.HighRollState.ACTIVE:
		high_roll_button.text = "Go Big (" + str(slot_machine.high_roll_burst) + ")"
		high_roll_button.disabled = true
	else:
		high_roll_button.text = "Recoup (" + str(slot_machine.high_roll_cooldown) + ")"
		high_roll_button.disabled = true

func _on_highroll_tick():
	_on_highroll_state_change(slot_machine.high_roll_current_state)

func _on_tokens_added(delta):
	update_token_label()

func update_token_label():
	var amount = TokenManager.current_tokens
	token_label.text = "Tokens: " + str(amount)


func save_game():
	var config = ConfigFile.new()
	config.set_value("player", "cash", cash)
	UpgradeManager.save_to_config(config)
	HouseManager.save_to_config(config)
	TokenManager.save_to_config(config)
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
	TokenManager.load_from_config(config)
	high_roll_button.visible = true
	#auto_spin_button.visible = UpgradeManager.is_unlocked("auto_spin")
	update_cash_label()

func _on_menu_hub_quit_requested() -> void:
	save_game()
	get_tree().change_scene_to_file("res://menu.tscn")
