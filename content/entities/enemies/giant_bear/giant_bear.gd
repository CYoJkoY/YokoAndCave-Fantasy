extends Enemy

const STAND_SPRITE = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/entities/enemies/giant_bear/giant_bear_stand.webp")
const STAND_FOUR_SPRITE = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/entities/enemies/giant_bear/giant_bear_stand_four.webp")

onready var _charging_shoot_attack_behavior: ShootingAttackBehavior = $"ChargingShootAttackBehavior"
onready var COOLDOWN: float = _charging_shoot_attack_behavior.cooldown
var current_projectiles_cooldown: float = 0.0
var _charge_shots_remaining: int = 0

# ══════════════════════════════════════════ Extension ══════════════════════════════════════════ #
func get_damage_value(dmg_value: int, from_player_index: int, armor_applied := true, dodgeable := true, is_crit := false, hitbox: Hitbox = null, is_burning := false) -> GetDamageValueResult:
    var result: GetDamageValueResult = .get_damage_value(dmg_value, from_player_index, armor_applied, dodgeable, is_crit, hitbox, is_burning)
    if _move_locked and result.value > 0:
        result.value = max(1, int(result.value * 0.5))
    return result

func respawn() -> void:
    .respawn()
    current_projectiles_cooldown = 0.0
    _charge_shots_remaining = 0

func _ready() -> void:
    _charging_shoot_attack_behavior.init(self )
    
    register_attack_behavior(_charging_shoot_attack_behavior)

func shoot() -> void:
    .shoot()
    current_projectiles_cooldown = 0.0
    _charge_shots_remaining = 2

func _physics_process(delta: float) -> void:
    if dead: return

    if _move_locked and _charge_shots_remaining > 0:
        current_projectiles_cooldown -= Utils.physics_one(delta)
        if current_projectiles_cooldown <= 0.0:
            current_projectiles_cooldown += COOLDOWN
            _charge_shots_remaining -= 1
            _charging_shoot_attack_behavior.shoot()
            sprite.texture = STAND_SPRITE
            _collision.position.y = 10
            _hurtbox.position.y = 11
            _hitbox.position.y = 26

    if _animation_player.current_animation == "idle" and !_move_locked:
        sprite.texture = STAND_FOUR_SPRITE
        _collision.position.y = -17
        _hurtbox.position.y = -16
        _hitbox.position.y = -1
