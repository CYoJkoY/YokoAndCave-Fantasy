extends Node2D

const STAR_COUNT: int = 3
const COLOR: Color = Color(1.0, 0.84, 0.25)

var _elapsed: float = 0.0
var _radius: float = 22.0
var _outline_points: PoolVector2Array = PoolVector2Array()
var _fill_points: PoolVector2Array = PoolVector2Array()


func _init() -> void:
    for point in range(10):
        var angle: float = -PI * 0.5 + point * TAU / 10.0
        var radius: float = 8.0 if point % 2 == 0 else 3.6
        var vertex: Vector2 = Vector2(cos(angle), sin(angle)) * radius
        _outline_points.append(vertex)
        _fill_points.append(vertex * 0.75)


func start(sprite: Sprite, enemy: Node2D) -> void:
    # Use the visible sprite bounds so the halo also fits large bosses.
    var bounds: Rect2 = (enemy.global_transform.affine_inverse() * sprite.global_transform).xform(sprite.get_rect())
    position = Vector2(bounds.position.x + bounds.size.x * 0.5, bounds.position.y - 18.0)
    _radius = clamp(bounds.size.x * 0.35, 18.0, 60.0)
    _elapsed = 0.0
    z_index = 10
    show()
    update()


func advance(delta: float) -> void:
    _elapsed += delta
    update()


func _draw() -> void:
    for i in range(STAR_COUNT):
        var angle: float = _elapsed * 4.0 + TAU * i / STAR_COUNT
        var center: Vector2 = Vector2(cos(angle) * _radius, sin(angle) * 9.0)
        # Reuse immutable star geometry; only the draw transform changes.
        draw_set_transform(center, sin(_elapsed * 3.0 + i) * 0.2, Vector2.ONE)
        draw_colored_polygon(_outline_points, Color(0.25, 0.16, 0.07, 0.9))
        draw_colored_polygon(_fill_points, COLOR)
        draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
        # Short lived sparkles trail each orbiting star.
        var age: float = fposmod(_elapsed * 1.8 + float(i) / STAR_COUNT, 1.0)
        var trail_angle: float = angle - age * 0.9
        var trail: Vector2 = Vector2(cos(trail_angle) * _radius, sin(trail_angle) * 9.0 - age * 13.5)
        draw_circle(trail, 3.0 * (1.0 - age), Color(1.0, 0.95, 0.65, 1.0 - age))
