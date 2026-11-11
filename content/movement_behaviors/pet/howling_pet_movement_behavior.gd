extends "res://mods-unpacked/YokoAndCave-Fantasy/content/movement_behaviors/pet/floating_pet_movement_behavior.gd"

# Howling-pet branch: inherits the shared wander around the owner and adds the
# tremor that accompanies the howl. Gameplay state changes and species-specific
# hover rhythms belong to the pet or its more specialized movement behavior.

export(float) var howl_shake_amplitude: float = 1.6
export(float) var howl_shake_speed: float = 34.0


func _get_hover_jitter() -> Vector2:
    if not _is_howling():
        return Vector2.ZERO
    return Vector2(
        sin(_motion_time * howl_shake_speed),
        cos(_motion_time * howl_shake_speed * 1.37)
    ) * howl_shake_amplitude


func _is_howling() -> bool:
    return _parent.is_charging() or _parent.is_blowing()
