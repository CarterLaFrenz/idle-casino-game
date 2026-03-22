extends Node

var upgrades: Dictionary = {}
const UPGRADE_PATH = "res://data/upgrades/"

signal upgrade_purchased(upgrade_id: String)

func _ready():
	load_all_upgrades()

func load_all_upgrades():
	upgrades.clear()
	var dir = DirAccess.open(UPGRADE_PATH)
	if not dir:
		push_warning("UpgradeManager: Could not open " + UPGRADE_PATH)
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres") or file_name.ends_with(".tres.remap"):
			var clean_name = file_name.replace(".remap", "")
			var upgrade_id = clean_name.get_basename()
				
			var resource = load(UPGRADE_PATH + clean_name)
			if resource is UpgradeData:
				upgrades[upgrade_id] = resource
		file_name = dir.get_next()
	dir.list_dir_end()


func get_sorted_upgrades(house_level: int = 1, prestige_level: int = 0) -> Array:
	var result = []
	for id in upgrades:
		var up = upgrades[id]
		if up.requires_house_level <= house_level and up.requires_prestige <= prestige_level:
			result.append({"id": id, "data": up})
	result.sort_custom(func(a, b): return a.data.shop_order < b.data.shop_order)
	return result
	

func try_buy(upgrade_id: String, cash: float) -> Dictionary:
	var up = upgrades.get(upgrade_id)
	if not up:
		return {"success": false, "cost": 0}
	if up.is_maxed():
		return {"success": false, "cost": 0}
	var cost = up.get_cost()
	if cash < cost:
		return {"success": false, "cost": cost}
	
	up.current_level += 1
	upgrade_purchased.emit(upgrade_id)
	return {"success": true, "cost": cost}

## Get the current value of an effect type across ALL upgrades that share it.
func get_effect_total(effect_type: String) -> float:
	var total = 0.0
	for id in upgrades:
		var up = upgrades[id]
		if up.effect_type == effect_type:
			total += up.get_current_effect()
	return total

func is_feature_unlocked(effect_type: String) -> bool:
	for id in upgrades:
		if upgrades[id].effect_type == effect_type and upgrades[id].is_unlocked():
			return true
	return false

## Get the scaled value for a feature upgrade (base_value - levels of improvement)
## Returns the base_value if not yet unlocked, or the improved value if leveled.
func get_feature_value(effect_type: String) -> float:
	for id in upgrades:
		if upgrades[id].effect_type == effect_type:
			return upgrades[id].get_scaled_value()
	return 0.0

## Apply all upgrades to the slot machine. Call this after loading a save
## or after any purchase. This replaces the old match statement entirely.
func apply_all(slot_machine) -> void:
	# --- NUMERIC SCALERS ---
	
	# Payout multiplier: base 1.0 + total from all payout_mult upgrades
	slot_machine.payout_mult = 1.0 + get_effect_total("payout_mult")
	
	# Pool per spin: base 1 + total from all pool_per_spin upgrades
	slot_machine.pool_per_spin = 1 + int(get_effect_total("pool_per_spin"))
	
	# Symbol unlocks: check the highest level among unlock_symbols upgrades
	var symbol_level = int(get_effect_total("unlock_symbols"))
	slot_machine.upgrade_symbols(symbol_level)
	
	# Luck, reroll, safety net — wire these up as you build them
	slot_machine.reroll_chance = get_effect_total("reroll_chance") / 100.0
	slot_machine.safety_net_pct = get_effect_total("safety_net") / 100.0
	
	# --- FEATURE UNLOCKS ---
	
	# Auto-spin: unlocked at level 1, interval improves with levels
	slot_machine.auto_spin_enabled = is_feature_unlocked("auto_spin")
	if slot_machine.auto_spin_enabled:
		slot_machine.auto_spin_interval = get_feature_value("auto_spin")
	
	# Hunt mode: pure unlock
	slot_machine.hunt_mode_available = is_feature_unlocked("hunt_mode")
	
	# Auto-cashout: pure unlock  
	slot_machine.auto_cashout_available = is_feature_unlocked("auto_cashout")


## Save all upgrade levels to a ConfigFile
func save_to_config(config: ConfigFile) -> void:
	for id in upgrades:
		config.set_value("upgrades", id, upgrades[id].current_level)

## Load upgrade levels from a ConfigFile
func load_from_config(config: ConfigFile) -> void:
	for id in upgrades:
		upgrades[id].current_level = config.get_value("upgrades", id, 0)

## Reset all upgrade levels (for prestige)
func reset_all() -> void:
	for id in upgrades:
		upgrades[id].current_level = 0
