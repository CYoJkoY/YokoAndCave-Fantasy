extends "res://mods-unpacked/YokoAndCave-Fantasy/content/weapons/shared/star_chain_visual.gd"

onready var _hitbox: Hitbox = $Hitbox

var _weapon: Weapon
var _main: Node
var _targets: Array = []
var _points: PoolVector2Array = PoolVector2Array()
var _next_hit: int = 0


func _ready() -> void:
    set_as_toplevel(true)
    global_transform = Transform2D.IDENTITY


func _source_is_active() -> bool:
    return is_instance_valid(_weapon) and not _weapon.is_queued_for_deletion() and _weapon.is_physics_processing() \
        and is_instance_valid(_weapon._parent) and not _weapon._parent.dead and not _weapon._parent.cleaning_up \
        and is_instance_valid(_main) and not _main._cleaning_up


func _advance_chain() -> void:
    for i in range(_next_hit, _targets.size()):
        if _valid_target(_targets[i]):
            _points[i + 1] = _targets[i]._hurtbox.global_position
    while _next_hit < _targets.size() and _age >= FIRST_HIT + _next_hit * LINK_INTERVAL:
        var target = _targets[_next_hit]
        var previous: Vector2 = _points[_next_hit]
        _next_hit += 1
        if _valid_target(target):
            _hit_chain_target(target, previous)
            if not _source_is_active():
                _finish_attack()
                return


func _hit_chain_target(target: Enemy, _previous: Vector2) -> void:
    _hitbox.global_position = target._hurtbox.global_position
    target.hurt_area_entered_deferred(_hitbox)


func _valid_target(target: Node) -> bool:
    return is_instance_valid(target) and target is Enemy and not target.dead and not target._pending_die \
        and not WeaponService.fantasy_should_ignore_tree_body(_weapon, target)


func _get_chain_lifetime() -> float:
    return FIRST_HIT + max(0, _targets.size() - 1) * LINK_INTERVAL + chain_hold_duration + FADE_DURATION


func _finish_attack() -> void:
    _hitbox.active = false
    set_physics_process(false)
    queue_free()
