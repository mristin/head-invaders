class_name GroundEnemy

extends Enemy

## Define what the enemies on the ground share: they slide down with the ground
## of the level, and come around from the top again after leaving at
## the bottom. The spaceships fly over them without clashing, and they fire
## only from the upper part of the screen, so that they never fire at
## a spaceship right above them.
##
## Each kind of ground enemy extends this class and moves on the ground in its
## own way by overriding _walk.

## How fast the ground slides down, in pixels per second. Keep it the same as
## the scrolling of the level's background.
@export var ground_speed: float = 50.0

## The enemy fires only above this fraction of the screen height.
@export_range(0.0, 1.0) var fire_above: float = 0.65

## Come around from the top this far from the screen edges.
@export var margin: float = 120.0


func _ready() -> void:
    super()
    grounded = true


func _move(delta: float) -> void:
    position.y += ground_speed * delta
    _walk(delta)

    var bounds := get_viewport_rect()
    if position.y > bounds.end.y + radius * 2.0:
        position.y = bounds.position.y - radius * 2.0
        position.x = randf_range(bounds.position.x + margin, bounds.end.x - margin)
    position.x = clampf(position.x, bounds.position.x + margin, bounds.end.x - margin)


## Move on the ground on top of the sliding; by default, stay put.
func _walk(_delta: float) -> void:
    pass


func _may_fire() -> bool:
    var bounds := get_viewport_rect()
    return global_position.y < bounds.position.y + bounds.size.y * fire_above
