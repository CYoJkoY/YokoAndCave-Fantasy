extends PlayerProjectile

const FANTASY_PROJECTILE_VISUAL_UTILS = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/utils/projectile_visual_utils.gd")

const TRAIL_HISTORY = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/utils/projectile_trail_history.gd")

const HIT_SPARK_SCENE: PackedScene = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/weapons/ranged/finger_snap/vfx/finger_snap_hit_spark.tscn")
const DISAPPEAR_SPARK_SCENE: PackedScene = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/weapons/ranged/finger_snap/vfx/finger_snap_disappear_spark.tscn")
onready var _hit_spark_pool_id: int = HIT_SPARK_SCENE.get_instance_id()
onready var _disappear_spark_pool_id: int = DISAPPEAR_SPARK_SCENE.get_instance_id()

const TELEGRAPH_TIME: float = 0.15
const BASE_CONVERGE_SPEED: float = 460.0
const TRAIL_MAX_POINTS: int = 9
const TRAIL_MIN_DIST: float = 3.0
const TRAIL_SAMPLE_INTERVAL: float = 1.0 / 30.0

var _target_center: Vector2 = Vector2.ZERO
var _inward_dir: Vector2 = Vector2.RIGHT
var _is_converging: bool = false
var _telegraph_timer: float = 0.0
var _current_speed: float = 0.0
var _history = TRAIL_HISTORY.new(TRAIL_MAX_POINTS)
var _trail_elapsed: float = 0.0
var _converge_visual_started: bool = false
var _spin_angle: float = 0.0
var _setting_opacity: float = 1.0

onready var _star_sprite: Sprite = $"%StarSprite" as Sprite
onready var _trail_line: Line2D = $"%TrailLine" as Line2D
onready var _trail_particles: CPUParticles2D = $"%TrailParticles" as CPUParticles2D


func _ready() -> void:
    if is_instance_valid(_sprite):
        _sprite.visible = false
        _sprite.texture = null
    _init_trail()


func _init_trail() -> void:
    _history.clear()
    _trail_elapsed = 0.0
    if is_instance_valid(_trail_line):
        _trail_line.clear_points()
        _trail_line.set_as_toplevel(true)
        _trail_line.global_transform = Transform2D.IDENTITY


func init_converge(
    target_center: Vector2,
    spawn_pos: Vector2,
    speed_val: float = BASE_CONVERGE_SPEED
) -> void:
    _target_center = target_center
    global_position = spawn_pos
    velocity = Vector2.ZERO
    sinusoidal_motion = Vector2.ZERO

    _setting_opacity = FANTASY_PROJECTILE_VISUAL_UTILS.get_opacity()

    _inward_dir = (target_center - spawn_pos).normalized()
    if _inward_dir == Vector2.ZERO:
        _inward_dir = Vector2.RIGHT

    rotation = _inward_dir.angle()
    _spin_angle = rand_range(0.0, TAU)
    _current_speed = speed_val * 0.45
    _is_converging = true
    _converge_visual_started = false
    _telegraph_timer = TELEGRAPH_TIME
    _enable_stop_delay = false
    _elapsed_delay = 0.0
    _time_until_max_range = 5.0

    if is_instance_valid(_hitbox):
        _hitbox.active = true
        _hitbox.enable()
        _hitbox.ignored_objects.clear()

    _init_trail()
    _history.push(spawn_pos)
    if is_instance_valid(_trail_line):
        _trail_line.add_point(spawn_pos)

    if is_instance_valid(_star_sprite):
        _star_sprite.visible = true
        _star_sprite.scale = Vector2(0.2, 0.2)
        _star_sprite.modulate = Color(1.0, 0.98, 0.85, 0.9 * _setting_opacity)
        _star_sprite.rotation = _spin_angle

    if is_instance_valid(_trail_line):
        _trail_line.modulate.a = _setting_opacity

    if is_instance_valid(_trail_particles):
        _trail_particles.modulate.a = _setting_opacity
        _trail_particles.emitting = _setting_opacity > 0.0
        if _trail_particles.emitting:
            _trail_particles.restart()


func _physics_process(delta: float) -> void:
    if not _is_converging:
        _update_trail(delta)
        return

    _time_until_max_range = 5.0
    if _setting_opacity > 0.0:
        _spin_angle += delta * 6.0

    if _telegraph_timer > 0.0:
        _telegraph_timer -= delta
        if _setting_opacity > 0.0 and is_instance_valid(_star_sprite):
            var p = 1.0 - max(0.0, _telegraph_timer / TELEGRAPH_TIME)
            var ease_p = sin(p * PI * 0.5)
            _star_sprite.scale = Vector2.ONE * lerp(0.18, 0.45, ease_p)
            _star_sprite.rotation = _spin_angle
            _star_sprite.modulate = Color(1.0, 0.96, 0.75, lerp(0.5, 1.0, ease_p) * _setting_opacity)
        return


    _current_speed = lerp(_current_speed, BASE_CONVERGE_SPEED * 1.3, delta * 8.0)
    var move_vec = _inward_dir * (_current_speed * delta)
    global_position += move_vec

    if _setting_opacity > 0.0 and is_instance_valid(_star_sprite):
        _star_sprite.rotation = _spin_angle
        if not _converge_visual_started:
            _converge_visual_started = true
            _star_sprite.scale = Vector2.ONE * 0.42
            _star_sprite.modulate.a = _setting_opacity

    _update_trail(delta)

    var to_center = _target_center - global_position
    var passed_center = to_center.dot(_inward_dir) <= 6.0 or to_center.length_squared() <= 256.0

    if passed_center:
        _on_reach_center()


func _on_reach_center() -> void:
    if _piercing <= 0:
        stop()
    else:
        _is_converging = false
        _set_time_until_max_range()
        var proj_speed: float = _weapon_stats.projectile_speed if is_instance_valid(_weapon_stats) else BASE_CONVERGE_SPEED
        velocity = _inward_dir * max(proj_speed, _current_speed)
        _spawn_hit_spark(global_position)


func _on_Hitbox_hit_something(thing_hit: Node, damage_dealt: int) -> void:
    _spawn_hit_spark(global_position)
    ._on_Hitbox_hit_something(thing_hit, damage_dealt)


func bounce(thing_hit: Node) -> void:
    _is_converging = false
    var speed: float = max(_current_speed, _weapon_stats.projectile_speed if is_instance_valid(_weapon_stats) else BASE_CONVERGE_SPEED)

    if velocity.length_squared() < 10.0:
        velocity = _inward_dir * speed
    .bounce(thing_hit)

    _time_until_max_range = 5.0


func _update_trail(delta: float) -> void:
    if _setting_opacity <= 0.0 or not is_instance_valid(_trail_line):
        return

    _trail_elapsed += delta
    if _trail_elapsed < TRAIL_SAMPLE_INTERVAL:
        if _trail_line.get_point_count() > 0:
            _trail_line.set_point_position(0, global_position)
        return
    _trail_elapsed = fmod(_trail_elapsed, TRAIL_SAMPLE_INTERVAL)

    if not _history.push(global_position, TRAIL_MIN_DIST * TRAIL_MIN_DIST):
        return
    if _trail_line.get_point_count() < _history.count:
        _trail_line.add_point(Vector2.ZERO)
    for i in range(_history.count):
        _trail_line.set_point_position(i, _history.newest(i))


func _spawn_hit_spark(pos: Vector2) -> void:
    if _setting_opacity <= 0.0:
        return
    var main = Utils.get_scene_node()
    if main == null or not is_instance_valid(main):
        return
    var spark = FANTASY_PROJECTILE_VISUAL_UTILS.get_pooled_effect(HIT_SPARK_SCENE, main)
    spark.play_hit(pos, main, _hit_spark_pool_id)


func _spawn_disappear_spark(pos: Vector2) -> void:
    if _setting_opacity <= 0.0:
        return
    var main = Utils.get_scene_node()
    if main == null or not is_instance_valid(main):
        return
    var spark = FANTASY_PROJECTILE_VISUAL_UTILS.get_pooled_effect(DISAPPEAR_SPARK_SCENE, main)
    spark.play_disappear(pos, main, _disappear_spark_pool_id)


func stop(from_screen_border: bool = false) -> void:
    if not _enable_stop_delay and visible and modulate.a > 0.05:
        _spawn_disappear_spark(global_position)
    .stop(from_screen_border)


func _return_to_pool() -> void:
    _is_converging = false
    if is_instance_valid(_trail_line):
        _trail_line.clear_points()
    _history.clear()
    _trail_elapsed = 0.0
    _converge_visual_started = false
    if is_instance_valid(_trail_particles):
        _trail_particles.emitting = false
    ._return_to_pool()
