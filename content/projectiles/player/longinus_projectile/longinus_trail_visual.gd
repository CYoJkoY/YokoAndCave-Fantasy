extends Node2D

const VFX = preload("res://mods-unpacked/Yoko-Fantasy/content/projectiles/player/longinus_projectile/longinus_vfx_utils.gd")
const BRANCH_INTERVAL_MIN: float = 0.05
const BRANCH_INTERVAL_MAX: float = 0.11
const HEAD_PLUME_DURATION: float = 0.55

var _points: Array = []
var _elapsed: float = 0.0
var _emitting: bool = false
var _head_fade: float = 1.0
var _pulse: float = 0.0
var _geometry_dirty: bool = true
var _bolt_timer: float = 0.0
var _branch_timer: float = 0.0
var _arc_slots: Array = []
var _motes: Array = []
var _pulses: Array = []
var _head_plume_timer: float = 0.0
var _head_plume_dir: Vector2 = Vector2.RIGHT
var _head_plume_head: Vector2 = Vector2.ZERO
var _head_plume_length: float = 0.0

onready var _halo_line: Line2D = $HaloLine
onready var _glow_line: Line2D = $GlowLine
onready var _core_line: Line2D = $CoreLine
onready var _bolt_glow: Line2D = $BoltGlow
onready var _bolt_core: Line2D = $BoltCore
onready var _head_glow: Sprite = $HeadGlow
onready var _head_star: Sprite = $HeadStar
onready var _embers: CPUParticles2D = $Embers
onready var _head_plume_glow: Line2D = $HeadPlumeGlow
onready var _head_plume_core: Line2D = $HeadPlumeCore


func _ready() -> void:
    for arc in $ArcRoot.get_children():
        _arc_slots.append({"glow": arc.get_node("Glow"), "core": arc.get_node("Core"),
            "life": 0.0, "max_life": 0.16, "glow_alpha": 0.0, "core_alpha": 0.0})
    for sprite in $Motes.get_children():
        var mote := {"sprite": sprite}
        _respawn_mote(mote, 1)
        _motes.append(mote)
    for sprite in $Pulses.get_children():
        var pulse := {"sprite": sprite}
        _respawn_pulse(pulse)
        _pulses.append(pulse)
    reset()


func reset() -> void:
    visible = false
    _emitting = false
    _elapsed = 0.0
    _pulse = 0.0
    _head_fade = 1.0
    _bolt_timer = 0.0
    _branch_timer = 0.0
    _geometry_dirty = true
    _head_plume_dir = Vector2.RIGHT
    _points = []
    _clear_lines()
    _clear_arcs()
    _reset_motes()
    _hide_head_plume()
    _head_glow.visible = false
    _head_star.visible = false
    _embers.emitting = false


func begin(points: Array, opacity: float) -> void:
    reset()
    _points = points
    visible = opacity > 0.0
    _emitting = true
    _head_glow.visible = true
    _head_star.visible = true
    _head_glow.modulate.a = 0.0
    _head_star.modulate.a = 0.0
    _embers.visible = visible
    _embers.modulate = Color.white
    _embers.emitting = visible
    if visible:
        _embers.restart()


func path_changed() -> void:
    _geometry_dirty = true


func finish_emission() -> void:
    _emitting = false
    _embers.emitting = false
    if visible:
        _start_head_plume()


func advance(delta: float) -> void:
    if not visible:
        return
    _elapsed += delta
    _update_line_geometry(delta)
    _update_bolts(delta)
    _update_branches(delta)
    _update_arc_slots(delta)
    _update_motes(delta)
    _update_pulses(delta)
    _update_head_glow(delta)
    _update_head_plume(delta)
    _update_pulse(delta)


func flash_hit() -> void:
    _pulse = min(1.4, _pulse + 0.85)


func _update_line_geometry(_delta: float) -> void:
    var point_count: int = _points.size()

    if point_count < 2:
        _halo_line.visible = false
        _glow_line.visible = false
        _core_line.visible = false
        return

    _halo_line.visible = true
    _glow_line.visible = true
    _core_line.visible = true
    if _geometry_dirty:
        var points: PoolVector2Array = VFX.points_to_pool(_points)
        _halo_line.points = points
        _glow_line.points = points
        _core_line.points = points
        _geometry_dirty = false

    _halo_line.width = 84.0 + _pulse * 22.0
    _glow_line.width = 26.0 + _pulse * 8.0
    _core_line.width = 5.0 + _pulse * 2.0

    var pulse_alpha: float = 0.82 + 0.18 * sin(_elapsed * 7.0)
    _halo_line.modulate = Color(1.0, 0.78, 0.36, 0.24 * pulse_alpha + _pulse * 0.07)
    _glow_line.modulate = Color(1.0, 0.91, 0.58, 0.68 * pulse_alpha + _pulse * 0.09)
    _core_line.modulate = Color(1.0, 0.98, 0.88, 0.96)


func _update_bolts(delta: float) -> void:
    _bolt_timer -= delta
    if _points.size() < 2:
        _bolt_glow.points = PoolVector2Array()
        _bolt_core.points = PoolVector2Array()
        _bolt_glow.visible = false
        _bolt_core.visible = false
        return
    if _bolt_timer > 0.0:
        return

    _bolt_timer = rand_range(0.040, 0.066)
    var glow_points: PoolVector2Array = VFX.offset_polyline(_points, 14.0, _elapsed, 0.0, 9.0)
    var core_points: PoolVector2Array = VFX.offset_polyline(_points, 8.0, _elapsed, 2.7, 5.0)
    _bolt_glow.points = glow_points
    _bolt_core.points = core_points

    var flicker: float = 0.55 + 0.45 * abs(sin(_elapsed * 19.0))
    _bolt_glow.width = 15.0
    _bolt_core.width = 4.2
    _bolt_glow.visible = true
    _bolt_core.visible = true
    _bolt_glow.modulate = Color(1.0, 0.56, 0.10, 0.62 * flicker)
    _bolt_core.modulate = Color(1.0, 0.98, 0.82, 1.0 * flicker)


func _update_branches(delta: float) -> void:
    if _points.size() < 3:
        return
    _branch_timer -= delta
    if _branch_timer > 0.0:
        return
    _branch_timer = rand_range(BRANCH_INTERVAL_MIN, BRANCH_INTERVAL_MAX)

    var branch_count: int = 1
    if randf() < 0.45:
        branch_count = 2
    for i in range(branch_count):
        var index: int = int(rand_range(1.0, float(_points.size() - 1)))
        index = clamp(index, 1, _points.size() - 2)
        var point: Vector2 = _points[index]
        var tangent: Vector2 = _points[index + 1] - _points[index - 1]
        if tangent.length_squared() < 0.001:
            continue
        tangent = tangent.normalized()
        var normal := Vector2(-tangent.y, tangent.x)
        var side: float = 1.0 if randf() > 0.5 else -1.0
        var length: float = rand_range(26.0, 82.0)
        var end: Vector2 = point + normal * length * side + tangent * rand_range(-34.0, 34.0)
        spawn_arc(point, end, rand_range(0.07, 0.13))


func _update_arc_slots(delta: float) -> void:
    for slot in _arc_slots:
        if slot.life <= 0.0:
            continue
        slot.life -= delta
        var fade: float = clamp(slot.life / slot.max_life, 0.0, 1.0)
        slot.glow.modulate.a = slot.glow_alpha * fade
        slot.core.modulate.a = slot.core_alpha * fade
        if slot.life <= 0.0:
            slot.glow.visible = false
            slot.core.visible = false


func _update_motes(delta: float) -> void:
    var count: int = _points.size()
    if count < 2:
        for mote in _motes:
            mote.sprite.visible = false
        return

    for mote in _motes:
        mote.age = float(mote.age) + delta
        if mote.age >= mote.life:
            _respawn_mote(mote, count)
        mote.age = min(float(mote.age), float(mote.life))
        var progress: float = float(mote.age) / max(0.001, float(mote.life))
        var envelope: float = sin(progress * PI)
        var index: int = mote.point_index
        var point: Vector2 = _points[clamp(index, 0, count - 1)]
        mote.sprite.position = point + mote.drift * progress
        mote.sprite.rotation = float(mote.rotation) + float(mote.spin) * float(mote.age)
        mote.sprite.scale = Vector2.ONE * float(mote.scale) * (0.55 + 0.70 * envelope)
        mote.sprite.modulate = Color(1.0, 0.92, 0.64, envelope * 0.82)
        mote.sprite.visible = true


func _update_pulses(delta: float) -> void:
    var count: int = _points.size()
    if count < 2:
        for pulse in _pulses:
            pulse.sprite.visible = false
        return

    for pulse in _pulses:
        pulse.progress = float(pulse.progress) + delta * float(pulse.speed)
        if pulse.progress >= 1.0:
            _respawn_pulse(pulse)
            continue
        var progress: float = float(pulse.progress)
        var index: int = int(progress * float(count - 1))
        index = clamp(index, 0, count - 1)
        var point: Vector2 = _points[index]
        var tangent := Vector2.RIGHT
        if index <= 0:
            tangent = _points[1] - _points[0]
        elif index >= count - 1:
            tangent = _points[count - 1] - _points[count - 2]
        else:
            tangent = _points[index + 1] - _points[index - 1]
        if tangent.length_squared() > 0.001:
            tangent = tangent.normalized()
            point += Vector2(-tangent.y, tangent.x) * sin(progress * 21.0 + float(pulse.phase)) * 7.0
        var envelope: float = sin(progress * PI)
        pulse.sprite.visible = true
        pulse.sprite.position = point
        pulse.sprite.rotation = float(pulse.rotation) + float(pulse.spin) * float(pulse.progress)
        pulse.sprite.scale = Vector2.ONE * float(pulse.scale) * (0.65 + 0.55 * envelope)
        pulse.sprite.modulate = Color(1.0, 0.92, 0.66, envelope * 0.86)


func _update_head_glow(delta: float) -> void:
    if _points.empty():
        _head_glow.visible = false
        _head_star.visible = false
        return

    var head: Vector2 = _points[_points.size() - 1]
    if not _emitting:
        _head_fade = max(0.0, _head_fade - delta / 0.40)

    var display_head: Vector2 = head
    if not _emitting:
        display_head += _head_plume_dir * (1.0 - _head_fade) * 16.0
    var fade_scale: float = 0.55 + 0.45 * _head_fade

    _head_glow.visible = true
    _head_star.visible = true
    _head_glow.position = display_head
    _head_star.position = display_head
    _head_glow.rotation += delta * 0.45
    _head_star.rotation += delta * 1.6

    var pulse: float = 0.5 + 0.06 * sin(_elapsed * 9.0) + _pulse * 0.12
    _head_glow.scale = Vector2.ONE * pulse * fade_scale
    _head_star.scale = Vector2.ONE * (pulse * 0.42 * fade_scale)
    _head_glow.modulate = Color(1.0, 0.96, 0.78, 0.62 * _head_fade)
    _head_star.modulate = Color(1.0, 1.0, 0.92, 0.70 * _head_fade * (0.75 + 0.25 * sin(_elapsed * 11.0)))

    _embers.position = head
    _embers.emitting = _emitting and _head_fade > 0.2
    _embers.modulate = Color(1, 1, 1, _head_fade)


func _update_pulse(delta: float) -> void:
    _pulse = max(0.0, _pulse - delta * 5.5)


func _start_head_plume() -> void:
    if _points.size() < 2:
        return
    _head_plume_head = _points[_points.size() - 1]
    var direction: Vector2 = _points[_points.size() - 1] - _points[_points.size() - 2]
    if direction.length_squared() < 0.001:
        direction = Vector2.RIGHT
    _head_plume_dir = direction.normalized()
    _head_plume_length = rand_range(36.0, 64.0)
    _head_plume_timer = HEAD_PLUME_DURATION
    _head_plume_glow.visible = true
    _head_plume_core.visible = true
    _update_head_plume(0.0)


func _update_head_plume(delta: float) -> void:
    if _head_plume_timer <= 0.0:
        return
    _head_plume_timer = max(0.0, _head_plume_timer - delta)
    if _head_plume_timer <= 0.0:
        _hide_head_plume()
        return

    var progress: float = clamp(_head_plume_timer / HEAD_PLUME_DURATION, 0.0, 1.0)
    var fade: float = progress * progress
    var length: float = _head_plume_length + (1.0 - progress) * 28.0
    var points := PoolVector2Array([
        _head_plume_head - _head_plume_dir * 10.0,
        _head_plume_head + _head_plume_dir * length * 0.45,
        _head_plume_head + _head_plume_dir * length,
    ])
    _head_plume_glow.points = points
    _head_plume_core.points = points
    _head_plume_glow.width = 30.0 * (1.0 + (1.0 - progress) * 0.40)
    _head_plume_core.width = 7.0 * (1.0 + (1.0 - progress) * 0.35)
    _head_plume_glow.modulate = Color(1.0, 0.84, 0.46, 0.85 * fade)
    _head_plume_core.modulate = Color(1.0, 0.98, 0.84, 1.0 * fade)


func _hide_head_plume() -> void:
    _head_plume_timer = 0.0
    _head_plume_glow.points = PoolVector2Array()
    _head_plume_glow.visible = false
    _head_plume_core.points = PoolVector2Array()
    _head_plume_core.visible = false


func spawn_arc(from_position: Vector2, to_position: Vector2, duration: float = -1.0) -> void:
    if _arc_slots.empty():
        return
    var slot = null
    for candidate in _arc_slots:
        if candidate.life <= 0.0:
            slot = candidate
            break
    if slot == null:
        slot = _arc_slots[0]
        for candidate in _arc_slots:
            if candidate.life < slot.life:
                slot = candidate

    var segments: int = int(rand_range(5, 8))
    var jitter: float = clamp(from_position.distance_to(to_position) * 0.16, 8.0, 26.0)
    var points: PoolVector2Array = VFX.jagged_points(from_position, to_position, segments, jitter)
    slot.glow.points = points
    slot.core.points = points
    slot.glow.width = rand_range(10.0, 16.0)
    slot.core.width = rand_range(2.4, 4.2)
    slot.glow_alpha = 0.52
    slot.core_alpha = 0.95
    slot.life = duration if duration > 0.0 else rand_range(0.10, 0.17)
    slot.max_life = slot.life
    slot.glow.visible = true
    slot.core.visible = true
    slot.glow.modulate = Color(1.0, 0.66, 0.20, slot.glow_alpha)
    slot.core.modulate = Color(1.0, 0.98, 0.78, slot.core_alpha)


func _respawn_pulse(pulse) -> void:
    pulse.progress = 0.0
    pulse.speed = rand_range(0.55, 0.95)
    pulse.scale = rand_range(0.38, 0.64)
    pulse.rotation = rand_range(0.0, TAU)
    pulse.spin = rand_range(1.4, 3.8)
    pulse.phase = rand_range(0.0, 10.0)


func _reset_motes() -> void:
    for mote in _motes:
        mote.sprite.visible = false
        mote.age = rand_range(0.0, 0.8)
    for pulse in _pulses:
        pulse.sprite.visible = false
        pulse.progress = rand_range(0.0, 1.0)


func _respawn_mote(mote, count: int) -> void:
    mote.age = 0.0
    mote.life = rand_range(0.45, 0.95)
    mote.scale = rand_range(0.16, 0.36)
    mote.rotation = rand_range(0.0, TAU)
    mote.spin = rand_range(-2.4, 2.4)
    mote.drift = Vector2(rand_range(-20.0, 20.0), rand_range(-30.0, 12.0))
    var min_index: int = int(count * 0.20)
    mote.point_index = int(rand_range(min_index, count))


func _clear_lines() -> void:
    _halo_line.points = PoolVector2Array()
    _halo_line.visible = false
    _glow_line.points = PoolVector2Array()
    _glow_line.visible = false
    _core_line.points = PoolVector2Array()
    _core_line.visible = false
    _bolt_glow.points = PoolVector2Array()
    _bolt_glow.visible = false
    _bolt_core.points = PoolVector2Array()
    _bolt_core.visible = false


func _clear_arcs() -> void:
    for slot in _arc_slots:
        slot.life = 0.0
        slot.glow.points = PoolVector2Array()
        slot.core.points = PoolVector2Array()
        slot.glow.visible = false
        slot.core.visible = false
