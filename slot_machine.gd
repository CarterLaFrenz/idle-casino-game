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

var slot_labels = []

var COLOR_DEFAULT = Color.WHITE
var COLOR_WIN_SMALL = Color.GREEN
var COLOR_WIN_BIG = Color.GOLD
var COLOR_BUST = Color.RED


var paylines = [
	# Horizontal
	[[0,0], [0,1], [0,2]],  # top row
	[[1,0], [1,1], [1,2]],  # middle row
	[[2,0], [2,1], [2,2]],  # bottom row
	# Vertical
	[[0,0], [1,0], [2,0]],  # left column
	[[0,1], [1,1], [2,1]],  # center column
	[[0,2], [1,2], [2,2]],  # right column
	# Diagonal
	[[0,0], [1,1], [2,2]],  # top-left to bottom-right
	[[2,0], [1,1], [0,2]],  # top-right to bottom-left
]

# Rolls
var reroll_chance: float = 0.0
var auto_spin_enabled: bool = false
var auto_spin_interval: float = 3.0

enum HighRollState { READY, ACTIVE, COOLDOWN }
var high_roll_current_state = HighRollState.READY
var high_roll_burst: int = 0
var high_roll_cooldown: int = 0

const HIGH_ROLL_BURST_MAX = 3
const HIGH_ROLL_COOLDOWN_MAX = 15


var auto_cashout_available: bool = false
var auto_cashout_threshold: int = 0




signal payout(amount)
signal spin_complete
signal pressure_invested(amount)
signal highroll_state_change(state)
signal highroll_tick

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
	
	slot_labels = [
		[$HBoxContainer/Reel1/VBoxContainer/Slot1, $HBoxContainer/Reel1/VBoxContainer/Slot2, $HBoxContainer/Reel1/VBoxContainer/Slot3],
		[$HBoxContainer/Reel2/VBoxContainer/Slot1, $HBoxContainer/Reel2/VBoxContainer/Slot2, $HBoxContainer/Reel2/VBoxContainer/Slot3],
		[$HBoxContainer/Reel3/VBoxContainer/Slot1, $HBoxContainer/Reel3/VBoxContainer/Slot2, $HBoxContainer/Reel3/VBoxContainer/Slot3],
		]

# Spin Func
func spin():
	

	for reel in slot_labels:
		for label in reel:
			label.add_theme_color_override("font_color", COLOR_DEFAULT)
	
	var modified = get_modified_symbols()
	for reel in [$HBoxContainer/Reel1, $HBoxContainer/Reel2, $HBoxContainer/Reel3]:
		reel.symbols = modified
	
	var growth = pool_per_spin
	pool += growth
	
	$PoolLabel.text = "Pool: " + str(pool)
	$HBoxContainer/Reel1.spin()
	
	while $HBoxContainer/Reel1.is_spinning:
		await get_tree().process_frame
	
	var results = []
	
	if high_roll_current_state == HighRollState.ACTIVE:
		var reel1_result = $HBoxContainer/Reel1.get_results()
		var highest_result = null
		
		for result in reel1_result:
			var sym = get_symbol_data(result)
			if highest_result == null and not sym.is_bust:
				highest_result = result
			elif not sym.is_bust and sym.base_value > get_symbol_data(highest_result).base_value:
				highest_result = result
		var high_roll_weights = get_high_roll_weights(highest_result)
		$HBoxContainer/Reel2.symbols = high_roll_weights
		$HBoxContainer/Reel3.symbols = high_roll_weights
	
	
	$HBoxContainer/Reel2.spin()
	$HBoxContainer/Reel3.spin()
	
	while $HBoxContainer/Reel2.is_spinning or $HBoxContainer/Reel3.is_spinning:
		await get_tree().process_frame
	
	
	for row in 3:
		results.append([
			$HBoxContainer/Reel1.get_results()[row],
			$HBoxContainer/Reel2.get_results()[row],
			$HBoxContainer/Reel3.get_results()[row]
		])
	
	apply_rerolls(results)
	resolve_spin(results)
	spin_complete.emit()
	
	if high_roll_current_state == HighRollState.ACTIVE:
		high_roll_burst -= 1
		highroll_tick.emit()
		if high_roll_burst == 0:
			high_roll_current_state = HighRollState.COOLDOWN
			high_roll_cooldown = HIGH_ROLL_COOLDOWN_MAX
			highroll_state_change.emit(high_roll_current_state)
			
	elif high_roll_current_state == HighRollState.COOLDOWN:
		high_roll_cooldown -= 1
		highroll_tick.emit()
		if high_roll_cooldown == 0:
			high_roll_current_state = HighRollState.READY
			highroll_state_change.emit(high_roll_current_state)

func get_high_roll_weights(result):
	var top_sym = []
	var non_bust = active_symbols.filter(func(s): return not s.is_bust)
	non_bust.sort_custom(func(a, b): return a.base_value > b.base_value)
	top_sym = non_bust.slice(0, 3)
	var lead = get_symbol_data(result)
	var is_high = top_sym.has(lead)
	
	var modified: Array[SymbolData] = []
	if is_high:
		for s in active_symbols:
			if s == get_symbol_data(result):
				var boosted = s.duplicate()
				boosted.weight = max(1, int(s.weight * 2.5))
				modified.append(boosted)
			else:
				modified.append(s)
	else:
		for s in active_symbols:
			if s == get_symbol_data(result):
				var boosted = s.duplicate()
				boosted.weight = max(1, int(s.weight / 2.5))
				modified.append(boosted)
			elif top_sym.has(s):
				var boosted = s.duplicate()
				boosted.weight = max(1, int(s.weight * 1.3))
				modified.append(boosted)
			else:
				modified.append(s)
	return modified

func check_wins(results):
	var wins = []
	for i in range(paylines.size()):
		var line = paylines[i]
		var sym1 = results[line[0][0]][line[0][1]]
		var sym2 = results[line[1][0]][line[1][1]]
		var sym3 = results[line[2][0]][line[2][1]]
		if (sym1 == sym2 && sym2 == sym3):
			wins.append({"payline": i, "symbol": sym1})
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
	var bust_line = null
	for i in range(paylines.size()):
		var line = paylines[i]
		var sym1 = get_symbol_data(results[line[0][0]][line[0][1]])
		var sym2 = get_symbol_data(results[line[1][0]][line[1][1]])
		var sym3 = get_symbol_data(results[line[2][0]][line[2][1]])
		if sym1 == null or not sym1.is_bust:
			continue
		if sym2 == null or not sym2.is_bust:
			continue
		if sym3 == null or not sym3.is_bust:
			continue
		busted = true
		bust_line = i
		break
	
	if busted:
		var base_rate = 0.5
		var safety_reduction = UpgradeManager.get_effect_total("safety_net")
		var thick_skin_reduction = 0.0
		var final_rate = clamp(base_rate - safety_reduction - thick_skin_reduction, 0.1, 0.75)
		var lost = int(pool * final_rate)
		pool = pool - lost
		$PoolLabel.text = "BUST! Lost " + str(lost) + ", kept " + str(pool)
		for pos in paylines[bust_line]:
			slot_labels[pos[1]][pos[0]].add_theme_color_override("font_color", COLOR_BUST)
		return
	
	var wins = check_wins(results)
	if wins.size() > 0:
		var payout_amount = 0
		for win in wins:
			print("Win on payline ", win.payline, " symbol: ", win.symbol)
			var sym_value = get_symbol_data(win.symbol).base_value
			payout_amount += pool * sym_value * payout_mult
			
			var color = COLOR_WIN_BIG if sym_value >= 5 else COLOR_WIN_SMALL
			for pos in paylines[win.payline]:
				slot_labels[pos[1]][pos[0]].add_theme_color_override("font_color", color)
		payout.emit(payout_amount)
		pool = 1  # reset after cashout
		$PoolLabel.text = "Pool: " + str(pool)


func invest():
	var rate = .5
	var invest_amount = int(pool * rate)
	pressure_invested.emit(invest_amount)
	pool = 1
	$PoolLabel.text = "Pool: " + str(pool)


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
	var modified: Array[SymbolData] = []
	for s in active_symbols:
		if s.is_bust:
			var boosted = s.duplicate()
			boosted.weight = int(s.weight * (1.0 + skull_bonus))
			modified.append(boosted)
		else:
			modified.append(s)
	return modified

func activate_high_roll():
	if high_roll_current_state == HighRollState.READY:
		high_roll_current_state = HighRollState.ACTIVE
		high_roll_burst = HIGH_ROLL_BURST_MAX
		highroll_state_change.emit(high_roll_current_state)
	

func high_roll_reset():
	high_roll_current_state = HighRollState.READY
	high_roll_burst = 0
	high_roll_cooldown = 0
	highroll_state_change.emit(high_roll_current_state)
