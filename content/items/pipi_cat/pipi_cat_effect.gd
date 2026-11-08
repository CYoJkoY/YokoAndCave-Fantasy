class_name PipiCatEffect
extends PetEffect

export(float) var charge_duration: float = 1.5
export(float) var cooldown_duration: float = 5.0
export(float) var blow_radius: float = 260.0
export(float) var blow_strength: float = 2.4

func get_args(_player_index: int) -> Array:
    return [str(charge_duration), str(blow_radius), str(cooldown_duration)]

func serialize() -> Dictionary:
    var serialized: Dictionary = .serialize()
    serialized.charge_duration = charge_duration
    serialized.cooldown_duration = cooldown_duration
    serialized.blow_radius = blow_radius
    serialized.blow_strength = blow_strength
    return serialized

func deserialize_and_merge(serialized: Dictionary) -> void:
    .deserialize_and_merge(serialized)
    charge_duration = serialized.get("charge_duration", charge_duration)
    cooldown_duration = serialized.get("cooldown_duration", cooldown_duration)
    blow_radius = serialized.get("blow_radius", blow_radius)
    blow_strength = serialized.get("blow_strength", blow_strength)
