extends "res://mods-unpacked/YokoAndCave-Fantasy/content/movement_behaviors/pet/wandering_pet_movement_behavior.gd"

# Floating branch of the wandering family: inherits the shared locomotion
# loop and wander intent, then adds the hover rhythm, tilt and shadow
# response that every flying pet shares. Flying pets pass over pits.

# A pit is a StaticBody2D whose own mask covers the pet layer, so the physics
# solver pushes a flying pet back even though the wander branch already
# ignores forbidden zones. Drop that single pair with a collision exception
# instead of stripping the pet's layers: the pet keeps its PETS layer for
# grass trampling and pet-to-pet collisions.
export(bool) var ignore_hole_collision: bool = true

export(float) var hover_height: float = 0.0
export(float) var hover_amplitude: float = 4.2
export(float) var hover_speed: float = 2.4
export(float) var hover_secondary_ratio: float = 0.285714
export(float) var hover_secondary_speed_ratio: float = 2.416667
export(float) var hover_secondary_phase: float = 0.0
export(float) var sway_distance: float = 0.0
export(float) var sway_angle: float = 0.0
export(float) var sway_speed: float = 0.0
export(float) var tilt_max: float = 0.35
export(float) var tilt_speed: float = 6.0
export(float) var shadow_min_scale: float = 0.8
export(float) var shadow_min_alpha: float = 0.65

export(NodePath) var hover_target_path: NodePath = NodePath("Animation/Offset")
export(NodePath) var tilt_target_path: NodePath = NodePath("Animation/Offset")
export(NodePath) var shadow_path: NodePath = NodePath("Animation/Offset/Shadow")

var _motion_time: float = 0.0
var _tilt: float = 0.0

var _hover_target: Node2D = null
var _tilt_target: Node2D = null
var _shadow: Sprite = null
var _shadow_ground_offset: Vector2 = Vector2.ZERO
var _shadow_base_scale: Vector2 = Vector2.ONE
var _hover_rest_position: Vector2 = Vector2.ZERO
var _body_rest_y: float = 0.0


func init(parent: Node) -> Node:
    .init(parent)
    _disable_hole_collision_response()
    _hover_target = _parent.get_node_or_null(hover_target_path) as Node2D
    _tilt_target = _parent.get_node_or_null(tilt_target_path) as Node2D
    if _tilt_target == null:
        _tilt_target = _hover_target
    assert(_hover_target != null, "FloatingPetMovementBehavior needs a hover target node")
    _hover_rest_position = _hover_target.position

    _shadow = _parent.get_node_or_null(shadow_path) as Sprite
    if is_instance_valid(_shadow):
        _shadow_ground_offset = _shadow.global_position - _parent.global_position
        _shadow_base_scale = _shadow.global_scale.abs()

    _body_rest_y = _hover_target.global_position.y - _parent.global_position.y
    reset_motion()
    return self


func _disable_hole_collision_response() -> void:
    if not ignore_hole_collision:
        return
    var body: RigidBody2D = _parent as RigidBody2D
    if body == null:
        return
    var tree: SceneTree = body.get_tree()
    if tree == null:
        # init() normally runs after the pet joins the tree; retry on entry.
        if not body.is_connected("tree_entered", self, "_disable_hole_collision_response"):
            body.connect("tree_entered", self, "_disable_hole_collision_response", [], CONNECT_ONESHOT)
        return
    if not tree.is_connected("node_added", self, "_on_scene_tree_node_added"):
        tree.connect("node_added", self, "_on_scene_tree_node_added")
    _add_hole_exceptions(tree.root)


func _on_scene_tree_node_added(node: Node) -> void:
    # A composite pit scene attaches its holes as children before the container
    # enters the tree, so only the container emits this signal. Walk the added
    # subtree instead of checking the node alone.
    _add_hole_exceptions(node)


func _add_hole_exceptions(node: Node) -> void:
    if node is Hole:
        _add_hole_exception(node as PhysicsBody2D)
        return
    for child in node.get_children():
        _add_hole_exceptions(child)


func _add_hole_exception(hole: PhysicsBody2D) -> void:
    var body: RigidBody2D = _parent as RigidBody2D
    if body == null or hole == null:
        return
    body.add_collision_exception_with(hole)


func reset_motion() -> void:
    .reset_motion()
    _tilt = 0.0
    _motion_time = rand_range(0.0, TAU)
    if is_instance_valid(_hover_target):
        _hover_target.position = _hover_rest_position
    if is_instance_valid(_tilt_target):
        _tilt_target.rotation = 0.0


func _process(delta: float) -> void:
    if not _initialized or not is_instance_valid(_parent) or _parent.dead or _parent._end_of_wave:
        return

    _motion_time += delta
    _update_hover(delta)


func _update_hover(delta: float) -> void:
    var motion_factor: float = _get_hover_motion_factor()
    var hover_speed_value: float = _get_hover_speed()
    var hover_amplitude_value: float = _get_hover_amplitude()
    var vertical_wave: float = sin(_motion_time * hover_speed_value) \
        + sin(_motion_time * hover_speed_value * hover_secondary_speed_ratio + hover_secondary_phase) * hover_secondary_ratio
    var sway: float = sin(_motion_time * sway_speed) * motion_factor
    var jitter: Vector2 = _get_hover_jitter()
    _hover_target.position = _hover_rest_position + Vector2(
        sway * sway_distance + jitter.x,
        -_get_hover_height() + vertical_wave * hover_amplitude_value * motion_factor + jitter.y
    )

    var target_tilt: float = _get_tilt_target()
    _tilt = lerp(_tilt, target_tilt, min(1.0, _get_tilt_lerp_speed() * delta))
    _tilt_target.rotation = _tilt + sway * sway_angle

    _update_shadow()
    _update_extra_visuals(delta)


func _update_shadow() -> void:
    if not is_instance_valid(_shadow):
        return

    var hover: float = _body_rest_y - (_hover_target.global_position.y - _parent.global_position.y)
    var hover_ratio: float = clamp(
        hover / max(1.0, _get_hover_height() + _get_hover_amplitude() * 1.2),
        0.0,
        1.0
    )
    var shadow_size: Vector2 = _shadow_base_scale * lerp(1.0, shadow_min_scale, hover_ratio)
    # Rebuild the world transform to cancel inherited animation, tilt and mirroring.
    _shadow.global_transform = Transform2D(
        Vector2(shadow_size.x, 0.0),
        Vector2(0.0, shadow_size.y),
        _parent.global_position + _shadow_ground_offset
    )
    _shadow.modulate.a = lerp(1.0, shadow_min_alpha, hover_ratio)


func _get_hover_motion_factor() -> float:
    return 1.0


func _get_hover_height() -> float:
    return hover_height


func _get_hover_amplitude() -> float:
    return hover_amplitude


func _get_hover_speed() -> float:
    return hover_speed


func _get_hover_jitter() -> Vector2:
    return Vector2.ZERO


func _should_avoid_forbidden_zones() -> bool:
    return false


func _get_tilt_target() -> float:
    return clamp(_velocity.x / max(1.0, _get_reference_speed()), -1.0, 1.0) * tilt_max


func _get_tilt_lerp_speed() -> float:
    return tilt_speed


func _update_extra_visuals(_delta: float) -> void:
    pass
