class_name Dart

extends Enemy

## A fast fighter: it dives down the screen weaving from side to side, fires
## the rockets straight ahead, and comes around from the top again until it is
## defeated.

@export var speed: float = 260.0
@export var weave_amplitude: float = 180.0
@export var weave_frequency: float = 0.35

## Keep the weaving this far from the screen edges.
@export var margin: float = 100.0

var _time: float = 0.0
var _lane_x: float = 0.0
var _bank: float = 0.0


func _ready() -> void:
    super()
    _lane_x = home.x


func _enter() -> void:
    super()
    _time = 0.0


func _move(delta: float) -> void:
    _time += delta

    var bounds := get_viewport_rect()
    position.y += speed * delta

    # NOTE (mristin):
    # The dart left the screen at the bottom, so it comes around from the top
    # in another lane.
    if position.y > bounds.end.y + radius * 2.0:
        position.y = bounds.position.y - radius * 2.0
        _lane_x = randf_range(bounds.position.x + margin, bounds.end.x - margin)

    var x := _lane_x + sin(_time * TAU * weave_frequency) * weave_amplitude
    position.x = clampf(x, bounds.position.x + margin, bounds.end.x - margin)

    # NOTE (mristin):
    # Bank into the weave for a bit of life. We only rotate the drawing, not
    # the node, so that the energy bar stays level.
    _bank = -cos(_time * TAU * weave_frequency) * 0.35


func _rocket_direction() -> Vector2:
    # NOTE (mristin):
    # The dart fires straight ahead, i.e., down along its nose.
    return Vector2.DOWN.rotated(_bank)


func _draw_body(flash: float) -> void:
    var white := Color(1, 1, 1)
    var r := radius

    draw_set_transform(Vector2.ZERO, _bank)

    # NOTE (mristin):
    # The dart points down, towards the spaceships.
    var glow := 0.6 + 0.4 * sin(_time * 30.0)
    draw_circle(Vector2(0, -r * 0.75), r * 0.22, Color(1.0, 0.5, 0.2, 0.6 * glow))

    var wings := PackedVector2Array(
        [
            Vector2(0, r),
            Vector2(r * 0.95, -r * 0.45),
            Vector2(r * 0.35, -r * 0.3),
            Vector2(0, -r * 0.7),
            Vector2(-r * 0.35, -r * 0.3),
            Vector2(-r * 0.95, -r * 0.45),
        ]
    )
    draw_colored_polygon(wings, Color(0.75, 0.15, 0.2).lerp(white, flash))

    var cockpit := PackedVector2Array(
        [Vector2(0, r * 0.55), Vector2(r * 0.15, 0), Vector2(0, -r * 0.2), Vector2(-r * 0.15, 0)]
    )
    draw_colored_polygon(cockpit, Color(1.0, 0.85, 0.4).lerp(white, flash))

    draw_set_transform(Vector2.ZERO, 0.0)
