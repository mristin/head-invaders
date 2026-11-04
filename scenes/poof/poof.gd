class_name Poof

extends Node2D

## Show a friendly puff of colorful sparkles, e.g., when a rocket hits or a
## pickup is collected. The poof frees itself once it is over.
##
## NOTE (mristin):
## This is a game for children, so nothing ever explodes; things go "poof".

const _SCENE_PATH: String = "res://scenes/poof/poof.tscn"

const _PALETTE: Array[Color] = [
    Color(1.0, 0.42, 0.42),
    Color(1.0, 0.82, 0.4),
    Color(0.02, 0.84, 0.63),
    Color(0.3, 0.79, 0.94),
    Color(0.78, 0.49, 1.0),
    Color(1.0, 0.56, 0.69),
]

## Roughly the radius of the poof in pixels.
@export var size: float = 60.0

## The color of the soft ring; the sparkles come in all the colors.
@export var color: Color = Color(1.0, 0.82, 0.4)

@export var duration: float = 0.8


class Sparkle:
    var position: Vector2
    var velocity: Vector2
    var spin: float
    var angle: float
    var size: float
    var color: Color


var _sparkles: Array[Sparkle] = []
var _age: float = 0.0


## Poof at the given global position in the projectiles of the current level.
static func spawn(near: Node, global_pos: Vector2, poof_size: float, poof_color: Color) -> void:
    var projectiles := Projectiles.of(near)
    if projectiles == null:
        return

    var poof: Poof = load(_SCENE_PATH).instantiate()
    poof.size = poof_size
    poof.color = poof_color
    projectiles.launch(poof, global_pos)


func _ready() -> void:
    for i in range(clampi(int(size * 0.3), 8, 40)):
        var sparkle := Sparkle.new()
        sparkle.velocity = (
            Vector2.RIGHT.rotated(randf() * TAU) * randf_range(size * 0.8, size * 3.0)
        )
        sparkle.spin = randf_range(-6.0, 6.0)
        sparkle.angle = randf() * TAU
        sparkle.size = randf_range(maxf(4.0, size * 0.08), maxf(8.0, size * 0.18))
        sparkle.color = _PALETTE.pick_random()
        _sparkles.append(sparkle)


func _process(delta: float) -> void:
    _age += delta
    if _age >= duration:
        queue_free()
        return

    for sparkle in _sparkles:
        sparkle.position += sparkle.velocity * delta
        sparkle.velocity *= 1.0 - minf(1.0, 3.0 * delta)
        sparkle.angle += sparkle.spin * delta

    queue_redraw()


func _draw() -> void:
    var t := clampf(_age / duration, 0.0, 1.0)
    var fade := 1.0 - t * t

    draw_circle(Vector2.ZERO, size * (0.4 + 0.8 * t), Color(color, 0.25 * fade))
    draw_arc(
        Vector2.ZERO, size * (0.3 + 1.2 * t), 0.0, TAU, 40, Color(1, 1, 1, 0.6 * fade), 3.0, true
    )

    for sparkle in _sparkles:
        draw_twinkle(
            self,
            sparkle.position,
            sparkle.size * (1.0 - 0.5 * t),
            sparkle.angle,
            Color(sparkle.color, fade)
        )


## Draw a four-pointed twinkle star.
static func draw_twinkle(
    canvas: CanvasItem, center: Vector2, star_size: float, angle: float, star_color: Color
) -> void:
    var points := PackedVector2Array()
    for i in range(8):
        var radius := star_size if i % 2 == 0 else star_size * 0.3
        points.append(center + Vector2.RIGHT.rotated(angle + TAU * i / 8.0) * radius)
    canvas.draw_colored_polygon(points, star_color)
