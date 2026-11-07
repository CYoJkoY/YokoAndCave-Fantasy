extends "res://mods-unpacked/Yoko-NewContentLoader/NewContent.gd"

const BASE_CHANCE_DROP_SOUL: float = 0.007
const MAX_LUCK_BONUS: float = 1.5

export(Array, Resource) var jobs = []
export(Resource) var soul_data
export(Dictionary) var additional_starting_weapons = {}
export(Dictionary) var dlc_additional_starting_weapons = {}

var _starting_weapons_active: bool = false

# ══════════════════════════════════════════ Extension ══════════════════════════════════════════ #
func add_custom_resources() -> void:
    .add_custom_resources()
    for job in jobs: job._generate_hashes()
    add_if_not_null(ItemService.jobs, jobs)
    ItemService._fantasy_rebuild_jobs_by_stage()
    _starting_weapons_active = true

func remove_custom_resources() -> void:
    .remove_custom_resources()
    erase_if_not_null(ItemService.jobs, jobs)
    ItemService._fantasy_rebuild_jobs_by_stage()
    _starting_weapons_active = false

func roll_soul_drop() -> ConsumableData:
    var stat_holy: float = Utils.average_all_player_stats(Utils.stat_fantasy_holy_hash)
    var extra_chance_drop_soul: float = Utils.sum_all_player_stats(Utils.fantasy_base_chance_drop_soul_hash) / 100.0
    var luck: float = Utils.average_all_player_stats(Keys.stat_luck_hash)
    var chance_drop_soul_luck_bonus: float = min(MAX_LUCK_BONUS, 1 + luck / (200.0 if luck > 0 else 100.0))
    var chance_drop_soul_holy_bonus: float = 1.0 + 0.5 * stat_holy / (stat_holy + 60.0) if stat_holy > 0 else 0.0
    var chance_drop_soul: float = max(0.0, BASE_CHANCE_DROP_SOUL * chance_drop_soul_luck_bonus * chance_drop_soul_holy_bonus) + extra_chance_drop_soul
    if Utils.get_chance_success(clamp(chance_drop_soul, 0.0, 1.0)): return soul_data

    return null

# ══════════════════════════════════════════ Method ══════════════════════════════════════════ #
func get_additional_starting_weapons(character: CharacterData) -> Array:
    if !_starting_weapons_active: return []

    var result: Array = []
    var weapon_ids: Dictionary = {}
    for weapon in character.starting_weapons:
        weapon_ids[weapon.my_id] = true

    var candidates: Array = additional_starting_weapons.get(character.my_id, []) + dlc_additional_starting_weapons.get(character.my_id, [])
    for weapon in candidates:
        if weapon_ids.has(weapon.my_id) or !ItemService.weapons.has(weapon): continue
        weapon_ids[weapon.my_id] = true
        result.append(weapon)

    return result
