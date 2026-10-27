extends "res://mods-unpacked/Yoko-Fantasy/extensions/effects/lightning_chain_effect.gd"

# ══════════════════════════════════════════ Extension ══════════════════════════════════ #
func _init() -> void:
    base_chance = 1.0
    damage_scaling_stats = [["stat_elemental_damage", 0.8]]
    base_chain_targets = 4
    targets_scaling_stats = [["stat_elemental_damage", 0.02]]

static func get_id() -> String:
    return "fantasy_lightning_chain_on_death"
