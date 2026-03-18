extends Control

var symbols = ["A", "B", "C", "D", "X"]
var is_spinning = false

func spin():
	is_spinning = true
	$SpinTimer.start()
	await get_tree().create_timer(randf_range(1.0, 2.0)).timeout
	stop()

func stop():
	$SpinTimer.stop()
	is_spinning = false
	$VBoxContainer/Slot1.text = symbols.pick_random()
	$VBoxContainer/Slot2.text = symbols.pick_random()
	$VBoxContainer/Slot3.text = symbols.pick_random()


func _on_spin_timer_timeout() -> void:
	$VBoxContainer/Slot1.text = symbols.pick_random()
	$VBoxContainer/Slot2.text = symbols.pick_random()
	$VBoxContainer/Slot3.text = symbols.pick_random()


func get_results() -> Array:
	return [
		$VBoxContainer/Slot1.text,
		$VBoxContainer/Slot2.text,
		$VBoxContainer/Slot3.text
	]
