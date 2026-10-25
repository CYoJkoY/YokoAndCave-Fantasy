extends Node2D

const EFFECT = preload("res://mods-unpacked/Yoko-Fantasy/content/weapons/ranged/sage_staff/sage_staff_effect.gd")
const Element = EFFECT.Element

const ART = preload("res://mods-unpacked/Yoko-Fantasy/content/weapons/ranged/sage_staff/vfx/sage_staff_art.gd")
const DURATIONS: Array = [0.56, 0.48, 0.60, 0.46, 0.32, 0.64]
const PARTICLE_COUNTS: Array = [10, 12, 9, 8, 6, 10]

onready var _burst: Sprite = $Burst
onready var _flash: Sprite = $Flash

var _age: float = 0.0
var _element: int = Element.WATER
var _radius: float = 44.0
var _angle: float = 0.0
var _seed: float = 0.0
var _duration: float = 0.56
var _main: Node
var _pool_id: int


func start(center: Vector2, element: int, direction: float, radius: float, main: Node, pool_id: int) -> void:
    _main = main
    _pool_id = pool_id
    _age = 0.0
    global_position = center
    _element = element
    _radius = radius
    _angle = direction
    _seed = rand_range(0.0, TAU)
    _duration = DURATIONS[element]
    _burst.scale = Vector2.ONE * radius * 3.8 / 128.0
    _burst.rotation = direction if element == Element.WIND or element == Element.THUNDER else 0.0
    _burst.material.set_shader_param("tint", ART.COLORS[element])
    _burst.material.set_shader_param("element", element)
    _burst.material.set_shader_param("seed", _seed)
    _burst.material.set_shader_param("age", 0.0)
    _burst.material.set_shader_param("duration", _duration)
    _flash.rotation = direction + _seed * 0.15
    _flash.scale = Vector2.ONE * (0.25 + radius / 350.0)
    _flash.modulate = ART.COLORS[element].linear_interpolate(Color.white, 0.75)
    _flash.modulate.a = 0.0
    modulate.a = ProgressData.settings.explosion_opacity
    set_process(true)
    update()


func _process(delta: float) -> void:
    _age += delta
    if _age >= _duration:
        set_process(false)
        var main: Node = _main
        _main = null
        main.add_node_to_pool(self, _pool_id)
        return
    _burst.material.set_shader_param("age", _age)
    var flash: float = (1.0 - exp(-_age * 100.0)) * exp(-_age * (15.0 if _element == Element.LIGHT else 28.0))
    _flash.modulate.a = flash * (0.95 if _element == Element.THUNDER or _element == Element.LIGHT else 0.65)
    _flash.scale = Vector2.ONE * (0.25 + _radius / 350.0 + _age * 0.14)
    update()


func _draw() -> void:
    var fade: float = pow(max(0.0, 1.0 - _age / _duration), 1.4)
    for i in range(PARTICLE_COUNTS[_element]):
        var age: float = max(0.0, _age - (i % 3) * 0.012)
        var angle: float = _angle + i * 2.399963 + _seed
        var direction: Vector2 = Vector2.RIGHT.rotated(angle)
        var distance: float = (1.0 - exp(-age * 9.0)) * _radius * (0.72 + (i % 4) * 0.24)
        var point: Vector2 = direction * distance
        var size: Vector2 = Vector2(7.0, 22.0) * (0.75 + (i % 3) * 0.16) * (0.45 + fade * 0.55)
        var spin: float = angle + PI * 0.5
        var texture: Texture = ART.SHARD
        var color: Color = ART.COLORS[_element].linear_interpolate(Color.white, 0.24)
        match _element:
            Element.WATER:
                point.y = point.y * 0.75 + age * age * 130.0
                size = Vector2(8.0, 14.0) * (0.6 + fade * 0.6)
                texture = ART.GLOW
                spin = -age * 2.0 + angle
            Element.FIRE:
                point.y -= age * age * 240.0
                size *= Vector2(1.0, 0.65 + age * 1.4)
                color = color.linear_interpolate(Color("ffad36"), 0.35)
            Element.EARTH:
                point.y = point.y * 0.48 - sin(min(1.0, age / _duration) * PI) * 22.0 + age * age * 90.0
                size *= Vector2(2.1, 1.15)
                spin += age * (2.0 if i % 2 == 0 else -2.0)
            Element.WIND:
                point = point.rotated(age * 4.8)
                size *= Vector2(0.7, 1.5)
                spin = point.angle()
            Element.THUNDER:
                texture = ART.SPARK
                size = Vector2.ONE * (20.0 + (i % 3) * 7.0) * fade
                point = direction * _radius * (0.45 + (i % 3) * 0.22)
            Element.LIGHT:
                texture = ART.SPARK
                size = Vector2.ONE * (16.0 + (i % 3) * 8.0) * (0.5 + fade * 0.5)
                point.y -= age * age * 45.0
                spin = age * 0.5 + i * 0.4
        color.a = fade * min(1.0, age * 75.0) * (0.65 + (i % 3) * 0.12)
        draw_set_transform(point, spin, Vector2.ONE)
        if _element == Element.EARTH:
            var corners: PoolVector2Array = PoolVector2Array([Vector2(0.0, -size.y * 0.5), Vector2(size.x * 0.5, -size.y * 0.1), Vector2(size.x * 0.15, size.y * 0.5), Vector2(-size.x * 0.5, size.y * 0.15)])
            var shadow: Color = Color(color.r * 0.32, color.g * 0.22, color.b * 0.15, color.a)
            draw_polygon(corners, PoolColorArray([shadow, color, shadow, shadow]))
            draw_texture_rect(ART.SHARD, Rect2(-size * 0.5, size), false, Color(color.r, color.g, color.b, color.a * 0.55))
        else:
            draw_texture_rect(texture, Rect2(-size * 0.5, size), false, color)
        draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
        if _element == Element.WATER or _element == Element.FIRE or _element == Element.EARTH:
            var halo: Color = ART.COLORS[_element]
            halo.a = color.a * 0.25
            draw_texture_rect(ART.GLOW, Rect2(point - Vector2.ONE * 13.0, Vector2.ONE * 26.0), false, halo)
