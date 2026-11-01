extends "res://overlap/hitbox.gd"

const CONFIG = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/weapons/melee/dead_hand/dead_hand_effect.gd")
const ECHO_SOUND: AudioStream = preload("res://weapons/melee_sounds/whoosh_swish_high_big_02.wav")

onready var _sigil: Sprite = $Sigil
onready var _mist: Sprite = $Mist
onready var _sweep: Sprite = $Sweep
onready var _hand: Node2D = $Hand
onready var _bones: Sprite = $Hand/Bones
onready var _flames: Sprite = $Hand/Flames
onready var _embers: CPUParticles2D = $Hand/Embers

var _main: Node
var _radius: float = 0.0
var _side: float = 1.0
var _age: float = 0.0
var _swing_progress: float = 0.0
var _swing_angle: float = 0.0
var _ignited: bool = false


func _ready() -> void:
    active = false
    set_physics_process(false)
    set_process(false)
    visible = false


func start(weapon: Weapon, main: Node, origin: Vector2, direction: float, side: float, effect: Resource) -> void:
    from = weapon
    _main = main
    _side = side
    _swing_angle = -_side * CONFIG.ECHO_HALF_ANGLE
    _radius = min(max(88.0, weapon.current_stats.max_range) * CONFIG.ECHO_RANGE_MULTIPLIER, 180.0 * CONFIG.ECHO_MAX_SCALE)
    _collision.scale = Vector2.ONE * _radius / 180.0
    set_as_toplevel(true)
    global_transform = Transform2D(direction, origin)
    var args = Hitbox.HitboxArgs.new().set_from_weapon_stats(weapon.current_stats)
    args.scaling_stats = effect.get_scaling_stats()
    set_damage(effect.get_damage(weapon.player_index), args)
    effects = weapon.effects.duplicate()
    effect_scale = weapon._hitbox.effect_scale
    speed_percent_modifier = weapon._hitbox.speed_percent_modifier
    projectiles_on_hit = weapon._hitbox.projectiles_on_hit
    damage_tracking_key_hash = weapon._hitbox.damage_tracking_key_hash
    player_attack_id = weapon._hitbox.player_attack_id
    set_knockback(Vector2.RIGHT.rotated(direction), weapon.current_stats.knockback, weapon.current_stats.knockback_piercing)
    set_meta("fantasy_damage_color", Color("dca6ff"))
    connect("hit_something", self, "_on_echo_hit")
    connect("hit_something", weapon, "on_weapon_hit_something", [self])
    WeaponService.fantasy_connect_hitbox_events(self, weapon)
    _sweep.scale = Vector2.ONE * _radius / 230.0
    _sweep.material.set_shader_param("side", side)
    _sweep.material.set_shader_param("half_angle", CONFIG.ECHO_HALF_ANGLE)
    _bones.flip_v = side < 0.0
    _flames.flip_v = _bones.flip_v
    _update_visuals()
    set_physics_process(true)
    set_process(true)


func _source_is_active() -> bool:
    return is_instance_valid(from) and not from.is_queued_for_deletion() and from.is_physics_processing() \
        and not from._parent.dead and not from._parent.cleaning_up and is_instance_valid(_main) and not _main._cleaning_up


func _physics_process(delta: float) -> void:
    if not _source_is_active():
        active = false
        queue_free()
        return
    _age += delta
    _swing_progress = smoothstep(0.0, 1.0, clamp((_age - CONFIG.ECHO_DELAY) / CONFIG.ECHO_DURATION, 0.0, 1.0))
    _swing_angle = _side * lerp(-CONFIG.ECHO_HALF_ANGLE, CONFIG.ECHO_HALF_ANGLE, _swing_progress)
    _collision.position = Vector2.RIGHT.rotated(_swing_angle) * (_radius * 0.57 + 32.0 * _radius / 180.0)
    _collision.rotation = _swing_angle
    if _age >= CONFIG.ECHO_DELAY and _age < CONFIG.ECHO_DELAY + CONFIG.ECHO_DURATION:
        if not _ignited:
            _ignited = true
            active = true
            enable()
            SoundManager2D.play(ECHO_SOUND, global_position, -12.0, 0.08)
    elif active:
        active = false
        disable()
    if _age >= CONFIG.ECHO_DELAY + CONFIG.ECHO_DURATION + CONFIG.ECHO_FADE:
        queue_free()


func _on_echo_hit(thing_hit: Node, _damage_dealt: int) -> void:
    ignored_objects.append(thing_hit)


func _process(_delta: float) -> void:
    _update_visuals()


func _update_visuals() -> void:
    var opacity: float = ProgressData.settings.explosion_opacity
    visible = opacity > 0.0
    if not visible:
        _embers.emitting = false
        return
    var charge: float = clamp(_age / CONFIG.ECHO_DELAY, 0.0, 1.0)
    var fade: float = clamp((_age - CONFIG.ECHO_DELAY - CONFIG.ECHO_DURATION) / CONFIG.ECHO_FADE, 0.0, 1.0)
    var arrival: float = smoothstep(0.12, 0.95, charge)
    var scale_factor: float = _radius / 230.0
    var lift: Vector2 = Vector2.UP.rotated(-global_rotation) * smoothstep(0.0, 1.0, fade)
    _sigil.scale = Vector2(1.0, 0.72) * (0.42 + 0.24 * charge + 0.10 * fade)
    _sigil.rotation = -global_rotation - _side * (0.12 * charge + 0.22 * _swing_progress)
    _sigil.modulate.a = opacity * smoothstep(0.0, 0.25, charge) * (0.55 + sin(charge * PI) * 0.25) * pow(1.0 - fade, 2.0)
    _mist.scale = Vector2.ONE * scale_factor * (0.70 + 0.175 * charge + fade * 0.10)
    _mist.position = lift * 18.0
    _mist.rotation = _side * (-0.35 + charge * 0.2 + _swing_progress * 0.15)
    _mist.modulate = Color(0.65, 0.26, 1.0, opacity * 0.18 * arrival * (1.0 - smoothstep(0.0, 0.75, fade)))
    _mist.material.set_shader_param("phase", _age)
    _mist.material.set_shader_param("release", fade)
    _hand.position = Vector2.RIGHT.rotated(_swing_angle) * _radius * (0.48 + arrival * 0.09)
    _hand.position += lift * 38.0
    _hand.rotation = _swing_angle + _side * smoothstep(0.0, 1.0, fade) * 0.10
    _hand.scale = Vector2.ONE * (_radius / 180.0) * (0.55 + arrival * 0.45)
    _hand.modulate.a = opacity * arrival
    _bones.modulate.a = 1.0 - smoothstep(0.02, 0.55, fade)
    _flames.modulate.a = 1.0 - smoothstep(0.12, 1.0, fade)
    _flames.scale = Vector2(0.5 * (1.0 - fade * 0.30), 0.5 * (1.0 + sin(fade * PI) * 0.12))
    _flames.material.set_shader_param("phase", _age * 1.35)
    _flames.material.set_shader_param("charge", 0.7 + sin(_swing_progress * PI) * 0.3)
    _flames.material.set_shader_param("release", fade)
    _embers.emitting = _ignited and _age < CONFIG.ECHO_DELAY + CONFIG.ECHO_DURATION + 0.10
    _sweep.visible = _ignited
    _sweep.modulate.a = opacity * 0.82 * (1.0 - smoothstep(0.0, 0.90, fade))
    _sweep.material.set_shader_param("progress", _swing_progress)
    _sweep.material.set_shader_param("release", fade)
