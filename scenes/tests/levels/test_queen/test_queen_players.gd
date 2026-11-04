extends ScriptedHeads

## Show the queen: she comes down, sways, fires the fans and the showers, and
## calls in her darts. Two players chase her away, and her darts follow her
## home.


func _play() -> void:
    appear(0, Vector2(760, 950))
    appear(1, Vector2(1160, 950))
    await wait(3.0)
    chase(0, func(): return _below_queen(-90.0), 60.0)
    await chase(1, func(): return _below_queen(90.0), 60.0)


func _below_queen(offset: float) -> Variant:
    for node in get_tree().get_nodes_in_group(Enemy.GROUP):
        var queen := node as Queen
        if queen != null and queen.is_alive() and queen.has_arrived():
            return Vector2(queen.global_position.x + offset, 940.0)
    return null
