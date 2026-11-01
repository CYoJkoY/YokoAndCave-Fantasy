extends Node2D

const LIFETIME: float = 0.36
const CLOCK_PERIOD: float = 8.0

onready var _layers: Array = get_children()

var expires_at: float = 0.0


func start_visual(source_transform: Transform2D, shared_material: ShaderMaterial, time: float, opacity: float) -> void:
    global_transform = source_transform
    material = shared_material
    modulate.a = opacity
    expires_at = time + LIFETIME
    var birth: float = fposmod(time, CLOCK_PERIOD) / CLOCK_PERIOD
    var rotation_seed: float = rand_range(0.0, 1.0)
    for i in range(_layers.size()):
        _layers[i].color = Color(float(i) / 3.0, birth, rotation_seed, 1.0)
    visible = true
