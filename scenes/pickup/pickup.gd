class_name Pickup

extends Area2D

## A power-up falling down the screen. The first spaceship to touch it
## collects it.
##
## The pickup only scans the spaceships' collision layer, so the enemies and
## the projectiles pass it by.

enum Kind {
    ## Fire twice as often, with faster bullets.
    RAPID_FIRE,
    ## Fire three bullets in a fan.
    SPREAD_SHOT,
    ## Launch the homing rockets at the enemies.
    ROCKETS,
    ## Recharge the shield.
    SHIELD,
    ## Wrap the spaceship in a bubble, which keeps off all the damage for
    ## a while. Only the treasure chests give it.
    BUBBLE,
}

const GROUP: String = "pickups"

const _SCENE_PATH: String = "res://scenes/pickup/pickup.tscn"

@export var kind: Kind = Kind.SHIELD
@export var fall_speed: float = 150.0
@export var sway_amplitude: float = 40.0
@export var radius: float = 60.0

var _time: float = 0.0
var _base_x: float = 0.0
var _collected: bool = false


## Drop the pickup at the given global position in the current level.
static func drop(near: Node, global_pos: Vector2, pickup_kind: Kind) -> void:
    var projectiles := Projectiles.of(near)
    if projectiles == null:
        return

    var pickup: Pickup = load(_SCENE_PATH).instantiate()
    pickup.kind = pickup_kind
    projectiles.launch(pickup, global_pos)


## Return a random kind, except the bubble, which only the chests give.
static func random_kind() -> Kind:
    return (
        ([Kind.RAPID_FIRE, Kind.SPREAD_SHOT, Kind.ROCKETS, Kind.SHIELD] as Array[Kind])
        . pick_random()
    )


static func color_of(pickup_kind: Kind) -> Color:
    match pickup_kind:
        Kind.RAPID_FIRE:
            return Color(1.0, 0.8, 0.2)
        Kind.SPREAD_SHOT:
            return Color(0.3, 0.9, 1.0)
        Kind.ROCKETS:
            return Color(1.0, 0.4, 0.3)
        Kind.BUBBLE:
            return Color(0.85, 0.6, 1.0)
        _:
            return Color(0.4, 1.0, 0.5)


## Draw the symbol of the kind, centered and fitting in the given radius.
static func draw_symbol(
    canvas: CanvasItem, pickup_kind: Kind, center: Vector2, size: float, color: Color
) -> void:
    var width := maxf(1.5, size * 0.18)
    match pickup_kind:
        Kind.RAPID_FIRE:
            for dy in [-0.35, 0.25]:
                var tip := center + Vector2(0, (dy - 0.3) * size)
                canvas.draw_polyline(
                    PackedVector2Array(
                        [tip + Vector2(-0.5, 0.45) * size, tip, tip + Vector2(0.5, 0.45) * size]
                    ),
                    color,
                    width,
                    true
                )
        Kind.SPREAD_SHOT:
            var base := center + Vector2(0, 0.55 * size)
            for angle in [-0.5, 0.0, 0.5]:
                var direction := Vector2.UP.rotated(angle)
                canvas.draw_line(base, base + direction * size * 1.1, color, width, true)
        Kind.ROCKETS:
            var body := Rect2(center + Vector2(-0.2, -0.45) * size, Vector2(0.4, 0.9) * size)
            canvas.draw_rect(body, color)
            (
                canvas
                . draw_colored_polygon(
                    PackedVector2Array(
                        [
                            center + Vector2(-0.2, -0.45) * size,
                            center + Vector2(0.0, -0.85) * size,
                            center + Vector2(0.2, -0.45) * size,
                        ]
                    ),
                    color
                )
            )
            (
                canvas
                . draw_colored_polygon(
                    PackedVector2Array(
                        [
                            center + Vector2(-0.2, 0.15) * size,
                            center + Vector2(-0.5, 0.5) * size,
                            center + Vector2(-0.2, 0.45) * size,
                        ]
                    ),
                    color
                )
            )
            (
                canvas
                . draw_colored_polygon(
                    PackedVector2Array(
                        [
                            center + Vector2(0.2, 0.15) * size,
                            center + Vector2(0.5, 0.5) * size,
                            center + Vector2(0.2, 0.45) * size,
                        ]
                    ),
                    color
                )
            )
        Kind.BUBBLE:
            canvas.draw_arc(center, size * 0.8, 0.0, TAU, 24, color, width, true)
            canvas.draw_arc(center, size * 0.5, PI * 1.1, PI * 1.5, 8, color, width, true)
            canvas.draw_circle(center + Vector2(0.35, 0.3) * size, size * 0.12, color)
        _:
            canvas.draw_arc(center, size * 0.75, 0.0, TAU, 24, color, width, true)
            canvas.draw_line(
                center + Vector2(-0.4, 0) * size, center + Vector2(0.4, 0) * size, color, width
            )
            canvas.draw_line(
                center + Vector2(0, -0.4) * size, center + Vector2(0, 0.4) * size, color, width
            )


func _ready() -> void:
    add_to_group(GROUP)
    area_entered.connect(_on_area_entered)
    _base_x = position.x
    _time = randf() * TAU


func _physics_process(delta: float) -> void:
    _time += delta
    position.y += fall_speed * delta
    position.x = _base_x + sin(_time * 2.0) * sway_amplitude

    if global_position.y > get_viewport_rect().end.y + radius * 2.0:
        queue_free()
        return

    queue_redraw()


func _on_area_entered(area: Area2D) -> void:
    if _collected:
        return

    var spaceship := area as Spaceship
    if spaceship == null or not spaceship.is_alive():
        return

    _collected = true
    spaceship.collect(kind)
    Poof.spawn(self, global_position, radius, color_of(kind))
    queue_free()


func _draw() -> void:
    var color := color_of(kind)
    var pulse := 0.5 + 0.5 * sin(_time * 6.0)

    draw_circle(Vector2.ZERO, radius * (1.2 + 0.15 * pulse), Color(color, 0.18))
    draw_circle(Vector2.ZERO, radius, Color(color.darkened(0.6), 0.9))
    draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, color, 6.0, true)
    draw_symbol(self, kind, Vector2.ZERO, radius * 0.6, Color(1, 1, 1))
