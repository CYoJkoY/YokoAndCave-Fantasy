extends Node2D

const AFTERLIGHT_DURATION: float = 0.55
const CRYSTAL_ORBIT_RADIUS: float = 134.0
const RING_RELEASE_DURATION: float = 0.72
const RING_RELEASE_SWEEP: float = TAU * 0.875

var _time: float = 0.0
var _charge_target: float = 0.0
var _charge: float = 0.0
var _shot_age: float = AFTERLIGHT_DURATION
var _ascent: float = 0.0
var _active: bool = true
var _aim_target: float = PI * 0.5
var _aim_angle: float = PI * 0.5
var _link_energy: float = 0.0
var _orbit_phase: float = 0.0
var _orbit_speed: float = 0.18
var _ring_phase: float = 0.0
var _ring_energy: float = 0.0
var _ring_pulse: float = 0.0
var _ring_flow: float = 0.0
var _ring_speed: float = 0.45
var _ring_releases: Array = [Vector2(0.0, RING_RELEASE_DURATION), Vector2(0.0, RING_RELEASE_DURATION), Vector2(0.0, RING_RELEASE_DURATION)]
var _ring_release_index: int = 0

onready var _core: Node2D = $Core
onready var _body: Sprite = $Core/Body
onready var _facets: Sprite = $Core/Facets
onready var _halo: Sprite = $Radiance/Halo
onready var _halo_inner: Sprite = $Radiance/InnerHalo
onready var _aura: Sprite = $Radiance/Aura
onready var _rays: Sprite = $Radiance/Rays
onready var _corona: Sprite = $Radiance/Corona
onready var _corners: Array = [$Orbit/TopLeft, $Orbit/TopRight, $Orbit/BottomRight, $Orbit/BottomLeft]
onready var _glints: Array = [$Orbit/TopLeft/Glint, $Orbit/TopRight/Glint, $Orbit/BottomRight/Glint, $Orbit/BottomLeft/Glint]
onready var _motes: CPUParticles2D = $Radiance/Motes
onready var _radiance: Node2D = $Radiance
onready var _conduits: Node2D = $Conduits
onready var _streams: Array = [$Conduits/TopLeft, $Conduits/TopRight, $Conduits/BottomRight, $Conduits/BottomLeft]


func _ready() -> void:
    for corner in _corners:
        var texture_size: Vector2 = corner.texture.get_size()
        var region: Rect2 = corner.region_rect
        corner.material.set_shader_param("region", Color(region.position.x / texture_size.x, region.position.y / texture_size.y, region.size.x / texture_size.x, region.size.y / texture_size.y))


func set_active(active: bool) -> void:
    if _active == active:
        return
    _active = active
    _motes.emitting = active and _ascent > 0.72
    if not active:
        _charge = 0.0
        _charge_target = 0.0
        _shot_age = AFTERLIGHT_DURATION
        _link_energy = 0.0
        _ring_energy = 0.0
        _ring_pulse = 0.0
        _ring_flow = 0.0
        _ring_speed = 0.45
        _ring_release_index = 0
        for i in range(_ring_releases.size()):
            _ring_releases[i] = Vector2(0.0, RING_RELEASE_DURATION)
        _orbit_speed = 0.18
        for stream in _streams:
            stream.modulate.a = 0.0


func set_ascent(ascent: float) -> void:
    _ascent = ascent


func set_charge(charge: float) -> void:
    _charge_target = charge


func aim_at(target: Vector2) -> void:
    _aim_target = (target - global_position).angle() - global_rotation


func get_emitter() -> Node2D:
    return _core


func flash() -> void:
    _shot_age = 0.0
    _charge_target = 0.0
    _ring_pulse += (1.0 - _ring_pulse) * 0.92
    _ring_releases[_ring_release_index] = Vector2(_aim_target, 0.0)
    _ring_release_index = (_ring_release_index + 1) % _ring_releases.size()


func _process(delta: float) -> void:
    if not _active:
        return
    _time += delta
    _shot_age = min(AFTERLIGHT_DURATION, _shot_age + delta)
    _charge = lerp(_charge, _charge_target, 1.0 - exp(-delta * 22.0))
    _aim_angle = lerp_angle(_aim_angle, _aim_target, 1.0 - exp(-delta * 14.0))
    var shot_light: float = smoothstep(0.0, 0.018, _shot_age) * (1.0 - smoothstep(0.055, AFTERLIGHT_DURATION, _shot_age))
    var focus: float = smoothstep(0.0, 1.0, _charge)
    _ring_pulse *= exp(-delta * 4.5)
    _ring_energy = lerp(_ring_energy, max(focus * 0.95, _ring_pulse), 1.0 - exp(-delta * 14.0))
    _ring_flow = lerp(_ring_flow, _ring_energy, 1.0 - exp(-delta * 4.0))
    _ring_speed = lerp(_ring_speed, 0.45 + _ring_flow * 2.4, 1.0 - exp(-delta * 4.0))
    _ring_phase += delta * _ring_speed
    var release_progress := Vector3.ONE
    var release_direction_x := Vector3.ZERO
    var release_direction_y := Vector3.ZERO
    for i in range(_ring_releases.size()):
        var release: Vector2 = _ring_releases[i]
        release.y = min(RING_RELEASE_DURATION, release.y + delta)
        _ring_releases[i] = release
        var progress: float = release.y / RING_RELEASE_DURATION
        var travel: float = progress * 0.95 + smoothstep(0.0, 1.0, progress) * 0.05
        var release_angle: float = release.x + travel * RING_RELEASE_SWEEP
        release_progress[i] = progress
        release_direction_x[i] = cos(release_angle)
        release_direction_y[i] = sin(release_angle)
    var cast_phase: float = lerp(-0.25, 1.25, _shot_age / AFTERLIGHT_DURATION)
    _orbit_speed = lerp(_orbit_speed, 0.18 + focus * 1.25 + shot_light * 0.75, 1.0 - exp(-delta * 8.0))
    _orbit_phase += delta * _orbit_speed
    _link_energy = lerp(_link_energy, max(focus, shot_light * 0.7), 1.0 - exp(-delta * 20.0))
    var relay_phase: float = _charge_target
    if _charge_target == 0.0 and _shot_age < 0.22:
        relay_phase = 1.0 + _shot_age * 2.5
    var core_reveal: float = smoothstep(0.02, 0.18, _ascent)
    var birth_light: float = smoothstep(0.02, 0.06, _ascent) * (1.0 - smoothstep(0.10, 0.26, _ascent))
    modulate.a = smoothstep(0.0, 0.06, _ascent)
    _core.modulate.a = core_reveal
    _body.material.set_shader_param("phase", _time)
    _body.material.set_shader_param("energy", focus * 0.55 + shot_light * 1.1 + birth_light * 0.7)
    _body.material.set_shader_param("cast_phase", lerp(-0.25, 1.25, clamp(_ascent / 0.26, 0.0, 1.0)) if _ascent < 0.26 else cast_phase)
    _facets.modulate.a = (0.32 + focus * 0.34 + shot_light * 0.54 + birth_light * 0.4) * ProgressData.settings.projectile_opacity
    for i in range(_corners.size()):
        var corner: Sprite = _corners[i]
        var initial_angle: float = -PI * 0.75 + float(i) * PI * 0.5
        var angle: float = initial_angle + _orbit_phase
        var depth: float = sin(angle)
        corner.position = Vector2(cos(angle), depth * 0.82) * CRYSTAL_ORBIT_RADIUS
        corner.rotation = corner.position.angle() + PI - initial_angle
        corner.z_index = 2 if depth > 0.0 else -1
        var reveal_start: float = 0.24 + float(i) * 0.085
        var reveal: float = smoothstep(reveal_start, reveal_start + 0.16, _ascent)
        var birth_glint: float = sin(reveal * PI) if reveal < 1.0 else 0.0
        corner.modulate.a = reveal
        var transfer: float = (relay_phase - float(i) * 0.09) / 0.68
        var relay: float = clamp(transfer, 0.0, 1.0)
        var lens_light: float = sin(relay * PI) * _link_energy
        corner.material.set_shader_param("phase", _time + float(i) * 0.6)
        corner.material.set_shader_param("energy", lens_light * 1.2 + shot_light * 0.45 + birth_glint * 0.9)
        var facet_phase: float = lerp(-0.2, 1.2, relay) if _charge_target > 0.0 else cast_phase
        corner.material.set_shader_param("cast_phase", lerp(-0.2, 1.2, reveal) if reveal < 1.0 else facet_phase)
        _glints[i].modulate = Color.from_hsv(fmod(float(i) * 0.24 + 0.52, 1.0), 0.28, 1.0, (lens_light * 0.95 + shot_light * 0.38 + birth_glint * 0.7) * ProgressData.settings.explosion_opacity)
        _glints[i].rotation = -corner.rotation + _time * 0.35
        var direction: Vector2 = corner.position.normalized()
        var start: Vector2 = corner.position - direction * 18.0
        var end: Vector2 = direction * 22.0
        var stream: Sprite = _streams[i]
        stream.position = (start + end) * 0.5
        stream.rotation = (end - start).angle()
        stream.scale.x = start.distance_to(end) / 256.0
        var feed: float = smoothstep(0.02, 0.28, transfer) * (1.0 - smoothstep(0.96, 1.5, transfer))
        feed = max(feed, birth_glint * 0.45)
        stream.modulate.a = lerp(stream.modulate.a, feed, 1.0 - exp(-delta * 24.0))
        stream.material.set_shader_param("phase", _time + float(i) * 0.37)
        stream.material.set_shader_param("progress", reveal if _ascent < 1.0 else transfer)
    _radiance.modulate.a = ProgressData.settings.explosion_opacity
    _conduits.modulate.a = ProgressData.settings.explosion_opacity
    _motes.emitting = _ascent > 0.72
    _motes.modulate.a = smoothstep(0.72, 0.96, _ascent)
    _pose_ring(_halo, -0.18 + _time * 0.055, 1.0, _orbit_phase * 0.85, 0.94)
    _pose_ring(_halo_inner, 0.82 - _time * 0.045, 0.36, -_orbit_phase * 1.1, 0.73)
    var halo_reveal: float = smoothstep(0.50, 0.86, _ascent)
    var inner_reveal: float = smoothstep(0.62, 0.96, _ascent)
    _halo.modulate.a = 0.70 * smoothstep(0.0, 0.10, halo_reveal)
    _halo_inner.modulate.a = 0.52 * smoothstep(0.0, 0.10, inner_reveal)
    _halo.material.set_shader_param("reveal", halo_reveal)
    _halo_inner.material.set_shader_param("reveal", inner_reveal)
    _halo.material.set_shader_param("phase", _time)
    _halo.material.set_shader_param("energy", _ring_energy * 0.55 + _ring_flow * 0.45)
    _set_ring_sweep(_halo, _ring_phase, release_progress, release_direction_x, release_direction_y)
    _halo_inner.material.set_shader_param("phase", -_time * 0.8 + 2.0)
    _halo_inner.material.set_shader_param("energy", _ring_flow * 0.85)
    _set_ring_sweep(_halo_inner, -_ring_phase * 0.75, release_progress, release_direction_x, release_direction_y)
    _aura.modulate.a = (0.14 + focus * 0.08 + shot_light * 0.14) * smoothstep(0.12, 0.45, _ascent)
    _rays.rotation = -_orbit_phase * 0.4
    _rays.modulate.a = (0.22 + focus * 0.16 + shot_light * 0.35) * smoothstep(0.40, 0.75, _ascent)
    _corona.rotation = _aim_angle
    _corona.modulate.a = focus * focus * 0.58 + shot_light * 0.95 + birth_light * 0.4


func _pose_ring(ring: Sprite, angle: float, tilt: float, spin: float, radius: float) -> void:
    var x_axis: Vector2 = Vector2(cos(spin), sin(spin) * tilt).rotated(angle) * radius
    var y_axis: Vector2 = Vector2(-sin(spin), cos(spin) * tilt).rotated(angle) * radius
    ring.transform = Transform2D(x_axis, y_axis, Vector2.ZERO)


func _set_ring_sweep(ring: Sprite, angle: float, release_progress: Vector3, release_direction_x: Vector3, release_direction_y: Vector3) -> void:
    var inverse: Transform2D = ring.transform.affine_inverse()
    var local_direction: Vector2 = inverse.basis_xform(Vector2(cos(angle), sin(angle)))
    ring.material.set_shader_param("sweep_angle", local_direction.angle())
    var release_angles := Vector3.ZERO
    for i in range(_ring_releases.size()):
        var release_direction: Vector2 = inverse.basis_xform(Vector2(release_direction_x[i], release_direction_y[i]))
        release_angles[i] = release_direction.angle()
    ring.material.set_shader_param("release_angles", release_angles)
    ring.material.set_shader_param("release_progress", release_progress)
