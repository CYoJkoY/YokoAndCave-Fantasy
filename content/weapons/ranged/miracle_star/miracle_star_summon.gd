extends Node2D

const BEAM_SCENE: PackedScene = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/weapons/ranged/miracle_star/vfx/miracle_star_beam.tscn")
const STAR_GROUP: String = "fantasy_miracle_stars"
const ASCENT_DURATION: float = 2.25
const TARGET_RETRY: float = 0.16
const LASER_COOLDOWN_MULTIPLIER: float = 1.8
const MIN_LASER_INTERVAL: float = 0.25
const HOVER_HEIGHT: float = 175.0

var _weapon: Weapon
var _main: Node
var _zone_rect: Rect2
var _anchor: Vector2
var _age: float = 0.0
var _slot: int = 0
var _count: int = 1
var _cooldown: float = 0.2
var _charge: float = 0.0
var _charge_duration: float = 0.32
var _interval: float = 0.9
var _target: Enemy
var _last_target: Enemy

onready var _visual: Node2D = $Visual
onready var _beams: Array = [$Beam]
onready var _laser_hitbox: Hitbox = $LaserHitbox
onready var _shadow: Sprite = $Shadow


func initialize(weapon: Weapon, main: Node) -> void:
    _weapon = weapon
    _main = main


func _ready() -> void:
    set_as_toplevel(true)
    global_rotation = 0.0
    global_scale = Vector2.ONE
    _zone_rect = ZoneService.get_current_zone_rect()
    _anchor = _zone_rect.position + _zone_rect.size * Vector2(0.5, 0.34)
    global_position = _anchor
    add_to_group(STAR_GROUP)
    get_tree().call_group_flags(SceneTree.GROUP_CALL_DEFAULT, STAR_GROUP, "_update_slot")
    _laser_hitbox.from = _weapon
    _laser_hitbox.active = false
    _laser_hitbox.set_meta("fantasy_damage_color", Color("e9e1ff"))
    _laser_hitbox.connect("hit_something", self, "_on_laser_hit")
    WeaponService.fantasy_connect_hitbox_events(_laser_hitbox, _weapon)


func _exit_tree() -> void:
    remove_from_group(STAR_GROUP)
    get_tree().call_group_flags(SceneTree.GROUP_CALL_DEFAULT, STAR_GROUP, "_update_slot")


func _update_slot() -> void:
    var stars: Array = get_tree().get_nodes_in_group(STAR_GROUP)
    _slot = stars.find(self)
    _count = stars.size()
    var columns: int = int(min(_count, 6))
    var column: int = _slot % columns
    var row: int = _slot / columns
    _anchor = _zone_rect.position + _zone_rect.size * Vector2(0.5, 0.34)
    if columns > 1:
        var spread: float = min(_zone_rect.size.x * 0.64, float(columns - 1) * 250.0)
        _anchor.x += (float(column) / float(columns - 1) - 0.5) * spread
    _anchor.y += float(row) * min(130.0, _zone_rect.size.y * 0.10)
    if _age == 0.0:
        global_position = _anchor
    if _age < ASCENT_DURATION:
        _cooldown = 0.18 + float(_slot) * 0.13


func _physics_process(delta: float) -> void:
    var active: bool = (not _weapon.is_queued_for_deletion() and _weapon.is_physics_processing()
        and not _weapon._parent.dead and not _weapon._parent.cleaning_up and not _main._cleaning_up)
    visible = active
    _visual.set_active(active)
    if not active:
        _cancel_charge()
        for beam in _beams:
            beam.cancel()
        return

    _age += delta
    var ascent: float = clamp(_age / ASCENT_DURATION, 0.0, 1.0)
    var rise: float = ascent * ascent * (3.0 - 2.0 * ascent)
    var phase: float = float(_slot) * 1.7
    global_position = global_position.linear_interpolate(_anchor, 1.0 - exp(-delta * 2.5))
    var size: float = clamp(1.5 / sqrt(float(_count)), 0.50, 1.0)
    var sway := Vector2(sin(_age * 0.62 + phase) * 7.0, sin(_age * 1.1 + phase) * 5.0) * rise
    var height: float = lerp(14.0, HOVER_HEIGHT * size, rise)
    _visual.position = Vector2(0, -height) + sway
    _visual.scale = Vector2.ONE * size
    _visual.set_ascent(ascent)
    _shadow.position = Vector2(10.0 + sway.x * 0.3, 8.0)
    _shadow.scale = Vector2.ONE * size * lerp(0.66, 1.12, rise)
    _shadow.modulate.a = smoothstep(0.0, 0.12, ascent) * lerp(0.48, 0.29, rise) * (1.0 + sway.y * 0.008)
    if ascent < 1.0:
        return

    var can_attack: bool = not WeaponService.fantasy_cannot_attack_while_stationary(_weapon)
    if _weapon._parent._current_movement != Vector2.ZERO and not RunData.get_player_effect(Keys.can_attack_while_moving_hash, _weapon.player_index):
        can_attack = false
    if not can_attack:
        _cancel_charge()
        return

    if _charge > 0.0:
        if not _is_valid_target(_target):
            _cancel_charge()
            _cooldown = TARGET_RETRY
            return
        _charge -= delta
        _visual.aim_at(_target._hurtbox.global_position)
        _visual.set_charge(clamp(1.0 - _charge / _charge_duration, 0.0, 1.0))
        if _charge <= 0.0:
            var overrun: float = -_charge
            _fire()
            _cooldown -= overrun
        return

    _cooldown -= delta
    if _cooldown > 0.0:
        return
    _target = _choose_target()
    if _target == null:
        _cooldown = TARGET_RETRY
        return
    _interval = _get_laser_interval()
    _charge_duration = min(0.32, _interval * 0.35)
    _charge = max(0.0, _charge_duration + _cooldown)
    _cooldown = 0.0
    _visual.aim_at(_target._hurtbox.global_position)
    _visual.set_charge(clamp(1.0 - _charge / _charge_duration, 0.0, 1.0))
    if _charge <= 0.0:
        _fire()


func _get_laser_interval() -> float:
    var interval: float = float(_weapon.stats.cooldown) / 60.0 * LASER_COOLDOWN_MULTIPLIER
    var attack_speed: float = (Utils.get_stat(Keys.stat_attack_speed_hash, _weapon.player_index) + _weapon.current_stats.attack_speed_mod) / 100.0
    if attack_speed < 0.0:
        interval *= 1.0 - attack_speed
    else:
        interval /= 1.0 + attack_speed
    return max(MIN_LASER_INTERVAL, interval)


func _is_valid_target(target) -> bool:
    return (is_instance_valid(target) and target is Enemy and not target.dead and not target._pending_die
        and not target.is_queued_for_deletion() and not target._hurtbox.is_disabled()
        and not WeaponService.fantasy_should_ignore_tree_body(_weapon, target))


func _choose_target() -> Enemy:
    var selected: Enemy = null
    var count: int = 0
    for enemy in _main._entity_spawner.get_all_enemies(false):
        if not _is_valid_target(enemy) or enemy == _last_target:
            continue
        count += 1
        if Utils.randi_range(1, count) == 1:
            selected = enemy
    if selected == null and _is_valid_target(_last_target):
        selected = _last_target
    return selected


func _fire() -> void:
    var target_position: Vector2 = _target._hurtbox.global_position
    var current: WeaponStats = _weapon.current_stats
    _laser_hitbox.set_damage(current.damage, Hitbox.HitboxArgs.new().set_from_weapon_stats(current))
    _laser_hitbox.effect_scale = current.effect_scale
    _laser_hitbox.speed_percent_modifier = current.speed_percent_modifier
    _laser_hitbox.effects = _weapon.effects
    _laser_hitbox.projectiles_on_hit = _weapon._hitbox.projectiles_on_hit
    _laser_hitbox.damage_tracking_key_hash = _weapon._hitbox.damage_tracking_key_hash
    _laser_hitbox.player_attack_id = _weapon._shooting_behavior._get_next_attack_id()
    _laser_hitbox.ignored_objects.clear()
    _laser_hitbox.global_position = target_position
    _laser_hitbox.set_knockback((target_position - _visual.global_position).normalized(), current.knockback, current.knockback_piercing)
    _play_beam(target_position)
    _visual.flash()
    _last_target = _target
    _cooldown = _interval - _charge_duration
    _laser_hitbox.active = true
    _target.hurt_area_entered_deferred(_laser_hitbox)
    _laser_hitbox.active = false
    _target = null


func _play_beam(target_position: Vector2) -> void:
    for beam in _beams:
        if not beam.is_processing():
            beam.fire(_visual.get_emitter(), target_position)
            return
    var new_beam: Node2D = BEAM_SCENE.instance()
    add_child(new_beam)
    _beams.append(new_beam)
    new_beam.fire(_visual.get_emitter(), target_position)


func _on_laser_hit(target: Node, damage_dealt: int) -> void:
    RunData.manage_life_steal(_weapon.current_stats, _weapon.player_index)
    _laser_hitbox.ignored_objects.append(target)
    _weapon.on_weapon_hit_something(target, damage_dealt, _laser_hitbox)


func _cancel_charge() -> void:
    _charge = 0.0
    _target = null
    _visual.set_charge(0.0)
