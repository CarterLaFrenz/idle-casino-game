extends Control
# earning data
var pool = 1
var pool_per_spin = 1
var symbol_values = {"A": 1, "B": 2, "C": 3, "D": 5}
var payout_mult = 1

signal payout(amount)
signal spin_complete


func _ready() -> void:
	$PoolLabel.text = "Pool: " + str(pool)
	

# Spin Func
func spin(grows_pool):
	if grows_pool:
		pool += pool_per_spin
		$PoolLabel.text = "Pool: " + str(pool)
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
	
	resolve_spin(results)
	spin_complete.emit()


func check_wins(results):
	var wins = []
	for row in 3:
		if results[row][0] == results[row][1] and results[row][1] == results[row][2]:
			wins.append({"row": row, "symbol": results[row][0]})
	return wins


func resolve_spin(results):
	var busted = false
	for row in 3:
		if results[row][0] == "X" and results[row][1] == "X" and results[row][2] == "X":
			busted = true
			break
	
	if busted:
		pool = 0
		$PoolLabel.text = "Pool: 0 - BUST!"
		return
	
	var wins = check_wins(results)
	if wins.size() > 0:
		var payout_amount = 0
		for win in wins:
			payout_amount += (symbol_values[win.symbol] + (pool * symbol_values[win.symbol])) * payout_mult
		payout.emit(payout_amount)
		pool = 1  # reset after cashout
		$PoolLabel.text = "Pool: " + str(pool)


func cashout():
	var cashout_amount = pool * 0.5
	payout.emit(cashout_amount)
	pool = 0
	$PoolLabel.text = "Pool: " + str(pool)


# Upgrade Func
func upgrade_symbols(level):
	match level:
		1:
			symbol_values["E"] = 8
		2:
			symbol_values["F"] = 12
		3:
			symbol_values["G"] = 20
	
	$HBoxContainer/Reel1.symbols = symbol_values.keys()
	$HBoxContainer/Reel2.symbols = symbol_values.keys()
	$HBoxContainer/Reel3.symbols = symbol_values.keys()
