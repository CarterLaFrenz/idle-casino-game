extends Control

var symbols: Array [SymbolData] = []
var is_spinning = false

func spin():
	is_spinning = true
	$SpinTimer.start()
	await get_tree().create_timer(randf_range(1.0, 2.0)).timeout
	stop()

func stop():
	$SpinTimer.stop()
	is_spinning = false
	$VBoxContainer/Slot1.text = weighted_pick(symbols).id
	$VBoxContainer/Slot2.text = weighted_pick(symbols).id
	$VBoxContainer/Slot3.text = weighted_pick(symbols).id


func _on_spin_timer_timeout() -> void:
	$VBoxContainer/Slot1.text = weighted_pick(symbols).id
	$VBoxContainer/Slot2.text = weighted_pick(symbols).id
	$VBoxContainer/Slot3.text = weighted_pick(symbols).id


func get_results() -> Array:
	return [
		$VBoxContainer/Slot1.text,
		$VBoxContainer/Slot2.text,
		$VBoxContainer/Slot3.text
	]


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
		return symbols
	# Build a copy with boosted skull weight
	var modified = []
	for s in symbols:
		if s.is_bust:
			var boosted = s.duplicate()
			boosted.weight = int(s.weight * (1.0 + skull_bonus))
			modified.append(boosted)
		else:
			modified.append(s)
	return modified
