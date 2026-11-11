extends Pet

# Pipi Cat: drifts around the owner, charges when an enemy enters its trigger
# zone, blows nearby enemies airborne, then rests. The cat only depends on Pet;
# its mood state machine, voice and exit dissolve all live here.

enum State { ARMED, CHARGING, BLOWING, COOLDOWN }

const FANTASY_VISUAL_PARTS_SYNC = preload("res://mods-unpacked/YokoAndCave-Fantasy/extensions/services/visual_parts_sync.gd")
const ANGRY_SOUND = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/entities/pets/pipi_cat/audio/pipi_cat_angry.wav")
const PURRING_SOUND = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/entities/pets/pipi_cat/audio/pipi_cat_purring.wav")
const EXIT_DISSOLVE_SHADER = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/entities/pets/pipi_cat/scene/pipi_cat_exit_dissolve.shader")

# The cat leaves through a four-point star iris. The corners of the sprite are
# clipped first, then the remaining diamond star shrinks into the center so the
# pet never pops out of existence between waves.
export(float) var exit_dissolve_duration: float = 0.9
export(float) var exit_star_sharpness: float = 0.62
export(float) var exit_edge_softness: float = 0.012
export(float) var exit_edge_width: float = 0.06
export(Color) var exit_edge_color: Color = Color(1.0, 1.0, 1.0, 0.85)
export(float) var exit_shadow_fade_ratio: float = 0.7

onready var _parts_offset: Node2D = $"Animation/Offset"
onready var _trigger_shape: CollisionShape2D = $"TargetTriggerZone/CollisionShape2D"
onready var _normal: Sprite = $"Animation/Offset/Normal"
onready var _angry: Sprite = $"Animation/Offset/Angry"
onready var _tired: Sprite = $"Animation/Offset/Tired"
onready var _voice: AudioStreamPlayer2D = $"Voice"
onready var _exit_shadow: Sprite = $"Animation/Offset/Shadow"

var _visual_parts_sync = FANTASY_VISUAL_PARTS_SYNC.new()
var _effect = null
var _state: int = State.ARMED
var _state_time_left: float = 0.0
var _targets_in_range: Array = []
var _idle_voice_time_left: float = 0.0

var _exit_material: ShaderMaterial = null
var _exit_sprites: Array = []
var _exit_base_materials: Dictionary = {}
var _exit_elapsed: float = 0.0
var _exit_shadow_alpha: float = 1.0
var _exit_dissolving: bool = false
var _exit_waiting_for_animation: bool = false
var _exit_released: bool = false

# ══════════════════════════════════════════ Lifecycle ══════════════════════════════════════════ #

func _ready() -> void:
    # Evaluate animation tracks before the body and shadow are updated each frame.
    _animation_player.process_priority = -1
    _visual_parts_sync.setup_from(_parts_offset, sprite)
    _set_visual_state(State.ARMED)


func init(zone_min_pos: Vector2, zone_max_pos: Vector2, p_players_ref: Array = [], entity_spawner_ref = null) -> void:
    .init(zone_min_pos, zone_max_pos, p_players_ref, entity_spawner_ref)
    _movement_behavior.reset_wander()
    _reset_idle_voice()


func respawn() -> void:
    # The spawner registers targetable pets after respawn() returns. Registering
    # here as well would add a duplicate entry that erase() cannot fully remove,
    # so this only restores the state machine.
    .respawn()
    _state = State.ARMED
    _state_time_left = 0.0
    _targets_in_range.clear()
    _movement_behavior.reset_wander()
    _reset_idle_voice()
    _set_visual_state(State.ARMED)
    _reset_exit_dissolve()


func die(args: = DieArgs.new()) -> void:
    _voice.stop()
    _set_targetable(false)
    .die(args)
    _start_exit_dissolve()


func death_animation_finished() -> void:
    if _exit_released:
        return
    if _exit_dissolving:
        _exit_waiting_for_animation = true
        return
    _exit_released = true
    .death_animation_finished()


func end_of_wave_callback() -> void:
    _voice.stop()
    .end_of_wave_callback()


func update_animation(movement: Vector2) -> void:
    .update_animation(movement)
    _parts_offset.scale.x = sprite.scale.x * _parts_offset.scale.y


func _set_outlines(alpha: float = 1.0, desaturation: float = 0.0) -> void:
    ._set_outlines(alpha, desaturation)
    _visual_parts_sync.sync_from(sprite)


func update_data(effect: PetEffect) -> void:
    .update_data(effect)
    _effect = effect
    assert(
        _effect != null
        and _effect.has_method("get_charge_duration")
        and _effect.has_method("get_stun_duration")
        and _effect.has_method("get_cooldown_duration"),
        "PipiCat requires a HowlingPetEffect resource"
    )
    # The scene shares subresources; each pet needs its own detection radius.
    _trigger_shape.shape = _trigger_shape.shape.duplicate()
    _trigger_shape.shape.radius = _effect.blow_radius

# ══════════════════════════════════════════ Mood State ═════════════════════════════════════════ #

func _physics_process(delta: float) -> void:
    if dead or _end_of_wave:
        return

    _update_idle_voice(delta)

    match _state:
        State.ARMED:
            _try_charge()

        State.CHARGING:
            _prune_targets()
            if _targets_in_range.empty():
                _set_state(State.ARMED)
                _state_time_left = 0.0
                return

            _state_time_left -= delta
            if _state_time_left <= 0.0:
                _blow_away_enemies()

        State.BLOWING:
            _state_time_left -= delta
            if _state_time_left <= 0.0:
                _enter_cooldown()

        State.COOLDOWN:
            _state_time_left -= delta
            if _state_time_left <= 0.0:
                _set_state(State.ARMED)


func _try_charge() -> void:
    if dead or _end_of_wave:
        return
    _prune_targets()
    if _targets_in_range.empty():
        return
    _set_state(State.CHARGING)
    _state_time_left = _effect.get_charge_duration(player_index)


func _enter_cooldown() -> void:
    _set_state(State.COOLDOWN)
    _state_time_left = _effect.get_cooldown_duration(player_index)


func _blow_away_enemies() -> void:
    _set_state(State.BLOWING)
    _play_attack_voice()
    _state_time_left = max(0.1, _animation_player.get_animation("angry_trigger").length)
    var blow_distance: float = _get_blow_distance()
    var stun_duration: float = _effect.get_stun_duration(player_index)
    var impact_damage_percent: float = _effect.impact_damage_percent
    var boss_impact_damage_percent: float = _effect.boss_impact_damage_percent
    for enemy in _targets_in_range.duplicate():
        if not is_instance_valid(enemy) or enemy.dead or enemy._pending_die:
            continue

        var direction: Vector2 = enemy.global_position - global_position
        if direction.length_squared() == 0:
            direction = Vector2.RIGHT
        enemy.fa_launch_airborne(
            direction.normalized(),
            blow_distance,
            player_index,
            stun_duration,
            impact_damage_percent,
            boss_impact_damage_percent
        )


func _get_blow_distance() -> float:
    var zone_size: Vector2 = ZoneService.get_current_zone_rect().size
    return min(zone_size.x, zone_size.y) * _effect.blow_distance_map_ratio


func _prune_targets() -> void:
    for i in range(_targets_in_range.size() - 1, -1, -1):
        var enemy = _targets_in_range[i]
        if not is_instance_valid(enemy) or enemy.dead or enemy._pending_die:
            _targets_in_range.remove(i)


func _set_state(next_state: int) -> void:
    if _state == next_state:
        return

    var was_targetable: bool = _is_targetable_state(_state)
    _state = next_state
    var is_targetable: bool = _is_targetable_state(next_state)
    if was_targetable != is_targetable:
        _set_targetable(is_targetable)
    _set_visual_state(next_state)


func _set_visual_state(state: int) -> void:
    _normal.visible = state == State.ARMED or state == State.CHARGING
    _tired.visible = state == State.COOLDOWN
    _angry.visible = state == State.BLOWING

    if state == State.COOLDOWN:
        _animation_player.play("tired_idle")
    elif state == State.CHARGING or state == State.BLOWING:
        _animation_player.play("angry_trigger")
    elif state == State.ARMED:
        _animation_player.play("idle")


func _is_targetable_state(state: int) -> bool:
    return state != State.COOLDOWN


func is_charging() -> bool:
    return _state == State.CHARGING


func is_blowing() -> bool:
    return _state == State.BLOWING


func is_cooling_down() -> bool:
    return _state == State.COOLDOWN


func _set_targetable(targetable: bool) -> void:
    if not is_instance_valid(_entity_spawner_ref):
        return

    var targetable_pets: Array = _entity_spawner_ref.targetable_pets
    if targetable:
        if not can_be_targeted_by_enemies:
            return
        if not targetable_pets.has(self):
            targetable_pets.push_back(self)
        return

    if not targetable_pets.has(self):
        return

    targetable_pets.erase(self)
    if _entity_spawner_ref._cleaning_up:
        return

    # Removing the pet only affects future target refreshes. Enemies already
    # locked on it keep a stale target until their next refresh, so retarget
    # them once here instead of revisiting every enemy each frame.
    _retarget_enemies_away_from_self()


func _retarget_enemies_away_from_self() -> void:
    for enemy in _entity_spawner_ref.get_all_enemies(false):
        if not is_instance_valid(enemy) or enemy.dead:
            continue
        if enemy.current_target != self:
            continue
        enemy.update_target()

# ══════════════════════════════════════════ Voice ══════════════════════════════════════════════ #

func _reset_idle_voice() -> void:
    _voice.stop()
    _idle_voice_time_left = rand_range(6.0, 10.0)


func _update_idle_voice(delta: float) -> void:
    _idle_voice_time_left = max(0.0, _idle_voice_time_left - delta)
    if _idle_voice_time_left > 0.0 or _voice.playing:
        return
    if _state != State.ARMED and _state != State.COOLDOWN:
        return

    _prune_targets()
    if _targets_in_range.empty():
        return

    _play_idle_voice()
    _idle_voice_time_left = rand_range(6.0, 10.0)


func _play_voice(sound: AudioStream, volume_db: float) -> void:
    if sound == null:
        return
    # One channel lets the attack interrupt the idle voice without overlapping.
    _voice.stop()
    _voice.stream = sound
    _voice.volume_db = volume_db
    _voice.play()
    _idle_voice_time_left = rand_range(6.0, 10.0)


func _play_idle_voice() -> void:
    _play_voice(PURRING_SOUND, -12.0)


func _play_attack_voice() -> void:
    _play_voice(ANGRY_SOUND, -6.5)

# ══════════════════════════════════════════ Target Trigger ═════════════════════════════════════ #

func _on_TargetTriggerZone_body_entered(body: Node) -> void:
    if body.dead or body._pending_die:
        return

    if not _targets_in_range.has(body):
        _targets_in_range.append(body)

    if _state == State.ARMED:
        _try_charge()


func _on_TargetTriggerZone_body_exited(body: Node) -> void:
    _targets_in_range.erase(body)


func _on_AnimationPlayer_animation_finished(anim_name: String) -> void:
    if dead or _end_of_wave or anim_name != "angry_trigger":
        return

    if _state == State.BLOWING:
        _enter_cooldown()

# ══════════════════════════════════════════ Exit Dissolve ══════════════════════════════════════ #

func _process(delta: float) -> void:
    if not _exit_dissolving:
        return

    _exit_elapsed += delta
    var duration: float = max(0.05, exit_dissolve_duration)
    var ratio: float = clamp(_exit_elapsed / duration, 0.0, 1.0)
    var eased: float = ratio * ratio * (3.0 - 2.0 * ratio)
    _apply_exit_progress(eased)
    _fade_exit_shadow(eased)

    if ratio >= 1.0:
        _finish_exit_dissolve()


func _start_exit_dissolve() -> void:
    if _exit_dissolving or _exit_released:
        return

    _exit_dissolving = true
    _exit_elapsed = 0.0
    _prepare_exit_material()
    _apply_exit_progress(0.0)
    if is_instance_valid(_exit_shadow):
        _exit_shadow_alpha = _exit_shadow.modulate.a


func _prepare_exit_material() -> void:
    if _exit_material == null:
        _exit_material = ShaderMaterial.new()
        _exit_material.shader = EXIT_DISSOLVE_SHADER

    _exit_material.set_shader_param("star_sharpness", exit_star_sharpness)
    _exit_material.set_shader_param("edge_softness", exit_edge_softness)
    _exit_material.set_shader_param("edge_width", exit_edge_width)
    _exit_material.set_shader_param("edge_color", exit_edge_color)

    if _exit_sprites.empty():
        _exit_sprites = [_normal, _angry, _tired]

    _exit_base_materials.clear()
    for sprite in _exit_sprites:
        _exit_base_materials[sprite] = sprite.material
        sprite.material = _exit_material


func _apply_exit_progress(value: float) -> void:
    if _exit_material != null:
        _exit_material.set_shader_param("progress", clamp(value, 0.0, 1.0))


func _fade_exit_shadow(eased: float) -> void:
    if not is_instance_valid(_exit_shadow):
        return
    var fade_ratio: float = clamp(eased / max(0.01, exit_shadow_fade_ratio), 0.0, 1.0)
    _exit_shadow.modulate.a = _exit_shadow_alpha * (1.0 - fade_ratio)


func _finish_exit_dissolve() -> void:
    _exit_dissolving = false
    _apply_exit_progress(1.0)
    for sprite in _exit_sprites:
        sprite.visible = false
    if is_instance_valid(_exit_shadow):
        _exit_shadow.visible = false

    if _exit_waiting_for_animation:
        _exit_waiting_for_animation = false
        _exit_released = true
        .death_animation_finished()


func _reset_exit_dissolve() -> void:
    _exit_dissolving = false
    _exit_waiting_for_animation = false
    _exit_released = false
    _exit_elapsed = 0.0
    _apply_exit_progress(0.0)

    for sprite in _exit_sprites:
        if _exit_base_materials.has(sprite):
            sprite.material = _exit_base_materials[sprite]
    _exit_base_materials.clear()

    if is_instance_valid(_exit_shadow):
        _exit_shadow.visible = true
        _exit_shadow.modulate.a = 1.0
