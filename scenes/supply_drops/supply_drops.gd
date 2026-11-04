class_name SupplyDrops

extends Node

## Drop a random pickup from the top of the screen every now and then, on top
## of what the defeated enemies leave behind.

## Set to false for a level without the supply drops.
@export var enabled: bool = true

## Drop only these kinds; drop any kind if empty.
@export var kinds: Array[Pickup.Kind] = []

@export var min_interval: float = 8.0
@export var max_interval: float = 14.0

## Keep the drops this far from the screen edges.
@export var margin: float = 160.0

var _cooldown: float = 0.0


func _ready() -> void:
    _cooldown = randf_range(min_interval, max_interval)


func _physics_process(delta: float) -> void:
    if not enabled:
        return

    _cooldown -= delta
    if _cooldown > 0.0:
        return
    _cooldown = randf_range(min_interval, max_interval)

    var bounds := get_viewport().get_visible_rect()
    var x := randf_range(bounds.position.x + margin, bounds.end.x - margin)
    var kind: Pickup.Kind = Pickup.random_kind() if kinds.is_empty() else kinds.pick_random()
    Pickup.drop(self, Vector2(x, bounds.position.y - 40.0), kind)
