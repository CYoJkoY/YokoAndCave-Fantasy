extends "res://entities/units/enemies/attack_behaviors/shooting_attack_behavior.gd"

export(float, 0.0, 3.14, 0.01) var projectile_spawn_angle_randomization = 0.0

# ══════════════════════════════════════════ Extension ══════════════════════════════════════════ #
func get_projectile_spawn_pos(target_pos: Vector2, projectile_index: int, base_pos: float) -> Vector2:
    var pos: Vector2 = .get_projectile_spawn_pos(target_pos, projectile_index, base_pos)
    var offset: Vector2 = pos - _parent.global_position
    var angle: float = rand_range(-projectile_spawn_angle_randomization, projectile_spawn_angle_randomization)
    return _parent.global_position + offset.rotated(angle)
