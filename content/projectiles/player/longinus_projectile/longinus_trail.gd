extends Node2D

const VISUAL_UTILS = preload("res://mods-unpacked/Yoko-Fantasy/content/utils/projectile_visual_utils.gd")
signal finished

const TRAIL_EFFECT = preload("res://mods-unpacked/Yoko-Fantasy/content/weapons/ranged/longinus/longinus_effect.gd")
const VFX = preload("res://mods-unpacked/Yoko-Fantasy/content/projectiles/player/longinus_projectile/longinus_vfx_utils.gd")
const HIT_SPARK_SCENE = preload("res://mods-unpacked/Yoko-Fantasy/content/projectiles/player/longinus_projectile/longinus_hit_spark.tscn")
const TRAIL_LIFETIME: float = TRAIL_EFFECT.TRAIL_LIFETIME
const TICK_INTERVAL: float = 1.0 / TRAIL_EFFECT.TICKS_PER_SECOND
const HIT_RADIUS: float = 29.0
const POINT_MIN_DISTANCE_SQUARED: float = 225.0
const MAX_POINTS: int = 220
const MAX_ARC_HITS: int = 5
const MAX_HIT_SPARKS: int = 5
const MAX_DAMAGE_TICKS: int = int(TRAIL_LIFETIME * TRAIL_EFFECT.TICKS_PER_SECOND)
const END_FADE_TIME: float = 0.30

var _damage_effect = null
var _weapon = null
var _player_index: int = -1
var _main: Node = null
var _pool_id: int = -1
var _hitbox = null
var _active: bool = false
var _emitting: bool = false
var _elapsed: float = 0.0
var _life_left: float = 0.0
var _ticks_done: int = 0
var _tick_timer: float = 0.0
var _visual_opacity: float = 1.0
var _points: Array = []
var _bounds: Rect2 = Rect2()
var _last_head_time: float = 0.0
var _hit_spark_pool_id: int = HIT_SPARK_SCENE.get_instance_id()

onready var _visual: Node2D = $Visuals


func _ready() -> void:
    set_as_toplevel(true)
    global_transform = Transform2D.IDENTITY
    visible = false
    set_process(false)


func begin(weapon, main: Node, pool_id: int, opacity: float = 1.0) -> void:
    _weapon = weapon
    _main = main
    _pool_id = pool_id
    _visual_opacity = clamp(opacity, 0.0, 1.0)
    _player_index = weapon.player_index
    _hitbox = weapon._hitbox
    _damage_effect = null
    for effect in weapon.effects:
        if effect is TRAIL_EFFECT:
            _damage_effect = effect
            break
    assert(_damage_effect != null)
    _points.clear()
    _bounds = Rect2()
    _active = true
    _emitting = true
    _elapsed = 0.0
    _last_head_time = 0.0
    _life_left = TRAIL_LIFETIME
    _ticks_done = 0
    _tick_timer = 0.0
    visible = _visual_opacity > 0.0
    modulate = Color(1, 1, 1, _visual_opacity)
    set_process(true)
    _visual.begin(_points, _visual_opacity)


func add_head(world_position: Vector2) -> void:
    if not _active:
        return
    _last_head_time = _elapsed

    if not _points.empty() and _points.back().distance_squared_to(world_position) < POINT_MIN_DISTANCE_SQUARED:
        return
    _points.append(world_position)
    _visual.path_changed()
    if _points.size() == 1:
        _bounds = Rect2(world_position, Vector2.ZERO)
    else:
        _bounds = _bounds.expand(world_position)
    if _points.size() > MAX_POINTS:
        _points.pop_front()
        _rebuild_bounds()


func finish_emission() -> void:
    if not _active or not _emitting:
        return
    _emitting = false
    _visual.finish_emission()


func _process(delta: float) -> void:
    if not _active:
        return

    _elapsed += delta
    _life_left -= delta

    if _life_left <= 0.0 or _points.empty():
        _finish()
        return

    modulate.a = _visual_opacity * clamp(_life_left / END_FADE_TIME, 0.0, 1.0)

    if _emitting and _elapsed - _last_head_time > 0.10:
        finish_emission()

    _visual.advance(delta)

    _tick_timer -= delta
    var safety: int = 0
    while _tick_timer <= 0.0 and safety < 4 and _ticks_done < MAX_DAMAGE_TICKS:
        _tick_timer += TICK_INTERVAL
        _apply_trail_damage()
        _ticks_done += 1
        safety += 1


func _rebuild_bounds() -> void:
    if _points.empty():
        _bounds = Rect2()
        return
    var minimum: Vector2 = _points[0]
    var maximum: Vector2 = _points[0]
    for point in _points:
        minimum.x = min(minimum.x, point.x)
        minimum.y = min(minimum.y, point.y)
        maximum.x = max(maximum.x, point.x)
        maximum.y = max(maximum.y, point.y)
    _bounds = Rect2(minimum, maximum - minimum)


func _apply_trail_damage() -> void:
    if _points.empty() or not is_instance_valid(_weapon) or not is_instance_valid(_hitbox):
        return
    if _player_index < 0:
        return
    if not is_instance_valid(_main) or not ("_entity_spawner" in _main) or _main._entity_spawner == null:
        return

    var parent = _weapon._parent
    if not is_instance_valid(parent):
        return
    if ("dead" in parent and parent.dead) or ("cleaning_up" in parent and parent.cleaning_up):
        return

    var damage: int = _damage_effect.get_damage(_player_index)

    var enemies: Array = _main._entity_spawner.get_all_enemies(false)
    var original_knockback: float = _hitbox.knockback_amount
    _hitbox.knockback_amount = 0.0
    var hit_count: int = 0
    var hit_any: bool = false

    var args := TakeDamageArgs.new(_player_index, _hitbox)
    args.set_meta("custom_color", VFX.DAMAGE_COLOR)
    var weapon_pos: int = _weapon.weapon_pos
    var track_damage: bool = weapon_pos >= 0 and weapon_pos < RunData.get_player_weapons(_player_index).size()

    for enemy in enemies:
        if not is_instance_valid(enemy) or enemy.dead or enemy._pending_die:
            continue
        var collision: CollisionShape2D = enemy._hurtbox._collision
        if collision.disabled:
            continue
        var enemy_position: Vector2 = collision.global_position
        var shape: CircleShape2D = collision.shape
        var collision_transform: Transform2D = collision.global_transform
        var radius: float = HIT_RADIUS + shape.radius * max(collision_transform.x.length(), collision_transform.y.length())
        if not _bounds.grow(radius).has_point(enemy_position):
            continue

        var nearest: Vector2 = VFX.nearest_point_on_path(_points, enemy_position)
        if nearest.distance_squared_to(enemy_position) > radius * radius:
            continue

        var damage_taken: Array = enemy.take_damage(damage, args)
        var dealt: int = int(damage_taken[1])
        hit_count += 1
        if dealt <= 0:
            continue

        hit_any = true
        if track_damage:
            RunData.add_weapon_dmg_dealt(weapon_pos, dealt, _player_index)

        if _visual_opacity > 0.0 and hit_count <= MAX_ARC_HITS:
            _visual.spawn_arc(nearest, enemy_position)
        if _visual_opacity > 0.0 and hit_count <= MAX_HIT_SPARKS:
            _spawn_hit_spark(enemy_position)

    _hitbox.knockback_amount = original_knockback
    if hit_any:
        _visual.flash_hit()


func _spawn_hit_spark(position: Vector2) -> void:
    if not is_instance_valid(_main):
        return
    var spark = VISUAL_UTILS.get_pooled_effect(HIT_SPARK_SCENE, _main)
    spark.play(position, _main, _hit_spark_pool_id, rand_range(0.42, 0.62), _visual_opacity)


func _finish() -> void:
    if not _active:
        return
    _active = false
    emit_signal("finished")
    _emitting = false
    set_process(false)
    visible = false
    _visual.reset()

    var main: Node = _main
    _damage_effect = null
    _weapon = null
    _hitbox = null
    _main = null
    _player_index = -1

    if _pool_id >= 0 and is_instance_valid(main):
        main.add_node_to_pool(self, _pool_id)
    else:
        queue_free()
