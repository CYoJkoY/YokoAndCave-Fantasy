extends Reference

const META_KEY: String = "fantasy_tambourine_scheduler"


static func for_scene(main: Node) -> Node:
    if not main.has_meta(META_KEY):
        var scheduler = Scheduler.new()
        scheduler.name = "FantasyTambourineScheduler"
        main.add_child(scheduler)
        main.set_meta(META_KEY, scheduler)
    return main.get_meta(META_KEY)


class Scheduler:
    extends Node2D

    const BLASTS_PER_FRAME: int = 12
    const BLAST_INTERVAL: float = 0.03
    const DAMAGE_DURATION: float = 0.06
    const VISUAL_SCENE: PackedScene = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/weapons/melee/tambourine/vfx/tambourine_shockwave_visual.tscn")
    const VISUAL_SCRIPT = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/weapons/melee/tambourine/vfx/tambourine_shockwave_visual.gd")
    const VISUAL_SHADER: Shader = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/weapons/melee/tambourine/vfx/shaders/tambourine_shockwave.gdshader")

    var _sequences: Array = []
    var _next_sequence: int = 0
    var _time: float = 0.0
    var _explosions: Array = []
    var _retiring_explosions: Array = []
    var _visuals: Array = []
    var _visual_pool: Array = []
    var _materials: Dictionary = {}


    func _ready() -> void:
        set_process(false)
        set_physics_process(false)


    func enqueue(weapon: Node, offsets: Array, origin: Vector2, args: Reference, tint: Color, attack_id: int) -> void:
        _sequences.append({
            "weapon": weapon,
            "offsets": offsets,
            "origin": origin,
            "args": args,
            "tint": tint,
            "attack_id": attack_id,
            "next_index": 0,
            "next_time": _time
        })
        set_process(true)


    func track_explosion(explosion: Node) -> void:
        _explosions.append({
            "node": explosion,
            "age": 0.0,
            "damage_active": true,
            "release_at": VISUAL_SCRIPT.LIFETIME if get_parent()._is_fog_wave else DAMAGE_DURATION
        })
        set_physics_process(true)


    func spawn_visual(explosion: Node2D, tint: Color) -> void:
        var opacity: float = ProgressData.settings.explosion_opacity
        if opacity <= 0.0:
            return
        if not _materials.has(tint):
            var shared_material: ShaderMaterial = ShaderMaterial.new()
            shared_material.shader = VISUAL_SHADER
            shared_material.set_shader_param("tint_color", tint)
            shared_material.set_shader_param("visual_lifetime", VISUAL_SCRIPT.LIFETIME)
            shared_material.set_shader_param("clock_period", VISUAL_SCRIPT.CLOCK_PERIOD)
            _materials[tint] = shared_material
        var visual: Node2D
        if _visual_pool.empty():
            visual = VISUAL_SCENE.instance()
            add_child(visual)
        else:
            visual = _visual_pool.pop_back()
            move_child(visual, get_child_count() - 1)
        visual.start_visual(explosion.global_transform, _materials[tint], _time, opacity)
        _visuals.append(visual)
        set_process(true)


    func _physics_process(delta: float) -> void:
        for explosion in _retiring_explosions:
            explosion.end_explosion()
        _retiring_explosions.clear()
        var i: int = 0
        while i < _explosions.size():
            var entry: Dictionary = _explosions[i]
            entry.age += delta
            if entry.damage_active and entry.age >= DAMAGE_DURATION:
                entry.node._hitbox.disable()
                entry.damage_active = false
            if entry.age >= entry.release_at:
                _retiring_explosions.append(entry.node)
                _explosions[i] = _explosions.back()
                _explosions.pop_back()
            else:
                i += 1
        if _explosions.empty() and _retiring_explosions.empty():
            set_physics_process(false)


    func _process(delta: float) -> void:
        if get_parent()._cleaning_up:
            _sequences.clear()
        _time += delta
        var i: int = 0
        while i < _visuals.size():
            var visual: Node2D = _visuals[i]
            if _time >= visual.expires_at:
                visual.hide()
                _visual_pool.append(visual)
                _visuals[i] = _visuals.back()
                _visuals.pop_back()
            else:
                i += 1
        var visits_left: int = _sequences.size()
        var budget: int = BLASTS_PER_FRAME
        while visits_left > 0 and budget > 0:
            if _next_sequence >= _sequences.size():
                _next_sequence = 0
            var sequence: Dictionary = _sequences[_next_sequence]
            visits_left -= 1
            var weapon = sequence.weapon
            if not is_instance_valid(weapon) or not weapon.is_inside_tree() or weapon.is_queued_for_deletion() \
                    or weapon._parent.dead or weapon._parent.cleaning_up:
                _sequences.remove(_next_sequence)
                continue
            if sequence.next_time <= _time:
                sequence.args.pos = sequence.origin + sequence.offsets[sequence.next_index]
                weapon._spawn_shockwave(sequence.args, sequence.tint, sequence.attack_id)
                sequence.next_index += 1
                sequence.next_time = max(sequence.next_time + BLAST_INTERVAL, _time)
                budget -= 1
                if sequence.next_index == sequence.offsets.size():
                    _sequences.remove(_next_sequence)
                    continue
            _next_sequence += 1
        var clock_time: float = fposmod(_time, VISUAL_SCRIPT.CLOCK_PERIOD)
        for shared_material in _materials.values():
            shared_material.set_shader_param("clock_time", clock_time)
        if _sequences.empty():
            _next_sequence = 0
        if _sequences.empty() and _visuals.empty():
            _time = 0.0
            set_process(false)
