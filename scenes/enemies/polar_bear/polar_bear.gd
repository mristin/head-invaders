class_name PolarBear

extends GroundEnemy

## A chubby polar bear sitting on a little ice floe, which drifts down with
## the sea and slowly to the sides. The bear scoops up the snow and pats it
## into a snowball in its paws, which grows for a moment so that the players
## see it coming, then gives it a push. The snowball rolls slowly down the ice
## towards the nearest spaceship and keeps growing as it rolls, picking up
## the snow, so the players had better get out of its way early.
##
## It floats on the sea, so the spaceships fly over it.

## How long the bear pats the snowball before it pushes it, in seconds.
@export var pat_duration: float = 1.2

## How much bigger the snowball grows while it rolls, and in how many seconds.
@export var roll_growth: float = 1.6
@export var growth_duration: float = 3.0

## How fast the floe drifts to the sides, in pixels per second.
@export var drift_speed: float = 60.0

## How many snowballs the bear rolled so far, e.g., for the tests.
var snowballs_rolled: int = 0

## The biggest scale a rolling snowball reached so far, in the sizes of
## a rocket, e.g., for the tests.
var biggest_snowball: float = 0.0

var _time: float = 0.0
var _patting: float = -1.0
var _drift: float = 1.0
var _rolling: Array[Rocket] = []


func _ready() -> void:
    super()
    rocket_look = Rocket.Look.SNOWBALL
    _drift = -1.0 if randf() < 0.5 else 1.0


func is_patting() -> bool:
    return _patting >= 0.0


func _walk(delta: float) -> void:
    _time += delta

    var bounds := get_viewport_rect()
    position.x += _drift * drift_speed * delta
    if position.x < bounds.position.x + margin * 1.5:
        _drift = 1.0
    elif position.x > bounds.end.x - margin * 1.5:
        _drift = -1.0

    if _patting >= 0.0:
        _patting += delta
        if _patting >= pat_duration:
            _patting = -1.0
            _push_snowball()

    _grow_snowballs()


func _fire_rocket() -> void:
    if _patting < 0.0:
        _patting = 0.0


func _push_snowball() -> void:
    if not _may_fire():
        return
    var direction := _rocket_direction()
    if direction == Vector2.ZERO:
        direction = Vector2.DOWN
    var snowball := _launch_rocket_from(
        global_position + Vector2(0, radius * 0.45), direction, rocket_speed
    )
    if snowball != null:
        snowball.set_meta("rolled_at", _time)
        _rolling.append(snowball)
        snowballs_rolled += 1


## Let the rolling snowballs grow as they pick up the snow.
func _grow_snowballs() -> void:
    var alive: Array[Rocket] = []
    for snowball in _rolling:
        if not is_instance_valid(snowball) or snowball.is_queued_for_deletion():
            continue
        alive.append(snowball)
        if not snowball.is_inside_tree():
            continue
        var t := clampf((_time - float(snowball.get_meta("rolled_at"))) / growth_duration, 0.0, 1.0)
        var size := Rocket.SIZE * (1.0 + roll_growth * t)
        snowball.scale = Vector2.ONE * size
        biggest_snowball = maxf(biggest_snowball, size / Rocket.SIZE)
    _rolling = alive


func _draw_body(flash: float) -> void:
    var white := Color(1, 1, 1)
    var r := radius
    var fur := Color(0.93, 0.94, 0.97).lerp(white, flash)
    var shade := Color(0.78, 0.82, 0.9).lerp(white, flash)
    var dark := Color(0.12, 0.12, 0.18)

    # NOTE (mristin):
    # The floe bobs on the water: a slab of ice with a darker rim.
    var bob := sin(_time * 1.5) * r * 0.02
    var floe := PackedVector2Array()
    for i in range(12):
        var a := TAU * i / 12.0
        var jag := 1.0 + 0.08 * sin(a * 5.0 + 1.3)
        floe.append(Vector2(cos(a) * r * 0.85 * jag, sin(a) * r * 0.62 * jag + r * 0.08 + bob))
    draw_colored_polygon(floe, Color(0.35, 0.48, 0.6).lerp(white, flash * 0.5))
    var top := PackedVector2Array()
    for point in floe:
        top.append(point * 0.9 + Vector2(-r * 0.02, -r * 0.03))
    draw_colored_polygon(top, Color(0.5, 0.62, 0.74).lerp(white, flash * 0.5))

    # The bear sits on the floe, facing down: the round body, the legs.
    draw_circle(Vector2(0, -r * 0.05), r * 0.45, fur)
    for side: float in [-1.0, 1.0]:
        draw_circle(Vector2(side * r * 0.28, r * 0.32), r * 0.14, fur)
        draw_circle(Vector2(side * r * 0.28, r * 0.38), r * 0.06, shade)

    # The snowball in the paws grows while the bear pats it.
    var pat := clampf(_patting / pat_duration, 0.0, 1.0) if _patting >= 0.0 else 0.0
    var paw_y := r * 0.15 + sin(_time * 18.0) * r * 0.03 * pat
    if _patting >= 0.0:
        var ball := Vector2(0, r * 0.32)
        draw_circle(ball, r * (0.08 + 0.16 * pat), Color(0.55, 0.85, 1.0, 0.5))
        draw_circle(ball, r * (0.06 + 0.13 * pat), Color(0.95, 0.98, 1.0))
    for side: float in [-1.0, 1.0]:
        var paw := Vector2(side * r * (0.32 - 0.1 * pat), paw_y)
        draw_circle(paw, r * 0.12, fur)
        draw_circle(paw + Vector2(0, r * 0.05), r * 0.04, dark)

    # The head with the round ears, the eyes, the nose and the smile.
    var head := Vector2(0, -r * 0.2)
    for side: float in [-1.0, 1.0]:
        draw_circle(head + Vector2(side * r * 0.2, -r * 0.2), r * 0.09, fur)
        draw_circle(head + Vector2(side * r * 0.2, -r * 0.2), r * 0.05, Color(1.0, 0.7, 0.75))
    draw_circle(head, r * 0.28, fur)
    draw_circle(head + Vector2(0, r * 0.12), r * 0.13, shade)
    draw_circle(head + Vector2(0, r * 0.07), r * 0.05, dark)
    draw_arc(head + Vector2(0, r * 0.12), r * 0.06, 0.3, PI - 0.3, 8, dark, r * 0.025)
    for side: float in [-1.0, 1.0]:
        var eye := head + Vector2(side * r * 0.11, -r * 0.06)
        draw_circle(eye, r * 0.045, dark)
        draw_circle(eye + Vector2(-r * 0.015, -r * 0.015), r * 0.018, white)
        draw_circle(
            head + Vector2(side * r * 0.19, r * 0.06), r * 0.05, Color(1.0, 0.55, 0.65, 0.7)
        )
