class_name Lizard

extends GroundEnemy

## A fire salamander on the rocks, seen from above: it freezes for a moment,
## then scurries off in a quick dash, mostly sideways. While frozen, it spits
## a fireball at the nearest spaceship.

@export var dash_speed: float = 420.0
@export var dash_duration: float = 0.35

@export var min_freeze_duration: float = 0.8
@export var max_freeze_duration: float = 1.6

var _time: float = 0.0
var _heading: float = 0.0
var _dash_left: float = 0.0
var _freeze_left: float = 0.0


func _ready() -> void:
    super()
    _heading = 0.0 if randf() < 0.5 else PI
    _freeze_left = randf_range(min_freeze_duration, max_freeze_duration)


func _walk(delta: float) -> void:
    _time += delta

    if _dash_left > 0.0:
        _dash_left -= delta
        position += Vector2.from_angle(_heading) * dash_speed * delta
        if _dash_left <= 0.0:
            _freeze_left = randf_range(min_freeze_duration, max_freeze_duration)
        return

    _freeze_left -= delta
    if _freeze_left <= 0.0:
        # NOTE (mristin):
        # Dash mostly sideways, and away from the screen edge if close to it.
        var bounds := get_viewport_rect()
        var side := 1.0 if randf() < 0.5 else -1.0
        if position.x < bounds.position.x + margin + dash_speed * dash_duration:
            side = 1.0
        elif position.x > bounds.end.x - margin - dash_speed * dash_duration:
            side = -1.0
        _heading = (0.0 if side > 0.0 else PI) + randf_range(-0.6, 0.6)
        _dash_left = dash_duration


func _may_fire() -> bool:
    return _dash_left <= 0.0 and super()


func _draw_body(flash: float) -> void:
    var white := Color(1, 1, 1)
    var r := radius
    var orange := Color(1.0, 0.55, 0.15).lerp(white, flash)
    var dark := Color(0.15, 0.08, 0.05).lerp(white, flash * 0.6)

    draw_set_transform(Vector2.ZERO, _heading)

    # NOTE (mristin):
    # The legs and the tail move fast while dashing.
    var speed := 4.0 if _dash_left <= 0.0 else 30.0
    for i in range(4):
        var x := r * (0.2 if i < 2 else -0.25)
        var side := -1.0 if i % 2 == 0 else 1.0
        var step := sin(_time * speed + i * PI * 0.5) * r * 0.1
        draw_line(
            Vector2(x, side * r * 0.1), Vector2(x + step, side * r * 0.32), orange, r * 0.07, true
        )

    var tail := PackedVector2Array()
    for j in range(8):
        var t := j / 7.0
        tail.append(
            Vector2(-r * 0.35 - t * r * 0.55, sin(_time * speed * 0.5 + t * 3.0) * r * 0.12 * t)
        )
    draw_polyline(tail, orange, r * 0.1 * 1.0, true)

    var body := PackedVector2Array()
    for i in range(20):
        var a := TAU * i / 20.0
        body.append(Vector2(cos(a) * r * 0.42, sin(a) * r * 0.14))
    draw_colored_polygon(body, orange)
    for x: float in [-0.2, 0.0, 0.2]:
        draw_circle(Vector2(x * r, 0), r * 0.05, dark)

    draw_circle(Vector2(r * 0.45, 0), r * 0.15, orange)
    for side: float in [-1.0, 1.0]:
        draw_circle(Vector2(r * 0.5, side * r * 0.09), r * 0.05, white)
        draw_circle(Vector2(r * 0.52, side * r * 0.09), r * 0.025, dark)

    draw_set_transform(Vector2.ZERO, 0.0)
