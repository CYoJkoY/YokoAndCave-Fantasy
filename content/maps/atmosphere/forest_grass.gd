extends Sprite

var flattened_texture: Texture
var ground_container: Node2D
var _flattened: bool = false

# ══════════════════════════════════════════ Extension ══════════════════════════════════════════ #
func _ready() -> void:
    var area = Area2D.new()
    area.collision_layer = 0
    area.collision_mask = Utils.PLAYER_BIT
    area.monitorable = false
    var collision = CollisionShape2D.new()
    var circle = CircleShape2D.new()
    circle.radius = 19.0
    collision.shape = circle
    collision.position.y = -4.0
    area.add_child(collision)
    area.connect("body_entered", self, "_on_body_entered", [area])
    add_child(area)

# ══════════════════════════════════════════ Custom ══════════════════════════════════════════ #
func _on_body_entered(_body: Node, area: Area2D) -> void:
    if _flattened: return
    _flattened = true
    call_deferred("_flatten", area)

func _flatten(area: Area2D) -> void:
    texture = flattened_texture
    offset = -texture.get_size() * Vector2(0.5, 0.98)
    area.queue_free()
    var world_transform: Transform2D = global_transform
    get_parent().remove_child(self)
    ground_container.add_child(self)
    global_transform = world_transform
