extends Reference

const TAPER_CURVE = preload("res://mods-unpacked/Yoko-Fantasy/content/projectiles/player/longinus_projectile/lightning_taper_curve.tres")

const DAMAGE_COLOR: Color = Color("#ffd76a")


static func jagged_points(from: Vector2, to: Vector2, segments: int = 6, jitter: float = 12.0) -> PoolVector2Array:
    var points := PoolVector2Array()
    var delta := to - from
    var length := delta.length()
    if length <= 0.001:
        points.append(from)
        points.append(to)
        return points

    var normal := Vector2(-delta.y, delta.x) / length
    for i in range(segments + 1):
        var t := float(i) / float(segments)
        var point := from.linear_interpolate(to, t)
        if i > 0 and i < segments:
            var envelope := sin(t * PI)
            point += normal * rand_range(-jitter, jitter) * envelope
            point += delta.normalized() * rand_range(-jitter * 0.18, jitter * 0.18) * envelope
        points.append(point)
    return points


static func offset_polyline(
        source_points: Array,
        amplitude: float,
        time: float,
        phase: float,
        random_strength: float = 0.0
    ) -> PoolVector2Array:
    var result := PoolVector2Array()
    var count := source_points.size()
    if count < 2:
        return result

    for i in range(count):
        var point: Vector2 = source_points[i]
        var tangent := Vector2.RIGHT
        if i == 0:
            tangent = source_points[1] - source_points[0]
        elif i == count - 1:
            tangent = source_points[count - 1] - source_points[count - 2]
        else:
            tangent = source_points[i + 1] - source_points[i - 1]
        if tangent.length_squared() < 0.0001:
            tangent = Vector2.RIGHT
        var normal := Vector2(-tangent.y, tangent.x).normalized()
        var wave := sin(float(i) * 0.82 + time * 18.0 + phase) * amplitude
        wave += sin(float(i) * 2.13 - time * 11.0 + phase * 1.7) * amplitude * 0.46
        var jitter := 0.0
        if i > 0 and i < count - 1:
            jitter = rand_range(-random_strength, random_strength)
        result.append(point + normal * (wave + jitter))
    return result


static func nearest_point_on_path(source_points: Array, point: Vector2) -> Vector2:
    var closest_point: Vector2 = source_points[0]
    var closest_distance: float = point.distance_squared_to(closest_point)
    for i in range(1, source_points.size()):
        var a: Vector2 = source_points[i - 1]
        var ab: Vector2 = source_points[i] - a
        var length_squared: float = ab.length_squared()
        var closest: Vector2 = a
        if length_squared > 0.0001:
            var t: float = clamp((point - a).dot(ab) / length_squared, 0.0, 1.0)
            closest = a + ab * t
        var distance_squared: float = point.distance_squared_to(closest)
        if distance_squared < closest_distance:
            closest_distance = distance_squared
            closest_point = closest
    return closest_point


static func points_to_pool(source_points: Array) -> PoolVector2Array:
    var result := PoolVector2Array()
    result.resize(source_points.size())
    for i in range(source_points.size()):
        result[i] = source_points[i]
    return result

