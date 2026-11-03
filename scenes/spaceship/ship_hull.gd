class_name ShipHull

extends Node2D

## Draw a player's spaceship: a chunky, cheerful rocket in the player's color,
## with a white nose, a big glass cockpit, swept wings and two engines with
## flickering flames.
##
## The spaceship turns the hull to lean into the turns or to spin when dizzy;
## the hull only draws.

## The player's color.
var color: Color = Color.WHITE:
    set(value):
        color = value
        queue_redraw()

## How strongly the engines burn, from 0 (off) to 1.
var thrust: float = 1.0

var _time: float = 0.0


func _process(delta: float) -> void:
    _time += delta
    queue_redraw()


func _draw() -> void:
    var body := color
    var dark := color.darkened(0.35)
    var light := color.lightened(0.5)
    var white := Color(0.97, 0.98, 1.0)

    # NOTE (mristin):
    # The flames flicker, each engine a little differently.
    for side: float in [-1.0, 1.0]:
        var nozzle := Vector2(side * 20.0, 44.0)
        var length := (30.0 + 9.0 * sin(_time * 40.0 + side * 1.7)) * thrust
        draw_colored_polygon(
            PackedVector2Array(
                [nozzle + Vector2(-10, 0), nozzle + Vector2(0, length), nozzle + Vector2(10, 0)]
            ),
            Color(1.0, 0.5, 0.15, 0.9)
        )
        draw_colored_polygon(
            PackedVector2Array(
                [nozzle + Vector2(-5, 0), nozzle + Vector2(0, length * 0.6), nozzle + Vector2(5, 0)]
            ),
            Color(1.0, 0.95, 0.5)
        )

    # The swept wings with the white tips.
    for side: float in [-1.0, 1.0]:
        draw_colored_polygon(
            PackedVector2Array(
                [
                    Vector2(side * 14.0, -6.0),
                    Vector2(side * 56.0, 28.0),
                    Vector2(side * 54.0, 44.0),
                    Vector2(side * 14.0, 34.0),
                ]
            ),
            dark
        )
        draw_circle(Vector2(side * 55.0, 36.0), 8.0, white)

    # The engines.
    for side: float in [-1.0, 1.0]:
        draw_rect(Rect2(Vector2(side * 20.0 - 10.0, 22.0), Vector2(20.0, 24.0)), white)
        draw_rect(Rect2(Vector2(side * 20.0 - 10.0, 40.0), Vector2(20.0, 6.0)), dark)

    # The body, with a shine on the left.
    var hull := PackedVector2Array()
    for i in range(40):
        var angle := TAU * i / 40.0
        hull.append(Vector2(cos(angle) * 25.0, sin(angle) * 52.0 - 4.0))
    draw_colored_polygon(hull, body)
    var shine := PackedVector2Array()
    for i in range(24):
        var angle := TAU * i / 24.0
        shine.append(Vector2(-11.0 + cos(angle) * 6.0, -6.0 + sin(angle) * 30.0))
    draw_colored_polygon(shine, Color(light, 0.55))

    # The white nose and the tail fin.
    var nose := PackedVector2Array()
    for i in range(17):
        var angle := PI + PI * i / 16.0
        nose.append(Vector2(cos(angle) * 17.0, -38.0 + sin(angle) * 19.0))
    draw_colored_polygon(nose, white)
    draw_colored_polygon(
        PackedVector2Array([Vector2(0, 30), Vector2(-7, 54), Vector2(7, 54)]), dark
    )

    # NOTE (mristin):
    # The big round cockpit makes the spaceship look friendly.
    draw_circle(Vector2(0, -10), 16.0, white)
    draw_circle(Vector2(0, -10), 12.5, Color(0.25, 0.75, 0.95))
    draw_circle(Vector2(2, -7), 8.0, Color(0.15, 0.55, 0.85))
    draw_circle(Vector2(-4.5, -15), 4.5, Color(1, 1, 1, 0.9))
