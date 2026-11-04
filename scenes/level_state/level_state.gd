class_name LevelState

extends Node

## Hold the rules and the bookkeeping of a level, and decide when the level is
## accomplished or failed.
##
## The level is accomplished when all the enemies have fled, and failed when any
## spaceship is knocked out. Either way, we wait a bit so that the players see
## what happened.
##
## The level state knows nothing about the visuals. The game wires it to the
## fleet, the enemies and the HUD.

signal player_count_changed(count: int)
signal enemy_count_changed(count: int)
signal accomplished
signal failed

## Seconds between the decisive moment and the end of the level.
@export var outro_duration: float = 2.0

var _player_count: int = 0
var _enemy_count: int = 0
var _finished: bool = false


func set_player_count(count: int) -> void:
    _player_count = count
    player_count_changed.emit(count)


func set_enemy_count(count: int) -> void:
    _enemy_count = count
    enemy_count_changed.emit(count)


func on_spaceship_spawned(_key: String, _spaceship: Spaceship) -> void:
    set_player_count(_player_count + 1)


func on_spaceship_removed(_key: String) -> void:
    set_player_count(_player_count - 1)


func on_spaceship_knocked_out(_key: String) -> void:
    _finish(failed)


func on_enemy_joined() -> void:
    set_enemy_count(_enemy_count + 1)


func on_enemy_defeated() -> void:
    set_enemy_count(_enemy_count - 1)
    if _enemy_count == 0:
        _finish(accomplished)


func _finish(outcome: Signal) -> void:
    if _finished:
        return
    _finished = true

    # NOTE (mristin):
    # We use a timer node, not a scene-tree timer, so that the outcome is never
    # emitted once the level is gone.
    var timer := Timer.new()
    timer.one_shot = true
    timer.wait_time = outro_duration
    timer.timeout.connect(func(): outcome.emit())
    add_child(timer)
    timer.start()
