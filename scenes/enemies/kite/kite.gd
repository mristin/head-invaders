class_name Kite

extends Enemy

## A cheerful diamond kite with a long tail of bows, dancing on its string.
## The string is tied far above the screen, so the kite swings to and fro
## like a pendulum and dips in little loops in between. At the end of each
## swing, where it stops for a moment, it may shake a fan of twinkling stars
## out of its tail at the nearest spaceship.

## How long the string is, from the knot above the screen to the kite.
@export var string_length: float = 700.0

## How far the kite swings, in radians, and how many swings per second.
@export var swing_amplitude: float = 0.55
@export var swing_frequency: float = 0.11

## The little loops the kite dips in while swinging, in pixels.
@export var loop_size: float = 40.0

## The fan of stars: the number and the angle between them.
@export var fan_size: int = 3
@export var fan_angle: float = 0.3

@export var descent_speed: float = 220.0

## How many fans the kite shook out so far, e.g., for the tests.
var fans_shaken: int = 0

## How many times the kite turned at the end of a swing, e.g., for the tests.
var swings: int = 0

var _time: float = 0.0
var _swing_time: float = 0.0
var _knot: Vector2 = Vector2.ZERO
var _descending: bool = true
var _last_direction: float = 0.0
var _shake: float = 0.0
var _fan_ready: bool = false


func _ready() -> void:
    super()
    rocket_look = Rocket.Look.ZAP


func _enter() -> void:
    super()
    _knot = Vector2(home.x, home.y - string_length)


## Return where the kite is on its string at the given time of the swing.
func _on_string(t: float) -> Vector2:
    var angle := sin(t * TAU * swing_frequency) * swing_amplitude
    var at := _knot + Vector2(sin(angle), cos(angle)) * string_length
    var loop := t * TAU * swing_frequency * 4.0
    return at + Vector2(cos(loop) * 0.3, sin(loop)) * loop_size


func _move(delta: float) -> void:
    _time += delta
    _shake = maxf(0.0, _shake - delta * 2.0)

    if _descending:
        var start := _on_string(0.0)
        position.y = minf(position.y + descent_speed * delta, start.y)
        position.x = start.x
        if position.y >= start.y:
            _descending = false
            _swing_time = 0.0
        return

    _swing_time += delta
    position = _on_string(_swing_time)

    # NOTE (mristin):
    # We bound the kite to the screen, in case the level ties it near
    # the edge.
    var bounds := get_viewport_rect()
    position.x = clampf(position.x, bounds.position.x + radius, bounds.end.x - radius)

    # NOTE (mristin):
    # The swing turns where the sine of the angle changes direction.
    var direction := signf(cos(_swing_time * TAU * swing_frequency))
    if _last_direction != 0.0 and direction != _last_direction:
        swings += 1
        if _fan_ready:
            _fan_ready = false
            _shake_fan()
    _last_direction = direction


func _may_fire() -> bool:
    return not _descending


## Get ready to shake out the fan at the end of the current swing.
func _fire_rocket() -> void:
    _fan_ready = true


func _shake_fan() -> void:
    var aim := _rocket_direction()
    if aim == Vector2.ZERO:
        return

    fans_shaken += 1
    _shake = 1.0
    var tail := global_position + Vector2(0, radius * 0.7)
    for i in range(fan_size):
        var angle := (i - (fan_size - 1) / 2.0) * fan_angle
        _launch_rocket_from(tail, aim.rotated(angle), rocket_speed)


func _energy_bar_y() -> float:
    return -radius * 0.85


func _draw_body(flash: float) -> void:
    var white := Color(1, 1, 1)
    var r := radius

    # NOTE (mristin):
    # The string goes up to the knot far above the screen.
    if not is_fleeing():
        draw_line(Vector2.ZERO, _knot - position, Color(0.85, 0.8, 0.9, 0.5), 2.5, true)

    # The tail of bows waves behind the kite.
    var tail := PackedVector2Array()
    for i in range(12):
        var t := i / 11.0
        var wave := sin(_time * 5.0 - t * 5.0) * r * 0.25 * t
        wave += _shake * sin(_time * 30.0) * r * 0.1
        tail.append(Vector2(wave, r * 0.45 + t * r * 1.1))
    draw_polyline(tail, Color(0.95, 0.9, 1.0, 0.8).lerp(white, flash), r * 0.03, true)
    var bow_colors: Array[Color] = [
        Color(1.0, 0.45, 0.55), Color(1.0, 0.8, 0.35), Color(0.45, 0.85, 1.0)
    ]
    for k in range(3):
        var at := tail[3 + k * 3]
        var bow := bow_colors[k].lerp(white, flash)
        for side: float in [-1.0, 1.0]:
            draw_colored_polygon(
                PackedVector2Array(
                    [
                        at,
                        at + Vector2(side * r * 0.14, -r * 0.07),
                        at + Vector2(side * r * 0.14, r * 0.07),
                    ]
                ),
                bow
            )
        draw_circle(at, r * 0.035, bow)

    # The kite is a diamond in four colored panes, with the crossed sticks.
    var top := Vector2(0, -r * 0.7)
    var left := Vector2(-r * 0.5, -r * 0.1)
    var right := Vector2(r * 0.5, -r * 0.1)
    var bottom := Vector2(0, r * 0.5)
    var middle := Vector2(0, -r * 0.1)
    var panes: Array[Color] = [
        Color(0.95, 0.4, 0.5), Color(1.0, 0.75, 0.3), Color(0.4, 0.75, 0.95), Color(0.55, 0.85, 0.5)
    ]
    var corners: Array[Vector2] = [top, right, bottom, left]
    draw_colored_polygon(
        PackedVector2Array(
            [
                top + Vector2(0, -r * 0.05),
                right + Vector2(r * 0.05, 0),
                bottom + Vector2(0, r * 0.05),
                left + Vector2(-r * 0.05, 0),
            ]
        ),
        Color(1, 1, 1, 0.9)
    )
    for i in range(4):
        draw_colored_polygon(
            PackedVector2Array([middle, corners[i], corners[(i + 1) % 4]]),
            panes[i].lerp(white, flash)
        )
    var stick := Color(0.55, 0.38, 0.25).lerp(white, flash)
    draw_line(top, bottom, stick, r * 0.03)
    draw_line(left, right, stick, r * 0.03)

    # NOTE (mristin):
    # The face in the middle: the big eyes, the rosy cheeks and the smile,
    # wide open when it shakes out the stars.
    var face := Vector2(0, -r * 0.08)
    draw_circle(face, r * 0.22, Color(1.0, 0.93, 0.8).lerp(white, flash))
    for side: float in [-1.0, 1.0]:
        var eye := face + Vector2(side * r * 0.08, -r * 0.04)
        draw_circle(eye, r * 0.055, white)
        draw_circle(eye + Vector2(0, r * 0.01), r * 0.033, Color(0.15, 0.1, 0.2))
        draw_circle(eye + Vector2(-r * 0.012, -r * 0.012), r * 0.012, white)
        draw_circle(
            face + Vector2(side * r * 0.14, r * 0.07), r * 0.035, Color(1.0, 0.5, 0.55, 0.8)
        )
    if _shake > 0.0:
        draw_circle(
            face + Vector2(0, r * 0.09), r * 0.05 * _shake + r * 0.02, Color(0.5, 0.15, 0.2)
        )
    else:
        draw_arc(
            face + Vector2(0, r * 0.06),
            r * 0.06,
            0.3,
            PI - 0.3,
            10,
            Color(0.3, 0.1, 0.15),
            r * 0.02
        )
