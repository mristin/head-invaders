class_name ScriptedHeads

extends HeadController

## Play the heads of the players by a script, like a puppeteer, so that a test
## level shows its behavior without anybody moving in front of the camera.
##
## Each test level comes with its own script, which extends this class and
## overrides _play. The helpers below move the heads smoothly at the speed of
## a real head. We play the script over and over again.

## The heads move at most this fast, in pixels per second, like real heads.
@export var head_speed: float = 900.0

## Pause between the repetitions of the script, in seconds.
@export var pause_between_plays: float = 1.5

var _positions: Dictionary[int, Vector2] = {}

## Count the repetitions so that the stale helpers stop moving their heads.
var _play_count: int = 0


func _ready() -> void:
    # NOTE (mristin):
    # The game connects to our signals only after adding us, so we start
    # playing in the next frame.
    _loop.call_deferred()


func _loop() -> void:
    while is_inside_tree():
        _play_count += 1
        await _play()
        lose_all()
        await wait(pause_between_plays)


## Play the script once; override in each test level.
func _play() -> void:
    await wait(1.0)


# region Helpers


func wait(seconds: float) -> void:
    await get_tree().create_timer(seconds).timeout


func appear(id: int, pos: Vector2) -> void:
    if _positions.has(id):
        teleport(id, pos)
        return
    _positions[id] = pos
    head_appeared.emit(id, pos)


func lose(id: int) -> void:
    if _positions.erase(id):
        head_lost.emit(id)


func lose_all() -> void:
    for id in _positions.keys():
        lose(id)


func teleport(id: int, pos: Vector2) -> void:
    if _positions.has(id):
        _positions[id] = pos
        head_moved.emit(id, pos)


func position_of(id: int) -> Vector2:
    return _positions.get(id, Vector2.ZERO)


## Glide the head to the position over the given seconds, easing in and out.
##
## Do not await the call to move several heads at once.
func glide(id: int, to: Vector2, seconds: float) -> void:
    if not _positions.has(id):
        return

    var play := _play_count
    var from := _positions[id]
    var elapsed := 0.0
    while elapsed < seconds:
        await get_tree().process_frame
        if play != _play_count or not _positions.has(id):
            return
        elapsed += get_process_delta_time()
        var t := smoothstep(0.0, 1.0, clampf(elapsed / seconds, 0.0, 1.0))
        teleport(id, from.lerp(to, t))


## Chase the target for the given seconds at the head speed. The target is
## a callable returning the position to chase, or null to stay put.
##
## Do not await the call to move several heads at once.
func chase(id: int, target: Callable, seconds: float) -> void:
    var play := _play_count
    var elapsed := 0.0
    while elapsed < seconds:
        await get_tree().process_frame
        if play != _play_count or not _positions.has(id):
            return
        var delta := get_process_delta_time()
        elapsed += delta

        var wanted: Variant = target.call()
        if wanted is Vector2:
            teleport(id, _positions[id].move_toward(wanted, head_speed * delta))


## Return the position below the nearest enemy at the given height, to chase
## it away, or null if there is no enemy.
func below_nearest_enemy(id: int, height: float) -> Variant:
    var enemy := Enemy.nearest_to(self, position_of(id))
    if enemy == null:
        return null
    return Vector2(enemy.global_position.x, height)


## Return the position of the nearest falling pickup, or null if none.
func nearest_pickup(id: int) -> Variant:
    var nearest: Variant = null
    var nearest_distance := INF
    for node in get_tree().get_nodes_in_group(Pickup.GROUP):
        var pickup := node as Pickup
        if pickup == null or pickup.is_queued_for_deletion():
            continue
        var distance := position_of(id).distance_squared_to(pickup.global_position)
        if distance < nearest_distance:
            nearest_distance = distance
            nearest = pickup.global_position
    return nearest

# endregion
