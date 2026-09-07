extends CanvasLayer

signal quit_requested

@onready var UpgradePanel = $PanelContainer/Layout/ContentArea/UpgradePanel
@onready var TokenPanel = $PanelContainer/Layout/ContentArea/TokenShopPanel
@onready var PrestigePanel = $PanelContainer/Layout/ContentArea/PrestigePanel


func toggle_hub():
	visible = !visible

func show_panel(panel: Control):
	for child in $Background/Layout/ContentArea.get_children():
		child.visible = (child == panel)

func _on_quit_button_pressed():
	quit_requested.emit()


func _on_return_button_pressed() -> void:
	toggle_hub()


func _on_upgrade_button_pressed() -> void:
	show_panel(UpgradePanel)


func _on_token_button_pressed() -> void:
	show_panel(TokenPanel)


func _on_prestige_button_pressed() -> void:
	show_panel(PrestigePanel)
