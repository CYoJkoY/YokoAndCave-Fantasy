extends "res://weapons/melee/melee_weapon.gd"

const HOLY_STRIKE: PackedScene = preload("res://mods-unpacked/Yoko-Fantasy/content/weapons/melee/silver_cross/silver_cross_strike.tscn")

onready var _blade: Sprite = $Sprite/LightBlade
onready var _glow: Sprite = $Sprite/Glow
onready var _trail: Sprite = $Sweep
onready var _sparks: CPUParticles2D = $Sprite/Sparks
onready var _impact: Sprite = $Sprite/Impact

var _holy_effect: Resource
var _clock: float = 0.0
var _charge: float = 0.0
var _trail_fade: float = 0.0
var _impact_time: float = 0.0


func _ready() -> void:
    for effect in effects:
        if effect.get_id() == "weapon_silver_cross":
            _holy_effect = effect
            break
    assert(_holy_effect != null, "Silver cross holy light effect is missing")
    _trail.set_as_toplevel(true)
    update_sprite_flipv()


func get_direction() -> float:
    if _shooting_behavior.phase != _shooting_behavior.Phase.IDLE:
        return _shooting_behavior.attack_angle
    return .get_direction()


func update_sprite_flipv() -> void:
    if _shooting_behavior.phase != _shooting_behavior.Phase.IDLE:
        return
    var facing: float = 1.0 if Utils.is_facing_right(rotation_degrees) else -1.0
    sprite.flip_v = facing < 0.0
    sprite.offset = Vector2(65, -35 * facing)
    _hitbox.position = Vector2(67, 30 * facing)
    _blade.flip_v = facing > 0.0
    _glow.flip_v = _blade.flip_v
    _blade.offset = Vector2(65, 35 * facing)
    _glow.offset = _blade.offset
    _sparks.position.y = 30 * facing
    _impact.position.y = 30 * facing


func shoot() -> void:
    if _parent.dead or _parent.cleaning_up:
        _shooting_behavior.cancel_attack()
        return
    update_sprite_flipv()
    .shoot()


func _physics_process(delta: float) -> void:
    if _parent.dead or _parent.cleaning_up:
        _shooting_behavior.cancel_attack()
        _trail.visible = false
        _sparks.emitting = false
        _impact.visible = false
        _impact_time = 0.0
        _trail_fade = 0.0
        _blade.visible = false
        _glow.visible = false
        set_process(false)
        set_physics_process(false)
        return
    _shooting_behavior.advance(delta)


func _process(delta: float) -> void:
    _clock += delta
    _impact_time = max(0.0, _impact_time - delta)
    var flash: float = _impact_time / 0.10
    var opacity: float = ProgressData.settings.explosion_opacity
    _blade.material.set_shader_param("phase", _clock)
    _blade.material.set_shader_param("charge", max(_charge, flash))
    _blade.modulate.a = opacity
    _glow.modulate.a = (0.32 + _charge * 0.5 + flash * 0.18) * opacity
    _sparks.modulate.a = opacity
    _impact.visible = flash > 0.0
    _impact.modulate.a = flash * flash * opacity * 0.75
    _impact.scale = Vector2.ONE * (0.18 + (1.0 - flash) * 0.20)
    sprite.self_modulate = Color(1.0 + flash * 0.45, 1.0 + flash * 0.40, 1.0 + flash * 0.25)
    if _trail_fade > 0.0:
        _trail_fade = max(0.0, _trail_fade - delta)
        _trail.modulate.a = pow(_trail_fade / 0.14, 2.0) * opacity * 0.65
        _trail.visible = _trail_fade > 0.0


func prepare_swing(side: float, radius: float) -> void:
    _trail_fade = 0.0
    _trail.visible = false
    var extent: float = (radius + 125.0) * 90.0 / 70.0
    _trail.scale = Vector2.ONE * extent / 90.0
    _trail.material.set_shader_param("side", side)
    _trail.material.set_shader_param("progress", 0.0)


func begin_swing(center: Vector2) -> void:
    _trail.global_position = to_global(center)
    _trail.global_rotation = global_rotation
    _trail.visible = true
    _sparks.emitting = true


func update_swing(progress: float) -> void:
    _trail.material.set_shader_param("progress", progress)
    _trail.modulate.a = (0.42 + sin(progress * PI) * 0.30) * ProgressData.settings.explosion_opacity
    set_charge(0.65 + sin(progress * PI) * 0.35)


func end_swing() -> void:
    _trail_fade = 0.14
    _sparks.emitting = false


func set_charge(charge: float) -> void:
    _charge = charge


func disable_hitbox() -> void:
    _hitbox.active = false
    .disable_hitbox()


func on_weapon_hit_something(thing_hit: Node, damage_dealt: int, hitbox: Hitbox) -> void:
    .on_weapon_hit_something(thing_hit, damage_dealt, hitbox)
    if hitbox != _hitbox or not thing_hit is Enemy:
        return
    _impact_time = 0.10
    var main = Utils.get_scene_node()
    if not is_instance_valid(main) or main._cleaning_up or _parent.dead or _parent.cleaning_up:
        return
    var target: Enemy = _get_random_holy_target(main._entity_spawner.get_all_enemies(false))
    if target == null:
        return
    var strike = HOLY_STRIKE.instance()
    add_child(strike)
    strike.start(self, target, main, _holy_effect)


func _get_random_holy_target(enemies: Array) -> Enemy:
    if enemies.empty():
        return null
    var candidate = enemies[Utils.randi_range(0, enemies.size() - 1)]
    if is_valid_holy_target(candidate):
        return candidate
    var target: Enemy = null
    var count: int = 0
    for enemy in enemies:
        if not is_valid_holy_target(enemy):
            continue
        count += 1
        if Utils.randi_range(1, count) == 1:
            target = enemy
    return target


func is_valid_holy_target(target) -> bool:
    return is_instance_valid(target) and target is Enemy and not target.dead and not target._pending_die \
        and not target.is_queued_for_deletion() and not WeaponService.fantasy_should_ignore_tree_body(self, target)
