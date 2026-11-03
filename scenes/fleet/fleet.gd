class_name Fleet

extends Node2D

## Manage the spaceships of all the players: spawn them and give each a unique
## color. The spaceships may overlap each other.
##
## When a player leaves and returns (the head tracker recognizes them under the
## same key), they get back their spaceship with the damage and the color it had.

signal spaceship_spawned(key: String, spaceship: Spaceship)
signal spaceship_removed(key: String)
signal spaceship_knocked_out(key: String)

const _SPACESHIP_SCENE: PackedScene = preload("res://scenes/spaceship/spaceship.tscn")

## Hue of the first spaceship; the following ones are spread around it.
@export_range(0.0, 1.0) var first_hue: float = 0.55
@export_range(0.0, 1.0) var saturation: float = 0.85
@export_range(0.0, 1.0) var value: float = 1.0

var _spaceships: Dictionary[String, Spaceship] = {}
var _hues: Dictionary[String, float] = {}

# NOTE (mristin):
# We remember the spaceships of the players who left until the next level.
var _left_health: Dictionary[String, int] = {}
var _left_hues: Dictionary[String, float] = {}


func spawn(key: String, pos: Vector2) -> void:
    if _spaceships.has(key):
        move(key, pos)
        return

    var hue: float = _left_hues.get(key, _allocate_hue())
    _hues[key] = hue

    var spaceship: Spaceship = _SPACESHIP_SCENE.instantiate()
    spaceship.set_color(Color.from_hsv(hue, saturation, value))
    spaceship.set_target(pos)
    spaceship.position = pos
    add_child(spaceship)
    _spaceships[key] = spaceship

    if _left_health.has(key):
        spaceship.set_health(_left_health[key])
    _left_health.erase(key)
    _left_hues.erase(key)

    spaceship.knocked_out.connect(func(): spaceship_knocked_out.emit(key))

    spaceship_spawned.emit(key, spaceship)


func move(key: String, pos: Vector2) -> void:
    if _spaceships.has(key):
        _spaceships[key].set_target(pos)


func remove(key: String) -> void:
    if not _spaceships.has(key):
        return

    var spaceship := _spaceships[key]
    _left_health[key] = spaceship.health
    _left_hues[key] = _hues[key]

    spaceship.queue_free()
    _spaceships.erase(key)
    _hues.erase(key)

    spaceship_removed.emit(key)


## Repair all the spaceships and forget the damage of the players who left,
## e.g., at the start of a level.
func repair() -> void:
    for spaceship: Spaceship in _spaceships.values():
        spaceship.repair()

    _left_health.clear()
    _left_hues.clear()


func get_spaceships() -> Array[Spaceship]:
    var result: Array[Spaceship] = []
    result.assign(_spaceships.values())
    return result


## Pick the hue which is the most distinct from the hues currently in use.
func _allocate_hue() -> float:
    if _hues.is_empty():
        return first_hue

    var best_hue := first_hue
    var best_distance := -1.0

    for i in range(360):
        var candidate := fposmod(first_hue + i / 360.0, 1.0)

        var distance := 1.0
        for used: float in _hues.values():
            var d := absf(candidate - used)
            distance = minf(distance, minf(d, 1.0 - d))

        if distance > best_distance:
            best_distance = distance
            best_hue = candidate

    return best_hue


func _process(_delta: float) -> void:
    for spaceship: Spaceship in _spaceships.values():
        spaceship.position = spaceship.desired_position()
