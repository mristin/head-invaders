class_name Golem

extends GroundEnemy

## A magma golem: a big, friendly lump of rock with glowing cracks. It stomps
## slowly from side to side, and throws a boulder at the nearest spaceship,
## which bursts into a fan of glowing pebbles on the way.

@export var stomp_speed: float = 45.0

## The boulder bursts after this many seconds into so many pebbles.
@export var burst_after: float = 0.9
@export var burst_count: int = 3

## How long the golem winds up the throw, in seconds.
@export var wind_up_duration: float = 0.5

var _time: float = 0.0
var _direction: float = 1.0
var _wind_up_left: float = 0.0


func _ready() -> void:
    super()
    _direction = 1.0 if randf() < 0.5 else -1.0


func _walk(delta: float) -> void:
    _time += delta

    if _wind_up_left > 0.0:
        _wind_up_left -= delta
        if _wind_up_left <= 0.0:
            _throw()
        return

    var bounds := get_viewport_rect()
    position.x += _direction * stomp_speed * delta
    if position.x > bounds.end.x - margin and _direction > 0.0:
        _direction = -1.0
    elif position.x < bounds.position.x + margin and _direction < 0.0:
        _direction = 1.0


func _fire_rocket() -> void:
    _wind_up_left = wind_up_duration


func _throw() -> void:
    var aim := _rocket_direction()
    if aim == Vector2.ZERO:
        return
    var boulder := _launch_rocket(aim, rocket_speed)
    if boulder != null:
        boulder.burst_after = burst_after
        boulder.burst_count = burst_count


func _draw_body(flash: float) -> void:
    var white := Color(1, 1, 1)
    var r := radius
    var rock := Color(0.42, 0.36, 0.34).lerp(white, flash)
    var dark_rock := Color(0.3, 0.25, 0.24).lerp(white, flash)
    var glow := Color(1.0, 0.5, 0.12, 0.7 + 0.3 * sin(_time * 3.0))

    # NOTE (mristin):
    # The golem sways a little with each stomp, and raises its arm to throw.
    var sway := sin(_time * 4.0) * 0.06
    draw_set_transform(Vector2.ZERO, sway)

    for side: float in [-1.0, 1.0]:
        draw_circle(Vector2(side * r * 0.22, r * 0.42), r * 0.16, dark_rock)

    var throw := 0.0
    if _wind_up_left > 0.0:
        throw = 1.0 - _wind_up_left / wind_up_duration
    for side: float in [-1.0, 1.0]:
        var lift := r * 0.35 * throw if side > 0.0 else 0.0
        draw_circle(Vector2(side * r * 0.52, r * 0.05 - lift), r * 0.18, dark_rock)

    draw_circle(Vector2(0, 0), r * 0.45, rock)
    draw_circle(Vector2(-r * 0.12, -r * 0.12), r * 0.18, Color(rock.lightened(0.12)))
    draw_line(Vector2(-r * 0.3, r * 0.1), Vector2(-r * 0.05, r * 0.25), glow, r * 0.04)
    draw_line(Vector2(-r * 0.05, r * 0.25), Vector2(r * 0.2, r * 0.15), glow, r * 0.04)
    draw_line(Vector2(r * 0.25, -r * 0.3), Vector2(r * 0.32, -r * 0.05), glow, r * 0.04)

    for side: float in [-1.0, 1.0]:
        var eye := Vector2(side * r * 0.15, -r * 0.08)
        draw_circle(eye, r * 0.08, Color(1.0, 0.85, 0.3).lerp(white, flash))
        draw_circle(eye + Vector2(0, r * 0.02), r * 0.035, Color(0.2, 0.1, 0.05))
    draw_arc(Vector2(0, r * 0.08), r * 0.1, 0.3, PI - 0.3, 8, Color(0.15, 0.1, 0.1), r * 0.035)

    draw_set_transform(Vector2.ZERO, 0.0)
