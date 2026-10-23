extends PlayerProjectile

const TARGET_INDEX = preload("res://mods-unpacked/Yoko-Fantasy/content/utils/projectile_target_index.gd")
const IMPACT_SCENE = preload("res://mods-unpacked/Yoko-Fantasy/content/weapons/ranged/phantom_gale/vfx/phantom_impact.tscn")
const COLORS = [Color("55ffe0"), Color("aa78ff"), Color("ff65b5")]

export(bool) var is_echo: bool = false

var _age: float = 0.0
var _last_position: Vector2
var _launch_direction: Vector2
var _flight_origin: Vector2
var _flight_age: float = 0.0
var _flight_duration: float = 0.1
var _curve_a: Vector2
var _curve_b: Vector2
var _curve_goal: Vector2
var _color_index: int = 0
var _target: Node = null
var _retry: float = 0.0
var _main: Node
var _target_index: Reference
var _hit: bool = false

onready var _wake: Node2D = $Wake
onready var _glow: Sprite = $Glow
onready var _impact_pool_id: int = IMPACT_SCENE.get_instance_id()


func shoot_ex(p_from: Node, pos: Vector2, p_velocity: Vector2, p_rotation: float,
        p_weapon_stats: WeaponStats, damage_tracking_key: int, effects: Array,
        hitbox_args: Hitbox.HitboxArgs, knockback_direction: Vector2) -> void:
    player_index = p_from.player_index
    _age = 0.0
    _target = null
    _retry = 0.0
    _hit = false
    _color_index = 0
    _last_position = pos
    _launch_direction = p_velocity.normalized()
    _main = Utils.get_scene_node()
    .shoot_ex(p_from, pos, Vector2.ZERO if is_echo else p_velocity, p_rotation,
        p_weapon_stats, damage_tracking_key, effects, hitbox_args, knockback_direction)
    if is_echo:
        _bounce = 0
        _piercing = 0
        _time_until_max_range = INF
        if not _main.has_meta(TARGET_INDEX.META_KEY):
            _main.set_meta(TARGET_INDEX.META_KEY, TARGET_INDEX.new())
        _target_index = _main.get_meta(TARGET_INDEX.META_KEY)
    _sprite.visible = true
    _sprite.modulate = Color.white
    _sprite.modulate.a = ProgressData.settings.projectile_opacity
    _glow.visible = true
    _glow.modulate = Color(0.4, 0.95, 0.85,
        ProgressData.settings.projectile_opacity * (0.45 if is_echo else 0.6))
    _wake.begin(pos, is_echo)
    _update_sweep(pos, pos)


func configure_echo(index: int, initial_target: Node) -> void:
    _color_index = index % COLORS.size()
    _wake.set_color(COLORS[_color_index])
    _sprite.modulate = COLORS[_color_index].linear_interpolate(Color.white, 0.18)
    _sprite.modulate.a = ProgressData.settings.projectile_opacity
    _glow.modulate = COLORS[_color_index]
    _glow.modulate.a = ProgressData.settings.projectile_opacity * 0.45
    _target = initial_target
    if not _target_is_valid():
        _target = _find_target()
    _start_flight()


func _physics_process(delta: float) -> void:
    if not is_inside_tree():
        return
    if _enable_stop_delay:
        _wake.fade_out(max(0.0, 1.0 - _elapsed_delay / stop_delay), delta)
        return
    if not is_instance_valid(_hitbox.from) or _hitbox.from._parent.dead \
            or _hitbox.from._parent.cleaning_up or _main._cleaning_up:
        stop()
        return
    _age += delta
    if is_echo:
        _advance_echo(delta)
        if _enable_stop_delay:
            return
    var motion: Vector2 = global_position - _last_position
    if motion.length_squared() > 0.01:
        rotation = motion.angle()
    _update_sweep(_last_position, global_position)
    for step in range(1, 5):
        var point: Vector2 = _last_position.linear_interpolate(global_position, step / 4.0)
        if is_echo and _target != null:
            var progress: float = clamp((_flight_age - delta + delta * step / 4.0) / _flight_duration, 0.0, 1.0)
            point = _curve_point(progress)
        _wake.advance(point, delta / 4.0)
    _last_position = global_position
    var opacity: float = ProgressData.settings.projectile_opacity
    _wake.refresh()
    _sprite.modulate.a = opacity
    _glow.modulate.a = opacity * (0.45 + 0.1 * sin(_age * 35.0) if is_echo else 0.6)


func _advance_echo(delta: float) -> void:
    if _age >= 0.38:
        stop()
        return
    if not _target_is_valid():
        _target = null
        _retry -= delta
        if _retry <= 0.0:
            _target = _find_target()
            _retry = 0.05
            _start_flight()
        if _target == null:
            global_position += _launch_direction.rotated((_color_index - 1) * _age * 5.0) * 1400.0 * delta
            if _age > 0.15:
                stop()
            return
    _flight_age += delta
    _curve_goal = _target.global_position + Vector2(0, -8)
    var offset: Vector2 = _curve_goal - _flight_origin
    var normal: Vector2 = offset.normalized().tangent()
    var bend: float = min(135.0, 28.0 + offset.length() * 0.25) * [-1.0, 0.48, 1.0][_color_index]
    _curve_a = _flight_origin + offset * 0.18 + normal * bend
    _curve_b = _curve_goal - offset * 0.24 - normal * bend * 0.6
    global_position = _curve_point(min(1.0, _flight_age / _flight_duration))
    if _flight_age > _flight_duration + 0.065:
        stop()


func _curve_point(t: float) -> Vector2:
    var inverse: float = 1.0 - t
    return inverse * inverse * inverse * _flight_origin \
        + 3.0 * inverse * inverse * t * _curve_a \
        + 3.0 * inverse * t * t * _curve_b + t * t * t * _curve_goal


func _start_flight() -> void:
    _flight_origin = global_position
    _flight_age = 0.0
    if _target_is_valid():
        _flight_duration = clamp(global_position.distance_to(_target.global_position) / _weapon_stats.projectile_speed, 0.075, 0.15)


func _target_is_valid() -> bool:
    return is_instance_valid(_target) and _target is Enemy and not _target.dead \
        and not _target._pending_die and not _target.is_queued_for_deletion() \
        and global_position.distance_squared_to(_target.global_position) <= float(_max_range * _max_range)


func _find_target() -> Node:
    var nearest: Node = null
    var best_distance: float = float(_max_range * _max_range)
    for cell in _target_index.nearby_cells(_main, global_position, _max_range):
        if cell[0] > best_distance:
            break
        for enemy in cell[1]:
            if not is_instance_valid(enemy) or enemy.dead or enemy._pending_die:
                continue
            if WeaponService.fantasy_should_ignore_tree_body(_hitbox.from, enemy):
                continue
            var distance: float = global_position.distance_squared_to(enemy.global_position)
            if distance <= best_distance:
                nearest = enemy
                best_distance = distance
    return nearest


func _update_sweep(previous: Vector2, current: Vector2) -> void:
    var collision: CollisionShape2D = _hitbox._collision
    var motion: Vector2 = current - previous
    collision.global_position = (previous + current) * 0.5
    collision.global_rotation = motion.angle() + PI * 0.5
    collision.shape.height = motion.length()


func _on_Hitbox_hit_something(thing_hit: Node, damage_dealt: int) -> void:
    if _enable_stop_delay:
        return
    _hit = true
    _spawn_impact()
    if is_echo:
        _bounce = 0
        _piercing = 0
    ._on_Hitbox_hit_something(thing_hit, damage_dealt)


func stop() -> void:
    if _enable_stop_delay:
        return
    velocity = Vector2.ZERO
    _time_until_max_range = INF
    _target = null
    _sprite.visible = false
    _glow.visible = false
    if not _hit:
        _spawn_impact()
    .stop()


func _spawn_impact() -> void:
    if _main._cleaning_up or ProgressData.settings.projectile_opacity <= 0.0:
        return
    var impact = _main.get_node_from_pool(_impact_pool_id, _main._effects)
    if impact == null:
        impact = IMPACT_SCENE.instance()
        _main.add_effect(impact)
        impact.set_meta("pool_id", _impact_pool_id)
    impact.play(global_position, rotation, is_echo, COLORS[_color_index], _main)


func _return_to_pool() -> void:
    _target = null
    _wake.reset()
    ._return_to_pool()
