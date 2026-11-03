class_name Game

extends Node2D

## Orchestrate the game: own the head controllers, load the levels and wire
## everything together. The game rules belong to the levels and their objects.

const _FLEET_SCENE: PackedScene = preload("res://scenes/fleet/fleet.tscn")
const _LEVEL_STATE_SCENE: PackedScene = preload("res://scenes/level_state/level_state.tscn")
const _FINAL_MESSAGE_SCENE: PackedScene = preload("res://scenes/final_message/final_message.tscn")

const _LEVEL_ACCOMPLISHED_IMAGE: Texture2D = preload("res://assets/images/level_accomplished.svg")
const _LEVEL_FAILED_IMAGE: Texture2D = preload("res://assets/images/level_failed.svg")
const _GAME_FINISHED_IMAGE: Texture2D = preload("res://assets/images/game_finished.svg")

## How long the messages between the levels stay, in seconds.
@export var level_message_seconds: float = 5.0
@export var game_finished_message_seconds: float = 15.0

# Public so that other callers can override before _ready runs.
var level_scene_paths: Array[String] = [
    "res://scenes/levels/first/first.tscn",
    "res://scenes/levels/second/second.tscn",
    "res://scenes/levels/third/third.tscn",
    "res://scenes/levels/fourth/fourth.tscn",
    "res://scenes/levels/fifth/fifth.tscn",
    "res://scenes/levels/sixth/sixth.tscn",
    "res://scenes/levels/seventh/seventh.tscn",
    "res://scenes/levels/eighth/eighth.tscn",
    "res://scenes/levels/ninth/ninth.tscn",
    "res://scenes/levels/tenth/tenth.tscn",
]

var _head_controllers: Array[HeadController] = []

# NOTE (mristin):
# The fleet lives across the levels so that the players keep their spaceships
# and colors when the level changes.
var _fleet: Fleet = null

@onready var screen: Node2D = $Screen
@onready var hud: Hud = $Hud


func own_head_controllers(controllers: Array[HeadController]) -> void:
    # Take ownership of the head controllers and include them in this scene.
    _head_controllers = controllers


func _ready() -> void:
    _fleet = _FLEET_SCENE.instantiate()

    for i in range(_head_controllers.size()):
        var controller := _head_controllers[i]
        add_child(controller)

        controller.head_appeared.connect(_on_head_appeared.bind(i))
        controller.head_moved.connect(_on_head_moved.bind(i))
        controller.head_lost.connect(_on_head_lost.bind(i))

    set_level(0)


func _exit_tree() -> void:
    if _fleet != null and _fleet.get_parent() == null:
        _fleet.free()


func set_level(level: int) -> void:
    assert(level >= 0)
    assert(level < level_scene_paths.size())

    var scene_path := level_scene_paths[level]

    var fleet_parent := _fleet.get_parent()
    if fleet_parent != null:
        fleet_parent.remove_child(_fleet)

    for child in screen.get_children():
        screen.remove_child(child)
        child.queue_free()

    var scene: Node2D = load(scene_path).instantiate()
    screen.add_child(scene)

    # region Set up the fleet
    # NOTE (mristin):
    # Every level starts with the spaceships repaired, also when we restart
    # the level after a spaceship has been knocked out.
    _fleet.repair()
    scene.add_child(_fleet)
    # endregion

    # region Set up level state
    var level_state: LevelState = _LEVEL_STATE_SCENE.instantiate()
    scene.add_child(level_state)

    _fleet.spaceship_spawned.connect(level_state.on_spaceship_spawned)
    _fleet.spaceship_removed.connect(level_state.on_spaceship_removed)
    _fleet.spaceship_knocked_out.connect(level_state.on_spaceship_knocked_out)

    var enemies: Array[Enemy] = []
    for child in scene.get_node("Enemies").get_children():
        if child is Enemy:
            enemies.append(child)

    for enemy in enemies:
        enemy.defeated.connect(level_state.on_enemy_defeated)

    # NOTE (mristin):
    # Some enemies join in the middle of the level, e.g., the queen's darts.
    scene.get_node("Enemies").child_entered_tree.connect(
        func(node: Node):
            var enemy := node as Enemy
            if enemy != null:
                enemy.defeated.connect(level_state.on_enemy_defeated)
                level_state.on_enemy_joined()
    )
    # endregion

    # region Wire up HUD
    level_state.player_count_changed.connect(hud.on_player_count_changed)
    level_state.enemy_count_changed.connect(hud.on_enemy_count_changed)

    level_state.set_player_count(_fleet.get_spaceships().size())
    level_state.set_enemy_count(enemies.size())
    # endregion

    # region Wire up the level transition
    level_state.failed.connect(
        func():
            _show_message(
                _LEVEL_FAILED_IMAGE,
                "Let's try again!",
                "The aliens were too quick this time. Everybody gets a fresh shield.",
                level_message_seconds,
                func(): set_level(level)
            )
    )

    level_state.accomplished.connect(
        func():
            if level < level_scene_paths.size() - 1:
                _show_message(
                    _LEVEL_ACCOMPLISHED_IMAGE,
                    "Great job!",
                    "The aliens flew away. Get ready for the next level!",
                    level_message_seconds,
                    func(): set_level(level + 1)
                )
            else:
                _show_message(
                    _GAME_FINISHED_IMAGE,
                    "You did it!",
                    (
                        (
                            "The head invaders are gone, and all the bad dreams with them."
                            + " %d worlds are bright and happy again. Sweet dreams, heroes!"
                        )
                        % level_scene_paths.size()
                    ),
                    game_finished_message_seconds,
                    func(): set_level(0)
                )
    )
    # endregion


## Pause the game, show the message and continue once it is done.
func _show_message(
    image: Texture2D, title: String, subtitle: String, seconds: float, then: Callable
) -> void:
    var message: FinalMessage = _FINAL_MESSAGE_SCENE.instantiate()
    add_child(message)
    message.show_message(image, title, subtitle, seconds)
    get_tree().paused = true

    message.done.connect(
        func():
            get_tree().paused = false
            message.queue_free()
            then.call_deferred()
    )


# NOTE (mristin):
# We key the heads by "<controller index>:<head id>" so that the ids of different
# controllers never clash.
static func _head_key(controller_index: int, id: int) -> String:
    return "%d:%d" % [controller_index, id]


func _on_head_appeared(id: int, pos: Vector2, controller_index: int) -> void:
    _fleet.spawn(_head_key(controller_index, id), pos)


func _on_head_moved(id: int, pos: Vector2, controller_index: int) -> void:
    _fleet.move(_head_key(controller_index, id), pos)


func _on_head_lost(id: int, controller_index: int) -> void:
    _fleet.remove(_head_key(controller_index, id))
