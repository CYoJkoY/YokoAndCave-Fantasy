extends Sprite

var flattened_texture: Texture
var ground_container: Node2D
var _flattened: bool = false
var _trample_area: Area2D

# ══════════════════════════════════════════ Extension ══════════════════════════════════════════ #
func _ready() -> void:
    add_to_group("fantasy_standing_grass")
    var area = Area2D.new()
    _trample_area = area
    area.collision_layer = 0
    area.collision_mask = Utils.PLAYER_BIT | Utils.ENEMIES_BIT | Utils.PETS_BIT
    area.monitorable = false
    var collision = CollisionShape2D.new()
    var circle = CircleShape2D.new()
    circle.radius = 19.0
    collision.shape = circle
    collision.position.y = -4.0
    area.add_child(collision)
    area.connect("body_entered", self, "_on_body_entered")
    add_child(area)

# ══════════════════════════════════════════ Custom ══════════════════════════════════════════ #
func _on_body_entered(_body: Node) -> void:
    flatten()

func flatten() -> void:
    if _flattened: return
    _flattened = true
    remove_from_group("fantasy_standing_grass")
    call_deferred("_flatten")

func _flatten() -> void:
    texture = flattened_texture
    offset = -texture.get_size() * Vector2(0.5, 0.98)
    _trample_area.queue_free()
    var world_transform: Transform2D = global_transform
    get_parent().remove_child(self)
    ground_container.add_child(self)
    global_transform = world_transform
