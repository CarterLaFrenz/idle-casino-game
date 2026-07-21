extends Node

var current_tokens : int = 0

var token_tiers = [
	{"max_payout": 10.0,  "chance": 0.05, "min_tokens": 1, "max_tokens": 1},
	{"max_payout": 50.0,  "chance": 0.20, "min_tokens": 1, "max_tokens": 1},
	{"max_payout": 150.0, "chance": 0.40, "min_tokens": 1, "max_tokens": 2},
	{"max_payout": INF,   "chance": 0.70, "min_tokens": 2, "max_tokens": 3},
]


signal tokens_added(amount)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.


func on_win(payout_amount):
	for tier in token_tiers:
		if payout_amount <= tier.max_payout:
			var token_roll = randf()
			if token_roll < tier.chance:
				var token_amount = randi_range(tier.min_tokens, tier.max_tokens)
				current_tokens += token_amount
				tokens_added.emit(token_amount)
				break




# save/load
func save_to_config(config):
	config.set_value("player", "tokens", current_tokens)
	

func load_from_config(config):
	current_tokens = config.get_value("player", "tokens", 0)
	
