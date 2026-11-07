class_name Bullet

extends Area2D

## A bullet fired by a spaceship. It flies in a straight line, usually up, and
## damages the first enemy it hits.
##
## The bullet only scans the enemies' and the chests' collision layers, so it
## passes through the spaceships and the rockets.

## How many times bigger we draw the bullets and their collision shape, so
## that they are easy to see on a small screen from a distance.
const SIZE: float = 2.0

@export var speed: float = 1800.0
@export var damage: int = 13

var color: Color = Color.WHITE
var direction: Vector2 = Vector2.UP

# NOTE (mristin):
# Several enemies can enter the bullet in the same physics step; the bullet must
# hit only one of them.
var _spent: bool = false


func _ready() -> void:
    area_entered.connect(_on_area_entered)
    rotation = direction.angle() + PI / 2.0
    scale = Vector2.ONE * SIZE


func _physics_process(delta: float) -> void:
    position += direction * speed * delta
    if not get_viewport_rect().grow(20.0 * SIZE).has_point(global_position):
        queue_free()


func _on_area_entered(area: Area2D) -> void:
    if _spent:
        return

    var chest := area as Chest
    if chest != null and not chest.is_open():
        _spent = true
        chest.take_damage(damage)
        queue_free()
        return

    var enemy := area as Enemy
    if enemy == null or not enemy.is_alive():
        return

    _spent = true
    enemy.take_damage(damage)
    queue_free()


func _draw() -> void:
    draw_line(Vector2(0, 14), Vector2(0, -14), Color(color, 0.8), 8.0, true)
    draw_line(Vector2(0, 11), Vector2(0, -11), Color(1, 1, 1, 0.95), 3.5, true)
