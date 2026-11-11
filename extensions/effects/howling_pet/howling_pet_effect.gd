extends PetEffect

# Shared effect for howling pets: timings, blow range and distance, and the
# damage dealt when a launched enemy collides with another enemy.
# Seconds the launched enemy stays stunned after landing.
export(float) var stun_duration: float = 1.0
# Seconds the pet spends charging before it blows.
export(float) var charge_duration: float = 2.0
# Seconds the pet rests after blowing.
export(float) var cooldown_duration: float = 5.0
# Radius in pixels that starts the charge.
export(float) var blow_radius: float = 260.0
# Blow distance as a multiple of the shorter map edge.
export(float) var blow_distance_map_ratio: float = 0.5
# Percentage of the launched enemy's current health dealt to each enemy it hits.
export(float) var impact_damage_percent: float = 20.0
# Elites and bosses both inherit boss.gd, so this applies to either one.
export(float) var boss_impact_damage_percent: float = 2.0

export(Array, Array) var stun_scaling_stats: Array = [["stat_elemental_damage", 0.02]]
export(Array, Array) var charge_scaling_stats: Array = [["stat_elemental_damage", 0.06]]
export(Array, Array) var cooldown_scaling_stats: Array = [["stat_elemental_damage", -0.03]]

# Old saves stored the distance as fraction * strength, where strength was
# relative to this reference. It is only used to migrate those saves.
const LEGACY_BLOW_STRENGTH_REFERENCE: float = 2.4

# ══════════════════════════════════════════ Extension ══════════════════════════════════════════ #
func duplicate(subresources: bool = false) -> Resource:
    var duplication = .duplicate(subresources)
    # Keep the runtime hash arrays valid after the item curse flow duplicates
    # the effect, including when its deferred hash generation has not run yet.
    duplication.stun_scaling_stats = Utils.convert_to_hash_array(stun_scaling_stats)
    duplication.charge_scaling_stats = Utils.convert_to_hash_array(charge_scaling_stats)
    duplication.cooldown_scaling_stats = Utils.convert_to_hash_array(cooldown_scaling_stats)
    return duplication

func _generate_hashes() -> void:
    ._generate_hashes()
    stun_scaling_stats = Utils.convert_to_hash_array(stun_scaling_stats)
    charge_scaling_stats = Utils.convert_to_hash_array(charge_scaling_stats)
    cooldown_scaling_stats = Utils.convert_to_hash_array(cooldown_scaling_stats)

static func get_id() -> String:
    # Stable serialized ID for the Pipi Cat item. Renaming it would invalidate
    # existing saves, so a new howling pet must subclass this effect and
    # override this method with its own unique ID.
    return "fantasy_pipi_cat"

func get_args(_player_index: int) -> Array:
    return [
        _get_duration_text(get_charge_duration(_player_index), charge_scaling_stats),
        str(blow_radius),
        str(int(round(blow_distance_map_ratio * 100.0))),
        _get_duration_text(get_cooldown_duration(_player_index), cooldown_scaling_stats),
        _get_duration_text(get_stun_duration(_player_index), stun_scaling_stats),
        str(int(round(impact_damage_percent))),
        str(int(round(boss_impact_damage_percent)))
    ]

func serialize() -> Dictionary:
    var serialized: Dictionary = .serialize()
    serialized.charge_duration = charge_duration
    serialized.cooldown_duration = cooldown_duration
    serialized.blow_radius = blow_radius
    serialized.blow_distance_map_ratio = blow_distance_map_ratio
    serialized.impact_damage_percent = impact_damage_percent
    serialized.boss_impact_damage_percent = boss_impact_damage_percent
    serialized.stun_duration = stun_duration
    serialized.stun_scaling_stats = stun_scaling_stats
    serialized.charge_scaling_stats = charge_scaling_stats
    serialized.cooldown_scaling_stats = cooldown_scaling_stats
    return serialized

func deserialize_and_merge(serialized: Dictionary) -> void:
    .deserialize_and_merge(serialized)
    charge_duration = _get_serialized_float(serialized, "charge_duration", charge_duration)
    cooldown_duration = _get_serialized_float(serialized, "cooldown_duration", cooldown_duration)
    blow_radius = _get_serialized_float(serialized, "blow_radius", blow_radius)
    stun_duration = _get_serialized_float(serialized, "stun_duration", stun_duration)
    impact_damage_percent = _get_serialized_float(
        serialized,
        "impact_damage_percent",
        impact_damage_percent
    )
    boss_impact_damage_percent = _get_serialized_float(
        serialized,
        "boss_impact_damage_percent",
        boss_impact_damage_percent
    )

    if serialized.has("blow_distance_map_ratio"):
        blow_distance_map_ratio = _get_serialized_float(
            serialized,
            "blow_distance_map_ratio",
            blow_distance_map_ratio
        )
    else:
        # Old saves stored the distance as two multiplied factors.
        var old_fraction: float = _get_serialized_float(
            serialized,
            "blow_distance_map_fraction",
            0.5
        )
        var old_strength: float = _get_serialized_float(serialized, "blow_strength", 1.0)
        blow_distance_map_ratio = old_fraction * old_strength / LEGACY_BLOW_STRENGTH_REFERENCE

    if serialized.has("stun_scaling_stats"):
        stun_scaling_stats = Utils.convert_to_hash_array(serialized.stun_scaling_stats)
    if serialized.has("charge_scaling_stats"):
        charge_scaling_stats = Utils.convert_to_hash_array(serialized.charge_scaling_stats)
    if serialized.has("cooldown_scaling_stats"):
        cooldown_scaling_stats = Utils.convert_to_hash_array(serialized.cooldown_scaling_stats)

# ══════════════════════════════════════════ Custom ══════════════════════════════════════════ #
func get_stun_duration(player_index: int) -> float:
    return max(0.0, stun_duration + _get_duration_scaling(stun_scaling_stats, player_index))

func get_charge_duration(player_index: int) -> float:
    var scaling: float = _get_duration_scaling(charge_scaling_stats, player_index)
    return charge_duration * (1.0 + scaling / 100.0)

func get_cooldown_duration(player_index: int) -> float:
    var scaling: float = _get_duration_scaling(cooldown_scaling_stats, player_index)
    return max(0.1, cooldown_duration * (1.0 + scaling / 100.0))

func _get_duration_scaling(scaling_stats: Array, player_index: int) -> float:
    var scaling: float = 0.0
    for stat in scaling_stats:
        scaling += stat[1] * Utils.get_stat(stat[0], player_index)
    return scaling

func _get_duration_text(duration: float, scaling_stats: Array) -> String:
    return "%.1f (%s)" % [duration, WeaponService.get_scaling_stats_icon_text(scaling_stats)]

func _get_serialized_float(data: Dictionary, key: String, fallback: float) -> float:
    if not data.has(key):
        return fallback
    return float(data[key])
