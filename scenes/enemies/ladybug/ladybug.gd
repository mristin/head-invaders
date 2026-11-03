class_name Ladybug

extends GroundEnemy

## A ladybug crawling on the forest floor, seen from above: it wanders around,
## turning now and then, and throws the acorns at the nearest spaceship. When
## defeated, it opens its wings and flies home.

## How fast the ladybug crawls on the ground, in pixels per second.
@export var crawl_speed: float = 90.0

## How fast it turns towards its new heading, in radians per second.
@export var turn_rate: float = 1.5

@export var min_turn_interval: float = 1.5
@export var max_turn_interval: float = 3.5

var _time: float = 0.0
var _heading: float = 0.0
var _wanted_heading: float = 0.0
var _turn_cooldown: float = 0.0


func _ready() -> void:
    super()
    _heading = 0.0 if randf() < 0.5 else PI
    _wanted_heading = _heading


func _walk(delta: float) -> void:
    _time += delta

    _turn_cooldown -= delta
    if _turn_cooldown <= 0.0:
        _turn_cooldown = randf_range(min_turn_interval, max_turn_interval)
        # NOTE (mristin):
        # The ladybug wanders mostly sideways, so that it stays on the screen
        # for a while.
        var side := 0.0 if randf() < 0.5 else PI
        _wanted_heading = side + randf_range(-0.9, 0.9)

    _heading = rotate_toward(_heading, _wanted_heading, turn_rate * delta)

    var bounds := get_viewport_rect()
    var step := Vector2.from_angle(_heading) * crawl_speed * delta
    if (
        (position.x + step.x < bounds.position.x + margin and step.x < 0.0)
        or (position.x + step.x > bounds.end.x - margin and step.x > 0.0)
    ):
        _heading = PI - _heading
        _wanted_heading = _heading
        step.x = -step.x
    position += step


func _draw_body(flash: float) -> void:
    var white := Color(1, 1, 1)
    var r := radius
    var black := Color(0.08, 0.06, 0.06).lerp(white, flash * 0.6)

    # NOTE (mristin):
    # We draw the ladybug pointing along its heading.
    draw_set_transform(Vector2.ZERO, _heading)

    for i in range(3):
        var x := (i - 1) * r * 0.32
        var wiggle := sin(_time * 14.0 + i * 2.0) * r * 0.06
        for side: float in [-1.0, 1.0]:
            draw_line(
                Vector2(x, side * r * 0.35),
                Vector2(x + wiggle * side, side * r * 0.62),
                black,
                r * 0.06
            )

    draw_circle(Vector2(r * 0.5, 0), r * 0.26, black)
    for side: float in [-1.0, 1.0]:
        draw_circle(Vector2(r * 0.62, side * r * 0.12), r * 0.07, white)

    var opened := 0.0
    if is_fleeing():
        opened = minf(1.0, _flee_time * 4.0)
        for side: float in [-1.0, 1.0]:
            var wing := Vector2(-r * 0.15, side * r * 0.55)
            draw_circle(wing, r * 0.4, Color(0.85, 0.9, 1.0, 0.45 + 0.2 * sin(_flee_time * 40.0)))

    var shell_color := Color(0.95, 0.2, 0.2).lerp(white, flash)
    for side: float in [-1.0, 1.0]:
        var shell := PackedVector2Array()
        var tilt := side * opened * 0.5
        for i in range(17):
            var angle := side * PI * i / 16.0
            var point := Vector2(cos(angle) * r * 0.5, sin(angle) * r * 0.45)
            shell.append(point.rotated(tilt) + Vector2(-r * 0.05, 0))
        draw_colored_polygon(shell, shell_color)
        for spot: Vector2 in [Vector2(0.15, 0.2), Vector2(-0.22, 0.25)]:
            var at := Vector2(spot.x, spot.y * side) * r
            draw_circle(at.rotated(tilt) + Vector2(-r * 0.05, 0), r * 0.09, black)
    if opened == 0.0:
        draw_line(Vector2(-r * 0.55, 0), Vector2(r * 0.45, 0), black, r * 0.04)

    draw_set_transform(Vector2.ZERO, 0.0)
