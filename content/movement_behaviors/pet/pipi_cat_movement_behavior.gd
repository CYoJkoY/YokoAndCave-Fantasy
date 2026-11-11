extends "res://mods-unpacked/YokoAndCave-Fantasy/content/movement_behaviors/pet/howling_pet_movement_behavior.gd"

# Pipi Cat specialization: the cat keeps the generic howling-pet wander and
# howl tremor, then adds its own state-driven hover rhythm and slower movement
# while winding up, blowing and resting. Height changes and the shadow response
# come from the shared floating layer.

export(float) var charge_speed_factor: float = 0.4
export(float) var blow_speed_factor: float = 0.7
export(float) var cooldown_speed_factor: float = 0.55

export(float) var howl_hover_amplitude_factor: float = 1.2
export(float) var howl_hover_speed_factor: float = 1.35
export(float) var cooldown_hover_amplitude_factor: float = 0.6
export(float) var cooldown_hover_speed_factor: float = 0.8


func _get_speed_factor() -> float:
    if _parent.is_charging():
        return charge_speed_factor
    if _parent.is_blowing():
        return blow_speed_factor
    if _parent.is_cooling_down():
        return cooldown_speed_factor
    return 1.0


func _get_hover_motion_factor() -> float:
    if _is_howling():
        return howl_hover_amplitude_factor
    if _parent.is_cooling_down():
        return cooldown_hover_amplitude_factor
    return 1.0


func _get_hover_speed() -> float:
    if _is_howling():
        return hover_speed * howl_hover_speed_factor
    if _parent.is_cooling_down():
        return hover_speed * cooldown_hover_speed_factor
    return hover_speed
