extends Node2D

const BEAM: Texture = preload("res://mods-unpacked/Yoko-Fantasy/content/weapons/melee/seven_star_sword/vfx/textures/star_filament.webp")
const STAR: Texture = preload("res://mods-unpacked/Yoko-Fantasy/content/weapons/melee/seven_star_sword/vfx/textures/star_flare.webp")
const SHARD: Texture = preload("res://mods-unpacked/Yoko-Fantasy/content/weapons/melee/seven_star_sword/vfx/textures/star_shard.webp")
const FIRST_HIT: float = 0.045
const LINK_INTERVAL: float = 0.035
const FADE_DURATION: float = 0.30

export(Color) var chain_glow_color = Color(0.2, 0.6, 1.0)
export(Color) var chain_core_color = Color(0.9, 0.98, 1.0)
export(Color) var chain_star_color = Color(0.55, 0.85, 1.0)
export(Color) var chain_shard_color = Color(0.6, 0.9, 1.0)

var _age: float = 0.0


func _draw_chain(points: PoolVector2Array) -> void:
    if points.empty():
        return
    _draw_star(points[0], 80.0, pow(max(0.0, 1.0 - _age / 0.25), 2.0))
    for i in range(points.size() - 1):
        var local_age: float = _age - i * LINK_INTERVAL
        if local_age <= 0.0 or local_age >= FIRST_HIT + FADE_DURATION:
            continue
        var fade: float = pow(clamp(1.0 - (local_age - FIRST_HIT) / FADE_DURATION, 0.0, 1.0), 1.6)
        var reveal: float = clamp(local_age / FIRST_HIT, 0.0, 1.0)
        _draw_link(points[i], points[i + 1], reveal, fade, i)
        if local_age >= FIRST_HIT:
            var burst_age: float = local_age - FIRST_HIT
            _draw_star(points[i + 1], 58.0 + burst_age * 95.0, fade)
            _draw_sparks(points[i + 1], burst_age, fade, i)


func _draw_link(start: Vector2, finish: Vector2, reveal: float, fade: float, variation: int) -> void:
    var distance: float = start.distance_to(finish)
    if distance < 1.0:
        return
    var normal: Vector2 = (finish - start).normalized().tangent()
    var steps: int = int(clamp(ceil(distance / 24.0), 6, 36))
    var points: PoolVector2Array = PoolVector2Array([start])
    var widths: PoolRealArray = PoolRealArray([0.7])
    var pulse: float = 0.78 + fade * fade * 0.52
    for j in range(1, steps + 1):
        var t: float = min(float(j) / steps, reveal)
        var envelope: float = sin(t * PI)
        var bend: float = (abs(fposmod(t * 4.0 + variation * 0.37, 2.0) - 1.0) * 2.0 - 1.0) * min(18.0, distance * 0.075)
        var filament: float = sin(t * 53.0 + variation * 3.7 + _age * 36.0) * min(1.6, distance * 0.02)
        var point: Vector2 = start.linear_interpolate(finish, t) + normal * envelope * (bend + filament)
        points.append(point)
        widths.append((0.88 + sin(t * 17.0 + variation * 2.3) * 0.12) * (0.7 + envelope * 0.3))
        if t >= reveal:
            break
    _draw_link_ribbon(points, widths, pulse, fade)
    _draw_star(points[points.size() - 1], 24.0, fade * (1.0 - reveal))


func _draw_link_ribbon(points: PoolVector2Array, widths: PoolRealArray, pulse: float, fade: float) -> void:
    var count: int = points.size()
    var glow: PoolVector2Array = PoolVector2Array()
    var core: PoolVector2Array = PoolVector2Array()
    var uvs: PoolVector2Array = PoolVector2Array()
    var indices: PoolIntArray = PoolIntArray()
    glow.resize(count * 2)
    core.resize(count * 2)
    uvs.resize(count * 2)
    indices.resize((count - 1) * 6)
    for i in range(count):
        var before: Vector2 = points[max(0, i - 1)]
        var after: Vector2 = points[min(count - 1, i + 1)]
        var side: Vector2 = (after - before).normalized().tangent()
        var edge: Vector2 = (points[i] - before) if i == count - 1 else (after - points[i])
        var joint_scale: float = 1.0 / max(0.75, side.dot(edge.normalized().tangent()))
        side *= widths[i] * pulse * joint_scale
        glow[i * 2] = points[i] - side * 12.0
        glow[i * 2 + 1] = points[i] + side * 12.0
        core[i * 2] = points[i] - side * 3.3
        core[i * 2 + 1] = points[i] + side * 3.3
        uvs[i * 2] = Vector2(0.5, 0.0)
        uvs[i * 2 + 1] = Vector2(0.5, 1.0)
    for i in range(count - 1):
        var left: int = i * 2
        var offset: int = i * 6
        indices[offset] = left
        indices[offset + 1] = left + 2
        indices[offset + 2] = left + 3
        indices[offset + 3] = left
        indices[offset + 4] = left + 3
        indices[offset + 5] = left + 1
    _draw_ribbon_triangles(glow, uvs, indices, Color(chain_glow_color.r, chain_glow_color.g, chain_glow_color.b, fade * 0.7))
    _draw_ribbon_triangles(core, uvs, indices, Color(chain_core_color.r, chain_core_color.g, chain_core_color.b, fade))


func _draw_ribbon_triangles(vertices: PoolVector2Array, uvs: PoolVector2Array, indices: PoolIntArray, color: Color) -> void:
    VisualServer.canvas_item_add_triangle_array(get_canvas_item(), indices, vertices,
        PoolColorArray([color]), uvs, PoolIntArray(), PoolRealArray(), BEAM.get_rid())


func _draw_beam(a: Vector2, b: Vector2, width: float, color: Color) -> void:
    var side: Vector2 = (b - a).normalized().tangent() * width * 0.5
    draw_primitive(PoolVector2Array([a - side, b - side, b + side, a + side]),
        PoolColorArray([color, color, color, color]),
        PoolVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]), BEAM)


func _draw_star(center: Vector2, size: float, alpha: float) -> void:
    draw_texture_rect(STAR, Rect2(center - Vector2.ONE * size * 0.5, Vector2.ONE * size), false, Color(chain_star_color.r, chain_star_color.g, chain_star_color.b, alpha))


func _draw_sparks(center: Vector2, age: float, alpha: float, variation: int) -> void:
    for i in range(7):
        var angle: float = i * TAU / 7.0 + variation * 0.73
        var direction: Vector2 = Vector2.RIGHT.rotated(angle)
        var point: Vector2 = center + direction * (16.0 + (1.0 - exp(-age * 7.0)) * (40.0 + (i % 3) * 15.0))
        var size: Vector2 = Vector2(8.0, 22.0) * (0.5 + alpha * 0.65)
        draw_set_transform(point, angle + PI * 0.5, Vector2.ONE)
        draw_texture_rect(SHARD, Rect2(-size * 0.5, size), false, Color(chain_shard_color.r, chain_shard_color.g, chain_shard_color.b, alpha))
        draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
        if i % 2 == 0:
            _draw_star(center + direction.rotated(0.18) * (20.0 + age * 110.0), 10.0, alpha * 0.75)
