extends "res://weapons/shooting_behaviors/ranged_weapon_shooting_behavior.gd"


func shoot(_distance: float) -> void:
    _parent.emit_erosion_pulse(_get_next_attack_id())
    _parent.tween.interpolate_callback(_parent, _parent.current_stats.recoil_duration * 2.0, "set_shooting", false)
    _parent.tween.start()
