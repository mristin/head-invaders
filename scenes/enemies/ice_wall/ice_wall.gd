class_name IceWall

extends Enemy

## A wall of ice which the giant walrus raises out of the ice floes. It stands
## between the walrus and the players and slides down with the ice. The bullets
## bump into it, so the players either shoot it down, which takes a few hits,
## or fly to the gaps between the walls to reach the walrus. It does not fire.
##
## The wall stands on the ice, so the spaceships fly over it. It is no alien to
## chase away: it waits for the others, so that it does not hold up the level,
## and goes away with the walrus.

## How fast the ice slides down, in pixels per second.
@export var ground_speed: float = 40.0

@export var rise_duration: float = 0.5

var _time: float = 0.0


## Keep the wall at its size: the walls must leave clear gaps between them, so
## we do not enlarge them like the other enemies.
func _enlarge_by(_factor: float) -> void:
    pass


func _ready() -> void:
    super()
    grounded = true


func is_targetable() -> bool:
    return false


func _may_fire() -> bool:
    return false


## Return how far the wall has risen, from 0 to 1.
func risen() -> float:
    return clampf(_time / rise_duration, 0.0, 1.0)


func _move(delta: float) -> void:
    _time += delta
    position.y += ground_speed * delta
    if global_position.y > get_viewport_rect().end.y + radius:
        retreat()


func _start_fleeing(_beaten: bool = true) -> void:
    # NOTE (mristin):
    # The wall does not flee; it crumbles into snow with a poof.
    Poof.spawn(self, global_position, radius, Color(0.75, 0.92, 1.0))
    set_deferred("monitorable", false)
    defeated.emit()
    queue_free()


func _energy_bar_y() -> float:
    return radius * 0.5


func _draw_body(flash: float) -> void:
    var white := Color(1, 1, 1)
    var r := radius
    var rise := risen()
    draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, lerpf(0.2, 1.0, rise)))

    # NOTE (mristin):
    # A thick block of ice seen from above and a bit from the front: the dark
    # front face, then the lit top.
    var front := Rect2(Vector2(-r, -r * 0.1), Vector2(r * 2.0, r * 0.5))
    draw_rect(front, Color(0.3, 0.52, 0.72).lerp(white, flash))
    var top := Rect2(Vector2(-r, -r * 0.5), Vector2(r * 2.0, r * 0.42))
    draw_rect(top, Color(0.7, 0.88, 1.0).lerp(white, flash))
    for i in range(4):
        var x := -r + r * 0.5 * (i + 0.5)
        draw_line(Vector2(x, -r * 0.08), Vector2(x, r * 0.4), Color(0.4, 0.62, 0.8), r * 0.02)
    draw_rect(Rect2(Vector2(-r * 0.9, -r * 0.44), Vector2(r * 0.7, r * 0.07)), Color(1, 1, 1, 0.5))

    # The cracks grow as it takes the hits.
    var damage := 1.0 - float(energy) / float(max_energy)
    if damage > 0.0:
        var crack := PackedVector2Array(
            [
                Vector2(-r * 0.1, -r * 0.5),
                Vector2(r * 0.05, -r * 0.2),
                Vector2(-r * 0.05, -r * 0.05),
                Vector2(r * 0.1, r * 0.12),
                Vector2(0, r * 0.4),
            ]
        )
        var count := clampi(ceili(damage * crack.size()), 2, crack.size())
        draw_polyline(crack.slice(0, count), Color(0.15, 0.3, 0.5), r * 0.03)

    # The sleepy face on the front.
    var face := Vector2(r * 0.55, r * 0.15)
    for side: float in [-1.0, 1.0]:
        draw_arc(
            face + Vector2(side * r * 0.1, 0),
            r * 0.05,
            0.2,
            PI - 0.2,
            8,
            Color(0.1, 0.22, 0.38),
            r * 0.025
        )
    draw_arc(
        face + Vector2(0, r * 0.08), r * 0.05, 0.3, PI - 0.3, 8, Color(0.1, 0.22, 0.38), r * 0.02
    )
    draw_set_transform(Vector2.ZERO, 0.0)
