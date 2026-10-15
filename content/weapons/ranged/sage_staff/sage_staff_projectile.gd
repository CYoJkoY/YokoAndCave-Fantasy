extends "res://projectiles/player_projectile.gd"

const TARGET_INDEX = preload("res://mods-unpacked/Yoko-Fantasy/content/utils/projectile_target_index.gd")
const EXPLOSION_SCENE: PackedScene = preload("res://projectiles/explosion.tscn")

enum Element { WATER, FIRE, EARTH, WIND, THUNDER, LIGHT }
enum Phase { SCATTER, HOVER, FLIGHT }

const COLORS: Array = [Color("58bfff"), Color("ff654d"), Color("e9a14f"), Color("70edba"), Color("bd83ff"), Color("fff18a")]
const SCATTER_DURATION: float = 0.32
const HOVER_DURATION: float = 0.18
const MAX_TARGET_WAIT: float = 0.7
const TARGET_RETRY: float = 0.1

var _element: int = Element.WATER
var _phase: int = Phase.SCATTER
var _alive: bool = false
var _elapsed: float = 0.0
var _retry: float = 0.0
var _scatter_direction: Vector2
var _scatter_distance: float = 0.0
var _last_position: Vector2
var _flight_speed: float = 0.0
var _light_triggered: bool = false
var _main: Node
var _target_index: Reference
var _earth_explosion: ExplodingEffect = ExplodingEffect.new()


func _ready() -> void:
    _earth_explosion.explosion_scene = EXPLOSION_SCENE
    _earth_explosion.scale = 60.0 / 147.34
    _earth_explosion.base_smoke_amount = 4
    _earth_explosion.sound_db_mod = -22


func shoot_ex(p_from: Node, pos: Vector2, p_velocity: Vector2, p_rotation: float,
    p_weapon_stats: WeaponStats, damage_tracking_key: int, effects: Array,
    _args: Hitbox.HitboxArgs, knockback_direction: Vector2) -> void:
    player_index = p_from.player_index
    _element = Utils.randi() % Element.size()
    _phase = Phase.SCATTER
    _alive = true
    _elapsed = 0.0
    _retry = 0.0
    _light_triggered = false
    _scatter_direction = Vector2.RIGHT.rotated(p_rotation)
    _scatter_distance = min(135.0, max(0.0, p_weapon_stats.max_range * 0.22))
    _flight_speed = max(1.0, p_velocity.length())
    _last_position = pos
    _main = Utils.get_scene_node()
    if not _main.has_meta(TARGET_INDEX.META_KEY):
        _main.set_meta(TARGET_INDEX.META_KEY, TARGET_INDEX.new())
    _target_index = _main.get_meta(TARGET_INDEX.META_KEY)

    var orb_stats: RangedWeaponStats = p_weapon_stats.duplicate()
    orb_stats.burning_data = p_weapon_stats.burning_data.duplicate()
    match _element:
        Element.FIRE:
            var base_burn = BurningData.new()
            base_burn.chance = 1.0
            base_burn.damage = 10
            base_burn.duration = 10
            var burn: BurningData = WeaponService.init_burning_data(base_burn, player_index)
            burn.from = p_from
            burn.duration = max(burn.duration, orb_stats.burning_data.duration)
            burn.spread = max(burn.spread, orb_stats.burning_data.spread)
            if burn.damage >= orb_stats.burning_data.damage:
                orb_stats.burning_data = burn
            orb_stats.burning_data.chance = 1.0
            orb_stats.burning_data.duration = max(burn.duration, orb_stats.burning_data.duration)
            orb_stats.burning_data.spread = max(burn.spread, orb_stats.burning_data.spread)
        Element.WIND:
            orb_stats.piercing += 3
            orb_stats.piercing_dmg_reduction = 0.0
            orb_stats.knockback += 50
        Element.THUNDER:
            orb_stats.bounce += 4
            orb_stats.bounce_dmg_reduction = 0.0
    var orb_args = Hitbox.HitboxArgs.new().set_from_weapon_stats(orb_stats)
    .shoot_ex(p_from, pos, Vector2.ZERO, p_rotation, orb_stats,
        damage_tracking_key, effects, orb_args, knockback_direction)
    _time_until_max_range = INF
    _sprite.modulate = COLORS[_element]
    _sprite.modulate.a = ProgressData.settings.projectile_opacity
    _sprite.scale = Vector2.ONE * 0.55
    _update_sweep(pos, pos)


func _physics_process(delta: float) -> void:
    if not _alive:
        return
    if not is_instance_valid(_hitbox.from) or _hitbox.from.is_queued_for_deletion() \
        or _hitbox.from._parent.dead or _hitbox.from._parent.cleaning_up or _main._cleaning_up:
        stop()
        return
    _elapsed += delta
    if _phase == Phase.SCATTER:
        var progress: float = min(1.0, _elapsed / SCATTER_DURATION)
        global_position = spawn_position + _scatter_direction * _scatter_distance * (1.0 - pow(1.0 - progress, 3.0))
        if progress >= 1.0:
            _phase = Phase.HOVER
    elif _phase == Phase.HOVER:
        _sprite.scale = Vector2.ONE * (0.55 + 0.045 * sin(_elapsed * 18.0))
        if _elapsed >= SCATTER_DURATION + HOVER_DURATION:
            _retry -= delta
            if _retry <= 0.0:
                _retry = TARGET_RETRY
                _try_launch()
    _update_sweep(_last_position, global_position)
    _last_position = global_position


func _try_launch() -> void:
    var direction: Vector2 = _scatter_direction
    if _hitbox.from._manual_aim:
        direction = Vector2.RIGHT.rotated(_hitbox.from.rotation)
    else:
        var target: Node = _find_target()
        if target != null:
            direction = global_position.direction_to(target.global_position)
            if direction == Vector2.ZERO:
                direction = _scatter_direction
        elif _elapsed < SCATTER_DURATION + HOVER_DURATION + MAX_TARGET_WAIT:
            return
    _phase = Phase.FLIGHT
    velocity = direction * _flight_speed
    rotation = direction.angle()
    _sprite.scale = Vector2(0.85, 0.4)
    set_knockback_vector(direction, _weapon_stats.knockback, _weapon_stats.knockback_piercing)
    _set_time_until_max_range()


func _find_target() -> Node:
    var target: Node = null
    var nearest: float = float(_max_range) * float(_max_range)
    for enemy in _target_index.candidates(_main, global_position, _max_range):
        if not is_instance_valid(enemy) or enemy.dead or enemy._pending_die or _hitbox.ignored_objects.has(enemy):
            continue
        if WeaponService.fantasy_should_ignore_tree_body(_hitbox.from, enemy):
            continue
        var distance: float = global_position.distance_squared_to(enemy.global_position)
        if distance <= nearest:
            nearest = distance
            target = enemy
    return target


func _update_sweep(previous: Vector2, current: Vector2) -> void:
    var collision: CollisionShape2D = _hitbox._collision
    var motion: Vector2 = current - previous
    collision.global_position = (previous + current) * 0.5
    collision.global_rotation = motion.angle() + PI * 0.5
    collision.shape.height = motion.length()


func _on_Hitbox_hit_something(thing_hit: Node, damage_dealt: int) -> void:
    if not _alive:
        return
    if damage_dealt > 0 and is_instance_valid(thing_hit):
        match _element:
            Element.WATER:
                if thing_hit is Enemy and not thing_hit.dead:
                    thing_hit.add_decaying_speed(-int(thing_hit.get_base_speed_value_for_pct_based_decrease() * 0.3))
            Element.EARTH:
                _explode(thing_hit)
            Element.LIGHT:
                if thing_hit is Enemy and not _light_triggered:
                    _light_triggered = true
                    TempStats.add_stat(Keys.stat_attack_speed_hash, 5, player_index)
    ._on_Hitbox_hit_something(thing_hit, damage_dealt)


func bounce(_thing_hit: Node) -> void:
    _phase = Phase.FLIGHT
    _bounce -= 1
    var target: Node = _find_target()
    var direction: Vector2 = velocity.normalized() if velocity != Vector2.ZERO else _scatter_direction
    if target != null:
        var to_target: Vector2 = global_position.direction_to(target.global_position)
        if to_target != Vector2.ZERO:
            direction = to_target
    velocity = direction * _flight_speed
    rotation = direction.angle()
    _set_time_until_max_range()
    set_knockback_vector(direction, _weapon_stats.knockback, _weapon_stats.knockback_piercing)
    if _hitbox.damage > 0:
        _hitbox.damage = max(1, _hitbox.damage * (1.0 - _weapon_stats.bounce_dmg_reduction))
    _sprite.scale = Vector2(0.85, 0.4)


func _explode(thing_hit: Node) -> void:
    var weapon: Weapon = _hitbox.from
    var args = WeaponServiceExplodeArgs.new()
    args.pos = thing_hit.global_position
    args.damage = _hitbox.damage
    args.scaling_stats = _hitbox.scaling_stats
    args.accuracy = _hitbox.accuracy
    args.crit_chance = _hitbox.crit_chance
    args.crit_damage = _hitbox.crit_damage
    args.burning_data = _hitbox.burning_data
    args.from_player_index = player_index
    args.is_healing = _hitbox.is_healing
    args.ignored_objects = [thing_hit]
    args.damage_tracking_key_hash = _hitbox.damage_tracking_key_hash
    var explosion = WeaponService.explode(_earth_explosion, args)
    explosion._hitbox.player_attack_id = _hitbox.player_attack_id
    explosion.connect("hit_something", weapon, "on_weapon_hit_something", [explosion._hitbox])
    explosion.connect("killed_something", weapon, "on_killed_something", [explosion._hitbox])


func stop() -> void:
    if not _alive:
        return
    _alive = false
    .stop()


func _return_to_pool() -> void:
    _alive = false
    _main = null
    _target_index = null
    _light_triggered = false
    ._return_to_pool()
