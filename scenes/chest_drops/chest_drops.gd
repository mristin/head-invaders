class_name ChestDrops

extends Node

## Float a treasure chest down from the top of the screen every now and then.
## The chests are the only source of the boosters. The test levels without the
## chests leave it disabled.

@export var enabled: bool = false

## Drop the chests only in these styles; in any style if empty.
@export var styles: Array[Chest.Style] = []

## The chests give only these kinds of boosters; any kind if empty.
@export var kinds: Array[Pickup.Kind] = []

@export var min_interval: float = 6.0
@export var max_interval: float = 9.0

## Seconds until the first chest.
@export var first_delay: float = 3.0

## Keep the chests this far from the screen edges.
@export var margin: float = 200.0

var _cooldown: float = 0.0


func _ready() -> void:
    _cooldown = first_delay


func _physics_process(delta: float) -> void:
    if not enabled:
        return

    _cooldown -= delta
    if _cooldown > 0.0:
        return
    _cooldown = randf_range(min_interval, max_interval)

    var bounds := get_viewport().get_visible_rect()
    var x := randf_range(bounds.position.x + margin, bounds.end.x - margin)
    Chest.drop(self, Vector2(x, bounds.position.y - 80.0), styles, kinds)
