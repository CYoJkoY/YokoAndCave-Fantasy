extends Node2D

const LIGHT = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/weapons/ranged/phantom_gale/vfx/phantom_front.webp")
const MOTE = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/weapons/ranged/phantom_gale/vfx/phantom_charge_mote.webp")
const CYAN = Color("6edfff")
const VIOLET = Color("a796ff")

var _age: float = 0.0
var _draw_amount: float = 0.0
var _flash: float = 0.0
var _string_points = PoolVector2Array([Vector2(-4, -16), Vector2(-4, 1.5), Vector2(-4, 19)])


func refresh(delta: float, draw_amount: float, release_age: float, flash: float,
        flipped: bool, opacity: float) -> void:
    _age += delta
    _draw_amount = draw_amount
    _flash = flash
    var recoil: float = sin(release_age * 100.0) * exp(-release_age * 34.0) * 3.0
    scale.y = -1.0 if flipped else 1.0
    modulate.a = opacity
    _string_points[1] = Vector2(-4.0 - draw_amount * 22.0 + recoil, 1.5)
    visible = opacity > 0.0
    if visible:
        update()


func _mote_point(progress: float, index: int, nock: Vector2) -> Vector2:
    var angle: float = index * 2.39996 + _age * 0.32 + progress * progress * 1.7
    var radius: float = pow(1.0 - progress, 1.25) * (25.0 + index % 3 * 5.0)
    return nock + Vector2(cos(angle) * radius, sin(angle) * radius * 0.72)


func _draw() -> void:
    var nock: Vector2 = _string_points[1]
    draw_polyline(_string_points, Color(0.3, 0.6, 1.0, 0.035 + _draw_amount * 0.025), 5.0, true)
    draw_polyline(_string_points, Color(0.4, 0.85, 1.0, 0.09 + _draw_amount * 0.06), 2.4, true)
    draw_polyline(_string_points, Color(0.8, 0.97, 1.0, 0.55 + _draw_amount * 0.3), 0.6, true)
    for i in range(2):
        var tip: Vector2 = _string_points[i * 2]
        draw_texture_rect(MOTE, Rect2(tip - Vector2.ONE * 4.0, Vector2.ONE * 8.0), false,
            Color(0.6, 0.85, 1.0, 0.3 + _draw_amount * 0.3))
    if _draw_amount > 0.01:
        var arrow_length: float = 38.0 - nock.x
        draw_texture_rect(LIGHT, Rect2(nock.x - arrow_length * 0.04, -4.5,
            arrow_length * 1.11, 12.0), false, Color(1.0, 1.0, 1.0, pow(_draw_amount, 0.7)))
        var glow_size: float = 16.0 + _draw_amount * 12.0
        draw_texture_rect(MOTE, Rect2(nock - Vector2.ONE * glow_size * 0.5,
            Vector2.ONE * glow_size), false, Color(0.65, 0.8, 1.0, _draw_amount * 0.7))
        for lane in range(2):
            var points = PoolVector2Array()
            for step in range(19):
                var along: float = step / 18.0
                var envelope: float = sin(along * PI)
                var wave: float = sin(along * 8.0 - _age * 5.0 + lane * PI) * envelope
                points.append(Vector2(lerp(nock.x, 33.0, along), 1.5 + wave * (1.0 + _draw_amount * 2.0)))
            var tint: Color = CYAN if lane == 0 else VIOLET
            tint.a = _draw_amount * 0.28
            draw_polyline(points, tint, 0.6, true)
    for i in range(8):
        var progress: float = fmod(_age * (0.58 + _draw_amount * 0.4) + i * 0.618034, 1.0)
        var head: Vector2 = _mote_point(progress, i, nock)
        var point: Vector2 = head
        var strength: float = pow(sin(progress * PI), 1.2) * (0.12 + _draw_amount * 0.65)
        var tint: Color = CYAN if i % 3 != 0 else VIOLET
        for segment in range(4):
            var back: float = max(0.0, progress - (segment + 1) * 0.014)
            var previous: Vector2 = _mote_point(back, i, nock)
            tint.a = strength * (1.0 - segment / 4.0) * 0.65
            draw_line(point, previous, tint, 0.65, true)
            point = previous
        tint.a = strength
        var size: float = 9.0 + progress * 4.0
        draw_texture_rect(MOTE, Rect2(head - Vector2.ONE * size * 0.5, Vector2.ONE * size), false, tint)
    if _flash > 0.0:
        draw_texture_rect(MOTE, Rect2(nock - Vector2.ONE * 12.0, Vector2.ONE * 24.0),
            false, Color(0.8, 0.95, 1.0, _flash * 0.8))
