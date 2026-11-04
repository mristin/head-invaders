extends ScriptedHeads

## Show the banker: he flies over with the money rain, circles and tosses
## the bouncing coins, and dives where the line and the ring show. First two
## players wait at the sides; then they follow him, and dodge his dives.


func _play() -> void:
    appear(0, Vector2(300, 950))
    appear(1, Vector2(1620, 950))
    await wait(16.0)
    chase(0, func(): return _below_banker(-80.0), 100.0)
    await chase(1, func(): return _below_banker(80.0), 100.0)


func _below_banker(offset: float) -> Variant:
    for node in get_tree().get_nodes_in_group(Enemy.GROUP):
        var banker := node as Banker
        if banker == null or not banker.is_alive() or not banker.has_arrived():
            continue
        if banker.is_aiming():
            # NOTE: Get out of the way of the dive.
            return Vector2(banker.dive_x() + 400.0 * signf(offset), 950.0)
        return Vector2(clampf(banker.global_position.x + offset, 150.0, 1770.0), 950.0)
    return null
