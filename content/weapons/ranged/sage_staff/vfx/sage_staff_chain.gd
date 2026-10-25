extends "res://mods-unpacked/Yoko-Fantasy/content/weapons/shared/star_chain_visual.gd"

const ART = preload("res://mods-unpacked/Yoko-Fantasy/content/weapons/ranged/sage_staff/vfx/sage_staff_art.gd")
const EFFECT = preload("res://mods-unpacked/Yoko-Fantasy/content/weapons/ranged/sage_staff/sage_staff_effect.gd")
const LINK_COUNT: int = EFFECT.CHAIN_COUNT

onready var _hitbox: Hitbox = $Hitbox

var _weapon: Weapon
var _main: Node
var _stats: RangedWeaponStats
var _targets: Array = []
var _points: PoolVector2Array = PoolVector2Array()
var _next_hit: int = 0


func _ready() -> void:
    set_as_toplevel(true)
    global_transform = Transform2D.IDENTITY


func start(source, first_target: Enemy) -> void:
    _weapon = source._hitbox.from
    _main = source._main
    _stats = source._weapon_stats
    _hitbox.from = _weapon
    _hitbox.set_damage(source._hitbox.damage, Hitbox.HitboxArgs.new().set_from_weapon_stats(_stats))
    _hitbox.effect_scale = source._hitbox.effect_scale
    _hitbox.speed_percent_modifier = source._hitbox.speed_percent_modifier
    _hitbox.damage_tracking_key_hash = source._hitbox.damage_tracking_key_hash
    _hitbox.player_attack_id = source._hitbox.player_attack_id
    for effect in source._hitbox.effects:
        _hitbox.effects.append(effect.duplicate())
    _hitbox.projectiles_on_hit = source._hitbox.projectiles_on_hit.duplicate()
    _hitbox.ignored_objects = source._hitbox.ignored_objects.duplicate()
    _hitbox.ignored_objects.append(first_target)
    _hitbox.set_meta("fantasy_damage_color", ART.COLORS[EFFECT.Element.THUNDER])
    _hitbox.connect("hit_something", self, "_on_hit")
    _hitbox.connect("killed_something", _weapon, "on_killed_something", [_hitbox])
    _hitbox.connect("critically_hit_something", _weapon, "_on_weapon_critically_hit_something")
    _hitbox.connect("one_shot_something", _weapon, "on_one_shot_something")
    _hitbox.connect("added_gold_on_crit", _weapon, "on_added_gold_on_crit")
    var previous: Vector2 = first_target._hurtbox.global_position
    _points.append(previous)
    for _i in range(LINK_COUNT):
        var nearest: Enemy = null
        var distance_squared: float = float(_stats.max_range) * float(_stats.max_range)
        for enemy in source._target_index.candidates(_main, previous, _stats.max_range):
            if not _valid_target(enemy) or _targets.has(enemy) or _hitbox.ignored_objects.has(enemy):
                continue
            var distance: float = previous.distance_squared_to(enemy._hurtbox.global_position)
            if distance < distance_squared:
                nearest = enemy
                distance_squared = distance
        if nearest == null:
            break
        _targets.append(nearest)
        previous = nearest._hurtbox.global_position
        _points.append(previous)
    if _targets.empty():
        queue_free()
    modulate.a = ProgressData.settings.explosion_opacity


func _valid_target(target: Node) -> bool:
    return is_instance_valid(target) and target is Enemy and not target.dead and not target._pending_die \
        and not WeaponService.fantasy_should_ignore_tree_body(_weapon, target)


func _physics_process(delta: float) -> void:
    if not is_instance_valid(_weapon) or _weapon.is_queued_for_deletion() or _weapon._parent.dead \
        or _weapon._parent.cleaning_up or _main._cleaning_up:
        _hitbox.active = false
        queue_free()
        return
    _age += delta
    for i in range(_next_hit, _targets.size()):
        if _valid_target(_targets[i]):
            _points[i + 1] = _targets[i]._hurtbox.global_position
    while _next_hit < _targets.size() and _age >= FIRST_HIT + _next_hit * LINK_INTERVAL:
        var target: Node = _targets[_next_hit]
        var previous: Vector2 = _points[_next_hit]
        _next_hit += 1
        if not _valid_target(target):
            continue
        _hitbox.global_position = target._hurtbox.global_position
        _hitbox.set_knockback(previous.direction_to(_hitbox.global_position), _stats.knockback, _stats.knockback_piercing)
        target.hurt_area_entered_deferred(_hitbox)
    if _age >= FIRST_HIT + max(0, _targets.size() - 1) * LINK_INTERVAL + FADE_DURATION:
        _hitbox.active = false
        queue_free()
        return
    update()


func _on_hit(target: Node, damage: int) -> void:
    _hitbox.ignored_objects.append(target)
    RunData.manage_life_steal(_stats, _weapon.player_index)
    _weapon.on_weapon_hit_something(target, damage, _hitbox)


func _draw() -> void:
    _draw_chain(_points)
