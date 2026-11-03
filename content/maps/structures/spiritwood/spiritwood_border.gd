extends Node2D

enum Scenery { TREE, PLANT, ACCENT }

const OCCLUDED_ALPHA: float = 0.35
const OCCLUSION_FADE_SPEED: float = 5.0
const OCCLUSION_MARGIN: float = 6.0

const FOLIAGE_SHADER = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/maps/structures/spiritwood/spirit_foliage.shader")
const SPIRIT_POOL = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/maps/structures/spiritwood/textures/spirit_pool.webp")
const MOTE = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/maps/atmosphere/textures/forest_mote.png")
const TREES = [
    preload("res://mods-unpacked/YokoAndCave-Fantasy/content/maps/structures/spiritwood/textures/trees_tree_01.webp"),
    preload("res://mods-unpacked/YokoAndCave-Fantasy/content/maps/structures/spiritwood/textures/trees_tree_02.webp"),
    preload("res://mods-unpacked/YokoAndCave-Fantasy/content/maps/structures/spiritwood/textures/trees_tree_03.webp"),
    preload("res://mods-unpacked/YokoAndCave-Fantasy/content/maps/structures/spiritwood/textures/trees_tree_04.webp")
]
const PLANTS = [
    preload("res://mods-unpacked/YokoAndCave-Fantasy/content/maps/structures/spiritwood/textures/plants_01_spirit_fern.webp"),
    preload("res://mods-unpacked/YokoAndCave-Fantasy/content/maps/structures/spiritwood/textures/plants_02_lantern_herb.webp"),
    preload("res://mods-unpacked/YokoAndCave-Fantasy/content/maps/structures/spiritwood/textures/plants_03_moon_mushrooms.webp"),
    preload("res://mods-unpacked/YokoAndCave-Fantasy/content/maps/structures/spiritwood/textures/plants_08_twisted_sapling.webp"),
    preload("res://mods-unpacked/YokoAndCave-Fantasy/content/maps/structures/spiritwood/textures/plants_plant_01_curled_fern.webp"),
    preload("res://mods-unpacked/YokoAndCave-Fantasy/content/maps/structures/spiritwood/textures/plants_plant_02_fan_leaf.webp"),
    preload("res://mods-unpacked/YokoAndCave-Fantasy/content/maps/structures/spiritwood/textures/plants_plant_03_pod.webp")
]
const SPIRIT_MARK_STONE = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/maps/structures/spiritwood/textures/accents_06_spirit_mark_stone.webp")
const GHOST_CRYSTAL_MOSS = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/maps/structures/spiritwood/textures/accents_07_ghost_crystal_moss.webp")
const CRYSTAL_ROCK = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/maps/structures/spiritwood/textures/accents_rock_02_crystal.webp")
const SPIRIT_SPRING_TEXTURES = [SPIRIT_MARK_STONE, GHOST_CRYSTAL_MOSS, CRYSTAL_ROCK]
const ACCENTS = [
    preload("res://mods-unpacked/YokoAndCave-Fantasy/content/maps/structures/spiritwood/textures/accents_04_hollow_spirit_stump.webp"),
    preload("res://mods-unpacked/YokoAndCave-Fantasy/content/maps/structures/spiritwood/textures/accents_05_rootbound_rock.webp"),
    SPIRIT_MARK_STONE,
    GHOST_CRYSTAL_MOSS,
    preload("res://mods-unpacked/YokoAndCave-Fantasy/content/maps/structures/spiritwood/textures/accents_rock_01_moss.webp"),
    CRYSTAL_ROCK,
    preload("res://mods-unpacked/YokoAndCave-Fantasy/content/maps/structures/spiritwood/textures/accents_rock_03_standing.webp")
]
const PLANT_VARIANTS = [0, 1, 2, 3, 4, 4, 5, 5, 6, 6]
const SCENERY_TEXTURES = [TREES, PLANTS, ACCENTS]

var _random = RandomNumberGenerator.new()
var _materials: Array = []
var _occluders: Array = []
var _entities: YSort
var _spirit_material: CanvasItemMaterial
var _mote_gradient: Gradient
var moonlit: bool = false

# ══════════════════════════════════════════ Custom ══════════════════════════════════════════ #
func create_border(bounds: Rect2, entities: YSort) -> void:
    name = "FantasySpiritwoodBorder"
    _entities = entities
    _random.randomize()
    _spirit_material = CanvasItemMaterial.new()
    _spirit_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
    _spirit_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
    _mote_gradient = Gradient.new()
    _mote_gradient.offsets = PoolRealArray([0.0, 0.25, 0.7, 1.0])
    if moonlit:
        _mote_gradient.colors = PoolColorArray([
            Color(0.6, 0.7, 1.0, 0.0), Color(0.72, 0.82, 1.0, 0.55),
            Color(0.52, 0.5, 0.9, 0.3), Color(0.4, 0.45, 0.8, 0.0)])
    else:
        _mote_gradient.colors = PoolColorArray([
            Color(0.25, 0.8, 1.0, 0.0), Color(0.35, 0.9, 1.0, 0.65),
            Color(0.2, 0.65, 1.0, 0.35), Color(0.15, 0.4, 0.8, 0.0)])
    _create_ring(bounds.grow_individual(245.0, 120.0, 235.0, 500.0),
        Scenery.TREE, Vector2(135.0, 210.0), 32.0, Vector2(0.94, 1.06),
        Color(0.38, 0.48, 0.68) if moonlit else Color(0.55, 0.69, 0.66), _create_material(3.4, 0.65, 0.0))
    _create_ring(bounds.grow_individual(64.0, 18.0, 60.0, 155.0),
        Scenery.PLANT, Vector2(108.0, 170.0), 24.0, Vector2(0.72, 0.92),
        Color(0.48, 0.6, 0.8) if moonlit else Color(0.68, 0.82, 0.78), _create_material(2.3, 1.15, 0.24))
    _create_ring(bounds.grow_individual(80.0, 64.0, 74.0, 150.0),
        Scenery.ACCENT, Vector2(380.0, 600.0), 22.0, Vector2(0.70, 0.86),
        Color(0.57, 0.65, 0.88) if moonlit else Color(0.76, 0.84, 0.86), _create_material(0.0, 0.0, 0.32))

func update_wind(elapsed: float) -> void:
    for material in _materials:
        material.set_shader_param("elapsed", elapsed)

func update_occlusion(players: Array, delta: float) -> void:
    var player_regions: Array = []
    var entities_inverse: Transform2D = _entities.global_transform.affine_inverse()
    for player in players:
        if not is_instance_valid(player) or player.dead or not player.is_visible_in_tree():
            continue
        var sprite_transform: Transform2D = entities_inverse * player.sprite.global_transform
        var bounds: Rect2 = sprite_transform.xform(player.sprite.get_rect())
        var feet: Vector2 = entities_inverse.xform(player.global_position)
        player_regions.append({"bounds": bounds.expand(feet), "y": feet.y})
    for occluder in _occluders:
        var sprite: Sprite = occluder.sprite
        var target_alpha: float = 1.0
        for region in player_regions:
            if sprite.position.y >= region.y and occluder.bounds.intersects(region.bounds):
                target_alpha = OCCLUDED_ALPHA
                break
        if not is_equal_approx(sprite.modulate.a, target_alpha):
            sprite.modulate.a = move_toward(sprite.modulate.a, target_alpha, OCCLUSION_FADE_SPEED * delta)

func _register_occluder(sprite: Sprite) -> void:
    var bounds: Rect2 = sprite.transform.xform(sprite.get_rect())
    _occluders.append({"sprite": sprite, "bounds": bounds.grow(OCCLUSION_MARGIN)})

func _create_material(sway: float, speed: float, glow: float) -> ShaderMaterial:
    var material = ShaderMaterial.new()
    material.shader = FOLIAGE_SHADER
    material.set_shader_param("sway_strength", sway)
    material.set_shader_param("sway_speed", speed)
    material.set_shader_param("glow_strength", glow)
    if moonlit:
        material.set_shader_param("desaturation", 0.6)
        material.set_shader_param("glow_color", Color(0.58, 0.66, 1.0))
    _materials.append(material)
    return material

func _create_ring(ring: Rect2, scenery: int, spacing: Vector2, jitter: float,
        sizes: Vector2, color: Color, material: ShaderMaterial) -> void:
    var textures: Array = SCENERY_TEXTURES[scenery]
    var distance: float = _random.randf_range(0.0, spacing.x)
    var perimeter: float = 2.0 * (ring.size.x + ring.size.y)
    var previous_index: int = -1
    while distance < perimeter:
        var index: int
        if scenery == Scenery.PLANT:
            index = PLANT_VARIANTS[_random.randi_range(0, PLANT_VARIANTS.size() - 1)]
        else:
            index = _random.randi_range(0, textures.size() - 1)
        if index == previous_index:
            index = (index + _random.randi_range(1, textures.size() - 1)) % textures.size()
        previous_index = index
        var sprite = Sprite.new()
        sprite.name = "SpiritwoodScenery"
        sprite.texture = textures[index]
        sprite.centered = false
        sprite.offset = -sprite.texture.get_size() * Vector2(0.5, 0.9)
        sprite.flip_h = _random.randf() > 0.5
        sprite.scale = Vector2.ONE * _random.randf_range(sizes.x, sizes.y)
        sprite.modulate = color
        sprite.material = material
        var point: Vector2 = _point_on_ring(ring, distance)
        point += Vector2(_random.randf_range(-jitter, jitter), _random.randf_range(-jitter, jitter))
        if scenery == Scenery.PLANT and distance < ring.size.x:
            point.y = min(point.y, ring.position.y - jitter * 0.5)
        sprite.position = _entities.to_local(to_global(point))
        _entities.add_child(sprite)
        _register_occluder(sprite)
        if scenery == Scenery.ACCENT and sprite.texture in SPIRIT_SPRING_TEXTURES:
            _create_spirit_spring(point, sprite.scale.x)
        distance += _random.randf_range(spacing.x, spacing.y)

func _point_on_ring(ring: Rect2, distance: float) -> Vector2:
    if distance < ring.size.x:
        return ring.position + Vector2(distance, 0.0)
    distance -= ring.size.x
    if distance < ring.size.y:
        return ring.position + Vector2(ring.size.x, distance)
    distance -= ring.size.y
    if distance < ring.size.x:
        return ring.end - Vector2(distance, 0.0)
    return Vector2(ring.position.x, ring.end.y - (distance - ring.size.x))

func _create_spirit_spring(point: Vector2, size: float) -> void:
    var pool = Sprite.new()
    pool.texture = SPIRIT_POOL
    pool.position = point + Vector2(0.0, 10.0 * size)
    pool.scale = Vector2.ONE * size
    pool.modulate = Color(0.5, 0.58, 1.0, 0.23) if moonlit else Color(0.25, 0.75, 1.0, 0.28)
    pool.material = _spirit_material
    add_child(pool)
    var motes = CPUParticles2D.new()
    motes.name = "SpiritSpringMotes"
    motes.texture = MOTE
    motes.material = _spirit_material
    motes.position = _entities.to_local(to_global(point))
    motes.amount = 4
    motes.lifetime = 8.0 if moonlit else 6.0
    motes.preprocess = motes.lifetime
    motes.randomness = 0.4
    motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
    motes.emission_rect_extents = Vector2(38.0, 10.0) * size
    motes.direction = Vector2(0.0, -1.0)
    motes.spread = 30.0
    motes.gravity = Vector2(0.0, -0.6 if moonlit else -1.2)
    motes.initial_velocity = 5.5 if moonlit else 9.0
    motes.initial_velocity_random = 0.4
    motes.scale_amount = 0.16
    motes.scale_amount_random = 0.5
    motes.color_ramp = _mote_gradient
    _entities.add_child(motes)
