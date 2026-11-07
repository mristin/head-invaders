class_name Missile

extends Area2D

## A homing rocket launched by a spaceship. It steers towards the nearest
## enemy ahead of it and hits harder than a bullet.
##
## The rocket only steers within a cone around straight up: it never turns
## sideways to chase the enemies at the sides, so that the players still have
## to aim.
##
## Like the bullets, the missile only scans the enemies' and the chests'
## collision layers. It homes in on the enemies only, but opens a chest in
## its way.

## How many times bigger we draw the missiles and their collision shape, so
## that they are easy to see on a small screen from a distance.
const SIZE: float = 2.0

@export var speed: float = 750.0

## How fast the missile turns, in radians per second.
@export var turn_rate: float = 4.0

## How far the rocket may turn away from straight up, in radians.
@export var max_angle: float = deg_to_rad(35.0)

@export var damage: int = 26
@export var lifetime: float = 4.0

var direction: Vector2 = Vector2.UP
var color: Color = Color.WHITE

var _age: float = 0.0
var _spent: bool = false


func _ready() -> void:
    area_entered.connect(_on_area_entered)
    rotation = direction.angle()
    scale = Vector2.ONE * SIZE


func _physics_process(delta: float) -> void:
    _age += delta

    var target := _nearest_ahead()
    if target != null:
        var wanted := global_position.direction_to(target.global_position)
        var turn := clampf(direction.angle_to(wanted), -turn_rate * delta, turn_rate * delta)
        direction = direction.rotated(turn)

    var off_up := clampf(Vector2.UP.angle_to(direction), -max_angle, max_angle)
    direction = Vector2.UP.rotated(off_up)

    rotation = direction.angle()
    position += direction * speed * delta

    var bounds := get_viewport_rect().grow(40.0 * SIZE)
    if _age > lifetime or not bounds.has_point(global_position):
        queue_free()
        return

    queue_redraw()


## Return the nearest enemy within the cone ahead of the rocket, or null.
func _nearest_ahead() -> Enemy:
    var nearest: Enemy = null
    var nearest_distance := INF

    for node in get_tree().get_nodes_in_group(Enemy.GROUP):
        var enemy := node as Enemy
        if (
            enemy == null
            or not enemy.is_alive()
            or not enemy.has_arrived()
            or not enemy.is_targetable()
        ):
            continue

        var offset := enemy.global_position - global_position
        if offset.y >= 0.0 or absf(Vector2.UP.angle_to(offset)) > max_angle:
            continue

        var distance := offset.length_squared()
        if distance < nearest_distance:
            nearest_distance = distance
            nearest = enemy

    return nearest


func _on_area_entered(area: Area2D) -> void:
    if _spent:
        return

    var chest := area as Chest
    if chest != null and not chest.is_open():
        _spent = true
        chest.take_damage(damage)
        Poof.spawn(self, global_position, 30.0, color)
        queue_free()
        return

    var enemy := area as Enemy
    if enemy == null or not enemy.is_alive():
        return

    _spent = true
    enemy.take_damage(damage)
    Poof.spawn(self, global_position, 30.0, color)
    queue_free()


func _draw() -> void:
    # NOTE (mristin):
    # The missile points along the positive x-axis; we rotate the whole node.
    var flame := 8.0 + 5.0 * sin(_age * 60.0)
    draw_colored_polygon(
        PackedVector2Array([Vector2(-8, -3), Vector2(-8 - flame, 0), Vector2(-8, 3)]),
        Color(1.0, 0.85, 0.3, 0.9)
    )
    draw_rect(Rect2(-10, -3, 16, 6), color.lightened(0.3))
    draw_colored_polygon(
        PackedVector2Array([Vector2(6, -3), Vector2(12, 0), Vector2(6, 3)]), Color(1, 1, 1)
    )
