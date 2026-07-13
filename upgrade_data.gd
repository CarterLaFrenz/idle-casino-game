class_name UpgradeData
extends Resource


@export var display_name: String = "New Upgrade"
@export_multiline var description: String = ""

@export_enum("payout_mult", "pool_per_spin", "unlock_symbols", "luck", "bust_penalty", 
	"spin_speed", "house_threshold", "reroll_chance", "safety_net",
	"auto_spin", "offline_efficiency", "max_afk_hours",
	"high_roll_mode", "auto_cashout", "skull_weight") var effect_type: String = "payout_mult"
@export var effect_per_level: float = 1.0

## Base value for feature unlocks
@export var base_value: float = 0.0

@export var base_cost: int = 10
@export var cost_scale: float = 1.5
@export var max_level: int = 0

## Sort order in the shop (lower = higher in the list)
@export var shop_order: int = 0

## Is this upgrade available from the start, or unlocked later?
@export var requires_house_level: int = 1
@export var requires_prestige: int = 0

# --- Runtime state ---
var current_level: int = 0

func get_cost() -> int:
	return int(base_cost * pow(cost_scale, current_level))
 
func is_maxed() -> bool:
	return max_level > 0 and current_level >= max_level
 
## For numeric scalers: total accumulated effect
func get_current_effect() -> float:
	return effect_per_level * current_level
 
## For feature unlocks: is this purchased/available?
func is_unlocked() -> bool:
	return current_level >= 1

## For hybrid upgrades: base_value modified by levels
func get_scaled_value() -> float:
	return base_value - (effect_per_level * current_level)
