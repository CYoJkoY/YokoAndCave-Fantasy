extends Reference

const SET_ID = "set_fantasy_unique"

static func is_unique(item: Resource) -> bool:
    if !(item is WeaponData): return false
    for weapon_set in item.sets:
        if weapon_set.my_id == SET_ID: return true
    return false

static func get_owned_unique_weapon(weapon: WeaponData, owned_weapons: Array) -> WeaponData:
    if !is_unique(weapon): return null
    for owned in owned_weapons:
        if owned.weapon_id == weapon.weapon_id: return owned
    return null

static func chance(wave: int, luck_bonus: float = 0.0) -> float:
    if wave < 6: return 0.0
    var growth: float = (wave - 6) * 0.003
    growth = growth * (1.0 + luck_bonus) if luck_bonus >= 0 else growth / (1.0 + abs(luck_bonus))
    return min(growth, 0.10)

static func prefer_sets(candidates: Array, player_sets: Array) -> Array:
    var matching: Array = []
    for weapon in candidates:
        for weapon_set in weapon.sets:
            if weapon_set.my_id == SET_ID: continue
            if weapon_set.my_id_hash in player_sets:
                matching.append(weapon)
                break
    return candidates if matching.empty() else matching
