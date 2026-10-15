extends "res://weapons/ranged/ranged_weapon.gd"


func should_shoot() -> bool:
    if _shooting_behavior.is_emitting() or not WeaponService.fantasy_can_start_attack(self):
        return false
    if not .should_shoot():
        return false
    return _manual_aim or _current_target[1] <= current_stats.max_range


func get_max_range() -> int:
    return current_stats.max_range


func get_max_rand_cooldown(_cooldown_basis: int) -> float:
    return 0.0
