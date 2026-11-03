extends CanvasLayer

const DISTORTION_SHADER = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/visual_effects/time_distortion/time_distortion.shader")

var entity_spawner: EntitySpawner
var _screen_copy: BackBufferCopy
var _material: ShaderMaterial
var _lenses: Array = []
var _active: bool = false
var _finished: bool = false
var _visibility: float = 0.0
var _elapsed: float = 0.0
var _strength: float = 0.0

# ══════════════════════════════════════════ Extension ══════════════════════════════════════════ #
func _ready() -> void:
    name = "FantasyTimeDistortion"
    layer = 1
    _screen_copy = BackBufferCopy.new()
    _screen_copy.copy_mode = BackBufferCopy.COPY_MODE_DISABLED
    add_child(_screen_copy)
    _material = ShaderMaterial.new()
    _material.shader = DISTORTION_SHADER
    EntityService.connect("enemy_time_slow_changed", self, "_on_enemy_time_slow_changed")
    set_process(false)
    if EntityService.enemy_time_factor < 1.0:
        _on_enemy_time_slow_changed(true)

func _process(delta: float) -> void:
    if !ProgressData.settings.visual_effects:
        _visibility = 0.0
        _hide_distortion()
        if !_active: set_process(false)
        return

    _visibility = move_toward(_visibility, 1.0 if _active else 0.0, delta * (6.0 if _active else 4.0))
    if !_active and _visibility <= 0.0:
        _hide_distortion()
        set_process(false)
        return

    _elapsed += delta
    if _active:
        _strength = clamp(1.0 - EntityService.enemy_time_factor, 0.0, 1.0)
    _material.set_shader_param("strength", _strength * _visibility)
    _material.set_shader_param("elapsed", _elapsed)

    var viewport_rect: Rect2 = get_viewport().get_visible_rect()
    var count: int = 0
    for enemy in entity_spawner.get_all_enemies():
        if !is_instance_valid(enemy) or enemy.dead or enemy._is_charmed: continue
        var sprite: Sprite = enemy.sprite
        if !sprite.is_visible_in_tree(): continue
        var bounds: Rect2 = sprite.get_global_transform_with_canvas().xform(sprite.get_rect())
        bounds = bounds.grow(max(bounds.size.x, bounds.size.y) * 0.3 + 10.0)
        if !viewport_rect.intersects(bounds): continue
        if count == _lenses.size():
            var new_lens: ColorRect = ColorRect.new()
            new_lens.mouse_filter = Control.MOUSE_FILTER_IGNORE
            new_lens.material = _material
            add_child(new_lens)
            _lenses.append(new_lens)
        var lens: ColorRect = _lenses[count]
        lens.rect_position = bounds.position
        lens.rect_size = bounds.size
        lens.show()
        count += 1

    for i in range(count, _lenses.size()):
        _lenses[i].hide()
    _screen_copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT if count > 0 else BackBufferCopy.COPY_MODE_DISABLED

# ══════════════════════════════════════════ Custom ══════════════════════════════════════════ #
func _on_enemy_time_slow_changed(active: bool) -> void:
    if _finished: return
    _active = active
    set_process(true)

func _hide_distortion() -> void:
    for lens in _lenses:
        lens.hide()
    _screen_copy.copy_mode = BackBufferCopy.COPY_MODE_DISABLED

func clear() -> void:
    _finished = true
    _active = false
    _hide_distortion()
    set_process(false)
