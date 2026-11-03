class_name ScooterHipster

extends Enemy

## A cheerful hipster with a big beard, a beanie and a cup of coffee, riding
## a flying e-scooter. It drifts lazily along the top of the screen, sipping
## its coffee and tossing a fan of coffee beans at the nearest spaceship, then
## suddenly zips in a deep swoop to another spot, dipping down towards
## the spaceships and up again, and drifts on.

enum Phase { ARRIVING, DRIFTING, SWOOPING }

## How fast the hipster arrives at its place.
@export var arrive_speed: float = 260.0

@export var drift_speed: float = 60.0
@export var min_drift_duration: float = 2.5
@export var max_drift_duration: float = 4.0

## The swoop: how long it takes, how far down it dips, as a fraction of
## the screen height, and how far it goes at least.
@export var swoop_duration: float = 1.6
@export_range(0.0, 1.0) var swoop_depth: float = 0.58
@export var min_swoop_distance: float = 500.0

## It stays this far from the screen edges.
@export var margin: float = 160.0

## The fan of beans: the number and the angle between them.
@export var fan_size: int = 3
@export var fan_angle: float = 0.22

var _phase: Phase = Phase.ARRIVING
var _time: float = 0.0
var _phase_left: float = 0.0
var _drift: Vector2 = Vector2.RIGHT
var _swoop_from: Vector2 = Vector2.ZERO
var _swoop_to: Vector2 = Vector2.ZERO
var _swoops: int = 0
var _facing: float = 1.0
var _tilt: float = 0.0


func _ready() -> void:
    super()
    rocket_look = Rocket.Look.COFFEE_BEAN


## Return how many swoops the hipster has made so far.
func swoops() -> int:
    return _swoops


func is_swooping() -> bool:
    return _phase == Phase.SWOOPING


func _move(delta: float) -> void:
    _time += delta
    var bounds := get_viewport_rect()

    match _phase:
        Phase.ARRIVING:
            position = position.move_toward(home, arrive_speed * delta)
            if position.is_equal_approx(home):
                _start_drift()
        Phase.DRIFTING:
            position += _drift * drift_speed * delta
            position.y = clampf(position.y, bounds.position.y + radius, home.y + radius)
            if position.x < bounds.position.x + margin or position.x > bounds.end.x - margin:
                _drift.x = -_drift.x
                position.x = clampf(position.x, bounds.position.x + margin, bounds.end.x - margin)
            _facing = signf(_drift.x) if _drift.x != 0.0 else _facing
            _tilt = move_toward(_tilt, 0.0, delta)
            _phase_left -= delta
            if _phase_left <= 0.0:
                _start_swoop()
        Phase.SWOOPING:
            _phase_left -= delta
            var t := clampf(1.0 - _phase_left / swoop_duration, 0.0, 1.0)
            var eased := smoothstep(0.0, 1.0, t)
            var dip := bounds.size.y * swoop_depth - _swoop_from.y
            var before := position
            position = _swoop_from.lerp(_swoop_to, eased) + Vector2(0, sin(PI * eased) * dip)
            var step := position - before
            if step.x != 0.0:
                _facing = signf(step.x)
            _tilt = clampf(step.y / maxf(delta, 0.001) / 900.0, -0.5, 0.5) * _facing
            if _phase_left <= 0.0:
                _start_drift()


func _start_drift() -> void:
    _phase = Phase.DRIFTING
    _phase_left = randf_range(min_drift_duration, max_drift_duration)
    _drift = Vector2(1.0 if randf() < 0.5 else -1.0, randf_range(-0.3, 0.3)).normalized()


func _start_swoop() -> void:
    var bounds := get_viewport_rect()
    _phase = Phase.SWOOPING
    _phase_left = swoop_duration
    _swoop_from = position
    var x := randf_range(bounds.position.x + margin, bounds.end.x - margin)
    if absf(x - position.x) < min_swoop_distance:
        var away := 1.0 if position.x < bounds.get_center().x else -1.0
        x = clampf(
            position.x + away * min_swoop_distance,
            bounds.position.x + margin,
            bounds.end.x - margin
        )
    _swoop_to = Vector2(x, home.y)
    _swoops += 1


func _may_fire() -> bool:
    return _phase == Phase.DRIFTING


func _fire_rocket() -> void:
    var aim := _rocket_direction()
    if aim == Vector2.ZERO:
        return
    for i in range(fan_size):
        var angle := (i - (fan_size - 1) / 2.0) * fan_angle
        _launch_rocket(aim.rotated(angle), rocket_speed)


func _draw_body(flash: float) -> void:
    var white := Color(1, 1, 1)
    var r := radius
    draw_set_transform(Vector2.ZERO, _tilt, Vector2(_facing, 1.0))

    # NOTE (mristin):
    # The scooter hovers on two soft glows instead of wheels on the road.
    var hover := 0.7 + 0.3 * sin(_time * 12.0)
    for x: float in [-0.45, 0.45]:
        draw_circle(Vector2(x * r, r * 0.52), r * 0.16, Color(0.4, 0.9, 1.0, 0.3 * hover))
        draw_circle(Vector2(x * r, r * 0.45), r * 0.1, Color(0.25, 0.25, 0.3).lerp(white, flash))
        draw_circle(Vector2(x * r, r * 0.45), r * 0.05, Color(0.5, 0.95, 1.0))
    var green := Color(0.3, 0.85, 0.55).lerp(white, flash)
    draw_line(Vector2(-r * 0.55, r * 0.38), Vector2(r * 0.5, r * 0.38), green, r * 0.1)
    draw_line(
        Vector2(r * 0.45, r * 0.38), Vector2(r * 0.35, -r * 0.35), Color(0.3, 0.3, 0.35), r * 0.07
    )
    draw_line(
        Vector2(r * 0.25, -r * 0.38), Vector2(r * 0.48, -r * 0.33), Color(0.3, 0.3, 0.35), r * 0.07
    )

    # The hipster: the legs, the checked shirt and the arms.
    var jeans := Color(0.3, 0.4, 0.65).lerp(white, flash)
    draw_line(Vector2(-r * 0.1, r * 0.34), Vector2(-r * 0.05, r * 0.05), jeans, r * 0.12)
    draw_line(Vector2(r * 0.1, r * 0.34), Vector2(r * 0.05, r * 0.05), jeans, r * 0.12)
    var shirt := Rect2(Vector2(-r * 0.2, -r * 0.32), Vector2(r * 0.4, r * 0.4))
    draw_rect(shirt, Color(0.85, 0.3, 0.3).lerp(white, flash))
    for k in range(3):
        var x := shirt.position.x + (k + 0.5) * shirt.size.x / 3.0
        draw_line(
            Vector2(x, shirt.position.y), Vector2(x, shirt.end.y), Color(0.55, 0.15, 0.2), r * 0.03
        )
        var y := shirt.position.y + (k + 0.5) * shirt.size.y / 3.0
        draw_line(
            Vector2(shirt.position.x, y), Vector2(shirt.end.x, y), Color(0.55, 0.15, 0.2), r * 0.03
        )
    var skin := Color(1.0, 0.82, 0.66).lerp(white, flash)
    draw_line(Vector2(r * 0.15, -r * 0.25), Vector2(r * 0.33, -r * 0.33), skin, r * 0.08)

    # The coffee cup in the other hand, with the steam.
    var cup := Vector2(-r * 0.42, -r * 0.18)
    draw_line(Vector2(-r * 0.15, -r * 0.25), cup + Vector2(r * 0.05, r * 0.02), skin, r * 0.08)
    draw_rect(
        Rect2(cup - Vector2(r * 0.08, r * 0.12), Vector2(r * 0.16, r * 0.2)),
        Color(0.98, 0.95, 0.88).lerp(white, flash)
    )
    draw_rect(
        Rect2(cup - Vector2(r * 0.08, r * 0.02), Vector2(r * 0.16, r * 0.06)), Color(0.6, 0.4, 0.25)
    )
    for k in range(2):
        var steam := fmod(_time * 0.8 + k * 0.5, 1.0)
        draw_circle(
            cup + Vector2(sin(steam * 6.0 + k) * r * 0.04, -r * (0.18 + steam * 0.25)),
            r * (0.03 + steam * 0.03),
            Color(1, 1, 1, 0.5 * (1.0 - steam))
        )

    # The head: the big beard, the round glasses and the beanie.
    var head := Vector2(0, -r * 0.52)
    draw_circle(head, r * 0.22, skin)
    var beard := PackedVector2Array()
    for k in range(13):
        var angle := PI * k / 12.0
        beard.append(head + Vector2(cos(angle) * r * 0.23, r * 0.02 + sin(angle) * r * 0.3))
    draw_colored_polygon(beard, Color(0.5, 0.3, 0.15).lerp(white, flash))
    draw_arc(
        head + Vector2(0, r * 0.1), r * 0.07, 0.3, PI - 0.3, 8, Color(0.95, 0.5, 0.45), r * 0.03
    )
    for side: float in [-1.0, 1.0]:
        var eye := head + Vector2(side * r * 0.09, -r * 0.03)
        draw_circle(eye, r * 0.065, Color(1, 1, 1))
        draw_circle(eye + Vector2(r * 0.015, 0), r * 0.03, Color(0.1, 0.07, 0.05))
        draw_arc(eye, r * 0.075, 0.0, TAU, 16, Color(0.15, 0.12, 0.1), r * 0.025, true)
    draw_line(
        head + Vector2(-r * 0.02, -r * 0.03),
        head + Vector2(r * 0.02, -r * 0.03),
        Color(0.15, 0.12, 0.1),
        r * 0.02
    )
    var beanie := PackedVector2Array()
    for k in range(13):
        var angle := PI + PI * k / 12.0
        beanie.append(head + Vector2(cos(angle) * r * 0.24, -r * 0.1 + sin(angle) * r * 0.2))
    draw_colored_polygon(beanie, Color(0.95, 0.75, 0.2).lerp(white, flash))
    draw_rect(
        Rect2(head + Vector2(-r * 0.25, -r * 0.13), Vector2(r * 0.5, r * 0.07)),
        Color(0.85, 0.6, 0.15).lerp(white, flash)
    )
    draw_circle(head + Vector2(0, -r * 0.33), r * 0.07, Color(1.0, 0.95, 0.85).lerp(white, flash))

    draw_set_transform(Vector2.ZERO, 0.0)
