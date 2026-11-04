extends ScriptedHeads

## Show the mothership: it comes down, spins the pinwheel, fires from its pods,
## calls in the zippers, and drops its treasure chests. Two players chase it
## away, and its zippers follow it home.


func _play() -> void:
    appear(0, Vector2(760, 950))
    appear(1, Vector2(1160, 950))
    await wait(3.0)
    chase(0, func(): return _below_mothership(-110.0), 80.0)
    await chase(1, func(): return _below_mothership(110.0), 80.0)


func _below_mothership(offset: float) -> Variant:
    for node in get_tree().get_nodes_in_group(Enemy.GROUP):
        var mothership := node as Mothership
        if mothership != null and mothership.is_alive() and mothership.has_arrived():
            return Vector2(mothership.global_position.x + offset, 940.0)
    return null
