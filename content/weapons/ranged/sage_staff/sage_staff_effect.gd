extends NullEffect

enum Element { WATER, FIRE, EARTH, WIND, THUNDER, LIGHT }
enum Phase { SCATTER, HOVER, FLIGHT }

const BURNING_DATA = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/weapons/ranged/sage_staff/sage_staff_burning_data.tres")
const SCATTER_DURATION: float = 0.32
const HOVER_DURATION: float = 0.18
const EXPLOSION_BASE_RADIUS: float = 147.34
const EXPLOSION_MIN_SCALE: float = 0.1
const EMISSION_INTERVAL: float = 0.0625
const SLOW_PERCENT: int = 30
const EARTH_RADIUS: float = 60.0
const WIND_PIERCING: int = 3
const WIND_KNOCKBACK: int = 50
const CHAIN_COUNT: int = 4
const LIGHT_ATTACK_SPEED: int = 5


static func get_id() -> String:
    return "weapon_sage_staff"


func get_args(player_index: int) -> Array:
    var burn: BurningData = WeaponService.init_burning_data(BURNING_DATA, player_index)
    burn.duration = max(burn.duration, RunData.get_player_effect(Keys.burn_chance_hash, player_index).duration)
    var burning_text: String = Text.text("EFFECT_BURNING", [str(burn.duration), str(burn.damage),
        WeaponService.get_scaling_stats_icon_text(burn.scaling_stats)])
    var radius: float = max(EXPLOSION_BASE_RADIUS * EXPLOSION_MIN_SCALE, EARTH_RADIUS * (1.0 + Utils.get_stat(Keys.explosion_size_hash, player_index) / 100.0))
    return [str(EMISSION_INTERVAL), str(SLOW_PERCENT), burning_text,
        str(stepify(radius, 0.1)), str(WIND_PIERCING), str(WIND_KNOCKBACK), str(CHAIN_COUNT), str(LIGHT_ATTACK_SPEED)]
