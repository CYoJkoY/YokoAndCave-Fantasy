extends "res://weapons/shooting_behaviors/ranged_weapon_shooting_behavior.gd"


func shoot(_distance: float) -> void:
    _parent.strike_orb(_get_next_attack_id())
