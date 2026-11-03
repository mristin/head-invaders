class_name Puffer

extends Enemy

## A space puffer fish: it bounces around the upper part of the screen. Now and
## then it stops, puffs up and shoots a ring of rockets all around.

@export var speed: float = 190.0

## How long the puffer stays puffed up, in seconds.
@export var puff_duration: float = 1.2

## The number of rockets in a ring.
@export var ring_size: int = 6

## The puffer stays above this fraction of the screen height.
@export_range(0.0, 1.0) var lowest: float = 0.55

@export var margin: float = 90.0

var _time: float = 0.0
var _velocity: Vector2 = Vector2.ZERO
var _puff_left: float = 0.0


func _enter() -> void:
    super()
    var side := -1.0 if randf() < 0.5 else 1.0
    _velocity = Vector2(side * 0.8, 0.6).normalized() * speed


func _move(delta: float) -> void:
    _time += delta

    if _puff_left > 0.0:
        _puff_left = maxf(0.0, _puff_left - delta)
        return

    position += _velocity * delta

    # NOTE (mristin):
    # We bounce off the edges of the box only when moving towards them, so that
    # the puffer can come in from above the screen.
    var bounds := get_viewport_rect()
    var top := bounds.position.y + margin
    var bottom := bounds.position.y + bounds.size.y * lowest
    if position.x < bounds.position.x + margin and _velocity.x < 0.0:
        _velocity.x = -_velocity.x
    elif position.x > bounds.end.x - margin and _velocity.x > 0.0:
        _velocity.x = -_velocity.x
    if position.y < top and _velocity.y < 0.0:
        _velocity.y = -_velocity.y
    elif position.y > bottom and _velocity.y > 0.0:
        _velocity.y = -_velocity.y


func _fire_rocket() -> void:
    _puff_left = puff_duration
    var start := randf() * TAU
    for i in range(ring_size):
        _launch_rocket(Vector2.RIGHT.rotated(start + TAU * i / ring_size), rocket_speed)


func _draw_body(flash: float) -> void:
    var white := Color(1, 1, 1)
    var r := radius

    # NOTE (mristin):
    # The puffer puffs up quickly and deflates slowly.
    var puff := 0.0
    if _puff_left > 0.0:
        var t := 1.0 - _puff_left / puff_duration
        puff = minf(1.0, t * 6.0) * minf(1.0, (1.0 - t) * 3.0)
    var body_r := r * (0.6 + 0.25 * puff)
    var facing := signf(_velocity.x) if _velocity.x != 0.0 else 1.0
    var body_color := Color(1.0, 0.6, 0.35).lerp(white, flash)

    var tail := PackedVector2Array(
        [
            Vector2(-facing * body_r * 0.85, 0),
            Vector2(-facing * body_r * 1.45, -r * 0.3),
            Vector2(-facing * body_r * 1.45, r * 0.3),
        ]
    )
    draw_colored_polygon(tail, Color(1.0, 0.45, 0.3).lerp(white, flash))

    if puff > 0.0:
        for i in range(12):
            var direction := Vector2.RIGHT.rotated(TAU * i / 12.0)
            draw_line(
                direction * body_r * 0.9,
                direction * body_r * (1.0 + 0.3 * puff),
                Color(1.0, 0.9, 0.6).lerp(white, flash),
                r * 0.06,
                true
            )

    draw_circle(Vector2.ZERO, body_r, body_color)
    draw_circle(Vector2(0, body_r * 0.35), body_r * 0.55, Color(1.0, 0.85, 0.65).lerp(white, flash))

    var fin_angle := sin(_time * 10.0) * 0.4
    draw_set_transform(Vector2(0, body_r * 0.1), fin_angle)
    draw_circle(Vector2(0, 0), r * 0.15, Color(1.0, 0.45, 0.3).lerp(white, flash))
    draw_set_transform(Vector2.ZERO, 0.0)

    var eye := Vector2(facing * body_r * 0.4, -body_r * 0.25)
    draw_circle(eye, r * 0.17, white)
    draw_circle(eye + Vector2(facing * r * 0.04, 0), r * 0.08, Color(0.1, 0.1, 0.2))
    var mouth := Vector2(facing * body_r * 0.8, body_r * 0.1)
    draw_circle(mouth, r * (0.05 + 0.04 * puff), Color(0.5, 0.15, 0.2))
