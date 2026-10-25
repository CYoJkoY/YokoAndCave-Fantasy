extends "res://projectiles/player_projectile.gd"

const TARGET_INDEX = preload("res://mods-unpacked/Yoko-Fantasy/content/utils/projectile_target_index.gd")
const EFFECT = preload("res://mods-unpacked/Yoko-Fantasy/content/weapons/ranged/sage_staff/sage_staff_effect.gd")
const EXPLOSION_SCENE: PackedScene = preload("res://mods-unpacked/Yoko-Fantasy/content/weapons/ranged/sage_staff/vfx/sage_earth_explosion.tscn")
const ART = preload("res://mods-unpacked/Yoko-Fantasy/content/weapons/ranged/sage_staff/vfx/sage_staff_art.gd")
const IMPACT: PackedScene = preload("res://mods-unpacked/Yoko-Fantasy/content/weapons/ranged/sage_staff/vfx/sage_staff_impact.tscn")
const CHAIN: PackedScene = preload("res://mods-unpacked/Yoko-Fantasy/content/weapons/ranged/sage_staff/vfx/sage_staff_chain.tscn")

const Element = EFFECT.Element
const Phase = EFFECT.Phase

const SCATTER_DURATION: float = EFFECT.SCATTER_DURATION
const HOVER_DURATION: float = EFFECT.HOVER_DURATION
const MAX_TARGET_WAIT: float = 0.7
const TARGET_RETRY: float = 0.1

onready var _visuals: Node2D = $Visuals

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
var _thunder_triggered: bool = false
var _motion_seed: float = 0.0
var _hover_origin: Vector2
var _hit_position: Vector2
var _ends_on_hit: bool = false
var _main: Node
var _target_index: Reference
var _earth_explosion: ExplodingEffect = ExplodingEffect.new()


func _ready() -> void:
    _earth_explosion.explosion_scene = EXPLOSION_SCENE
    _earth_explosion.scale = EFFECT.EARTH_RADIUS / EFFECT.EXPLOSION_BASE_RADIUS
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
    _thunder_triggered = false
    _motion_seed = rand_range(0.0, TAU)
    _ends_on_hit = false
    _scatter_direction = Vector2.RIGHT.rotated(p_rotation)
    _scatter_distance = min(135.0, max(0.0, p_weapon_stats.max_range * 0.22)) * rand_range(0.76, 1.0)
    _hover_origin = pos + _scatter_direction * _scatter_distance
    _flight_speed = max(1.0, p_velocity.length())
    _last_position = pos
    _main = Utils.get_scene_node()
    if not _main.has_meta(TARGET_INDEX.META_KEY):
        _main.set_meta(TARGET_INDEX.META_KEY, TARGET_INDEX.new())
    _target_index = _main.get_meta(TARGET_INDEX.META_KEY)

    var orb_stats: RangedWeaponStats = p_weapon_stats as RangedWeaponStats
    match _element:
        Element.FIRE:
            orb_stats = p_weapon_stats.duplicate()
            var burn: BurningData = WeaponService.init_burning_data(EFFECT.BURNING_DATA, player_index)
            burn.from = p_from
            burn.duration = max(burn.duration, p_weapon_stats.burning_data.duration)
            burn.spread = max(burn.spread, p_weapon_stats.burning_data.spread)
            orb_stats.burning_data = burn if burn.damage >= p_weapon_stats.burning_data.damage else p_weapon_stats.burning_data.duplicate()
            orb_stats.burning_data.chance = 1.0
            orb_stats.burning_data.duration = burn.duration
            orb_stats.burning_data.spread = burn.spread
        Element.WIND:
            orb_stats = p_weapon_stats.duplicate()
            orb_stats.burning_data = p_weapon_stats.burning_data
            orb_stats.piercing += EFFECT.WIND_PIERCING
            orb_stats.piercing_dmg_reduction = 0.0
            orb_stats.knockback += EFFECT.WIND_KNOCKBACK
    var orb_args = Hitbox.HitboxArgs.new().set_from_weapon_stats(orb_stats)
    .shoot_ex(p_from, pos, Vector2.ZERO, p_rotation, orb_stats,
        damage_tracking_key, effects, orb_args, knockback_direction)
    _time_until_max_range = INF
    _visuals.start(_element, _motion_seed)
    modulate.a = ProgressData.settings.projectile_opacity
    _hitbox.set_meta("fantasy_damage_color", ART.COLORS[_element])
    _update_sweep(pos, pos)


func get_element() -> int:
    return _element


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
        var reach: float = 1.0 - pow(1.0 - progress, 3.0)
        var curl: float = (0.65 + sin(_motion_seed) * 0.35) * (1.0 - reach)
        var flutter: float = sin(progress * TAU + _motion_seed) * sin(progress * PI) * 7.0
        global_position = spawn_position + _scatter_direction.rotated(curl) * _scatter_distance * reach \
            + _scatter_direction.tangent() * flutter
        if progress >= 1.0:
            _phase = Phase.HOVER
            _visuals.hover()
    elif _phase == Phase.HOVER:
        var hover_age: float = _elapsed - SCATTER_DURATION
        var settle: float = 1.0 - exp(-hover_age * 14.0)
        var sway: Vector2 = _scatter_direction.tangent() * sin(hover_age * 8.0 + _motion_seed) * 8.0
        sway += _scatter_direction * sin(hover_age * 5.5 + _motion_seed * 1.7) * 4.0
        sway += Vector2(0.0, -sin(hover_age * 4.0) * 5.0)
        global_position = _hover_origin + sway * settle
        if _elapsed >= SCATTER_DURATION + HOVER_DURATION:
            _retry -= delta
            if _retry <= 0.0:
                _retry = TARGET_RETRY
                _try_launch()
    _update_sweep(_last_position, global_position)
    _last_position = global_position
    _visuals.advance_motion(_elapsed)


func _try_launch() -> void:
    var direction: Vector2 = _scatter_direction
    if _hitbox.from._manual_aim:
        direction = _hitbox.from.get_orb_aim_direction()
        if direction == Vector2.ZERO:
            direction = _scatter_direction
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
    _visuals.launch(true, _elapsed)
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
        var impact_radius: float = 44.0
        match _element:
            Element.WATER:
                if thing_hit is Enemy and not thing_hit.dead:
                    thing_hit.add_decaying_speed(-int(thing_hit.get_base_speed_value_for_pct_based_decrease() * EFFECT.SLOW_PERCENT / 100.0))
            Element.EARTH:
                impact_radius = _explode(thing_hit)
            Element.THUNDER:
                if thing_hit is Enemy and not _thunder_triggered:
                    _thunder_triggered = true
                    var chain = CHAIN.instance()
                    _hitbox.from.add_child(chain)
                    chain.start(self, thing_hit)
            Element.LIGHT:
                if thing_hit is Enemy and not _light_triggered:
                    _light_triggered = true
                    TempStats.add_stat(Keys.stat_attack_speed_hash, EFFECT.LIGHT_ATTACK_SPEED, player_index)
        var pool_id: int = IMPACT.get_instance_id()
        var impact = _main.get_node_from_pool(pool_id, _main._effects)
        if impact == null:
            impact = IMPACT.instance()
            _main.add_effect(impact)
        impact.start(thing_hit.global_position, _element, rotation, impact_radius, _main, pool_id)
    if is_instance_valid(thing_hit):
        _ends_on_hit = true
        _hit_position = thing_hit.global_position
    ._on_Hitbox_hit_something(thing_hit, damage_dealt)
    if _alive:
        _ends_on_hit = false


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
    _visuals.launch(false, _elapsed)


func _explode(thing_hit: Node) -> float:
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
    return explosion.scale.x * EFFECT.EXPLOSION_BASE_RADIUS


func stop() -> void:
    if not _alive:
        return
    _alive = false
    _visuals.stop(_ends_on_hit, _hit_position)
    velocity = Vector2.ZERO
    .stop()


func _return_to_pool() -> void:
    _alive = false
    _main = null
    _target_index = null
    _light_triggered = false
    _thunder_triggered = false
    _ends_on_hit = false
    _visuals.reset()
    ._return_to_pool()
