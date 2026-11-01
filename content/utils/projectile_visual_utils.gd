extends Reference


const GROUND_Z_INDEX: int = 0


static func get_pooled_ground_effect(scene: PackedScene, main: Node) -> Node2D:
    var effect: Node2D = _get_pooled_effect(scene, main, main._tile_map)
    effect.z_index = GROUND_Z_INDEX
    effect.z_as_relative = true
    return effect


static func get_pooled_effect(scene: PackedScene, main: Node) -> Node:
    return _get_pooled_effect(scene, main, main._effects)


static func _get_pooled_effect(scene: PackedScene, main: Node, container: Node) -> Node:
    var effect = main.get_node_from_pool(scene.get_instance_id(), container)
    if effect == null:
        effect = scene.instance()
        container.add_child(effect)
    return effect


static func release_effect(effect: Node2D, main: Node, pool_id: int) -> void:
    effect.visible = false
    effect.set_process(false)
    effect.set_physics_process(false)
    if is_instance_valid(main) and pool_id >= 0:
        main.add_node_to_pool(effect, pool_id)
    else:
        effect.queue_free()


static func get_opacity() -> float:
    if ProgressData == null or not is_instance_valid(ProgressData):
        return 1.0
    var settings = ProgressData.settings
    if settings == null:
        return 1.0
    if not ("projectile_opacity" in settings):
        return 1.0
    return clamp(float(settings.projectile_opacity), 0.0, 1.0)
