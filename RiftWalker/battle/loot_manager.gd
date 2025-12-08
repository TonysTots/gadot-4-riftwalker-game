class_name LootManager extends Node

## Calculates gold rewards based on enemy stats and difficulty.
func calculate_loot(enemies: Array, difficulty_multiplier: float) -> int:
	var total_reward: int = 0
	
	for enemy_stats in enemies:
		# Defensive check to ensure we have valid stats objects
		if not enemy_stats is EnemyStats: continue
		
		# Recalculate scaled stats locally for coin value
		# Note: The actual battlers in the scene are already scaled, 
		# so if we pass the *scene battlers*, we don't need to re-multiply.
		# However, battle.gd passed 'battleData.enemies' (Resources) which are NOT scaled.
		# So we must apply the multiplier here as battle.gd did.
		
		var scaled_health = enemy_stats.health * difficulty_multiplier
		var scaled_strength = enemy_stats.strength * difficulty_multiplier
		var scaled_magic = enemy_stats.magicStrength * difficulty_multiplier
		
		var coin_value = (scaled_health * 0.1) + (scaled_strength * 0.2) + (scaled_magic * 0.2)
		total_reward += int(coin_value)
		
	return max(10, total_reward) # Minimum 10 coins
