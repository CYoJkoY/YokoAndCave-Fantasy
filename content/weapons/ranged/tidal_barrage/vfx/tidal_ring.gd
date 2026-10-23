extends Sprite

const DURATION: float = 0.20

var _age: float = 0.0
var _origin: Transform2D
var _main: Node


func _ready() -> void:
    set_as_toplevel(true)
    set_process(false)


func play(origin: Transform2D, main: Node) -> void:
    _origin = origin
    _origin.origin = origin.xform(Vector2(8, 0))
    _main = main
    _age = 0.0
    visible = true
    _update_visual()
    set_process(true)


func _process(delta: float) -> void:
    _age += delta
    if _age >= DURATION or _main._cleaning_up:
        visible = false
        set_process(false)
        _main.add_node_to_pool(self, get_meta("pool_id"))
        _main = null
        return
    _update_visual()


func _update_visual() -> void:
    var progress: float = _age / DURATION
    var opening: float = 1.0 - pow(1.0 - progress, 3.0)
    var visual_transform: Transform2D = _origin
    visual_transform.x *= 0.38 + opening * 0.24
    visual_transform.y *= 0.72 + opening * 0.38
    global_transform = visual_transform
    material.set_shader_param("progress", progress)
    modulate.a = (1.0 - smoothstep(0.055, DURATION, _age)) * 0.95 * ProgressData.settings.projectile_opacity
