extends "res://weapons/ranged/ranged_weapon.gd"

const VFX = preload("res://mods-unpacked/Yoko-Fantasy/content/projectiles/player/longinus_projectile/longinus_vfx_utils.gd")

const TASER_SOUND = preload("res://weapons/ranged/taser/taser.wav")

const MUZZLE_FLASH_DURATION: float = 0.30
const TIP_ARC_INTERVAL: float = 0.055
const MUZZLE_ARC_INTERVAL: float = 0.035

var _time: float = 0.0
var _charge: float = 0.0
var _flash: float = 0.0
var _kick: float = 0.0
var _tip_arc_timer: float = 0.0
var _muzzle_arc_timer: float = 0.0
var _aim_visibility: float = 0.0
var _aura_base_alpha: float = 0.18
var _tip_glow_base_scale: Vector2 = Vector2.ONE
var _tip_star_base_scale: Vector2 = Vector2.ONE
var _charge_ring_base_scale: Vector2 = Vector2.ONE
var _muzzle_flare_base_scale: Vector2 = Vector2.ONE
var _muzzle_glow_base_scale: Vector2 = Vector2.ONE
var _muzzle_ring_base_scale: Vector2 = Vector2.ONE
var _muzzle_beam_base_scale: Vector2 = Vector2.ONE

onready var _aura: Sprite = $Sprite/Aura
onready var _tip_fx: Node2D = $Sprite/TipFX
onready var _muzzle_fx: Node2D = $Sprite/MuzzleFX
onready var _tip_glow: Sprite = $Sprite/TipFX/TipGlow
onready var _tip_star: Sprite = $Sprite/TipFX/TipStar
onready var _charge_ring: Sprite = $Sprite/TipFX/ChargeRing
onready var _aim_beam: Line2D = $Sprite/TipFX/AimBeam
onready var _tip_arcs: Array = [$Sprite/TipFX/Arcs/Arc0, $Sprite/TipFX/Arcs/Arc1, $Sprite/TipFX/Arcs/Arc2]
onready var _muzzle_flare: Sprite = $Sprite/MuzzleFX/Flare
onready var _muzzle_glow: Sprite = $Sprite/MuzzleFX/Glow
onready var _muzzle_ring: Sprite = $Sprite/MuzzleFX/Ring
onready var _muzzle_beam: Sprite = $Sprite/MuzzleFX/Beam
onready var _muzzle_sparks: CPUParticles2D = $Sprite/MuzzleFX/Sparks
onready var _muzzle_arcs: Array = [
    $Sprite/MuzzleFX/Arcs/ArcGlowA,
    $Sprite/MuzzleFX/Arcs/ArcCoreA,
    $Sprite/MuzzleFX/Arcs/ArcGlowB,
    $Sprite/MuzzleFX/Arcs/ArcCoreB,
]


func _ready() -> void:
    if is_instance_valid(_hitbox):
        _hitbox.set_meta("fantasy_damage_color", VFX.DAMAGE_COLOR)
    _aura_base_alpha = _aura.modulate.a
    _tip_glow_base_scale = _tip_glow.scale
    _tip_star_base_scale = _tip_star.scale
    _charge_ring_base_scale = _charge_ring.scale
    _muzzle_flare_base_scale = _muzzle_flare.scale
    _muzzle_glow_base_scale = _muzzle_glow.scale
    _muzzle_ring_base_scale = _muzzle_ring.scale
    _muzzle_beam_base_scale = _muzzle_beam.scale
    for arc in _tip_arcs:
        arc.width_curve = VFX.TAPER_CURVE
    for arc in _muzzle_arcs:
        arc.width_curve = VFX.TAPER_CURVE
    _hide_muzzle_fx()
    _sync_opacity()


func _process(delta: float) -> void:
    _time += delta
    _update_charge(delta)
    _update_tip_visuals(delta)
    _update_tip_arcs(delta)
    _update_muzzle_flash(delta)
    _update_aim_beam(delta)
    _sync_opacity()


func _sync_opacity() -> void:
    var opacity: float = ProgressData.settings.projectile_opacity
    _tip_fx.modulate.a = opacity
    _muzzle_fx.modulate.a = opacity
    _aura.modulate.a = (_aura_base_alpha + _charge * 0.10 + 0.025 * sin(_time * 4.4)) * opacity


func _update_charge(delta: float) -> void:
    if current_stats == null:
        return
    var cooldown_basis: float = max(1.0, float(current_stats.cooldown))
    var target_charge: float = clamp(1.0 - _current_cooldown / cooldown_basis, 0.0, 1.0)
    _charge = lerp(_charge, target_charge, clamp(delta * 6.0, 0.0, 1.0))


func _update_tip_visuals(delta: float) -> void:
    var ready_pulse: float = 0.5 + 0.5 * sin(_time * 9.0)
    var charge_alpha: float = 0.30 + _charge * 0.55
    _tip_glow.scale = _tip_glow_base_scale * (0.92 + 0.10 * sin(_time * 6.2) + _charge * 0.16)
    _tip_glow.modulate = Color(1.0, 0.94 - _charge * 0.02, 0.58 + _charge * 0.20, charge_alpha * (0.82 + 0.18 * ready_pulse))
    _tip_star.rotation += delta * (1.3 + _charge * 2.8)
    _tip_star.scale = _tip_star_base_scale * (0.76 + _charge * 0.62 + 0.06 * sin(_time * 11.0))
    _tip_star.modulate = Color(1.0, 0.99, 0.92, (0.42 + _charge * 0.48) * (0.82 + 0.18 * ready_pulse))
    if _charge > 0.03:
        _charge_ring.visible = true
        _charge_ring.rotation += delta * (0.6 + _charge * 2.6)
        _charge_ring.scale = _charge_ring_base_scale * (0.24 + _charge * 0.94 + 0.04 * sin(_time * 7.0))
        _charge_ring.modulate = Color(1.0, 0.86, 0.45, _charge * 0.82)
    else:
        _charge_ring.visible = false

    _aura.rotation += delta * 0.55

    if _kick > 0.0:
        _kick = max(0.0, _kick - delta * 7.5)
    var kick_scale := Vector2(1.0 + _kick * 0.10, 1.0 - _kick * 0.06)
    var charge_bulge := 1.0 + _charge * 0.018 * sin(_time * 5.0)
    sprite.scale = kick_scale * charge_bulge


func _update_tip_arcs(delta: float) -> void:
    _tip_arc_timer -= delta
    if _tip_arc_timer > 0.0:
        return
    _tip_arc_timer = TIP_ARC_INTERVAL
    for i in range(_tip_arcs.size()):
        var arc: Line2D = _tip_arcs[i]
        if randf() > 0.48 + _charge * 0.26:
            arc.points = PoolVector2Array()
            continue
        var start := Vector2(rand_range(-10.0, 4.0), rand_range(-9.0, 9.0))
        var end := Vector2(rand_range(36.0, 88.0), rand_range(-34.0, 34.0))
        arc.points = VFX.jagged_points(start, end, int(rand_range(5, 8)), rand_range(5.0, 12.0))
        arc.width = 2.4 + float(i) * 0.8
        arc.modulate = Color(1.0, 0.92, 0.64, (0.26 + _charge * 0.50) * (0.55 + 0.45 * abs(sin(_time * 17.0 + float(i)))))


func _update_muzzle_flash(delta: float) -> void:
    if _flash <= 0.0:
        return

    _flash = max(0.0, _flash - delta)
    var progress: float = 1.0 - clamp(_flash / MUZZLE_FLASH_DURATION, 0.0, 1.0)
    var fade: float = pow(1.0 - progress, 2.0)
    var ease_out: float = 1.0 - pow(1.0 - progress, 3.0)

    _muzzle_flare.visible = true
    _muzzle_flare.scale = _muzzle_flare_base_scale * (1.0 + ease_out * 1.8) * (0.92 + randf() * 0.16)
    _muzzle_flare.rotation += delta * 3.0
    _muzzle_flare.modulate = Color(1.0, 0.98, 0.88, 0.96 * fade)

    _muzzle_glow.visible = true
    _muzzle_glow.scale = _muzzle_glow_base_scale * (1.0 + ease_out * 2.2)
    _muzzle_glow.modulate = Color(1.0, 0.88, 0.45, 0.78 * fade)

    _muzzle_ring.visible = true
    _muzzle_ring.scale = _muzzle_ring_base_scale * (0.8 + ease_out * 2.4)
    _muzzle_ring.modulate = Color(1.0, 0.88, 0.52, 0.68 * fade * fade)

    _muzzle_beam.visible = true
    _muzzle_beam.scale = Vector2(
        _muzzle_beam_base_scale.x * (1.0 + ease_out * 1.2),
        _muzzle_beam_base_scale.y * (1.0 - progress * 0.25)
    )
    _muzzle_beam.modulate = Color(1.0, 0.95, 0.7, 0.72 * fade)

    _muzzle_arc_timer -= delta
    if _muzzle_arc_timer <= 0.0:
        _muzzle_arc_timer = MUZZLE_ARC_INTERVAL
        _rebuild_muzzle_arcs()

    for i in range(_muzzle_arcs.size()):
        var arc: Line2D = _muzzle_arcs[i]
        var alpha: float = (0.72 if i % 2 == 0 else 0.95) * fade
        arc.modulate = Color(1.0, 0.88 if i % 2 == 0 else 0.99, 0.55 if i % 2 == 0 else 0.82, alpha)

    if _flash <= 0.0:
        _hide_muzzle_fx()


func _rebuild_muzzle_arcs() -> void:
    if _flash <= 0.0:
        return
    var progress: float = 1.0 - clamp(_flash / MUZZLE_FLASH_DURATION, 0.0, 1.0)
    var length_scale: float = 1.0 - progress * 0.45
    for i in range(0, _muzzle_arcs.size(), 2):
        var glow: Line2D = _muzzle_arcs[i]
        var core: Line2D = _muzzle_arcs[i + 1]
        var start := Vector2(rand_range(2.0, 12.0), rand_range(-5.0, 5.0))
        var end := Vector2(rand_range(78.0, 172.0) * length_scale, rand_range(-46.0, 46.0))
        var points: PoolVector2Array = VFX.jagged_points(start, end, int(rand_range(5, 8)), rand_range(7.0, 16.0))
        glow.points = points
        core.points = points
        glow.width = rand_range(9.0, 15.0)
        core.width = rand_range(2.3, 3.8)
        glow.visible = true
        core.visible = true


func _update_aim_beam(delta: float) -> void:
    var target_visibility: float = 1.0 if _charge > 0.93 and _current_cooldown <= 2.0 else 0.0
    _aim_visibility = lerp(_aim_visibility, target_visibility, clamp(delta * 7.0, 0.0, 1.0))
    _aim_beam.visible = _aim_visibility > 0.01
    _aim_beam.modulate = Color(1.0, 0.94, 0.62, _aim_visibility * (0.24 + 0.12 * abs(sin(_time * 10.0))))
    _aim_beam.width = 5.0 + 1.4 * sin(_time * 8.0)


func shoot() -> void:
    .shoot()
    _flash = MUZZLE_FLASH_DURATION
    _muzzle_arc_timer = 0.0
    _kick = 1.0
    _sync_opacity()
    _update_muzzle_flash(0.0)
    _muzzle_sparks.visible = true
    _muzzle_sparks.emitting = true
    _muzzle_sparks.restart()

    var main = Utils.get_scene_node()
    if main != null and is_instance_valid(main) and "_screenshaker" in main and main._screenshaker != null:
        main._screenshaker.shake(1.35, 0.055)
    if is_instance_valid(muzzle):
        SoundManager2D.play(TASER_SOUND, muzzle.global_position, -7.0, 0.10)


func _hide_muzzle_fx() -> void:
    _muzzle_flare.visible = false
    _muzzle_glow.visible = false
    _muzzle_ring.visible = false
    _muzzle_beam.visible = false
    for arc in _muzzle_arcs:
        arc.points = PoolVector2Array()
        arc.visible = false
    _muzzle_sparks.emitting = false
    _muzzle_sparks.visible = false
