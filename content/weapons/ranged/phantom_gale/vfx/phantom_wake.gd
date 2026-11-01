extends Node2D

const HISTORY = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/utils/projectile_trail_history.gd")
const MAIN_TEXTURE = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/weapons/ranged/phantom_gale/vfx/phantom_streak.webp")
const MAIN_MATERIAL = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/weapons/ranged/phantom_gale/vfx/phantom_streak_material.tres")
const MAIN_SPARK = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/weapons/ranged/phantom_gale/vfx/phantom_feather.webp")
const MAIN_COLORS = [Color("6bdfff"), Color("9c8aff"), Color("e9ffff")]

var _history = HISTORY.new(96, true)
var _samples: Array = []
var _directions: PoolVector2Array = PoolVector2Array()
var _is_echo: bool = false
var _color: Color = Color.white
var _fade: float = 1.0
var _age: float = 0.0
var _ribbons: Array = []
var _ghosts: Array = []


func _ready() -> void:
    set_as_toplevel(true)
    _samples.resize(28)
    _directions.resize(_samples.size())
    _ribbons = [$RibbonCyan, $RibbonViolet, $RibbonRose]
    _ghosts = [$GhostNear, $GhostFar]


func begin(point: Vector2, is_echo: bool) -> void:
    global_transform = Transform2D.IDENTITY
    _history.clear()
    _history.push(point)
    _is_echo = is_echo
    _color = Color.white
    _fade = 1.0
    _age = 0.0
    for ribbon in _ribbons:
        ribbon.clear_points()
        if not _is_echo:
            ribbon.texture = MAIN_TEXTURE
            ribbon.material = MAIN_MATERIAL
    for ghost in _ghosts:
        ghost.visible = false
        if not _is_echo:
            ghost.texture = MAIN_SPARK
    modulate.a = ProgressData.settings.projectile_opacity


func set_color(color: Color) -> void:
    _color = color


func advance(point: Vector2, delta: float) -> void:
    _age += delta
    _history.push(point, 0.25)


func refresh() -> void:
    modulate.a = ProgressData.settings.projectile_opacity
    if modulate.a > 0.0:
        _rebuild()


func fade_out(fraction: float, delta: float) -> void:
    _age += delta
    _fade = pow(fraction, 1.45 if _is_echo else 1.2)
    modulate.a = _fade * ProgressData.settings.projectile_opacity
    if modulate.a > 0.0:
        _rebuild()


func _rebuild() -> void:
    if _history.count < 2:
        return
    if not _is_echo:
        _rebuild_main()
        return
    var count: int = _sample_path(26.0)
    for lane in range(3):
        var points: PoolVector2Array = PoolVector2Array()
        points.resize(count)
        var tint: Color = _color
        if lane == 1:
            tint = tint.linear_interpolate(Color.white, 0.22)
        tint.a = [0.36, 0.72, 0.46][lane]
        var ribbon: Line2D = _ribbons[lane]
        ribbon.default_color = tint
        ribbon.width = [48.0, 20.0, 34.0][lane]
        for i in range(count):
            var along: float = float(i) / float(count - 1)
            var normal: Vector2 = _directions[i].tangent()
            var drift: float = sin(along * 10.0 + _age * 4.0 + lane * 2.1) * along
            var offset: float = (lane - 1) * 3.0 + drift * (6.0 + (1.0 - _fade) * 10.0)
            points[i] = _samples[i] + normal * offset * min(1.0, along * 9.0)
        ribbon.points = points
    for i in range(_ghosts.size()):
        var ghost: Sprite = _ghosts[i]
        var sample_index: int = 3 + i * 5
        ghost.visible = count > sample_index
        if not ghost.visible:
            continue
        ghost.position = _samples[sample_index]
        ghost.rotation = _directions[sample_index].angle()
        ghost.scale = Vector2(0.26 - i * 0.05, 0.21 - i * 0.04)
        ghost.modulate = _color
        ghost.modulate.a = 0.25 - i * 0.09


func _sample_path(spacing: float) -> int:
    var length: float = _history.sample(_samples, spacing, Transform2D.IDENTITY)
    var count: int = int(min(_samples.size(), ceil(length / spacing) + 1))
    for i in range(count):
        var previous: Vector2 = _samples[max(0, i - 1)]
        var next: Vector2 = _samples[min(count - 1, i + 1)]
        _directions[i] = (previous - next).normalized()
    return count


func _rebuild_main() -> void:
    var sample_count: int = _sample_path(17.0)
    var growth: float = min(1.0, float(sample_count - 1) / 6.0)
    for lane in range(3):
        var count: int = int(min(sample_count, [28, 25, 23][lane]))
        var points: PoolVector2Array = PoolVector2Array()
        points.resize(count)
        var ribbon: Line2D = _ribbons[lane]
        ribbon.default_color = MAIN_COLORS[lane]
        ribbon.default_color.a = [1.0, 0.7, 1.0][lane] * growth
        ribbon.width = [72.0, 40.0, 14.0][lane] * (0.7 + 0.3 * _fade) * lerp(0.35, 1.0, growth)
        for i in range(count):
            points[i] = _samples[i]
        ribbon.points = points
    for i in range(_ghosts.size()):
        var ghost: Sprite = _ghosts[i]
        var sample_index: int = 6 + i * 8
        ghost.visible = sample_count > sample_index
        if not ghost.visible:
            continue
        var direction: Vector2 = _directions[sample_index]
        ghost.position = _samples[sample_index]
        ghost.rotation = direction.angle()
        ghost.scale = Vector2.ONE * (0.2 - i * 0.04)
        ghost.modulate = Color(0.7, 0.85, 1.0, 0.5 - i * 0.15)


func reset() -> void:
    _history.clear()
    for ribbon in _ribbons:
        ribbon.clear_points()
    for ghost in _ghosts:
        ghost.visible = false
