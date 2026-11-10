extends Pet

enum State { ARMED, CHARGING, BLOWING, COOLDOWN }

const FANTASY_VISUAL_PARTS_SYNC = preload("res://mods-unpacked/YokoAndCave-Fantasy/extensions/services/visual_parts_sync.gd")
const ANGRY_SOUND = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/entities/pets/pipi_cat/audio/pipi_cat_angry.wav")
const PURRING_SOUND = preload("res://mods-unpacked/YokoAndCave-Fantasy/content/entities/pets/pipi_cat/audio/pipi_cat_purring.wav")

const DRIFT_EDGE_PADDING: float = 24.0
const DRIFT_MIN_RADIUS: float = 90.0
const DRIFT_ARRIVE_DISTANCE: float = 40.0
const DRIFT_TURN_LIMIT: float = 2.4
const DRIFT_FACING_THRESHOLD: float = 4.0
const DRIFT_TILT_MAX: float = 0.09
const DRIFT_CATCH_UP_MAX_FACTOR: float = 2.5
const SHADOW_MIN_SCALE: float = 0.8
const SHADOW_MIN_ALPHA: float = 0.65
const FLOAT_SWAY_DISTANCE: float = 3.0
const FLOAT_SWAY_ANGLE: float = PI / 60.0
const FLOAT_SWAY_SPEED: float = 1.1

export(float) var charge_duration: float = 2.0
export(float) var cooldown_duration: float = 5.0
export(float) var blow_radius: float = 260.0
export(float) var blow_strength: float = 2.4
export(float) var drift_radius: float = 240.0
export(float) var drift_acceleration: float = 260.0
export(float) var float_height: float = 26.0
export(float) var float_amplitude: float = 15.0
export(float) var float_speed: float = 1.6

var is_pipi_cat: bool = true

onready var _parts_offset: Node2D = $Animation/Offset
onready var _shadow: Sprite = $Animation/Offset/Shadow
onready var _trigger_shape: CollisionShape2D = $TargetTriggerZone/CollisionShape2D
onready var _normal: Sprite = $Animation/Offset/Normal
onready var _angry: Sprite = $Animation/Offset/Angry
onready var _tired: Sprite = $Animation/Offset/Tired
onready var _voice: AudioStreamPlayer2D = $Voice

var _visual_parts_sync = FANTASY_VISUAL_PARTS_SYNC.new()
var _pipi_effect: PipiCatEffect
var _state: int = State.ARMED
var _state_time_left: float = 0.0
var _targets_in_range: Array = []
var _drift_velocity: Vector2 = Vector2.ZERO
var _drift_target: Vector2 = Vector2.ZERO
var _drift_angle: float = 0.0
var _drift_timer: float = 0.0
var _float_time: float = 0.0
var _float_y: float = 0.0
var _tilt: float = 0.0
var _shadow_ground_offset: Vector2 = Vector2.ZERO
var _shadow_base_scale: Vector2 = Vector2.ONE
var _body_rest_y: float = 0.0
var _purr_time_left: float = 0.0

# ══════════════════════════════════════════ Extension ══════════════════════════════════════════ #
func _ready() -> void:
    _shadow_ground_offset = _shadow.global_position - global_position
    _shadow_base_scale = _shadow.global_scale.abs()
    _body_rest_y = _parts_offset.global_position.y - global_position.y
    # Evaluate animation tracks before the body and shadow are updated each frame.
    _animation_player.process_priority = -1
    _visual_parts_sync.setup_from(_parts_offset, sprite)
    _set_visual_state(State.ARMED)

func init(zone_min_pos: Vector2, zone_max_pos: Vector2, p_players_ref: Array = [], entity_spawner_ref = null) -> void:
    .init(zone_min_pos, zone_max_pos, p_players_ref, entity_spawner_ref)
    _reset_drift()
    _reset_voice()

func update_animation(movement: Vector2) -> void:
    .update_animation(movement)
    _parts_offset.scale.x = sprite.scale.x * _parts_offset.scale.y

func _set_outlines(alpha: float = 1.0, desaturation: float = 0.0) -> void:
    ._set_outlines(alpha, desaturation)
    _visual_parts_sync.sync_from(sprite)

func update_data(effect: PetEffect) -> void:
    .update_data(effect)
    _pipi_effect = effect as PipiCatEffect
    charge_duration = _pipi_effect.get_charge_duration(player_index)
    cooldown_duration = _pipi_effect.get_cooldown_duration(player_index)
    blow_radius = _pipi_effect.blow_radius
    blow_strength = _pipi_effect.blow_strength
    # The scene shares subresources; each cat needs its own detection radius.
    _trigger_shape.shape = _trigger_shape.shape.duplicate()
    _trigger_shape.shape.radius = blow_radius

func die(args: = DieArgs.new()) -> void:
    _voice.stop()
    _set_targetable(false)
    .die(args)

func end_of_wave_callback() -> void:
    _voice.stop()
    .end_of_wave_callback()

func respawn() -> void:
    # The spawner registers targetable pets after respawn() returns. Registering
    # here as well would add a duplicate entry that erase() cannot fully remove,
    # so this only restores the state machine.
    .respawn()
    _state = State.ARMED
    _state_time_left = 0.0
    _targets_in_range.clear()
    _reset_drift()
    _reset_voice()
    _set_visual_state(State.ARMED)

func _physics_process(delta: float) -> void:
    if dead or _end_of_wave:
        return

    _update_drift(delta)
    _update_purring(delta)

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

func _process(delta: float) -> void:
    if dead or _end_of_wave:
        return

    _update_float(delta)

# ══════════════════════════════════════════ Custom ══════════════════════════════════════════ #
func _reset_drift() -> void:
    _drift_velocity = Vector2.ZERO
    _drift_angle = rand_range(-PI, PI)
    _float_time = rand_range(0.0, TAU)
    # Picking a target needs the final spawn position, so the first physics tick does it.
    _drift_timer = 0.0

func _reset_voice() -> void:
    _voice.stop()
    _purr_time_left = rand_range(6.0, 10.0)

func _update_purring(delta: float) -> void:
    _purr_time_left = max(0.0, _purr_time_left - delta)
    if _purr_time_left > 0.0 or _voice.playing:
        return
    if _state != State.ARMED and _state != State.COOLDOWN:
        return

    _prune_targets()
    if _targets_in_range.empty():
        return

    _play_voice(PURRING_SOUND, -12.0)

func _play_voice(sound: AudioStream, volume_db: float) -> void:
    # One channel lets the blow interrupt purring without overlapping voices.
    _voice.stop()
    _voice.stream = sound
    _voice.volume_db = volume_db
    _voice.play()
    _purr_time_left = rand_range(6.0, 10.0)

func _update_drift(delta: float) -> void:
    var anchor: Vector2 = _get_drift_anchor()
    var distance_to_anchor: float = global_position.distance_to(anchor)
    var speed_factor: float = _get_drift_speed_factor()

    if distance_to_anchor > drift_radius:
        # Chase the nearest point of the drift ring so a running player never strands the cat.
        _drift_target = _clamp_to_zone(anchor + (global_position - anchor).normalized() * drift_radius)
        _drift_timer = 0.0
        speed_factor *= clamp(distance_to_anchor / drift_radius, 1.0, DRIFT_CATCH_UP_MAX_FACTOR)
    else:
        _drift_timer -= delta
        if _drift_timer <= 0.0 or global_position.distance_squared_to(_drift_target) < DRIFT_ARRIVE_DISTANCE * DRIFT_ARRIVE_DISTANCE:
            _pick_drift_target()

    var cruise_speed: float = get_move_speed() * speed_factor
    var desired_velocity: Vector2 = global_position.direction_to(_drift_target) * cruise_speed
    _drift_velocity = _drift_velocity.move_toward(desired_velocity, drift_acceleration * delta)
    global_position += _drift_velocity * delta

    var clamped_position: Vector2 = _clamp_to_zone(global_position)
    if clamped_position.x != global_position.x:
        _drift_velocity.x = 0.0
    if clamped_position.y != global_position.y:
        _drift_velocity.y = 0.0
    global_position = clamped_position

    # Hovering velocity crosses zero constantly; only flip facing on real sideways motion.
    if abs(_drift_velocity.x) >= DRIFT_FACING_THRESHOLD:
        update_animation(Vector2(_drift_velocity.x, 0.0))

func _update_float(delta: float) -> void:
    _float_time += delta
    var float_factor: float = 0.6 if _state == State.COOLDOWN else 1.0
    var amplitude: float = float_amplitude * float_factor
    _float_y = -float_height + sin(_float_time * float_speed) * amplitude \
        + sin(_float_time * float_speed * 2.26 + 1.3) * amplitude * 0.2
    _parts_offset.position.y = _float_y
    var sway: float = sin(_float_time * FLOAT_SWAY_SPEED) * float_factor
    _parts_offset.position.x = sway * FLOAT_SWAY_DISTANCE

    var cruise_speed: float = max(1.0, get_move_speed())
    var target_tilt: float = clamp(_drift_velocity.x / cruise_speed, -1.0, 1.0) * DRIFT_TILT_MAX
    _tilt = lerp(_tilt, target_tilt, min(1.0, 6.0 * delta))
    _animation.rotation = _tilt + sway * FLOAT_SWAY_ANGLE

    var hover: float = _body_rest_y - (_parts_offset.global_position.y - global_position.y)
    var hover_ratio: float = clamp(hover / max(1.0, float_height + float_amplitude * 1.2), 0.0, 1.0)
    var shadow_size: Vector2 = _shadow_base_scale * lerp(1.0, SHADOW_MIN_SCALE, hover_ratio)
    # Rebuild the world transform to cancel all inherited animation, tilt and mirroring.
    _shadow.global_transform = Transform2D(
        Vector2(shadow_size.x, 0.0),
        Vector2(0.0, shadow_size.y),
        global_position + _shadow_ground_offset
    )
    _shadow.modulate.a = lerp(1.0, SHADOW_MIN_ALPHA, hover_ratio)

func _pick_drift_target() -> void:
    _drift_angle += rand_range(-DRIFT_TURN_LIMIT, DRIFT_TURN_LIMIT)
    var target: Vector2 = _get_drift_anchor() \
        + Vector2(cos(_drift_angle), sin(_drift_angle)) * rand_range(DRIFT_MIN_RADIUS, drift_radius)
    target = _clamp_to_zone(target)
    _drift_target = target
    _drift_timer = rand_range(2.5, 4.5)

func _clamp_to_zone(pos: Vector2) -> Vector2:
    return Vector2(
        clamp(pos.x, ZoneService.current_zone_min_position.x + DRIFT_EDGE_PADDING, ZoneService.current_zone_max_position.x - DRIFT_EDGE_PADDING),
        clamp(pos.y, ZoneService.current_zone_min_position.y + DRIFT_EDGE_PADDING, ZoneService.current_zone_max_position.y - DRIFT_EDGE_PADDING)
    )

func _get_drift_anchor() -> Vector2:
    if player_index >= 0 and player_index < players_ref.size():
        var pet_owner: Player = players_ref[player_index]
        if is_instance_valid(pet_owner):
            return pet_owner.global_position
    return (ZoneService.current_zone_min_position + ZoneService.current_zone_max_position) * 0.5

func _get_drift_speed_factor() -> float:
    match _state:
        State.CHARGING:
            return 0.4
        State.BLOWING:
            return 0.7
        State.COOLDOWN:
            return 0.55
    return 1.0

func _blow_away_enemies() -> void:
    _set_state(State.BLOWING)
    _play_voice(ANGRY_SOUND, -6.5)
    _state_time_left = max(0.1, _animation_player.get_animation("angry_trigger").length)
    var blow_distance: float = _get_blow_distance()
    var stun_duration: float = _pipi_effect.get_stun_duration(player_index)
    for enemy in _targets_in_range.duplicate():
        if not is_instance_valid(enemy) or enemy.dead or enemy._pending_die:
            continue

        var direction: Vector2 = enemy.global_position - global_position
        if direction.length_squared() == 0:
            direction = Vector2.RIGHT
        enemy.fa_launch_airborne(direction.normalized(), blow_distance, player_index, stun_duration)

func _get_blow_distance() -> float:
    var zone_size: Vector2 = ZoneService.get_current_zone_rect().size
    return min(zone_size.x, zone_size.y) * _get_blow_distance_fraction()

func _prune_targets() -> void:
    for i in range(_targets_in_range.size() - 1, -1, -1):
        var enemy = _targets_in_range[i]
        if not is_instance_valid(enemy) or enemy.dead or enemy._pending_die:
            _targets_in_range.remove(i)

func _try_charge() -> void:
    if dead or _end_of_wave:
        return
    _prune_targets()
    if _targets_in_range.empty():
        return
    _set_state(State.CHARGING)
    _state_time_left = charge_duration

func _get_blow_distance_fraction() -> float:
    return PipiCatEffect.BLOW_DISTANCE_MAP_FRACTION * blow_strength / PipiCatEffect.BLOW_STRENGTH_REFERENCE

func _enter_cooldown() -> void:
    _set_state(State.COOLDOWN)
    _state_time_left = cooldown_duration

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

# ══════════════════════════════════════════ Method ══════════════════════════════════════════ #
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
