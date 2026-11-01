extends "res://mods-unpacked/YokoAndCave-Fantasy/content/weapons/ranged/shared/floating_spell_weapon.gd"

const ORB_SCENE = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/weapons/ranged/gospel/vfx/gospel_orb.tscn")
const ORBIT = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/weapons/ranged/gospel/gospel_orbit.gd")
const ORB_COUNT: int = 6
const RETARGET_INTERVAL: float = 0.04
const PASS_INTERVAL: float = 0.14
const MAX_APPROACHING: int = 2
const MAX_DEPLOYED: int = 4

var _orbs: Array = []
var _flights: Array = []
var _contacts: Array = []
var _ready_orbs: Array = []
var _next_flight: int = 0
var _retarget_timer: float = 0.0
var _pass_timer: float = 0.0
var _striking_orb: Node2D
var _striking_flight: Reference
var _strike_target: Node2D

onready var _book_light: Node2D = $Sprite/GospelLight


func _ready() -> void:
    for i in range(ORB_COUNT):
        var flight = ORBIT.new()
        flight.initialize(_parent.global_position, global_position, float(current_stats.max_range), i, ORB_COUNT, float(weapon_pos) * 0.37)
        var orb = ORB_SCENE.instance()
        add_child(orb)
        orb.initialize(flight.position, _parent.global_position,
            TAU * float(i) / ORB_COUNT, is_cursed)
        _orbs.append(orb)
        _flights.append(flight)
        _contacts.append(null)


func is_manual_aim() -> bool:
    return false


func get_direction() -> float:
    return 0.0


func get_direction_and_calculate_target() -> float:
    return 0.0


func update_sprite_flipv() -> void:
    sprite.flip_v = false


func update_current_spread() -> void:
    _current_shoot_spread = 0.0
    rotation = 0.0


func reset_cooldown() -> void:
    .reset_cooldown()
    var interval: float = current_stats.get_cooldown_value(player_index, 1.0)
    for flight in _flights:
        flight.cooldown = min(flight.cooldown, interval)


func fantasy_reset_attack_cooldown() -> void:
    for flight in _flights:
        flight.cooldown = 0.0


func should_shoot() -> bool:
    return false


func _physics_process(delta: float) -> void:
    var active: bool = not _parent.dead and not _parent.cleaning_up and not is_queued_for_deletion()
    _book_light.set_active(active)
    for orb in _orbs:
        orb.set_active(active)
    _ready_orbs.clear()
    for i in range(_contacts.size()):
        _contacts[i] = null
    if not active:
        for flight in _flights:
            flight.finish_pass()
        return

    var can_attack: bool = not WeaponService.fantasy_cannot_attack_while_stationary(self)
    if _parent._current_movement != Vector2.ZERO and not RunData.get_player_effect(Keys.can_attack_while_moving_hash, player_index):
        can_attack = false
    _advance_orbits(delta, can_attack)

    if can_attack:
        _find_contacts()
        for i in _ready_orbs:
            var target = _contacts[i]
            if not _is_valid_target(target):
                continue
            _striking_orb = _orbs[i]
            _striking_flight = _flights[i]
            _strike_target = target
            shoot()
            _striking_orb = null
            _striking_flight = null
            _strike_target = null
            if is_queued_for_deletion() or _parent.dead or _parent.cleaning_up:
                break
    for i in range(_orbs.size()):
        _orbs[i].attack_ready = _flights[i].cooldown <= 0.0


func _is_valid_target(target) -> bool:
    return (is_instance_valid(target) and target is Enemy and not target.dead
        and not target._pending_die and not target._hurtbox.is_disabled()
        and global_position.distance_squared_to(target.global_position) <= float(current_stats.max_range) * current_stats.max_range)


func _advance_orbits(delta: float, can_attack: bool) -> void:
    for flight in _flights:
        if flight.state == ORBIT.Flight.APPROACH and (not can_attack or not _is_valid_target(flight.target)):
            flight.finish_pass()
    _pass_timer = max(0.0, _pass_timer - delta)
    _retarget_timer = max(0.0, _retarget_timer - delta)
    if can_attack and _pass_timer <= 0.0 and _retarget_timer <= 0.0:
        _retarget_timer = RETARGET_INTERVAL
        _launch_pass()

    for i in range(_flights.size()):
        _flights[i].advance(delta, _parent.global_position, global_position, float(current_stats.max_range))
        _orbs[i].advance(delta, _flights[i].position, _parent.global_position)


func _launch_pass() -> void:
    if _targets_in_range.empty():
        return
    var assigned: Array = []
    var deployed: int = 0
    for flight in _flights:
        if flight.state != ORBIT.Flight.ORBIT:
            deployed += 1
        if flight.state == ORBIT.Flight.APPROACH:
            assigned.append(flight.target)
    if assigned.size() >= MAX_APPROACHING or deployed >= MAX_DEPLOYED:
        return

    var selected: int = -1
    var max_travel_time: float = float(current_stats.max_range) * 2.0 / ORBIT.ATTACK_SPEED + 0.06
    for offset in range(_flights.size()):
        var i: int = (_next_flight + offset) % _flights.size()
        if _flights[i].state == ORBIT.Flight.ORBIT and _flights[i].cooldown <= max_travel_time:
            selected = i
            break
    if selected < 0:
        return
    _next_flight = (selected + 1) % _flights.size()
    var flight = _flights[selected]
    var min_distance: float = 0.0
    if flight.cooldown > 0.06:
        min_distance = (flight.cooldown - 0.06) * ORBIT.ATTACK_SPEED + _orbs[selected].BODY_RADIUS
    var min_distance_squared: float = min_distance * min_distance
    var best_score: float = INF
    var best_target: Node2D = null
    for target in _targets_in_range:
        if not _is_valid_target(target):
            continue
        var score: float = flight.position.distance_squared_to(target.global_position)
        if score < min_distance_squared:
            continue
        if assigned.has(target):
            score *= 2.56
        if score < best_score:
            best_score = score
            best_target = target
    if best_target != null:
        flight.begin_pass(best_target)
        _pass_timer = PASS_INTERVAL


func _find_contacts() -> void:
    for i in range(_flights.size()):
        if _flights[i].cooldown <= 0.0:
            _ready_orbs.append(i)
    var remaining: int = _ready_orbs.size()
    if remaining == 0:
        return
    var orb_radius: float = _orbs[0].BODY_RADIUS
    for target in _targets_in_range:
        if not _is_valid_target(target):
            continue
        var collision: CollisionShape2D = target._hurtbox._collision
        var point: Vector2 = collision.global_position
        var collision_scale: Vector2 = collision.global_scale
        var radius: float = orb_radius + collision.shape.radius * max(abs(collision_scale.x), abs(collision_scale.y))
        var radius_squared: float = radius * radius
        for i in _ready_orbs:
            if _contacts[i] != null:
                continue
            if _flights[i].position.distance_squared_to(point) <= radius_squared:
                _contacts[i] = target
                remaining -= 1
        if remaining == 0:
            break


func strike_orb(attack_id: int) -> void:
    if not _is_valid_target(_strike_target):
        return
    var hitbox_args = Hitbox.HitboxArgs.new().set_from_weapon_stats(current_stats)
    _hitbox.set_damage(current_stats.damage, hitbox_args)
    _hitbox.effect_scale = current_stats.effect_scale
    _hitbox.speed_percent_modifier = current_stats.speed_percent_modifier
    _hitbox.player_attack_id = attack_id
    _hitbox.ignored_objects.clear()
    _hitbox.global_position = _striking_orb.global_position
    _hitbox.set_knockback((_strike_target.global_position - _parent.global_position).normalized(),
        current_stats.knockback, current_stats.knockback_piercing)
    _striking_flight.cooldown = current_stats.get_cooldown_value(player_index, 1.0)
    _hitbox.active = true
    _strike_target.hurt_area_entered_deferred(_hitbox)
    _hitbox.active = false


func _on_Hitbox_hit_something(thing_hit: Node, damage_dealt: int) -> void:
    _striking_orb.play_impact(thing_hit.global_position)
    _striking_flight.finish_pass()
    _book_light.play_pulse()
    RunData.manage_life_steal(current_stats, player_index)
    _hitbox.ignored_objects.append(thing_hit)
    on_weapon_hit_something(thing_hit, damage_dealt, _hitbox)
