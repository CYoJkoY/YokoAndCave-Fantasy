class_name PipiCatEffect
extends PetEffect

export(float) var charge_duration: float = 2.0
export(float) var cooldown_duration: float = 5.0
export(float) var blow_radius: float = 260.0
export(float) var blow_strength: float = 2.4

const CHARGE_ELEMENTAL_SCALING: float = 0.06
const COOLDOWN_ELEMENTAL_SCALING: float = 0.03

func get_charge_duration(player_index: int) -> float:
    var elemental_damage: float = Utils.get_stat(Keys.stat_elemental_damage_hash, player_index)
    return charge_duration * (1.0 + elemental_damage * CHARGE_ELEMENTAL_SCALING / 100.0)

func get_cooldown_duration(player_index: int) -> float:
    var elemental_damage: float = Utils.get_stat(Keys.stat_elemental_damage_hash, player_index)
    return max(0.1, cooldown_duration * (1.0 - elemental_damage * COOLDOWN_ELEMENTAL_SCALING / 100.0))

func get_args(player_index: int) -> Array:
    return [
        "%.1f" % charge_duration,
        str(int(CHARGE_ELEMENTAL_SCALING * 100.0)) + "%",
        str(blow_radius),
        "%.1f" % cooldown_duration,
        str(int(COOLDOWN_ELEMENTAL_SCALING * 100.0)) + "%"
    ]

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
