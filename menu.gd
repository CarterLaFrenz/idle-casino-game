extends Control


func _ready():
	if not FileAccess.file_exists("user://savegame.cfg"):
		$VBoxContainer/PlayButton.disabled = true

func _on_new_game_button_pressed():
	if FileAccess.file_exists("user://savegame.cfg"):
		DirAccess.remove_absolute("user://savegame.cfg")
	UpgradeManager.reset_all()
	HouseManager.reset()
	get_tree().change_scene_to_file("res://game.tscn")

func _on_play_button_pressed():
	get_tree().change_scene_to_file("res://game.tscn")
