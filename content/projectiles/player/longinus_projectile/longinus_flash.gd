extends Node2D

const VFX = preload("res://mods-unpacked/Yoko-Fantasy/content/projectiles/player/longinus_projectile/longinus_vfx_utils.gd")
const IMPACT_SOUND = preload("res://weapons/ranged/taser/taser.wav")

export (bool) var impact: bool = false

var _main: Node = null
var _pool_id: int = -1
onready var _animation: AnimationPlayer = $AnimationPlayer
onready var _particles: Array = $Particles.get_children()
onready var _arcs: Array = $ArcRoot.get_children()


func _ready() -> void:
    set_as_toplevel(true)
    visible = false


func play(position: Vector2, main: Node, pool_id: int, scale_mult: float = 1.0, opacity: float = 1.0, with_sound: bool = true) -> void:
    _main = main
    _pool_id = pool_id
    global_position = position
    rotation = rand_range(0.0, TAU)
    scale = Vector2.ONE * max(0.15, scale_mult)
    modulate = Color(1, 1, 1, clamp(opacity, 0.0, 1.0))
    visible = opacity > 0.0
    _animation.stop()
    _animation.play("flash")
    _animation.seek(0.0, true)
    for particles in _particles:
        particles.emitting = visible
        if visible:
            particles.restart()
    if impact:
        _build_arc_flash(scale_mult)
        if with_sound:
            if is_instance_valid(main) and main._screenshaker != null:
                main._screenshaker.shake(2.3 * scale_mult, 0.07)
            SoundManager2D.play(IMPACT_SOUND, global_position, -5.0, 0.16)


func _build_arc_flash(scale_mult: float) -> void:
    var count: int = int(clamp(round(4.0 * scale_mult), 2.0, float(_arcs.size())))
    var base_angle: float = rand_range(0.0, TAU)
    for i in range(_arcs.size()):
        var arc: Node2D = _arcs[i]
        arc.visible = visible and i < count
        if not arc.visible:
            continue
        var angle: float = base_angle + TAU * float(i) / float(count) + rand_range(-0.30, 0.30)
        var direction := Vector2(cos(angle), sin(angle))
        var start: Vector2 = direction * rand_range(6.0, 18.0)
        var end: Vector2 = direction * rand_range(76.0, 190.0) + Vector2(rand_range(-14.0, 14.0), rand_range(-14.0, 14.0))
        var points: PoolVector2Array = VFX.jagged_points(start, end, int(rand_range(6, 9)), rand_range(12.0, 26.0))
        var glow: Line2D = arc.get_node("Glow")
        var core: Line2D = arc.get_node("Core")
        glow.points = points
        core.points = points
        glow.width = rand_range(16.0, 24.0)
        core.width = rand_range(3.8, 6.2)


func _on_animation_finished(_animation_name: String) -> void:
    visible = false
    for particles in _particles:
        particles.emitting = false
    var main: Node = _main
    _main = null
    if is_instance_valid(main):
        main.add_node_to_pool(self, _pool_id)
    else:
        queue_free()
