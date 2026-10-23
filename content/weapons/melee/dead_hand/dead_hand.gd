extends "res://weapons/melee/melee_weapon.gd"

const ECHO: PackedScene = preload("res://mods-unpacked/Yoko-Fantasy/content/weapons/melee/dead_hand/vfx/dead_hand_echo.tscn")
const SWEEP_FADE_DURATION: float = 0.24

onready var _flames: Sprite = $Sprite/Flames
onready var _halo: Sprite = $Sprite/Halo
onready var _embers: CPUParticles2D = $Sprite/Embers
onready var _sweep: Sprite = $Sweep
onready var _trail: Node2D = $Trail

var _echo_effect: Resource
var _clock: float = 0.0
var _charge: float = 0.0
var _sweep_fade: float = 0.0


func _ready() -> void:
    for effect in effects:
        if effect.get_id() == "weapon_dead_hand":
            _echo_effect = effect
            break
    assert(_echo_effect != null, "Dead hand echo effect is missing")
    update_sprite_flipv()


func init_stats(at_wave_begin: bool = true) -> void:
    .init_stats(at_wave_begin)
    _hitbox.effects = effects.duplicate()
    for effect in effects:
        if effect.get_id() == "fantasy_erosion" and effect.source_id == "weapon_fantasy_dead_hand":
            _hitbox.effects.erase(effect)


func get_direction() -> float:
    if _shooting_behavior.phase != _shooting_behavior.Phase.IDLE:
        return _shooting_behavior.attack_angle
    return .get_direction()


func update_sprite_flipv() -> void:
    if _shooting_behavior.phase != _shooting_behavior.Phase.IDLE:
        return
    .update_sprite_flipv()
    _flames.scale.y = -0.5 if sprite.flip_v else 0.5
    _halo.flip_v = sprite.flip_v


func shoot() -> void:
    if _parent.dead or _parent.cleaning_up:
        _shooting_behavior.cancel_attack()
        return
    update_sprite_flipv()
    .shoot()


func _physics_process(delta: float) -> void:
    if _parent.dead or _parent.cleaning_up:
        _shooting_behavior.cancel_attack()
        _sweep.visible = false
        _flames.visible = false
        _halo.visible = false
        _embers.emitting = false
        _trail.clear_trail()
        set_process(false)
        set_physics_process(false)
        return
    _shooting_behavior.advance(delta)


func _process(delta: float) -> void:
    _clock += delta
    var opacity: float = ProgressData.settings.explosion_opacity
    _flames.material.set_shader_param("phase", _clock)
    _flames.material.set_shader_param("charge", _charge)
    _flames.modulate.a = opacity * (0.78 + _charge * 0.22)
    _halo.modulate.a = opacity * (0.08 + _charge * 0.14)
    _embers.modulate.a = opacity
    _embers.emitting = opacity > 0.0 and _shooting_behavior.phase == _shooting_behavior.Phase.SWEEP
    _trail.advance(_flames, _shooting_behavior.phase == _shooting_behavior.Phase.SWEEP, delta, opacity * 0.7)
    if _sweep_fade > 0.0:
        _sweep_fade = max(0.0, _sweep_fade - delta)
        var release: float = 1.0 - _sweep_fade / SWEEP_FADE_DURATION
        _sweep.modulate.a = (1.0 - smoothstep(0.0, 1.0, release)) * opacity * 0.52
        _sweep.material.set_shader_param("release", release)
        _sweep.visible = _sweep_fade > 0.0


func prepare_swing(side: float, radius: float) -> void:
    _sweep_fade = 0.0
    _sweep.visible = false
    _sweep.scale = Vector2.ONE * radius / 230.0
    _sweep.material.set_shader_param("side", side)
    _sweep.material.set_shader_param("half_angle", _shooting_behavior.HALF_ANGLE)
    _sweep.material.set_shader_param("release", 0.0)


func begin_swing(center: Vector2) -> void:
    _sweep.position = center
    _sweep.visible = true
    update_swing(0.0)


func update_swing(progress: float) -> void:
    _sweep.material.set_shader_param("progress", progress)
    _sweep.modulate.a = (0.48 + sin(progress * PI) * 0.18) * ProgressData.settings.explosion_opacity
    set_charge(0.6 + sin(progress * PI) * 0.4)


func end_swing(center: Vector2, side: float) -> void:
    _sweep_fade = SWEEP_FADE_DURATION
    var main: Node = Utils.get_scene_node()
    if not is_instance_valid(main) or main._cleaning_up or _parent.dead or _parent.cleaning_up:
        return
    var echo = ECHO.instance()
    add_child(echo)
    echo.start(self, main, to_global(center), global_rotation, side, _echo_effect)


func set_charge(charge: float) -> void:
    _charge = charge


func enable_hitbox() -> void:
    _hitbox.active = true
    .enable_hitbox()


func disable_hitbox() -> void:
    _hitbox.active = false
    .disable_hitbox()
