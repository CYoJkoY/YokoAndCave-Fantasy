extends "res://projectiles/player_projectile.gd"

const FANTASY_PROJECTILE_VISUAL_UTILS = preload("res://mods-unpacked/Yoko-Fantasy/content/utils/projectile_visual_utils.gd")

const PATH_SEGMENTS: int = 42
const TIP_SCALE: Vector2 = Vector2(0.64, 0.42)
const DAMAGE_RADIUS: float = 30.0
const TRAVEL_MIN_TIME: float = 0.46
const TRAVEL_MAX_TIME: float = 1.12
const LINGER_TIME: float = 0.42
const FADE_TIME: float = 0.28
const ARRIVAL_FLASH_TIME: float = 0.22
const TANGENT_SAMPLE_STEP: float = 0.012
const FLAME_WIDTH: float = 52.0
const CORE_WIDTH: float = 15.0

var _wave_index: int = 0
var _base_direction: Vector2 = Vector2.RIGHT
var _normal_direction: Vector2 = Vector2.UP
var _amplitude: float = 32.0
var _wave_turns: float = 1.4
var _wave_phase: float = 0.0
var _visual_seed: float = 1.0

var _elapsed: float = 0.0
var _path_progress: float = 0.0
var _travel_duration: float = 0.7
var _last_damage_tick: int = -1
var _arrival_time: float = -1.0
var _arrived: bool = false
var _trail_damage_active: bool = false
var _finished: bool = false
var _critical_hit: bool = false
var _head_active: bool = true
var _path_bounds: Rect2 = Rect2()

var _visual_opacity: float = 1.0
var _fade_multiplier: float = 1.0
var _trail_points: PoolVector2Array = PoolVector2Array()
var _fixed_point_count: int = 1
var _fixed_path_length: float = 0.0
var _fixed_path_bounds: Rect2 = Rect2()
var _trail_materials: Array = []
var _main: Node = null

onready var _trail_hitbox: Hitbox = $TrailHitbox
onready var _glow_line: Line2D = $GlowLine
onready var _flame_line: Line2D = $FlameLine
onready var _core_line: Line2D = $CoreLine
onready var _tip_glow: Sprite = $TipGlow
onready var _edge_glow: Sprite = $EdgeGlow
onready var _edge_flare: Sprite = $EdgeFlare
onready var _ember_particles: CPUParticles2D = $EmberParticles
onready var _tip_embers: CPUParticles2D = $TipEmbers


func _ready() -> void:
    _trail_materials = [_glow_line.material, _flame_line.material, _core_line.material]


func shoot_ex(p_from: Node,
        pos: Vector2,
        p_velocity: Vector2,
        p_rotation: float,
        p_weapon_stats,
        damage_tracking_key: int,
        effects: Array,
        hitbox_args: Hitbox.HitboxArgs,
        knockback_direction: Vector2
        ) -> void:
    if p_velocity.length_squared() > 0.001:
        _base_direction = p_velocity.normalized()
    else:
        _base_direction = Vector2.RIGHT.rotated(p_rotation)
    _normal_direction = Vector2(-_base_direction.y, _base_direction.x)

    _elapsed = 0.0
    _path_progress = 0.0
    _arrived = false
    _arrival_time = -1.0
    _finished = false
    _critical_hit = false
    _head_active = true
    _trail_damage_active = false
    _fade_multiplier = 1.0
    _trail_points = PoolVector2Array()
    _main = Utils.get_scene_node()
    _visual_opacity = FANTASY_PROJECTILE_VISUAL_UTILS.get_opacity()

    .shoot_ex(p_from, pos, p_velocity, p_rotation, p_weapon_stats, damage_tracking_key,
        effects, hitbox_args, knockback_direction)

    velocity = Vector2.ZERO
    rotation = 0.0
    _hitbox.ignored_objects.clear()
    _hitbox.position = Vector2.ZERO
    _hitbox.collision_layer = 8
    _trail_hitbox.from = p_from
    _trail_hitbox.set_damage(p_weapon_stats.damage, hitbox_args)
    _trail_hitbox.set_knockback(knockback_direction, p_weapon_stats.knockback, p_weapon_stats.knockback_piercing)
    _trail_hitbox.effects = []
    for effect in _hitbox.effects:
        _trail_hitbox.effects.append(effect.duplicate())
    _trail_hitbox.projectiles_on_hit = _hitbox.projectiles_on_hit
    _trail_hitbox.damage_tracking_key_hash = damage_tracking_key
    _trail_hitbox.effect_scale = p_weapon_stats.effect_scale
    _trail_hitbox.speed_percent_modifier = p_weapon_stats.speed_percent_modifier
    _trail_hitbox.active = true
    _trail_hitbox.connect("hit_something", p_from, "on_weapon_hit_something", [_trail_hitbox])
    _trail_hitbox.connect("killed_something", p_from, "on_killed_something", [_trail_hitbox])
    _trail_hitbox.connect("critically_hit_something", p_from, "_on_weapon_critically_hit_something")


func configure_wave(index: int) -> void:
    _trail_hitbox.player_attack_id = _hitbox.player_attack_id
    _wave_index = index
    _visual_seed = 1.7 + float(_wave_index) * 7.31
    _wave_phase = float(_wave_index) * 2.399963 + float(_wave_index % 2) * PI
    _wave_turns = 1.30 + float(_wave_index % 4) * 0.085
    _update_path_parameters()
    _trail_points = PoolVector2Array([Vector2.ZERO, Vector2.ZERO])
    _fixed_point_count = 1
    _fixed_path_length = 0.0
    _fixed_path_bounds = Rect2(Vector2.ZERO, Vector2.ZERO)
    _path_bounds = _fixed_path_bounds
    _last_damage_tick = -1
    _apply_material_seeds()


func shoot() -> void:
    .shoot()
    _hide_visuals()
    _sprite.position = Vector2.ZERO
    _sprite.rotation = 0.0
    _sprite.scale = TIP_SCALE
    _sprite.modulate = Color(1, 1, 1, _visual_opacity)

    _tip_glow.position = Vector2.ZERO
    _tip_glow.modulate = Color(1, 0.55, 0.14, 0)

    _ember_particles.modulate.a = _visual_opacity
    _tip_embers.modulate.a = _visual_opacity

    _trail_damage_active = true
    _fade_multiplier = 1.0


func _physics_process(delta: float) -> void:
    if _finished:
        return
    if not _is_source_valid():
        stop()
        return

    _elapsed += delta
    var travel_progress: float = clamp(_elapsed / max(_travel_duration, 0.0001), 0.0, 1.0)
    if not _arrived:
        _path_progress = 1.0 - pow(1.0 - travel_progress, 1.65)
    _hitbox.position = _path_point(_path_progress)

    _update_visuals()
    _update_path()

    if travel_progress >= 1.0 and not _arrived:
        _on_arrived()

    if _trail_damage_active:
        if _elapsed >= _travel_duration + LINGER_TIME:
            _stop_trail_damage()
        else:
            _update_damage_tick()

    if _elapsed >= _travel_duration + LINGER_TIME + FADE_TIME:
        stop()


func _is_source_valid() -> bool:
    var from = _hitbox.from
    if not is_instance_valid(from) or from.is_queued_for_deletion():
        return false
    if from is Weapon:
        var player = from._parent
        if not is_instance_valid(player) or player.dead or player.cleaning_up:
            return false
    if _main == null or not is_instance_valid(_main):
        return false
    if _main._cleaning_up:
        return false
    return true


func _set_time_until_max_range() -> void:
    # The wave drives its own travel and lifetime instead of the base range timer.
    _time_until_max_range = INF


func _update_path_parameters() -> void:
    _travel_duration = clamp(float(_max_range) / max(1.0, float(_weapon_stats.projectile_speed)), TRAVEL_MIN_TIME, TRAVEL_MAX_TIME)
    _amplitude = clamp(float(_max_range) * 0.105, 18.0, 42.0)
    _amplitude *= 0.88 + 0.07 * float(_wave_index % 3)


func _path_point(progress: float) -> Vector2:
    var clamped_progress: float = clamp(progress, 0.0, 1.0)
    var envelope: float = pow(max(0.0, sin(clamped_progress * PI)), 0.62)
    var lateral: float = sin(clamped_progress * _wave_turns * TAU + _wave_phase) * _amplitude * envelope
    lateral += sin(clamped_progress * _wave_turns * 1.73 * TAU + _wave_phase * 1.7) * _amplitude * 0.32 * envelope
    return _base_direction * (float(_max_range) * clamped_progress) + _normal_direction * lateral


func _update_path() -> void:
    if _path_progress <= 0.002:
        _sprite.visible = false
        _tip_glow.visible = false
        _glow_line.visible = false
        _flame_line.visible = false
        _core_line.visible = false
        return

    if not _arrived:
        _extend_trail_path()
    _glow_line.visible = true
    _flame_line.visible = true
    _core_line.visible = true
    _update_head_visuals()


func _extend_trail_path() -> void:
    while _fixed_point_count < PATH_SEGMENTS and float(_fixed_point_count) / float(PATH_SEGMENTS) <= _path_progress:
        var point: Vector2 = _path_point(float(_fixed_point_count) / float(PATH_SEGMENTS))
        _fixed_path_length += _trail_points[_fixed_point_count - 1].distance_to(point)
        _fixed_path_bounds = _fixed_path_bounds.expand(point)
        _trail_points[_fixed_point_count] = point
        _trail_points.append(point)
        _fixed_point_count += 1

    var head_position: Vector2 = _hitbox.position
    _trail_points[_fixed_point_count] = head_position
    _path_bounds = _fixed_path_bounds.expand(head_position)
    var path_length: float = _fixed_path_length + _trail_points[_fixed_point_count - 1].distance_to(head_position)

    _glow_line.points = _trail_points
    _flame_line.points = _trail_points
    _core_line.points = _trail_points
    _ember_particles.emission_points = _trail_points
    for material in _trail_materials:
        material.set_shader_param("path_length", path_length)


func _path_intersects_circle(point: Vector2, radius_squared: float) -> bool:
    var count: int = _trail_points.size()
    for i in range(count - 1):
        var a: Vector2 = _trail_points[i]
        var b: Vector2 = _trail_points[i + 1]
        var closest: Vector2 = Geometry.get_closest_point_to_segment_2d(point, a, b)
        var distance_squared: float = point.distance_squared_to(closest)
        if distance_squared <= radius_squared:
            return true
    return false


func _update_damage_tick() -> void:
    var tick: int = _hitbox.from.get_damage_tick()
    if tick == _last_damage_tick:
        return
    _last_damage_tick = tick
    _apply_damage_tick()


func _apply_damage_tick() -> void:
    if _main == null or not is_instance_valid(_main):
        return
    if _trail_points.size() < 2:
        return
    var weapon = _hitbox.from
    for target in weapon.get_trail_targets(_main):
        var enemy = target[0]
        if not is_instance_valid(enemy) or enemy.dead or enemy._pending_die:
            continue
        if weapon.has_hit_this_tick(enemy):
            continue
        var local_position: Vector2 = target[1] - global_position
        var radius: float = DAMAGE_RADIUS + target[2]
        if not _path_bounds.grow(radius).has_point(local_position):
            continue
        if not _path_intersects_circle(local_position, radius * radius):
            continue
        weapon.mark_hit_this_tick(enemy)
        _critical_hit = false
        enemy.hurt_area_entered_deferred(_trail_hitbox)


func _stop_trail_damage() -> void:
    _trail_damage_active = false
    _trail_hitbox.active = false
    _trail_hitbox.ignored_objects.clear()


func _on_Hitbox_hit_something(thing_hit: Node, damage_dealt: int) -> void:
    if _finished or not _head_active:
        return
    _play_hit_feedback(thing_hit, damage_dealt)
    emit_signal("hit_something", thing_hit, damage_dealt)
    _hitbox.ignored_objects.append(thing_hit)
    if _piercing <= 0:
        _travel_duration = _elapsed
        _on_arrived()
    else:
        _piercing -= 1
        if _hitbox.damage > 0:
            _hitbox.damage = max(1, _hitbox.damage - _hitbox.damage * _weapon_stats.piercing_dmg_reduction)
    _critical_hit = false


func _on_TrailHitbox_hit_something(thing_hit: Node, damage_dealt: int) -> void:
    _play_hit_feedback(thing_hit, damage_dealt)
    _critical_hit = false


func _on_Hitbox_critically_hit_something(thing_hit: Node, damage_dealt: int) -> void:
    _critical_hit = true
    ._on_Hitbox_critically_hit_something(thing_hit, damage_dealt)


func _on_TrailHitbox_critically_hit_something(_thing_hit: Node, _damage_dealt: int) -> void:
    _critical_hit = true


func _play_hit_feedback(thing_hit: Node, damage_dealt: int) -> void:
    var weapon = _hitbox.from
    if is_instance_valid(weapon):
        RunData.manage_life_steal(_weapon_stats, weapon.player_index)
        if damage_dealt > 0 and is_instance_valid(thing_hit):
            weapon.play_hit_feedback(thing_hit.global_position, _critical_hit)


func _update_head_visuals() -> void:
    _sprite.visible = true
    _tip_glow.visible = true

    var head_position: Vector2 = _path_point(_path_progress)
    var tangent: Vector2 = (head_position - _path_point(max(0.0, _path_progress - TANGENT_SAMPLE_STEP))).normalized()
    var pulse: float = 1.0 + 0.045 * sin(_elapsed * 12.0 + _visual_seed)
    var fade_scale: float = 0.72 + 0.28 * _fade_multiplier
    var head_fade: float = 1.0
    if _arrived:
        head_fade = 1.0 - clamp((_elapsed - _arrival_time) / ARRIVAL_FLASH_TIME, 0.0, 1.0)

    _sprite.position = head_position - tangent * 20.0
    _sprite.rotation = tangent.angle()
    _sprite.scale = TIP_SCALE * Vector2(pulse, 2.0 - pulse) * fade_scale
    _sprite.modulate = Color(1, 1, 1, _visual_opacity * _fade_multiplier * head_fade)

    _tip_glow.position = head_position - tangent * 8.0
    _tip_glow.rotation = tangent.angle()
    _tip_glow.scale = Vector2(0.56, 0.32) * pulse * fade_scale
    _tip_glow.modulate = Color(1, 0.42, 0.055, _visual_opacity * _fade_multiplier * head_fade * 0.38)


func _update_visuals() -> void:
    var appear: float = clamp(_path_progress * 12.0, 0.0, 1.0)
    var fade: float = 1.0
    var fade_start: float = _travel_duration + LINGER_TIME
    if _elapsed > fade_start:
        fade = 1.0 - clamp((_elapsed - fade_start) / FADE_TIME, 0.0, 1.0)
        _fade_multiplier = fade
    else:
        _fade_multiplier = 1.0

    var line_alpha: float = _visual_opacity * appear * fade
    _glow_line.modulate.a = line_alpha * (0.86 + 0.14 * sin(_elapsed * 5.3 + _visual_seed))
    _flame_line.modulate.a = line_alpha
    _core_line.modulate.a = line_alpha * (0.9 + 0.1 * sin(_elapsed * 13.0 + _visual_seed))
    _flame_line.width = FLAME_WIDTH * (0.58 + 0.42 * fade)
    _core_line.width = CORE_WIDTH * (0.45 + 0.55 * fade)
    for material in _trail_materials:
        material.set_shader_param("age", _elapsed)
    _sprite.material.set_shader_param("age", _elapsed)

    if _path_progress > 0.02 and _elapsed < _travel_duration + LINGER_TIME - _ember_particles.lifetime:
        if not _ember_particles.emitting:
            _ember_particles.restart()
        _ember_particles.emitting = true
    else:
        _ember_particles.emitting = false

    if _arrived:
        var arrival_age: float = _elapsed - _arrival_time
        var flare_progress: float = clamp(arrival_age / ARRIVAL_FLASH_TIME, 0.0, 1.0)
        var edge_alpha: float = _visual_opacity * fade
        _edge_flare.visible = flare_progress < 1.0
        _edge_flare.scale = Vector2(0.48 + flare_progress * 0.35, 0.42 * (1.0 - flare_progress))
        _edge_flare.modulate = Color(1, 1, 1, edge_alpha * (1.0 - flare_progress) * 0.7)
        _edge_glow.visible = true
        _edge_glow.scale = Vector2(0.48, 0.24) * (1.0 + flare_progress * 0.35)
        _edge_glow.modulate = Color(1, 0.19, 0.015, edge_alpha * (1.0 - flare_progress) * 0.3)


func _on_arrived() -> void:
    _head_active = false
    _hitbox.active = false
    _hitbox.collision_layer = 0
    _arrived = true
    _arrival_time = _elapsed
    var edge_position: Vector2 = _path_point(_path_progress)
    _edge_glow.position = edge_position
    _edge_flare.position = edge_position
    _tip_embers.position = edge_position
    _edge_glow.visible = true
    _edge_flare.visible = true
    _edge_flare.scale = Vector2(0.48, 0.42)
    _edge_flare.modulate = Color(1, 1, 1, _visual_opacity * 0.7)
    _edge_glow.scale = Vector2(0.48, 0.24)
    _edge_glow.modulate = Color(1, 0.19, 0.015, _visual_opacity * 0.3)
    var tangent: Vector2 = (edge_position - _path_point(max(0.0, _path_progress - TANGENT_SAMPLE_STEP))).normalized()
    _edge_flare.rotation = tangent.angle()
    _edge_glow.rotation = tangent.angle()
    _tip_embers.direction = tangent
    _tip_embers.angle = rad2deg(tangent.angle())
    _tip_embers.emitting = true
    _tip_embers.restart()


func _apply_material_seeds() -> void:
    for material in _trail_materials:
        material.set_shader_param("seed", _visual_seed)
        material.set_shader_param("age", 0.0)
    _sprite.material.set_shader_param("seed", _visual_seed)
    _sprite.material.set_shader_param("age", 0.0)
    _ember_particles.direction = -_base_direction
    _ember_particles.angle = rad2deg(_base_direction.angle())


func _hide_visuals() -> void:
    _sprite.visible = false
    _tip_glow.visible = false
    _edge_glow.visible = false
    _edge_flare.visible = false
    _glow_line.visible = false
    _flame_line.visible = false
    _core_line.visible = false
    _glow_line.clear_points()
    _flame_line.clear_points()
    _core_line.clear_points()
    _ember_particles.emitting = false
    _tip_embers.emitting = false


func stop() -> void:
    if _finished:
        return
    .stop()


func _return_to_pool() -> void:
    _finished = true
    _stop_trail_damage()
    _hide_visuals()
    _trail_points = PoolVector2Array()
    _main = null
    var weapon = _trail_hitbox.from
    if is_instance_valid(weapon):
        _trail_hitbox.disconnect("hit_something", weapon, "on_weapon_hit_something")
        _trail_hitbox.disconnect("killed_something", weapon, "on_killed_something")
        _trail_hitbox.disconnect("critically_hit_something", weapon, "_on_weapon_critically_hit_something")
    _trail_hitbox.from = null
    ._return_to_pool()
