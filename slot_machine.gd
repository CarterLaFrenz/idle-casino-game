extends Control
# earning data
var pool = 1
var pool_per_spin = 1
var payout_mult = 1

# Symbols
var base_symbols: Array[SymbolData] = []
var unlock_symbols: Array[SymbolData] = []
var active_symbols: Array[SymbolData] = []
const SYMBOL_PATH = "res://data/symbols/"
# Rolls
var reroll_chance: float = 0.0
var safety_net_pct: float = 0.0 
var auto_spin_enabled: bool = false
var auto_spin_interval: float = 3.0
var hunt_mode_available: bool = false
var hunt_mode_active: bool = false
var auto_cashout_available: bool = false
var auto_cashout_threshold: int = 0


signal payout(amount)
signal spin_complete
signal bust_penalty(amount)

func _ready() -> void:
	$PoolLabel.text = "Pool: " + str(pool)
	
	var dir = DirAccess.open(SYMBOL_PATH)
	if not dir:
		push_warning("SlotMachine: Could not open " + SYMBOL_PATH)
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres") or file_name.ends_with(".tres.remap"):
			var clean_name = file_name.replace(".remap", "")
			var resource = load(SYMBOL_PATH + clean_name)
			
			if resource is SymbolData:
				if resource.unlock_order == -1:
					base_symbols.append(resource)
				elif resource.unlock_order >= 0:
					unlock_symbols.append(resource)
		file_name = dir.get_next()
	dir.list_dir_end()
	unlock_symbols.sort_custom(func(a, b): return a.unlock_order < b.unlock_order)
	active_symbols = base_symbols.duplicate()
	update_reels()

# Spin Func
func spin(grows_pool):
	if grows_pool:
		var growth = pool_per_spin * 2 if hunt_mode_active else pool_per_spin
		pool += growth
		$PoolLabel.text = "Pool: " + str(pool)
		if auto_cashout_available and auto_cashout_threshold > 0:
			if pool >= auto_cashout_threshold:
				cashout()
				spin_complete.emit()
				return
	$HBoxContainer/Reel1.spin()
	$HBoxContainer/Reel2.spin()
	$HBoxContainer/Reel3.spin()
	
	while $HBoxContainer/Reel1.is_spinning or $HBoxContainer/Reel2.is_spinning or $HBoxContainer/Reel3.is_spinning:
		await get_tree().process_frame
	
	var results = []
	for row in 3:
		results.append([
			$HBoxContainer/Reel1.get_results()[row],
			$HBoxContainer/Reel2.get_results()[row],
			$HBoxContainer/Reel3.get_results()[row]
		])
	
	apply_rerolls(results)
	resolve_spin(results)
	spin_complete.emit()


func check_wins(results):
	var wins = []
	for row in 3:
		if results[row][0] == results[row][1] and results[row][1] == results[row][2]:
			wins.append({"row": row, "symbol": results[row][0]})
	return wins

func get_symbol_data(id:String) -> SymbolData:
	for s in active_symbols:
		if s.id == id:
			return s
	return null

func apply_rerolls(results):
	if reroll_chance <= 0:
		return results
	for row in 3:
		for col in 3:
			var sym = get_symbol_data(results[row][col])
			if sym and sym.is_bust and randf() < reroll_chance:
				var replacement = weighted_pick_non_bust()
				results[row][col] = replacement
				return results

func weighted_pick_non_bust() -> SymbolData:
	var non_bust = active_symbols.filter(func(s): return not s.is_bust)
	return weighted_pick(non_bust)

func resolve_spin(results):
	var busted = false
	for row in 3:
		var all_bust = true
		for col in 3:
			var sym = get_symbol_data(results[row][col])
			if sym == null or not sym.is_bust:
				all_bust = false
				break
		if all_bust:
			busted = true
			break
	
	if busted:
		var lost_pool = pool
		var saved = int(pool * safety_net_pct)
		pool = saved
		if hunt_mode_active:
			var penalty = int(lost_pool * 0.25)
			bust_penalty.emit(penalty)
		if saved > 0:
			$PoolLabel.text = "BUST! Saved " + str(saved)
		else:
			$PoolLabel.text = "Pool: 0 - BUST!"
		return
	
	var wins = check_wins(results)
	if wins.size() > 0:
		var payout_amount = 0
		for win in wins:
			var sym_value = get_symbol_data(win.symbol).base_value
			if hunt_mode_active:
				payout_amount += pool * sym_value * payout_mult
			else:
				payout_amount += (sym_value + (pool * sym_value)) * payout_mult
		payout.emit(payout_amount)
		pool = 1  # reset after cashout
		$PoolLabel.text = "Pool: " + str(pool)


func cashout():
	var rate = HouseManager.get_fight_back().cashout_rate
	if HouseManager.surveillance_penalty_spins > 0:
		rate -= 0.10
	var cashout_amount = int(pool * rate)
	payout.emit(cashout_amount)
	pool = 0


# Upgrade Func
func upgrade_symbols(level):
	active_symbols = base_symbols.duplicate()
	for i in min(level, unlock_symbols.size()):
		active_symbols.append(unlock_symbols[i])
		update_reels()

func update_reels():
	for reel in [$HBoxContainer/Reel1, $HBoxContainer/Reel2, $HBoxContainer/Reel3]:
		reel.symbols = active_symbols



func weighted_pick(symbols: Array[SymbolData]) -> SymbolData:
	var total = 0
	for s in symbols:
		total += s.weight
	var roll = randf() * total
	for s in symbols:
		roll -= s.weight
		if roll <= 0:
			return s
	return symbols[-1]


func get_modified_symbols() -> Array[SymbolData]:
	var skull_bonus = HouseManager.get_fight_back().skull_bonus
	if skull_bonus <= 0:
		return active_symbols
	# Build a copy with boosted skull weight
	var modified = []
	for s in active_symbols:
		if s.is_bust:
			var boosted = s.duplicate()
			boosted.weight = int(s.weight * (1.0 + skull_bonus))
			modified.append(boosted)
		else:
			modified.append(s)
	return modified
