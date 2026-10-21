extends "res://overlap/hitbox.gd"

const VISUAL: PackedScene = preload("res://mods-unpacked/Yoko-Fantasy/content/weapons/melee/silver_cross/vfx/silver_cross_holy_light.tscn")
const STRIKE_DELAY: float = 0.05

var _target: Enemy
var _main: Node
var _visual: Node2D
var _elapsed: float = 0.0


func _ready() -> void:
    set_physics_process(false)


func start(weapon: Weapon, target: Enemy, main: Node, holy_effect: Resource) -> void:
    from = weapon
    _target = target
    _main = main
    var args = Hitbox.HitboxArgs.new()
    args.scaling_stats = holy_effect.get_scaling_stats()
    args.accuracy = 1.0
    args.crit_chance = weapon.current_stats.crit_chance
    args.crit_damage = weapon.current_stats.crit_damage
    set_damage(holy_effect.get_damage(weapon.player_index), args)
    damage_tracking_key_hash = weapon._hitbox.damage_tracking_key_hash
    player_attack_id = weapon._hitbox.player_attack_id
    set_meta("fantasy_damage_color", Color("fff0b8"))
    connect("hit_something", weapon, "on_weapon_hit_something", [self])
    connect("killed_something", weapon, "on_killed_something", [self])
    connect("critically_hit_something", weapon, "_on_weapon_critically_hit_something")
    connect("one_shot_something", weapon, "on_one_shot_something")
    connect("added_gold_on_crit", weapon, "on_added_gold_on_crit")
    var pool_id: int = VISUAL.get_instance_id()
    _visual = main.get_node_from_pool(pool_id, main._effects)
    if not is_instance_valid(_visual):
        _visual = VISUAL.instance()
        main._effects.add_child(_visual)
    _visual.set_pool_id(pool_id)
    _visual.start_strike(target.global_position, target, 1.0, Color.white)
    set_physics_process(true)


func _physics_process(delta: float) -> void:
    if not is_instance_valid(from) or from.is_queued_for_deletion() or not from.is_physics_processing() \
        or from._parent.dead or from._parent.cleaning_up or not is_instance_valid(_main) or _main._cleaning_up:
        _finish()
        return
    if not from.is_valid_holy_target(_target):
        _finish()
        return
    _elapsed += delta
    _visual.global_position = _target.global_position
    if _elapsed >= STRIKE_DELAY:
        _target.hurt_area_entered_deferred(self)
        _finish()


func _finish() -> void:
    active = false
    set_physics_process(false)
    queue_free()
