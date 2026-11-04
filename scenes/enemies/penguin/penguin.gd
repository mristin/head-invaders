class_name Penguin

extends GroundEnemy

## A little penguin on the ice, seen from above. It stands and flaps for
## a moment, throws a snowball at the nearest spaceship, then flops on its
## belly and toboggans off in a fast slide, zigzagging across the ice: each
## slide goes the other way, and it turns back up before it gets too low.
##
## It slides on the ice, so the spaceships fly over it.

## How fast the penguin slides on its belly, in pixels per second.
@export var slide_speed: float = 430.0

@export var slide_duration: float = 1.0
@export var stand_duration: float = 1.6

## The penguin slides back up once below this fraction of the screen height.
@export_range(0.0, 1.0) var lowest: float = 0.5

## How many slides the penguin made so far, e.g., for the tests.
var slides: int = 0

var _time: float = 0.0
var _sliding: bool = false
var _state_left: float = 0.0
var _slide_direction: Vector2 = Vector2.RIGHT
var _side: float = 1.0
var _throw: float = 0.0


func _ready() -> void:
    super()
    rocket_look = Rocket.Look.SNOWBALL
    _state_left = stand_duration
    _side = -1.0 if randf() < 0.5 else 1.0


func is_sliding() -> bool:
    return _sliding


func _walk(delta: float) -> void:
    _time += delta
    _throw = maxf(0.0, _throw - delta * 2.5)
    _state_left -= delta

    if _sliding:
        position += _slide_direction * slide_speed * delta
        var bounds := get_viewport_rect()
        # NOTE (mristin):
        # The penguin bounces off the sides of the screen.
        if (
            (position.x < bounds.position.x + margin and _slide_direction.x < 0.0)
            or (position.x > bounds.end.x - margin and _slide_direction.x > 0.0)
        ):
            _slide_direction.x = -_slide_direction.x
        if _state_left <= 0.0:
            _sliding = false
            _state_left = stand_duration
        return

    if _state_left <= 0.0:
        _start_slide()


func _start_slide() -> void:
    _sliding = true
    _state_left = slide_duration
    slides += 1
    _side = -_side
    var bounds := get_viewport_rect()
    var down := 0.35
    if global_position.y > bounds.position.y + bounds.size.y * lowest:
        down = -0.55
    _slide_direction = Vector2(_side, down).normalized()


func _fire_rocket() -> void:
    if _sliding:
        # NOTE (mristin):
        # The penguin throws only while standing; it tries again soon.
        _rocket_cooldown = 0.3
        return
    _throw = 1.0
    super()


func _draw_body(flash: float) -> void:
    var white := Color(1, 1, 1)
    var r := radius
    var black := Color(0.13, 0.15, 0.22).lerp(white, flash)
    var belly := Color(0.95, 0.96, 1.0).lerp(white, flash)
    var orange := Color(1.0, 0.6, 0.15).lerp(white, flash)

    # NOTE (mristin):
    # Standing, the penguin faces down to the players; sliding, it lies on its
    # belly in the direction of the slide, with the flippers stretched out.
    if _sliding:
        var angle := _slide_direction.angle() - PI / 2.0
        draw_set_transform(Vector2.ZERO, angle)
        # The spray of snow behind the sliding penguin.
        for i in range(3):
            draw_circle(
                Vector2((i - 1) * r * 0.18, -r * 0.55 - i % 2 * r * 0.08),
                r * 0.12,
                Color(0.8, 0.9, 1.0, 0.25)
            )
        _draw_lying(r, black, belly, orange, white)
        draw_set_transform(Vector2.ZERO, 0.0)
        return

    var waddle := sin(_time * 8.0) * 0.08
    draw_set_transform(Vector2.ZERO, waddle)
    draw_circle(Vector2(0, r * 0.05), r * 0.5, black)
    draw_circle(Vector2(0, r * 0.14), r * 0.36, belly)

    # The flippers flap, and one goes up when it throws.
    for side: float in [-1.0, 1.0]:
        var lift := _throw if side > 0.0 else 0.0
        var flap := sin(_time * 10.0 + side) * 0.2 - lift * 1.4
        var shoulder := Vector2(side * r * 0.42, -r * 0.02)
        var tip := shoulder + Vector2(side * r * 0.3, r * 0.28).rotated(-side * flap)
        draw_line(shoulder, tip, black, r * 0.14, true)
        draw_circle(tip, r * 0.07, black)
    if _throw > 0.0:
        draw_circle(Vector2(r * 0.75, -r * 0.35), r * 0.12 * _throw, Color(1, 1, 1, _throw))

    # The feet.
    for side: float in [-1.0, 1.0]:
        draw_circle(Vector2(side * r * 0.18, r * 0.52), r * 0.1, orange)

    # The face: the big eyes, the rosy cheeks and the beak.
    var head := Vector2(0, -r * 0.2)
    draw_circle(head, r * 0.34, black)
    for side: float in [-1.0, 1.0]:
        var eye := head + Vector2(side * r * 0.13, -r * 0.02)
        draw_circle(eye, r * 0.11, white)
        draw_circle(eye + Vector2(0, r * 0.02), r * 0.06, Color(0.05, 0.05, 0.1))
        draw_circle(eye + Vector2(-r * 0.025, -r * 0.015), r * 0.025, white)
        draw_circle(
            head + Vector2(side * r * 0.22, r * 0.13), r * 0.06, Color(1.0, 0.55, 0.65, 0.8)
        )
    draw_colored_polygon(
        PackedVector2Array(
            [
                head + Vector2(-r * 0.08, r * 0.1),
                head + Vector2(r * 0.08, r * 0.1),
                head + Vector2(0, r * 0.24),
            ]
        ),
        orange
    )
    draw_set_transform(Vector2.ZERO, 0.0)


## Draw the penguin lying on its belly, head first along the positive y-axis.
func _draw_lying(r: float, black: Color, belly: Color, orange: Color, white: Color) -> void:
    var body := PackedVector2Array()
    for i in range(24):
        var a := TAU * i / 24.0
        body.append(Vector2(cos(a) * r * 0.36, sin(a) * r * 0.55))
    draw_colored_polygon(body, black)
    for side: float in [-1.0, 1.0]:
        var shoulder := Vector2(side * r * 0.3, r * 0.05)
        draw_line(shoulder, shoulder + Vector2(side * r * 0.35, -r * 0.2), black, r * 0.12, true)
        draw_circle(Vector2(side * r * 0.12, -r * 0.55), r * 0.08, orange)

    var head := Vector2(0, r * 0.45)
    draw_circle(head, r * 0.28, black)
    draw_circle(head + Vector2(0, r * 0.05), r * 0.17, belly)
    for side: float in [-1.0, 1.0]:
        var eye := head + Vector2(side * r * 0.11, r * 0.0)
        draw_circle(eye, r * 0.08, white)
        draw_circle(eye + Vector2(0, r * 0.02), r * 0.045, Color(0.05, 0.05, 0.1))
    draw_colored_polygon(
        PackedVector2Array(
            [
                head + Vector2(-r * 0.07, r * 0.18),
                head + Vector2(r * 0.07, r * 0.18),
                head + Vector2(0, r * 0.32),
            ]
        ),
        orange
    )
