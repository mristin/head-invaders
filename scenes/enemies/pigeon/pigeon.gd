class_name Pigeon

extends Enemy

## A cheeky city pigeon, who does everything the other way round: it flutters
## at the top of the screen as the mirror image of the nearest spaceship, so
## when the spaceship goes left, the pigeon goes right. The players catch it
## only by meeting it in the middle. Now and then it bobs its head and flicks
## a pair of bread crumbs at the nearest spaceship.

## How fast the pigeon flutters down to its place.
@export var descent_speed: float = 220.0

## How fast it follows its mirror image, in pixels per second.
@export var flutter_speed: float = 300.0

## It keeps this far from the screen edges.
@export var margin: float = 140.0

## The angle between the two crumbs, in radians.
@export var crumb_angle: float = 0.25

var _time: float = 0.0
var _descending: bool = true
var _peck_left: float = 0.0


## Return where the pigeon wants to be: the mirror image of the nearest
## spaceship across the middle of the screen, or null without a spaceship.
func mirror_x() -> Variant:
    var ship := _nearest_spaceship()
    if ship == null:
        return null
    var bounds := get_viewport_rect()
    var x := bounds.position.x + bounds.end.x - ship.global_position.x
    return clampf(x, bounds.position.x + margin, bounds.end.x - margin)


func _move(delta: float) -> void:
    _time += delta
    _peck_left = maxf(0.0, _peck_left - delta)

    if _descending:
        position.y = minf(position.y + descent_speed * delta, home.y)
        _descending = position.y < home.y
        return

    position.y = home.y + sin(_time * 2.2) * radius * 0.25
    var target_x := home.x + sin(_time * 0.5) * 300.0
    var wanted: Variant = mirror_x()
    if wanted != null:
        target_x = wanted
    position.x = move_toward(position.x, target_x, flutter_speed * delta)


func _may_fire() -> bool:
    return not _descending


func _fire_rocket() -> void:
    var aim := _rocket_direction()
    if aim == Vector2.ZERO:
        return
    _peck_left = 0.35
    for side: float in [-0.5, 0.5]:
        _launch_rocket(aim.rotated(side * crumb_angle), rocket_speed)


func _draw_body(flash: float) -> void:
    var white := Color(1, 1, 1)
    var r := radius
    var grey := Color(0.62, 0.66, 0.76).lerp(white, flash)
    var dark := Color(0.45, 0.48, 0.58).lerp(white, flash)

    # NOTE (mristin):
    # The wings flutter all the time.
    var beat := sin(_time * 16.0)
    for side: float in [-1.0, 1.0]:
        var wing := PackedVector2Array(
            [
                Vector2(side * r * 0.25, -r * 0.05),
                Vector2(side * r * 0.95, -r * (0.35 + 0.3 * beat)),
                Vector2(side * r * 0.9, -r * (0.1 + 0.2 * beat)),
                Vector2(side * r * 0.3, r * 0.25),
            ]
        )
        draw_colored_polygon(wing, dark)
        for k in range(2):
            var tip := wing[1].lerp(wing[2], 0.3 + k * 0.4)
            draw_line(tip, tip.lerp(wing[3], 0.4), grey, r * 0.04)

    draw_set_transform(Vector2(0, r * 0.12), 0.0, Vector2(0.8, 1.0))
    draw_circle(Vector2.ZERO, r * 0.42, grey)
    draw_set_transform(Vector2.ZERO, 0.0)
    draw_circle(Vector2(0, r * 0.25), r * 0.22, Color(0.75, 0.78, 0.86).lerp(white, flash))

    # The shiny neck, and the head, which bobs when pecking.
    var bob := -sin(PI * _peck_left / 0.35) * r * 0.1 if _peck_left > 0.0 else 0.0
    draw_circle(Vector2(0, -r * 0.18), r * 0.24, Color(0.45, 0.7, 0.6).lerp(white, flash))
    draw_arc(Vector2(0, -r * 0.18), r * 0.2, 0.3, PI - 0.3, 12, Color(0.7, 0.45, 0.8), r * 0.06)
    var head := Vector2(0, -r * 0.42 + bob)
    draw_circle(head, r * 0.24, grey)
    for side: float in [-1.0, 1.0]:
        var eye := head + Vector2(side * r * 0.1, -r * 0.03)
        draw_circle(eye, r * 0.085, Color(1.0, 0.6, 0.25))
        draw_circle(eye, r * 0.06, white)
        draw_circle(eye + Vector2(0, r * 0.01), r * 0.035, Color(0.05, 0.05, 0.1))
    draw_colored_polygon(
        PackedVector2Array(
            [
                head + Vector2(-r * 0.05, r * 0.05),
                head + Vector2(r * 0.05, r * 0.05),
                head + Vector2(0, r * 0.16)
            ]
        ),
        Color(0.95, 0.75, 0.5).lerp(white, flash)
    )
    draw_circle(head + Vector2(0, r * 0.04), r * 0.035, white)
    for side: float in [-1.0, 1.0]:
        draw_line(
            Vector2(side * r * 0.1, r * 0.45),
            Vector2(side * r * 0.14, r * 0.58),
            Color(1.0, 0.5, 0.5).lerp(white, flash),
            r * 0.05
        )
