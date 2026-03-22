extends Node


var vault: int
var house_level: int = 1
var house_name: String

var consecutive_cashouts: int = 0
var surveillance_penalty_spins: int = 0


signal vault_changed(new_amount)
signal vault_drained


var house_data = {
	1: {"name": "Louie's Back Alley Slots", "vault": 500},
	2: {"name": "The Lucky Dollar", "vault": 2500},
	3: {"name": "Golden Goose Casino", "vault": 15000},
	4: {"name": "The Velvet Vault", "vault": 100000},
	5: {"name": "The House Always Wins™", "vault": 1000000},
}

func _ready():
	
	vault = house_data[house_level].vault
	house_name = house_data[house_level].name

func drain(amount):
	vault = max(0, vault - amount)
	vault_changed.emit(vault)
	if vault <= 0:
		vault_drained.emit()
	

func feed(amount):
	vault += amount
	vault_changed.emit(vault)


func prestige():
	house_level += 1
	# Cap at highest defined level, or scale beyond it
	if house_level > house_data.size():
		var scaled_vault = 1000000 * (house_level - 4)
		vault = scaled_vault
		house_name = "The House Always Wins™ Lv." + str(house_level - 4)
	else:
		vault = house_data[house_level].vault
		house_name = house_data[house_level].name
	vault_changed.emit(vault)

func get_fight_back() -> Dictionary:
	var max_vault = house_data[house_level].vault
	var pct = float(vault) / max_vault
	
	if pct > 0.75:
		return {"skull_bonus": 0, "cashout_rate": 0.5, "surveillance_limit": 3, "flavor": ""}
	elif pct > 0.5:
		return {"skull_bonus": 0.25, "cashout_rate": 0.45, "surveillance_limit": 3, "flavor": "The House is watching you."}
	elif pct > 0.25:
		return {"skull_bonus": 0.5, "cashout_rate": 0.40, "surveillance_limit": 2, "flavor": "The House is getting nervous."}
	elif pct > 0.10:
		return {"skull_bonus": 0.75, "cashout_rate": 0.35, "surveillance_limit": 2, "flavor": "The House is desperate."}
	else:
		return {"skull_bonus": 1.0, "cashout_rate": 0.30, "surveillance_limit": 1, "flavor": "The House knows it's losing."}

func on_cashout():
	consecutive_cashouts += 1
	var fb = get_fight_back()
	if consecutive_cashouts >= fb.surveillance_limit:
		surveillance_penalty_spins = 5
		consecutive_cashouts = 0

func on_spin():
	if surveillance_penalty_spins > 0:
		surveillance_penalty_spins -= 1


func save_to_config(config):
	config.set_value("house", "vault", vault)
	config.set_value("house", "level", house_level)

func load_from_config(config):
	house_level = config.get_value("house", "level", 1)
	vault = config.get_value("house", "vault", house_data[house_level].vault)


func reset():
	house_level = 1
	vault = house_data[1].vault
	house_name = house_data[1].name
	vault_changed.emit(vault)
