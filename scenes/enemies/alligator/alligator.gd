class_name Alligator

extends GroundEnemy

## An alligator floating on the water like a log, seen from above: it drifts
## down with the current, paddles slowly from side to side, and now and then
## snaps its jaws and spits a pair of bubbles at the nearest spaceship.
##
## It floats on the water, so the spaceships fly over it.

@export var paddle_speed: float = 60.0

## The angle between the two bubbles, in radians.
@export var spit_angle: float = 0.18

## How long the jaws stay open, in seconds.
@export var snap_duration: float = 0.5

var _time: float = 0.0
var _direction: float = 1.0
var _snap_left: float = 0.0


func _ready() -> void:
    super()
    _direction = 1.0 if randf() < 0.5 else -1.0


func _walk(delta: float) -> void:
    _time += delta
    _snap_left = maxf(0.0, _snap_left - delta)

    var bounds := get_viewport_rect()
    position.x += _direction * paddle_speed * delta
    if position.x > bounds.end.x - margin - radius * 0.5 and _direction > 0.0:
        _direction = -1.0
    elif position.x < bounds.position.x + margin + radius * 0.5 and _direction < 0.0:
        _direction = 1.0


func _fire_rocket() -> void:
    var aim := _rocket_direction()
    if aim == Vector2.ZERO:
        return

    _snap_left = snap_duration
    var mouth := global_position + Vector2(_direction * radius * 0.8, 0)
    for side: float in [-1.0, 1.0]:
        var direction := mouth.direction_to(global_position + aim * 1000.0)
        _launch_rocket_from(mouth, direction.rotated(side * spit_angle * 0.5), rocket_speed)


func _draw_body(flash: float) -> void:
    var white := Color(1, 1, 1)
    var r := radius
    var green := Color(0.3, 0.55, 0.25).lerp(white, flash)
    var dark_green := Color(0.2, 0.4, 0.17).lerp(white, flash)

    # NOTE (mristin):
    # We draw the alligator pointing along the positive x-axis, and flip it
    # when it paddles to the left.
    draw_set_transform(Vector2.ZERO, 0.0, Vector2(_direction, 1.0))

    # The ripples around it.
    var ripple := fmod(_time * 0.8, 1.0)
    draw_arc(
        Vector2.ZERO,
        r * (0.9 + 0.3 * ripple),
        0.0,
        TAU,
        32,
        Color(0.7, 0.9, 1.0, 0.25 * (1.0 - ripple)),
        3.0,
        true
    )

    # The legs paddle in turns.
    for i in range(4):
        var x := r * (0.35 if i < 2 else -0.35)
        var side := -1.0 if i % 2 == 0 else 1.0
        var paddle := sin(_time * 8.0 + i * PI * 0.5) * r * 0.08
        draw_line(
            Vector2(x, side * r * 0.15),
            Vector2(x - r * 0.1 + paddle, side * r * 0.32),
            dark_green,
            r * 0.08,
            true
        )

    var wag := sin(_time * 4.0) * r * 0.1
    var tail := PackedVector2Array(
        [Vector2(-r * 0.5, -r * 0.12), Vector2(-r * 1.05, wag), Vector2(-r * 0.5, r * 0.12)]
    )
    draw_colored_polygon(tail, green)

    var body := PackedVector2Array()
    for i in range(24):
        var a := TAU * i / 24.0
        body.append(Vector2(cos(a) * r * 0.6, sin(a) * r * 0.2))
    draw_colored_polygon(body, green)
    for i in range(5):
        draw_circle(Vector2(-r * 0.4 + r * 0.18 * i, 0), r * 0.05, dark_green)

    # NOTE (mristin):
    # The jaws open when it snaps.
    var open := sin(PI * _snap_left / snap_duration) * 0.35 if _snap_left > 0.0 else 0.0
    var head := Vector2(r * 0.55, 0)
    for side: float in [-1.0, 1.0]:
        var jaw := PackedVector2Array(
            [
                head + Vector2(0, side * r * 0.15),
                head + Vector2(r * 0.45, side * r * 0.04).rotated(side * open),
                head + Vector2(r * 0.45, 0).rotated(side * open),
                head + Vector2(0, 0),
            ]
        )
        draw_colored_polygon(jaw, green)
    if open > 0.0:
        draw_colored_polygon(
            PackedVector2Array(
                [
                    head,
                    head + Vector2(r * 0.42, 0).rotated(-open * 0.8),
                    head + Vector2(r * 0.42, 0).rotated(open * 0.8),
                ]
            ),
            Color(0.95, 0.5, 0.55)
        )

    for side: float in [-1.0, 1.0]:
        var eye := head + Vector2(r * 0.05, side * r * 0.14)
        draw_circle(eye, r * 0.08, Color(0.95, 0.9, 0.4).lerp(white, flash))
        draw_circle(eye + Vector2(r * 0.02, 0), r * 0.035, Color(0.1, 0.1, 0.05))

    draw_set_transform(Vector2.ZERO, 0.0)
