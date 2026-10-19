extends NullEffect

const TRAIL_LIFETIME: float = 2.0
const TICKS_PER_SECOND: int = 3

export (float) var holy_scaling: float = 2.5


static func get_id() -> String:
    return "fantasy_longinus"


func get_damage(player_index: int) -> int:
    return Utils.ncl_get_dmg_with_scaling_stats(value, [[Utils.stat_fantasy_holy_hash, holy_scaling]], player_index)


func get_args(player_index: int) -> Array:
    return [Utils.ncl_get_dmg_text_with_scaling_stats(
        value, [[Utils.stat_fantasy_holy_hash, holy_scaling]], {"player_index": player_index}
    ), str(TRAIL_LIFETIME), str(TICKS_PER_SECOND)]


func serialize() -> Dictionary:
    var serialized: Dictionary = .serialize()
    serialized.holy_scaling = holy_scaling
    return serialized


func deserialize_and_merge(serialized: Dictionary) -> void:
    .deserialize_and_merge(serialized)
    holy_scaling = serialized.holy_scaling
