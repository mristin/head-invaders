class_name Queen

extends Enemy

## The queen of the aliens, who comes at the end of the level once all
## the others have fled. She is big and has plenty of energy. She sways across
## the top of the screen, and takes turns: a fan of rockets at the nearest
## spaceship, a shower of rockets all around, and calling in her darts.
##
## When she is low on energy, she gets in a hurry and attacks more often. When
## she flees, her darts follow her home.

const _DART_SCENE: PackedScene = preload("res://scenes/enemies/dart/dart.tscn")

## How fast the queen comes down to her place.
@export var descent_speed: float = 110.0

## How far and how fast she sways from side to side.
@export var sway_amplitude: float = 560.0
@export var sway_frequency: float = 0.07

@export var bob_amplitude: float = 30.0
@export var bob_frequency: float = 0.3

## The aimed fan: the number of rockets and the angle between them.
@export var fan_size: int = 3
@export var fan_angle: float = 0.3

## The shower: the number of rockets spread over the lower half circle.
@export var shower_size: int = 3
@export var shower_rocket_speed: float = 280.0

## How many darts she calls at once, and how many may fly at most.
@export var darts_per_call: int = 2
@export var max_darts: int = 2

## Below this fraction of the energy, she attacks this many times as often.
@export_range(0.0, 1.0) var hurry_below: float = 0.5
@export var hurry_factor: float = 1.6

@export var margin: float = 200.0

var _time: float = 0.0
var _descending: bool = true
var _attack: int = 0


func is_in_a_hurry() -> bool:
    return is_alive() and float(energy) / float(max_energy) < hurry_below


func _move(delta: float) -> void:
    _time += delta

    if _descending:
        position.y = minf(position.y + descent_speed * delta, home.y)
        if position.y >= home.y:
            _descending = false
            _time = 0.0
        return

    var bounds := get_viewport_rect()
    var x := home.x + sin(_time * TAU * sway_frequency) * sway_amplitude
    position.x = clampf(x, bounds.position.x + margin, bounds.end.x - margin)
    position.y = home.y + sin(_time * TAU * bob_frequency) * bob_amplitude


func _fire_rocket() -> void:
    if _descending:
        return

    if is_in_a_hurry():
        _rocket_cooldown /= hurry_factor

    match _attack % 3:
        0:
            _fire_fan()
        1:
            _fire_shower()
        _:
            if minions().size() + darts_per_call <= max_darts:
                _call_darts()
            else:
                _fire_fan()
    _attack += 1


func _fire_fan() -> void:
    var aim := _rocket_direction()
    if aim == Vector2.ZERO:
        aim = Vector2.DOWN
    for i in range(fan_size):
        var angle := (i - (fan_size - 1) / 2.0) * fan_angle
        _launch_rocket(aim.rotated(angle), rocket_speed)


func _fire_shower() -> void:
    for i in range(shower_size):
        var angle := lerpf(0.1 * PI, 0.9 * PI, i / float(shower_size - 1))
        _launch_rocket(Vector2.RIGHT.rotated(angle), shower_rocket_speed)


func _call_darts() -> void:
    for i in range(darts_per_call):
        var side := -1.0 if i % 2 == 0 else 1.0
        var dart := _summon(
            _DART_SCENE, global_position + Vector2(side * radius * 0.8, radius * 0.2)
        )
        dart.max_energy = 30

    Poof.spawn(self, global_position + Vector2(0, radius * 0.3), radius * 0.5, Color(1, 0.6, 0.9))


func _start_fleeing(beaten: bool = true) -> void:
    # NOTE (mristin):
    # Her darts follow her home; see Enemy.minions.
    super(beaten)
    Poof.spawn(self, global_position, radius * 1.5, Color(1.0, 0.6, 0.9))


func _draw_body(flash: float) -> void:
    var white := Color(1, 1, 1)
    var r := radius
    var hurry := is_in_a_hurry()

    # NOTE (mristin):
    # The wings flap slowly, faster when she is in a hurry.
    var flap := sin(_time * (9.0 if hurry else 5.0)) * 0.15
    var wing_color := Color(0.7, 0.85, 1.0, 0.5).lerp(white, flash * 0.5)
    for side: float in [-1.0, 1.0]:
        draw_set_transform(Vector2(side * r * 0.55, -r * 0.2), side * (0.5 + flap))
        draw_circle(Vector2(side * r * 0.35, 0), r * 0.42, wing_color)
    draw_set_transform(Vector2.ZERO, 0.0)

    var body := PackedVector2Array()
    for i in range(40):
        var angle := TAU * i / 40.0
        body.append(Vector2(cos(angle) * r * 0.8, sin(angle) * r * 0.5))
    var body_color := Color(0.85, 0.3, 0.6) if not hurry else Color(0.95, 0.35, 0.45)
    draw_colored_polygon(body, body_color.lerp(white, flash))

    # NOTE (mristin):
    # The jewels on her belly sparkle in turns.
    for i in range(5):
        var x := -r * 0.4 + r * 0.8 * i / 4.0
        var on := fmod(_time * 3.0 + i, 5.0) < 1.0
        var jewel := Color(0.5, 1.0, 1.0) if on else Color(0.3, 0.55, 0.8)
        draw_circle(Vector2(x, r * 0.3), r * 0.05, jewel.lerp(white, flash))

    for side: float in [-1.0, 1.0]:
        var eye := Vector2(side * r * 0.25, -r * 0.08)
        draw_circle(eye, r * 0.13, white)
        draw_circle(eye + Vector2(0, r * 0.02), r * 0.065, Color(0.2, 0.05, 0.15))
        draw_circle(eye + Vector2(-r * 0.025, -r * 0.02), r * 0.02, white)
        draw_circle(Vector2(side * r * 0.45, r * 0.08), r * 0.06, Color(1.0, 0.6, 0.7, 0.7))
    draw_arc(Vector2(0, r * 0.08), r * 0.12, 0.3, PI - 0.3, 12, Color(0.3, 0.05, 0.2), r * 0.035)

    var crown := PackedVector2Array(
        [
            Vector2(-r * 0.35, -r * 0.4),
            Vector2(-r * 0.4, -r * 0.8),
            Vector2(-r * 0.18, -r * 0.6),
            Vector2(0, -r * 0.9),
            Vector2(r * 0.18, -r * 0.6),
            Vector2(r * 0.4, -r * 0.8),
            Vector2(r * 0.35, -r * 0.4),
        ]
    )
    draw_colored_polygon(crown, Color(1.0, 0.82, 0.2).lerp(white, flash))
    for x: float in [-0.4, 0.0, 0.4]:
        var tip := Vector2(x * r, (-0.9 if x == 0.0 else -0.8) * r)
        draw_circle(tip, r * 0.05, Color(1.0, 0.4, 0.5).lerp(white, flash))
