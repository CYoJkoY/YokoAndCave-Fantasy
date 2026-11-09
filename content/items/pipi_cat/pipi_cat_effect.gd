class_name PipiCatEffect
extends PetEffect

# The blow travels this fraction of the map's shorter edge when blow_strength
# equals BLOW_STRENGTH_REFERENCE. Scaling blow_strength scales the distance
# linearly, so extra stats can be attached to it later without touching the
# description.
const BLOW_DISTANCE_MAP_FRACTION: float = 0.5
const BLOW_STRENGTH_REFERENCE: float = 2.4
export(float) var stun_duration: float = 1.0
export(float) var stun_elemental_scaling: float = 0.02

static func get_id() -> String:
    return "fantasy_pipi_cat"

func get_stun_duration(player_index: int) -> float:
    return max(0.0, stun_duration + stun_elemental_scaling * Utils.get_stat(Keys.stat_elemental_damage_hash, player_index))

export(float) var charge_duration: float = 2.0
export(float) var cooldown_duration: float = 5.0
export(float) var blow_radius: float = 260.0
export(float) var blow_strength: float = 2.4

export(Array, Array) var charge_scaling_stats: Array = [["stat_elemental_damage", 0.06]]
export(Array, Array) var cooldown_scaling_stats: Array = [["stat_elemental_damage", -0.03]]

# ══════════════════════════════════════════ Extension ══════════════════════════════════════════ #
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

func get_blow_distance_fraction() -> float:
    return BLOW_DISTANCE_MAP_FRACTION * blow_strength / BLOW_STRENGTH_REFERENCE

func get_args(_player_index: int) -> Array:
    return [
        "%.1f" % charge_duration,
        WeaponService.get_scaling_stats_icon_text(charge_scaling_stats),
        str(blow_radius),
        "%.1f" % cooldown_duration,
        WeaponService.get_scaling_stats_icon_text(cooldown_scaling_stats),
        str(int(round(get_blow_distance_fraction() * 100.0))),
        str(stun_duration),
        WeaponService.get_scaling_stats_icon_text([[Keys.stat_elemental_damage_hash, stun_elemental_scaling]])
    ]

func serialize() -> Dictionary:
    var serialized: Dictionary = .serialize()
    serialized.charge_duration = charge_duration
    serialized.cooldown_duration = cooldown_duration
    serialized.blow_radius = blow_radius
    serialized.blow_strength = blow_strength
    serialized.stun_duration = stun_duration
    serialized.stun_elemental_scaling = stun_elemental_scaling
    serialized.charge_scaling_stats = charge_scaling_stats
    serialized.cooldown_scaling_stats = cooldown_scaling_stats
    return serialized

func deserialize_and_merge(serialized: Dictionary) -> void:
    .deserialize_and_merge(serialized)
    charge_duration = serialized.charge_duration
    cooldown_duration = serialized.cooldown_duration
    blow_radius = serialized.blow_radius
    blow_strength = serialized.blow_strength
    stun_duration = serialized.get("stun_duration", 1.0)
    stun_elemental_scaling = serialized.get("stun_elemental_scaling", 0.02)
    charge_scaling_stats = Utils.convert_to_hash_array(serialized.charge_scaling_stats)
    cooldown_scaling_stats = Utils.convert_to_hash_array(serialized.cooldown_scaling_stats)
