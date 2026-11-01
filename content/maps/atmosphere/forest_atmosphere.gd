extends Node2D

const GRASS = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/maps/atmosphere/forest_grass.gd")
const GRASS_TEXTURES = [
    preload("res://mods-unpacked/YokoAndCave-Fantasy/content/maps/atmosphere/textures/grass_01.webp"),
    preload("res://mods-unpacked/YokoAndCave-Fantasy/content/maps/atmosphere/textures/grass_02.webp"),
    preload("res://mods-unpacked/YokoAndCave-Fantasy/content/maps/atmosphere/textures/grass_03.webp")
]
const FLATTENED_TEXTURES = [
    preload("res://mods-unpacked/YokoAndCave-Fantasy/content/maps/atmosphere/textures/grass_flattened_01.webp"),
    preload("res://mods-unpacked/YokoAndCave-Fantasy/content/maps/atmosphere/textures/grass_flattened_02.webp"),
    preload("res://mods-unpacked/YokoAndCave-Fantasy/content/maps/atmosphere/textures/grass_flattened_03.webp")
]
const RAY_TEXTURES = [
    preload("res://mods-unpacked/YokoAndCave-Fantasy/content/maps/atmosphere/textures/god_ray_00.webp"),
    preload("res://mods-unpacked/YokoAndCave-Fantasy/content/maps/atmosphere/textures/god_ray_01.webp"),
    preload("res://mods-unpacked/YokoAndCave-Fantasy/content/maps/atmosphere/textures/god_ray_02.webp")
]
const GRASS_SHADER = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/maps/atmosphere/forest_grass.shader")
const GLOW_SHADER = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/maps/atmosphere/forest_glow.shader")
const TINT_SHADER = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/maps/atmosphere/forest_tint.shader")
const PARTICLES = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/maps/atmosphere/forest_particles.tscn")
const BORDER = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/maps/structures/spiritwood/spiritwood_border.gd")

var entities_container: YSort
var players: Array = []
var _random = RandomNumberGenerator.new()
var _grass_material: ShaderMaterial
var _elapsed: float = 0.0
var _light_patches: Array = []
var _border: Node2D

# ══════════════════════════════════════════ Extension ══════════════════════════════════════════ #
func _ready() -> void:
    name = "FantasyForestAtmosphere"
    _random.randomize()
    var bounds: Rect2 = ZoneService.get_current_zone_rect()
    _border = BORDER.new()
    add_child(_border)
    _border.create_border(bounds, entities_container)
    _create_grass(bounds)
    _create_lighting(bounds)
    var particles = PARTICLES.instance()
    particles.position = bounds.position + bounds.size * 0.5
    particles.emission_rect_extents = bounds.size * 0.5
    particles.amount = int(clamp(bounds.get_area() / 60000.0, 12.0, 80.0))
    particles.z_index = 4
    add_child(particles)

func _process(delta: float) -> void:
    _elapsed += delta
    _border.update_wind(_elapsed)
    _border.update_occlusion(players, delta)
    _grass_material.set_shader_param("elapsed", _elapsed)
    for patch in _light_patches:
        patch.age += delta
        if patch.age >= patch.lifetime:
            _reset_light_patch(patch)
        var fade: float = smoothstep(0.0, patch.fade_duration, patch.age)
        fade *= 1.0 - smoothstep(patch.lifetime - patch.fade_duration, patch.lifetime, patch.age)
        var cycle: float = sin(patch.age * 0.24 + patch.phase)
        var breath: float = 1.0 + 0.04 * cycle
        patch.sprite.modulate.a = patch.strength * fade * (0.94 + 0.06 * cycle)
        patch.sprite.scale = patch.base_scale * Vector2(breath, breath)
        patch.sprite.position = patch.origin + patch.drift * (patch.age / patch.lifetime - 0.5)

# ══════════════════════════════════════════ Custom ══════════════════════════════════════════ #
func _create_grass(bounds: Rect2) -> void:
    _grass_material = ShaderMaterial.new()
    _grass_material.shader = GRASS_SHADER
    var spacing: float = max(80.0, sqrt(bounds.get_area() / 360.0))
    var columns: int = int(bounds.size.x / spacing)
    var rows: int = int(bounds.size.y / spacing)
    for x in range(columns):
        for y in range(rows):
            if _random.randf() > 0.55: continue
            var index: int = _random.randi_range(0, GRASS_TEXTURES.size() - 1)
            var grass = GRASS.new()
            grass.texture = GRASS_TEXTURES[index]
            grass.flattened_texture = FLATTENED_TEXTURES[index]
            grass.centered = false
            grass.offset = -grass.texture.get_size() * Vector2(0.5, 0.9)
            grass.material = _grass_material
            grass.flip_h = _random.randf() > 0.5
            var grass_position: Vector2 = bounds.position + Vector2(
                (x + _random.randf_range(0.25, 0.75)) * spacing,
                (y + _random.randf_range(0.25, 0.75)) * spacing)
            grass.position = entities_container.to_local(to_global(grass_position))
            var size: float = _random.randf_range(0.8, 1.15)
            grass.scale = Vector2(size, size)
            grass.modulate = Color(0.95, 1.0, 0.97, 0.9)
            grass.ground_container = get_parent()
            entities_container.add_child(grass)

func _create_lighting(bounds: Rect2) -> void:
    var glow_layer = CanvasLayer.new()
    glow_layer.name = "FantasyForestScreenLight"
    glow_layer.layer = 1
    add_child(glow_layer)
    var tint = ColorRect.new()
    tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
    tint.anchor_right = 1.0
    tint.anchor_bottom = 1.0
    var tint_material = ShaderMaterial.new()
    tint_material.shader = TINT_SHADER
    tint.material = tint_material
    glow_layer.add_child(tint)
    var glow = ColorRect.new()
    glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
    glow.anchor_right = 1.0
    glow.anchor_bottom = 1.0
    var glow_material = ShaderMaterial.new()
    glow_material.shader = GLOW_SHADER
    glow.material = glow_material
    glow_layer.add_child(glow)

    var light_material = CanvasItemMaterial.new()
    light_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
    light_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
    var light_bounds = Rect2(bounds.position, bounds.size * Vector2(1.0, 0.75))
    var columns: int = int(ceil(light_bounds.size.x / 1200.0))
    var rows: int = int(ceil(light_bounds.size.y / 850.0))
    var cell_size = Vector2(light_bounds.size.x / columns, light_bounds.size.y / rows)
    for x in range(columns):
        for y in range(rows):
            var spot = Sprite.new()
            spot.name = "ForestSunray"
            spot.z_index = 3
            spot.material = light_material
            spot.modulate = Color(1.0, 0.95, 0.82, 0.0)
            add_child(spot)
            var patch = {
                "sprite": spot,
                "cell": Rect2(light_bounds.position + Vector2(x, y) * cell_size, cell_size)
            }
            _reset_light_patch(patch)
            patch.age = float(x * rows + y) / float(columns * rows) * patch.lifetime + 8.0
            patch.age = fmod(patch.age, patch.lifetime)
            _light_patches.append(patch)
    _process(0.0)

func _reset_light_patch(patch: Dictionary) -> void:
    patch.sprite.texture = RAY_TEXTURES[_random.randi_range(0, RAY_TEXTURES.size() - 1)]
    patch.base_scale = Vector2.ONE * _random.randf_range(0.85, 1.15)
    patch.origin = patch.cell.position + patch.cell.size * Vector2(
        _random.randf_range(0.25, 0.75), _random.randf_range(0.25, 0.75))
    patch.drift = Vector2(_random.randf_range(35.0, 65.0), _random.randf_range(-12.0, 12.0)) * min(1.0, min(patch.cell.size.x, patch.cell.size.y) / 140.0)
    patch.phase = _random.randf_range(0.0, TAU)
    patch.age = 0.0
    patch.lifetime = _random.randf_range(28.0, 38.0)
    patch.fade_duration = _random.randf_range(7.0, 10.0)
    patch.strength = _random.randf_range(0.28, 0.36)
