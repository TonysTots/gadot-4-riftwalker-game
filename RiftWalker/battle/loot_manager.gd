class_name LootManager extends Node

## Calculates gold rewards based on enemy stats and difficulty.
func calculate_loot(enemies: Array[EnemyStats], difficulty_multiplier: float) -> int:
	var total_reward: int = 0
	
	for enemy_stats in enemies:
		if enemy_stats == null: continue
		
		var scaled_health: float = enemy_stats.health * difficulty_multiplier
		var scaled_strength: float = enemy_stats.strength * difficulty_multiplier
		var scaled_magic: float = enemy_stats.magicStrength * difficulty_multiplier
		
		var coin_value: float = (scaled_health * 0.1) + (scaled_strength * 0.2) + (scaled_magic * 0.2)
		total_reward += int(coin_value)
		
	return maxi(10, total_reward) # Minimum 10 coins
