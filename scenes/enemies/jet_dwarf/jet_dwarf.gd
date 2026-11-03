class_name JetDwarf

extends Enemy

## A dwarf with a jetpack, a helmet and a big beard. It hovers at one side of
## the screen and throws a lump of glowing coal at the nearest spaceship, then
## zooms across to the other side at another height, dropping the coal on
## the way.

@export var zoom_speed: float = 620.0

## How long the dwarf hovers between the zooms, in seconds.
@export var hover_duration: float = 2.4

## How many lumps of coal it drops while zooming across.
@export var drops_per_zoom: int = 2

@export var drop_speed: float = 300.0

## The dwarf stays above this fraction of the screen height.
@export_range(0.0, 1.0) var lowest: float = 0.45

@export var margin: float = 130.0

var _time: float = 0.0
var _side: float = 1.0
var _zooming: bool = true
var _target: Vector2 = Vector2.ZERO
var _hover_left: float = 0.0
var _zoom_from_x: float = 0.0
var _drops_done: int = 0


func _enter() -> void:
    # NOTE (mristin):
    # The dwarf zooms in from the side, at its height in the level.
    var bounds := get_viewport_rect()
    _side = 1.0 if home.x < bounds.get_center().x else -1.0
    position = Vector2(bounds.position.x - radius if _side > 0.0 else bounds.end.x + radius, home.y)
    _start_zoom(home)


func _start_zoom(to: Vector2) -> void:
    _zooming = true
    _target = to
    _zoom_from_x = position.x
    _drops_done = 0


func _move(delta: float) -> void:
    _time += delta

    if _zooming:
        position = position.move_toward(_target, zoom_speed * delta)

        # NOTE (mristin):
        # We drop the coal evenly along the way.
        var span := absf(_target.x - _zoom_from_x)
        if span > 0.0 and get_viewport_rect().has_point(global_position):
            var done := absf(position.x - _zoom_from_x) / span
            if _drops_done < drops_per_zoom and done >= (_drops_done + 0.5) / drops_per_zoom:
                _drops_done += 1
                _launch_rocket(Vector2.DOWN, drop_speed)

        if position.is_equal_approx(_target):
            _zooming = false
            _hover_left = hover_duration * randf_range(0.8, 1.2)
        return

    position = _target + Vector2(0, sin(_time * 3.0) * 8.0)
    _hover_left -= delta
    if _hover_left <= 0.0:
        var bounds := get_viewport_rect()
        _side = -_side
        var x := bounds.end.x - margin if _side > 0.0 else bounds.position.x + margin
        var y := randf_range(bounds.position.y + margin, bounds.position.y + bounds.size.y * lowest)
        _start_zoom(Vector2(x, y))


func _may_fire() -> bool:
    return not _zooming


func _draw_body(flash: float) -> void:
    var white := Color(1, 1, 1)
    var r := radius

    # NOTE (mristin):
    # The dwarf leans into the zoom.
    var lean := 0.0
    if _zooming:
        lean = signf(_target.x - position.x) * 0.35
    draw_set_transform(Vector2.ZERO, lean)

    var flame := 1.0 + 0.3 * sin(_time * 40.0)
    for side: float in [-1.0, 1.0]:
        var nozzle := Vector2(side * r * 0.28, r * 0.35)
        draw_colored_polygon(
            PackedVector2Array(
                [
                    nozzle + Vector2(-r * 0.08, 0),
                    nozzle + Vector2(0, r * 0.4 * flame),
                    nozzle + Vector2(r * 0.08, 0),
                ]
            ),
            Color(1.0, 0.6, 0.15, 0.9)
        )
        draw_rect(
            Rect2(nozzle + Vector2(-r * 0.1, -r * 0.45), Vector2(r * 0.2, r * 0.45)),
            Color(0.6, 0.62, 0.68).lerp(white, flash)
        )

    draw_circle(Vector2(0, r * 0.1), r * 0.28, Color(0.3, 0.45, 0.75).lerp(white, flash))
    draw_circle(Vector2(0, -r * 0.18), r * 0.22, Color(0.98, 0.78, 0.65).lerp(white, flash))

    var beard := PackedVector2Array(
        [
            Vector2(-r * 0.22, -r * 0.15),
            Vector2(-r * 0.2, r * 0.12),
            Vector2(0, r * 0.32),
            Vector2(r * 0.2, r * 0.12),
            Vector2(r * 0.22, -r * 0.15),
            Vector2(0, -r * 0.05),
        ]
    )
    draw_colored_polygon(beard, Color(0.95, 0.55, 0.2).lerp(white, flash))
    draw_circle(Vector2(0, -r * 0.1), r * 0.06, Color(0.95, 0.6, 0.55).lerp(white, flash))

    # NOTE (mristin):
    # The goggles and the helmet.
    for side: float in [-1.0, 1.0]:
        var goggle := Vector2(side * r * 0.1, -r * 0.24)
        draw_circle(goggle, r * 0.08, Color(0.4, 0.3, 0.2).lerp(white, flash))
        draw_circle(goggle, r * 0.055, Color(0.6, 0.9, 1.0).lerp(white, flash))
    var helmet := PackedVector2Array()
    for i in range(13):
        var angle := PI + PI * i / 12.0
        helmet.append(Vector2(cos(angle) * r * 0.25, sin(angle) * r * 0.2 - r * 0.32))
    draw_colored_polygon(helmet, Color(0.75, 0.75, 0.8).lerp(white, flash))
    draw_circle(Vector2(0, -r * 0.54), r * 0.05, Color(1.0, 0.8, 0.3).lerp(white, flash))

    draw_set_transform(Vector2.ZERO, 0.0)
