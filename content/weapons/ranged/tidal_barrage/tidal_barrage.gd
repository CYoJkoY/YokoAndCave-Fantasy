extends "res://weapons/ranged/ranged_weapon.gd"

const VISUAL_UTILS = preload("res://mods-unpacked/Yoko-Fantasy/content/utils/projectile_visual_utils.gd")
const RING_SCENE: PackedScene = preload("res://mods-unpacked/Yoko-Fantasy/content/weapons/ranged/tidal_barrage/vfx/tidal_ring.tscn")
const READY_FLASH_DURATION: float = 0.30

var _reload_pending: bool = false
var _reload_ticks: float = 1.0
var _shot_age: float = 1.0
var _ready_age: float = 1.0

onready var _channels: Sprite = $Sprite/Channels
onready var _current: Sprite = $Sprite/Current
onready var _ready_flash: Sprite = $Sprite/ReadyFlash
onready var _glint: Sprite = $Sprite/Glint
onready var _ring_pool_id: int = RING_SCENE.get_instance_id()
onready var _muzzle_position: Vector2 = $Sprite/Muzzle.position


func get_max_rand_cooldown(_cooldown_basis: int) -> float:
    return 0.0


func get_next_cooldown(at_wave_begin: bool = false) -> float:
    var cooldown: float = .get_next_cooldown(at_wave_begin)
    _reload_pending = is_big_reload_active(at_wave_begin)
    _reload_ticks = max(1.0, cooldown)
    return cooldown


func should_shoot() -> bool:
    if _reload_pending and not _is_shooting and _current_cooldown <= 0.0:
        _reload_pending = false
        _ready_age = 0.0
    return .should_shoot()


func shoot() -> void:
    _shot_age = 0.0
    update_sprite_flipv()
    _update_muzzle_position()
    .shoot()
    _spawn_muzzle_ring()


func _process(delta: float) -> void:
    _ready_age = min(1.0, _ready_age + delta)
    var opacity: float = VISUAL_UTILS.get_opacity()
    var shots_per_reload: int = current_stats.additional_cooldown_every_x_shots
    var charge: float = 1.0 - float(_nb_shots_taken % shots_per_reload) / float(shots_per_reload)
    if _reload_pending:
        charge = 1.0 - clamp(_current_cooldown / _reload_ticks, 0.0, 1.0)
    var kick: float = pow(max(0.0, 1.0 - _shot_age / 0.075), 2.0)
    var ready_progress: float = clamp(_ready_age / READY_FLASH_DURATION, 0.0, 1.0)
    var flash: float = 1.0 - ready_progress
    _channels.flip_v = sprite.flip_v
    _channels.material.set_shader_param("charge", charge)
    _channels.material.set_shader_param("pulse", max(kick, flash))
    _current.flip_v = sprite.flip_v
    _current.position.x = -kick * 1.5
    _current.modulate = Color(0.55, 1.0, 0.96, (0.24 + charge * 0.45 + kick * 0.25) * opacity)
    _ready_flash.visible = flash > 0.0 and opacity > 0.0
    _glint.visible = _ready_flash.visible
    if _ready_flash.visible:
        var side: float = -1.0 if sprite.flip_v else 1.0
        _ready_flash.flip_v = sprite.flip_v
        _ready_flash.modulate.a = opacity
        _ready_flash.material.set_shader_param("progress", ready_progress)
        _glint.position = Vector2(22, -14 * side)
        _glint.scale = Vector2.ONE * (0.45 + 0.55 * flash)
        _glint.modulate.a = pow(flash, 2.0) * opacity
    _update_muzzle_position()
    _shot_age = min(1.0, _shot_age + delta)


func _update_muzzle_position() -> void:
    muzzle.position = Vector2(_muzzle_position.x, -_muzzle_position.y if sprite.flip_v else _muzzle_position.y)


func _spawn_muzzle_ring() -> void:
    if VISUAL_UTILS.get_opacity() <= 0.0:
        return
    var main: Node = Utils.get_scene_node()
    var ring = VISUAL_UTILS.get_pooled_effect(RING_SCENE, main)
    ring.set_meta("pool_id", _ring_pool_id)
    var origin: Transform2D = muzzle.global_transform
    if sprite.flip_v:
        origin.y = -origin.y
    ring.play(origin, main)
