extends "res://weapons/ranged/ranged_weapon.gd"

const FANTASY_PROJECTILE_VISUAL_UTILS = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/utils/projectile_visual_utils.gd")

const CAST_BURST_SCENE = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/weapons/ranged/eightfold_inferno/vfx/eightfold_inferno_cast_burst.tscn")
const HIT_BURST_SCENE = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/weapons/ranged/eightfold_inferno/vfx/eightfold_inferno_hit_burst.tscn")

const HIT_SOUNDS = [
    preload("res://resources/sounds/burn/fireball_impact_burn_01.wav"),
    preload("res://resources/sounds/burn/fireball_impact_burn_02.wav"),
    preload("res://resources/sounds/burn/fireball_impact_burn_03.wav"),
    preload("res://resources/sounds/burn/fireball_impact_burn_04.wav"),
]

const HIT_TICK_INTERVAL: float = 1.0 / 3.0
const HIT_VFX_INTERVAL: float = 0.045
const HIT_SOUND_INTERVAL: float = 0.18

var _time: float = 0.0
var _combat_time: float = 0.0
var _float_phase: float = 0.0
var _cast_energy: float = 0.0
var _cast_glint: float = 0.0

var _base_sprite_position: Vector2 = Vector2.ZERO
var _base_sprite_scale: Vector2 = Vector2.ONE
var _aura_base_scale: Vector2 = Vector2.ONE
var _flames_back_base_scale: Vector2 = Vector2.ONE
var _flames_front_base_scale: Vector2 = Vector2.ONE
var _cast_glint_base_scale: Vector2 = Vector2.ONE

var _last_hit_vfx_time: float = -100.0
var _last_hit_sound_time: float = -100.0
var _damage_tick: int = 0
var _hit_ids_this_tick: Dictionary = {}
var _trail_targets: Array = []
var _target_frame: int = -1

onready var _aura: Sprite = $Sprite/Aura
onready var _flames_back: Sprite = $Sprite/FlamesBack
onready var _flames_front: Sprite = $Sprite/FlamesFront
onready var _idle_embers: CPUParticles2D = $Sprite/IdleEmbers
onready var _cast_glint_sprite: Sprite = $Sprite/CastGlint


func _ready() -> void:
    _float_phase = float(weapon_pos) * 2.399963 + float(player_index) * 0.73
    _base_sprite_position = sprite.position
    _base_sprite_scale = sprite.scale
    _aura_base_scale = _aura.scale
    _flames_back_base_scale = _flames_back.scale
    _flames_front_base_scale = _flames_front.scale
    _cast_glint_base_scale = _cast_glint_sprite.scale
    _cast_glint_sprite.visible = false
    _flames_back.material.set_shader_param("seed", 2.0 + float(weapon_pos) * 1.7)
    _flames_front.material.set_shader_param("seed", 7.0 + float(weapon_pos) * 1.3)
    _idle_embers.emitting = true


func _process(delta: float) -> void:
    _time += delta

    var opacity: float = FANTASY_PROJECTILE_VISUAL_UTILS.get_opacity()
    var cooldown_basis: float = max(1.0, float(current_stats.cooldown))
    var charge: float = clamp(1.0 - _current_cooldown / cooldown_basis, 0.0, 1.0)
    charge = pow(charge, 1.35)
    _cast_energy = max(0.0, _cast_energy - delta * 3.2)
    _cast_glint = max(0.0, _cast_glint - delta * 5.2)

    var breathe: float = sin(_time * 2.45 + _float_phase)
    var bob: float = sin(_time * 2.2 + _float_phase) * 2.0 + sin(_time * 4.9 + _float_phase * 1.3) * 0.7
    var facing: float = -1.0 if sprite.flip_v else 1.0
    sprite.position = Vector2(_base_sprite_position.x, _base_sprite_position.y * facing) + Vector2(sin(_time * 1.25 + _float_phase) * 1.0, bob)
    sprite.scale = _base_sprite_scale * (1.0 + 0.024 * breathe + 0.052 * _cast_energy)
    sprite.rotation = sin(_time * 1.55 + _float_phase) * 0.034 + sin(_time * 3.1 + _float_phase * 0.7) * 0.009
    sprite.rotation += _cast_energy * 0.035

    _aura.scale = _aura_base_scale * (1.0 + 0.055 * breathe + 0.14 * charge + 0.22 * _cast_energy)
    _aura.modulate = Color(1.0, 0.36, 0.06, opacity * (0.20 + 0.055 * breathe + 0.16 * charge + 0.18 * _cast_energy))

    _flames_back.rotation = -_time * 0.18 + sin(_time * 2.0 + _float_phase) * 0.022 + _cast_energy * 0.12
    _flames_back.scale = _flames_back_base_scale * (1.02 + 0.032 * breathe + 0.085 * charge + 0.12 * _cast_energy)
    _flames_back.modulate = Color(1.0, 0.68, 0.48, opacity * (0.62 + 0.08 * charge + 0.12 * _cast_energy))
    _flames_back.material.set_shader_param("age", _time)
    _flames_back.material.set_shader_param("energy", charge * 0.55 + _cast_energy * 0.9)
    _flames_back.material.set_shader_param("strength", 0.85 + 0.15 * charge + 0.2 * _cast_energy)

    _flames_front.rotation = _time * 0.15 + sin(_time * 2.7 + _float_phase * 1.4) * 0.018 - _cast_energy * 0.1
    _flames_front.scale = _flames_front_base_scale * (1.0 + 0.026 * breathe + 0.06 * charge + 0.09 * _cast_energy)
    _flames_front.modulate = Color(1.0, 0.86, 0.68, opacity * (0.20 + 0.05 * charge + 0.16 * _cast_energy))
    _flames_front.material.set_shader_param("age", _time + 1.7)
    _flames_front.material.set_shader_param("energy", charge * 0.4 + _cast_energy * 0.7)
    _flames_front.material.set_shader_param("strength", 0.55 + 0.1 * charge + 0.15 * _cast_energy)

    _idle_embers.emitting = opacity > 0.0
    _idle_embers.modulate.a = opacity * (0.55 + 0.2 * charge + 0.1 * _cast_energy)
    _idle_embers.position = Vector2(0, -2 + sin(_time * 1.7 + _float_phase) * 1.5)

    _cast_glint_sprite.visible = _cast_glint > 0.015
    _cast_glint_sprite.modulate = Color(1.0, 0.9, 0.62, opacity * _cast_glint)
    _cast_glint_sprite.scale = _cast_glint_base_scale * (0.65 + 0.75 * _cast_glint)
    _cast_glint_sprite.rotation += delta * 3.1


func _physics_process(delta: float) -> void:
    _combat_time += delta
    var tick: int = int(floor((_combat_time + 0.000001) / HIT_TICK_INTERVAL))
    if tick != _damage_tick:
        _damage_tick = tick
        _hit_ids_this_tick.clear()


func update_current_spread() -> void:
    _current_shoot_spread = 0.0


func shoot() -> void:
    if not is_instance_valid(_parent) or _parent.dead or _parent.cleaning_up:
        set_shooting(false)
        return
    .shoot()
    _cast_energy = 1.0
    _cast_glint = 1.0
    _spawn_cast_burst()
    _shake_screen()


func update_sprite_flipv() -> void:
    .update_sprite_flipv()
    _flames_back.flip_v = sprite.flip_v
    _flames_front.flip_v = sprite.flip_v
    var facing: float = -1.0 if sprite.flip_v else 1.0
    muzzle.position.y = 25.0 * facing
    _cast_glint_sprite.position = muzzle.position
    _flames_back.position.y = -2.0 * facing
    _flames_front.position.y = -2.0 * facing


func get_damage_tick() -> int:
    return _damage_tick


func get_trail_targets(main: Node) -> Array:
    var frame: int = Engine.get_physics_frames()
    if _target_frame != frame:
        _target_frame = frame
        _trail_targets.clear()
        for enemy in main._entity_spawner.get_all_enemies(false):
            if not is_instance_valid(enemy) or enemy.dead or enemy._pending_die:
                continue
            var collision: CollisionShape2D = enemy._hurtbox._collision
            if collision.disabled:
                continue
            var shape: CircleShape2D = collision.shape
            var transform: Transform2D = collision.global_transform
            var radius: float = shape.radius * max(transform.x.length(), transform.y.length())
            _trail_targets.append([enemy, collision.global_position, radius])
    return _trail_targets


func has_hit_this_tick(enemy: Node) -> bool:
    return _hit_ids_this_tick.has(enemy.get_instance_id())


func mark_hit_this_tick(enemy: Node) -> void:
    _hit_ids_this_tick[enemy.get_instance_id()] = true


func play_hit_feedback(hit_position: Vector2, is_critical: bool) -> void:
    var now: float = _combat_time
    if now - _last_hit_vfx_time >= HIT_VFX_INTERVAL:
        _last_hit_vfx_time = now
        var scale_mult: float = 1.22 if is_critical else 1.0
        var main = Utils.get_scene_node()
        var burst = FANTASY_PROJECTILE_VISUAL_UTILS.get_pooled_effect(HIT_BURST_SCENE, main)
        burst.play(hit_position, main, HIT_BURST_SCENE.get_instance_id(), scale_mult, is_critical)
    if now - _last_hit_sound_time >= HIT_SOUND_INTERVAL:
        _last_hit_sound_time = now
        SoundManager2D.play(Utils.get_rand_element(HIT_SOUNDS), hit_position, -15.0, 0.15)


func _spawn_cast_burst() -> void:
    var main = Utils.get_scene_node()
    if main == null or not is_instance_valid(main):
        return
    var burst = FANTASY_PROJECTILE_VISUAL_UTILS.get_pooled_ground_effect(CAST_BURST_SCENE, main)
    burst.play(get_cast_origin(), main, CAST_BURST_SCENE.get_instance_id())


func get_cast_origin() -> Vector2:
    return muzzle.global_position


func _shake_screen() -> void:
    var main = Utils.get_scene_node()
    if main != null and is_instance_valid(main) and "_screenshaker" in main and main._screenshaker != null:
        main._screenshaker.shake(1.6, 0.055)
