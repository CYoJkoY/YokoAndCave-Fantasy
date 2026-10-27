extends EnemyProjectile

export(int) var child_projectiles_num = 2
export(int) var child_init_rotation = 90
export(int) var child_rotation_change_after_each = 0
export(bool) var is_symmetrical = true
export(int) var offset_distance = 30
export(int) var init_spawn_cooldown = 0
export(int) var spawn_cooldown = 30
export(PackedScene) var child_projectile = preload("res://mods-unpacked/Yoko-Fantasy/content/projectiles/enemy/skeleton_archer_projectile/skeleton_archer_projectile_small.tscn")
var child_projectile_pool_id: int = Keys.empty_hash
export(float) var power = 0.6
export(String, "perpendicular", "orbit_parent") var child_motion_mode = "perpendicular"
export(float) var child_speed_multiplier = 0.85
export(float) var child_orbit_radius = 50.0
export(float) var child_orbit_radius_growth = 18.0
export(float) var child_orbit_speed = 8.0
export(bool) var will_spawn_entity = false
export(int) var entity_spawn_num = 1
export(Array, String, FILE, "*.tscn") var entity_scenes = []

var _spawn_cooldown: float = 0.0
var _has_spawned_orbit_children: bool = false
var _child_init_rotation_rad: float = 0.0
var _child_rotation_change_after_each_rad: float = 0.0
var main: Main = null
var entity_spawner: EntitySpawner = null

# ══════════════════════════════════════════ Extension ══════════════════════════════════════════ #
func _ready() -> void:
    _spawn_cooldown = init_spawn_cooldown
    if child_projectile != null:
        child_projectile_pool_id = Keys.generate_hash(child_projectile.resource_path)

    main = Utils.get_scene_node()
    entity_spawner = main._entity_spawner
    _child_init_rotation_rad = deg2rad(child_init_rotation)
    _child_rotation_change_after_each_rad = deg2rad(child_rotation_change_after_each)

func _return_to_pool() -> void:
    ._return_to_pool()

    _spawn_cooldown = init_spawn_cooldown
    _has_spawned_orbit_children = false

func _physics_process(delta) -> void:
    if !_has_live_spawn_context(): return
    if child_motion_mode == "orbit_parent" and _has_spawned_orbit_children: return

    _spawn_cooldown -= Utils.physics_one(delta)
    if _spawn_cooldown > 0: return

    for i in range(child_projectiles_num): spawn_child_projectile(i)
    if child_motion_mode == "orbit_parent":
        _has_spawned_orbit_children = true
    
    if will_spawn_entity:
        var args: EntitySpawner.SpawnEntityArgs = EntitySpawner.SpawnEntityArgs.new(global_position, EntityType.ENEMY)
        var entity_scene: PackedScene = load(Utils.get_rand_element(entity_scenes))
        for _i in range(entity_spawn_num): entity_spawner.spawn_entity(entity_scene, args)

    _spawn_cooldown = spawn_cooldown

func spawn_child_projectile(index: int) -> void:
    if !_has_live_spawn_context(): return

    var new_projectile: EnemyProjectile = main.get_node_from_pool(child_projectile_pool_id, main._enemy_projectiles)
    if !is_instance_valid(new_projectile):
        new_projectile = child_projectile.instance()
        main.add_enemy_projectile(new_projectile)
        new_projectile.set_meta("pool_id", child_projectile_pool_id)

    var child_velocity: Vector2 = velocity * child_speed_multiplier
    var spawn_direction: Vector2
    if child_motion_mode == "perpendicular":
        if is_symmetrical and index % 2 == 1:
            child_velocity = child_velocity.rotated(- (_child_init_rotation_rad + (index - 1) * _child_rotation_change_after_each_rad))
        else:
            child_velocity = child_velocity.rotated(_child_init_rotation_rad + index * _child_rotation_change_after_each_rad)
        spawn_direction = child_velocity.normalized()
    else:
        spawn_direction = velocity.normalized() if velocity.length_squared() > 0 else Vector2.RIGHT.rotated(rotation)

    new_projectile.global_position = global_position + spawn_direction * offset_distance
    new_projectile.rotation = child_velocity.angle()
    new_projectile.set_from(_hitbox.from)
    new_projectile.velocity = child_velocity

    new_projectile.set_damage(get_damage() * power)

    if _hitbox.collision_layer == Utils.PET_PROJECTILES_BIT:
        new_projectile.set_collision_layer(_hitbox.collision_layer)
        new_projectile.set_sprite_material(_sprite.material)

    if child_motion_mode == "orbit_parent":
        var orbit_angle: float = _child_init_rotation_rad + PI * 2.0 * float(index) / max(1.0, float(child_projectiles_num))
        new_projectile.setup_orbit_parent(self, orbit_angle, child_orbit_radius, child_orbit_radius_growth, child_orbit_speed)
    
    new_projectile.shoot()

func _has_live_spawn_context() -> bool:
    return is_instance_valid(main) and \
    is_instance_valid(main._enemy_projectiles) and \
    is_instance_valid(entity_spawner) and \
    is_instance_valid(_hitbox.from) and \
    !_hitbox.from.dead
