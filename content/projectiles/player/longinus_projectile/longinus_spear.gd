extends PlayerProjectile

const VFX = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/projectiles/player/longinus_projectile/longinus_vfx_utils.gd")
const VISUAL_UTILS = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/utils/projectile_visual_utils.gd")

const TRAIL_SCENE = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/projectiles/player/longinus_projectile/longinus_trail.tscn")
const IMPACT_SCENE = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/projectiles/player/longinus_projectile/longinus_impact.tscn")
const HIT_SPARK_SCENE = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/projectiles/player/longinus_projectile/longinus_hit_spark.tscn")

const AFTERIMAGE_LIFETIME: float = 0.13
const COMET_LIFETIME: float = 0.065
const BOLT_INTERVAL: float = 0.042

var _trail = null
var _trail_pool_id: int = TRAIL_SCENE.get_instance_id()
var _impact_pool_id: int = IMPACT_SCENE.get_instance_id()
var _hit_spark_pool_id: int = HIT_SPARK_SCENE.get_instance_id()
var _opacity: float = 1.0
var _time: float = 0.0
var _bolt_timer: float = 0.0
var _last_impact_time: float = -1.0
var _afterimage_history: Array = []
var _comet_history: Array = []
var _aura_base_scale: Vector2 = Vector2.ONE
var _glow_base_scale: Vector2 = Vector2.ONE
var _sprite_base_scale: Vector2 = Vector2.ONE

onready var _afterimages: Array = $Afterimages.get_children()
onready var _glow: Sprite = $Glow
onready var _aura: Sprite = $Aura
onready var _comet_trail: Line2D = $CometTrail
onready var _sparks: CPUParticles2D = $Sparks
onready var _bolts: Array = [$Bolts/Bolt0, $Bolts/Bolt1, $Bolts/Bolt2]


func _ready() -> void:
    _aura_base_scale = _aura.scale
    _glow_base_scale = _glow.scale
    _sprite_base_scale = _sprite.scale
    for bolt in _bolts:
        bolt.width_curve = VFX.TAPER_CURVE
    _comet_trail.set_as_toplevel(true)
    _comet_trail.global_transform = Transform2D.IDENTITY
    _comet_trail.z_as_relative = false
    _comet_trail.z_index = -3
    for ghost in _afterimages:
        ghost.set_as_toplevel(true)
    _hide_extras()


func _hide_extras() -> void:
    _glow.visible = false
    _aura.visible = false
    _comet_trail.visible = false
    _comet_trail.clear_points()
    _sparks.emitting = false
    for bolt in _bolts:
        bolt.visible = false
    for ghost in _afterimages:
        ghost.visible = false


func shoot() -> void:
    .shoot()
    _hide_extras()

    _opacity = VISUAL_UTILS.get_opacity()
    _time = 0.0
    _bolt_timer = 0.0
    _last_impact_time = -1.0
    _afterimage_history.clear()
    _comet_history.clear()

    _sprite.scale = _sprite_base_scale
    _sprite.modulate = Color(1, 1, 1, _opacity)
    _glow.visible = _opacity > 0.0
    _glow.modulate = Color(1.0, 0.91, 0.58, 0.88 * _opacity)
    _aura.visible = _opacity > 0.0
    _aura.modulate = Color(1.0, 0.88, 0.50, 0.42 * _opacity)
    _comet_trail.visible = _opacity > 0.0
    _comet_trail.modulate = Color(1.0, 0.94, 0.68, _opacity)
    _comet_trail.clear_points()
    _sparks.modulate = Color(1, 1, 1, _opacity)
    _sparks.emitting = _opacity > 0.0
    _sparks.restart()
    for ghost in _afterimages:
        ghost.visible = false

    _spawn_trail()
    if is_instance_valid(_trail):
        _trail.add_head(global_position)
    _spawn_spark(0.95)


func _spawn_trail() -> void:
    var main = Utils.get_scene_node()
    if main == null or not is_instance_valid(main) or not is_instance_valid(_hitbox):
        return
    var source = _hitbox.from
    if not is_instance_valid(source) or not ("_hitbox" in source):
        return

    _trail = VISUAL_UTILS.get_pooled_effect(TRAIL_SCENE, main)
    _trail.connect("finished", self, "_on_trail_finished", [], CONNECT_ONESHOT)
    _trail.begin(source, main, _trail_pool_id, _opacity)


func _physics_process(delta: float) -> void:
    if not is_inside_tree():
        return
    _time += delta

    if _hitbox.active and is_instance_valid(_trail):
        _trail.add_head(global_position)

    if _opacity <= 0.0:
        _sprite.modulate.a = 0.0
        _glow.visible = false
        _aura.visible = false
        _comet_trail.visible = false
        return

    if _hitbox.active:
        _update_comet_trail(delta)
        _update_afterimages(delta)
        _update_bolts(delta)
        _update_pulse(delta)


func _update_comet_trail(delta: float) -> void:
    for entry in _comet_history:
        entry.age = float(entry.age) + delta
    while not _comet_history.empty() and float(_comet_history[0].age) > COMET_LIFETIME:
        _comet_history.pop_front()

    var newest = null
    if not _comet_history.empty():
        newest = _comet_history[_comet_history.size() - 1]
    if newest == null or newest.position.distance_squared_to(global_position) > 1.0:
        _comet_history.append({"position": global_position, "age": 0.0})
    while _comet_history.size() > 14:
        _comet_history.pop_front()

    if _comet_history.size() < 2:
        _comet_trail.visible = false
        return

    var points := PoolVector2Array()
    for entry in _comet_history:
        points.append(entry.position)
    points.append(global_position)
    _comet_trail.visible = true
    _comet_trail.points = points
    _comet_trail.width = 24.0 + 2.0 * sin(_time * 22.0)


func _update_afterimages(delta: float) -> void:
    for entry in _afterimage_history:
        entry.age = float(entry.age) + delta
    while not _afterimage_history.empty() and float(_afterimage_history[0].age) > AFTERIMAGE_LIFETIME:
        _afterimage_history.pop_front()
    _afterimage_history.append({"position": global_position, "rotation": rotation, "age": 0.0})

    var history_count: int = _afterimage_history.size()
    for i in range(_afterimages.size()):
        var ghost: Sprite = _afterimages[i]
        var sample_index: int = history_count - 1 - (i + 1) * 2
        if sample_index < 0:
            ghost.visible = false
            continue
        var entry = _afterimage_history[sample_index]
        var fade: float = clamp(1.0 - float(entry.age) / AFTERIMAGE_LIFETIME, 0.0, 1.0)
        ghost.visible = true
        ghost.global_position = entry.position
        ghost.rotation = float(entry.rotation)
        ghost.scale = _sprite_base_scale * (1.0 - 0.06 * float(i))
        ghost.modulate = Color(1.0, 0.76, 0.28, (0.20 - 0.035 * float(i)) * fade * _opacity)


func _update_bolts(delta: float) -> void:
    _bolt_timer -= delta
    var should_rebuild: bool = _bolt_timer <= 0.0
    if should_rebuild:
        _bolt_timer = BOLT_INTERVAL

    for i in range(_bolts.size()):
        var bolt: Line2D = _bolts[i]
        if not should_rebuild:
            continue
        var start := Vector2(rand_range(-54.0, -38.0), rand_range(-7.0, 7.0))
        var finish := Vector2(rand_range(44.0, 78.0), rand_range(-9.0, 9.0))
        var points: PoolVector2Array = VFX.jagged_points(start, finish, int(rand_range(4, 7)), rand_range(3.0, 7.0))
        bolt.points = points
        bolt.width = 2.4 + float(i) * 1.1
        bolt.visible = _opacity > 0.0
        bolt.modulate = Color(1.0, 0.92 - float(i) * 0.08, 0.62 - float(i) * 0.10, (0.72 - float(i) * 0.16) * _opacity)


func _update_pulse(delta: float) -> void:
    var pulse: float = 1.0 + 0.018 * sin(_time * 18.0)
    _sprite.scale = _sprite_base_scale * pulse
    _glow.scale = _glow_base_scale * (0.9 + 0.08 * sin(_time * 8.0)) * pulse
    _aura.rotation += delta * 1.4
    _aura.scale = _aura_base_scale * (1.0 + 0.06 * sin(_time * 6.0))
    _glow.modulate = Color(1.0, 0.91, 0.58, (0.78 + 0.12 * sin(_time * 13.0)) * _opacity)
    _aura.modulate = Color(1.0, 0.88, 0.50, (0.34 + 0.08 * sin(_time * 7.0)) * _opacity)


func _on_Hitbox_hit_something(thing_hit: Node, damage_dealt: int) -> void:
    if _opacity > 0.0 and _time - _last_impact_time >= 0.06:
        _last_impact_time = _time
        var impact_position: Vector2 = global_position
        if is_instance_valid(thing_hit):
            impact_position = thing_hit.global_position
        _spawn_impact(impact_position, 0.88, true)
    ._on_Hitbox_hit_something(thing_hit, damage_dealt)


func _spawn_impact(position: Vector2, scale_mult: float, with_sound: bool) -> void:
    var main = Utils.get_scene_node()
    if main == null or not is_instance_valid(main):
        return
    var impact = VISUAL_UTILS.get_pooled_effect(IMPACT_SCENE, main)
    impact.play(position, main, _impact_pool_id, scale_mult, _opacity, with_sound)


func _spawn_spark(scale_mult: float) -> void:
    if _opacity <= 0.0:
        return
    var main = Utils.get_scene_node()
    if main == null or not is_instance_valid(main):
        return
    var spark = VISUAL_UTILS.get_pooled_effect(HIT_SPARK_SCENE, main)
    spark.play(global_position, main, _hit_spark_pool_id, scale_mult, _opacity)


func stop(from_screen_border: bool = false) -> void:
    if _enable_stop_delay:
        return

    if _hitbox.active and _opacity > 0.0 and _time - _last_impact_time >= 0.06:
        _spawn_spark(0.72)
    _release_trail()
    _sparks.emitting = false
    _comet_trail.visible = false
    for ghost in _afterimages:
        ghost.visible = false
    .stop(from_screen_border)


func _on_trail_finished() -> void:
    _trail = null


func _release_trail() -> void:
    if is_instance_valid(_trail):
        _trail.disconnect("finished", self, "_on_trail_finished")
        _trail.add_head(global_position)
        _trail.finish_emission()
        _trail = null


func _return_to_pool() -> void:
    _release_trail()
    _hide_extras()
    _afterimage_history.clear()
    _comet_history.clear()
    _sprite.scale = _sprite_base_scale
    ._return_to_pool()
