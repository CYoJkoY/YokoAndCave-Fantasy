class_name PipiCatEffect
extends PetEffect

export(float) var charge_duration: float = 2.0
export(float) var cooldown_duration: float = 5.0
export(float) var blow_radius: float = 260.0
export(float) var blow_strength: float = 2.4

export(Array, Array) var charge_scaling_stats: Array = [["stat_elemental_damage", 0.06]]
export(Array, Array) var cooldown_scaling_stats: Array = [["stat_elemental_damage", -0.03]]

func duplicate(subresources: bool = false) -> Resource:
    var duplication = .duplicate(subresources)
    duplication.charge_scaling_stats = Utils.convert_to_hash_array(charge_scaling_stats)
    duplication.cooldown_scaling_stats = Utils.convert_to_hash_array(cooldown_scaling_stats)
    return duplication

func _generate_hashes() -> void:
    ._generate_hashes()
    charge_scaling_stats = Utils.convert_to_hash_array(charge_scaling_stats)
    cooldown_scaling_stats = Utils.convert_to_hash_array(cooldown_scaling_stats)

func _get_duration_scaling(scaling_stats: Array, player_index: int) -> float:
    var scaling: float = 0.0
    for stat in scaling_stats:
        scaling += stat[1] * Utils.get_stat(stat[0], player_index)
    return scaling

func get_charge_duration(player_index: int) -> float:
    var scaling: float = _get_duration_scaling(charge_scaling_stats, player_index)
    return charge_duration * (1.0 + scaling / 100.0)

func get_cooldown_duration(player_index: int) -> float:
    var scaling: float = _get_duration_scaling(cooldown_scaling_stats, player_index)
    return max(0.1, cooldown_duration * (1.0 + scaling / 100.0))

func get_args(_player_index: int) -> Array:
    return [
        "%.1f" % charge_duration,
        WeaponService.get_scaling_stats_icon_text(charge_scaling_stats),
        str(blow_radius),
        "%.1f" % cooldown_duration,
        WeaponService.get_scaling_stats_icon_text(cooldown_scaling_stats)
    ]

func serialize() -> Dictionary:
    var serialized: Dictionary = .serialize()
    serialized.charge_duration = charge_duration
    serialized.cooldown_duration = cooldown_duration
    serialized.blow_radius = blow_radius
    serialized.blow_strength = blow_strength
    serialized.charge_scaling_stats = charge_scaling_stats
    serialized.cooldown_scaling_stats = cooldown_scaling_stats
    return serialized

func deserialize_and_merge(serialized: Dictionary) -> void:
    .deserialize_and_merge(serialized)
    charge_duration = serialized.get("charge_duration", charge_duration)
    cooldown_duration = serialized.get("cooldown_duration", cooldown_duration)
    blow_radius = serialized.get("blow_radius", blow_radius)
    blow_strength = serialized.get("blow_strength", blow_strength)
    charge_scaling_stats = Utils.convert_to_hash_array(serialized.get("charge_scaling_stats", charge_scaling_stats))
    cooldown_scaling_stats = Utils.convert_to_hash_array(serialized.get("cooldown_scaling_stats", cooldown_scaling_stats))
