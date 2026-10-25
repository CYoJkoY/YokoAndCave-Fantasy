extends "res://mods-unpacked/Yoko-Fantasy/content/weapons/shared/star_chain_visual.gd"

const TARGET_INDEX = preload("res://mods-unpacked/Yoko-Fantasy/content/utils/projectile_target_index.gd")
const CROSS_HIT_DELAY: float = 0.07

onready var _hitbox: Hitbox = $Hitbox
onready var _cross: Node2D = $Cross
onready var _main_cut: Sprite = $Cross/MainCut
onready var _echo_cut: Sprite = $Cross/EchoCut

var _weapon: Weapon
var _main: Node
var _chain: bool = false
var _targets: Array = []
var _points: PoolVector2Array = PoolVector2Array()
var _next_hit: int = 0
var _lifetime: float = 0.44
var _cross_hit: bool = false


func _ready() -> void:
    set_as_toplevel(true)
    global_transform = Transform2D.IDENTITY
    set_physics_process(false)


func _configure(weapon: Weapon, main: Node) -> void:
    _weapon = weapon
    _main = main
    _hitbox.from = weapon
    _hitbox.set_damage(weapon.current_stats.damage, Hitbox.HitboxArgs.new().set_from_weapon_stats(weapon.current_stats))
    _hitbox.effects = weapon.effects
    _hitbox.effect_scale = weapon.current_stats.effect_scale
    _hitbox.damage_tracking_key_hash = weapon._hitbox.damage_tracking_key_hash
    _hitbox.player_attack_id = weapon._hitbox.player_attack_id
    _hitbox.set_meta("fantasy_damage_color", Color("8cdeff"))
    _hitbox.connect("hit_something", self, "_on_hit")
    _hitbox.connect("killed_something", weapon, "on_killed_something", [_hitbox])
    _hitbox.connect("critically_hit_something", weapon, "_on_weapon_critically_hit_something")
    _hitbox.connect("one_shot_something", weapon, "on_one_shot_something")
    _hitbox.connect("added_gold_on_crit", weapon, "on_added_gold_on_crit")
    set_physics_process(true)


func start_cross(weapon: Weapon, main: Node, center: Vector2) -> void:
    _configure(weapon, main)
    global_position = center
    global_rotation = rand_range(0.0, TAU)
    _points.append(Vector2.ZERO)
    _cross.scale = Vector2.ONE * float(weapon._star_effect.CROSS_RADIUS) / 96.0
    _cross.visible = true


func start_chain(weapon: Weapon, main: Node, targets: Array, effect: Resource) -> void:
    _configure(weapon, main)
    _chain = true
    _targets = targets
    _points.append(weapon.muzzle.global_position)
    for target in targets:
        _points.append(target._hurtbox.global_position)
    _hitbox.damage = effect.get_damage(weapon.player_index)
    _hitbox.scaling_stats = effect.get_scaling_stats()
    _lifetime = FIRST_HIT + max(0, targets.size() - 1) * LINK_INTERVAL + FADE_DURATION


func _physics_process(delta: float) -> void:
    if not is_instance_valid(_weapon) or _weapon.is_queued_for_deletion() or _weapon._parent.dead \
        or _weapon._parent.cleaning_up or not is_instance_valid(_main) or _main._cleaning_up:
        queue_free()
        return
    _age += delta
    if _chain:
        for i in range(_next_hit, _targets.size()):
            if _weapon.is_valid_star_target(_targets[i]):
                _points[i + 1] = _targets[i]._hurtbox.global_position
        while _next_hit < _targets.size() and _age >= FIRST_HIT + _next_hit * LINK_INTERVAL:
            var target = _targets[_next_hit]
            _next_hit += 1
            if _weapon.is_valid_star_target(target):
                _hitbox.global_position = target._hurtbox.global_position
                target.hurt_area_entered_deferred(_hitbox)
    else:
        if not _cross_hit and _age >= CROSS_HIT_DELAY:
            _cross_hit = true
            _hit_cross_area()
        _main_cut.material.set_shader_param("age", _age)
        _echo_cut.material.set_shader_param("age", _age)
    modulate.a = ProgressData.settings.explosion_opacity
    update()
    if _age >= _lifetime:
        _hitbox.active = false
        queue_free()


func _hit_cross_area() -> void:
    var radius: float = _weapon._star_effect.CROSS_RADIUS
    var target_index = _main.get_meta(TARGET_INDEX.META_KEY) if _main.has_meta(TARGET_INDEX.META_KEY) else null
    if target_index == null:
        target_index = TARGET_INDEX.new()
        _main.set_meta(TARGET_INDEX.META_KEY, target_index)
    for enemy in target_index.candidates(_main, global_position, radius):
        if not _weapon.is_valid_star_target(enemy):
            continue
        if global_position.distance_squared_to(enemy._hurtbox.global_position) <= radius * radius:
            _hitbox.set_knockback((enemy.global_position - global_position).normalized(), _weapon.current_stats.knockback, _weapon.current_stats.knockback_piercing)
            enemy.hurt_area_entered_deferred(_hitbox)


func _on_hit(target: Node, damage: int) -> void:
    _hitbox.ignored_objects.append(target)
    RunData.manage_life_steal(_weapon.current_stats, _weapon.player_index)
    _weapon.on_weapon_hit_something(target, damage, _hitbox)


func _draw() -> void:
    if _points.empty():
        return
    if _chain:
        _draw_chain(_points)
    else:
        draw_set_transform(Vector2.ZERO, 0.0, _cross.scale)
        var flash: float = (1.0 - exp(-_age * 45.0)) * exp(-_age * 16.0)
        _draw_star(Vector2.ZERO, 34.0 + _age * 60.0, flash)
        _draw_cross_sparks()
        draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_cross_sparks() -> void:
    var age: float = max(0.0, _age - CROSS_HIT_DELAY)
    var fade: float = (1.0 - exp(-age * 70.0)) * pow(max(0.0, 1.0 - age / 0.26), 2.0)
    if fade <= 0.0:
        return
    var travel: float = 1.0 - exp(-age * 12.0)
    for i in range(6):
        var stroke: int = i / 3
        var lane: int = i % 3
        var direction: Vector2 = Vector2.RIGHT.rotated(stroke * PI * 0.5)
        var point: Vector2 = direction * (24.0 + travel * (44.0 + lane * 12.0))
        point += direction.tangent() * (lane - 1) * (5.0 + travel * 4.0)
        var tail: Vector2 = point - direction * (6.0 + fade * 12.0)
        _draw_beam(tail, point, 5.0 * fade, Color(0.15, 0.58, 1.0, fade * 0.55))
        _draw_beam(tail.linear_interpolate(point, 0.3), point, 1.5, Color(0.65, 0.95, 1.0, fade))
        _draw_star(point, 5.0 + fade * 3.0, fade * 0.7)
