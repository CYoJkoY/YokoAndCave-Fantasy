class_name PipiCat
extends Pet

enum State { ARMED, CHARGING, BLOWING, COOLDOWN }

export(float) var charge_duration: float = 1.5
export(float) var cooldown_duration: float = 5.0
export(float) var blow_radius: float = 260.0
export(float) var blow_strength: float = 2.4

onready var _trigger_zone: Area2D = $TargetTriggerZone
onready var _trigger_shape: CollisionShape2D = $TargetTriggerZone/CollisionShape2D
onready var _body: Sprite = $Animation/Offset/Body
onready var _head: Sprite = $Animation/Offset/Body/Head

var _state: int = State.ARMED
var _state_time_left: float = 0.0
var _targets_in_range: Array = []

func _ready() -> void:
    ._ready()
    _apply_black_cat_visuals()

func update_data(effect: PetEffect) -> void:
    .update_data(effect)
    var pipi_effect: PipiCatEffect = effect as PipiCatEffect
    charge_duration = pipi_effect.charge_duration
    cooldown_duration = pipi_effect.cooldown_duration
    blow_radius = pipi_effect.blow_radius
    blow_strength = pipi_effect.blow_strength
    _trigger_shape.shape.radius = blow_radius

func _physics_process(delta: float) -> void:
    if dead:
        return

    ._physics_process(delta)
    _prune_targets()

    if _state == State.CHARGING:
        if _targets_in_range.empty():
            _state = State.ARMED
            _state_time_left = 0.0
            return
        _state_time_left -= Utils.physics_one(delta)
        if _state_time_left <= 0.0:
            _blow_away_enemies()
    elif _state == State.BLOWING:
        _state = State.COOLDOWN
        _state_time_left = cooldown_duration
    elif _state == State.COOLDOWN:
        _state_time_left -= Utils.physics_one(delta)
        if _state_time_left <= 0.0:
            _state = State.ARMED

func _on_TargetTriggerZone_body_entered(body: Node) -> void:
    if !(body is Enemy) or body.dead:
        return
    if not _targets_in_range.has(body):
        _targets_in_range.push_back(body)
    if _state == State.ARMED:
        _state = State.CHARGING
        _state_time_left = charge_duration

func _on_TargetTriggerZone_body_exited(body: Node) -> void:
    _targets_in_range.erase(body)

func _prune_targets() -> void:
    for target in _targets_in_range.duplicate():
        if not is_instance_valid(target) or target.dead:
            _targets_in_range.erase(target)

func _blow_away_enemies() -> void:
    _state = State.BLOWING
    for enemy in _targets_in_range:
        if not is_instance_valid(enemy) or enemy.dead:
            continue
        var direction: Vector2 = enemy.global_position - global_position
        if direction.length_squared() == 0:
            direction = Vector2.RIGHT
        enemy.knockback_vector = direction.normalized() * blow_strength

func _apply_black_cat_visuals() -> void:
    _body.modulate = Color(0.22, 0.22, 0.27, 1.0)
    _head.modulate = Color(0.32, 0.32, 0.38, 1.0)
