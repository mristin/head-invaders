extends ScriptedHeads

## Show the old oak: it strides at the top, throws the acorns, puffs the spores
## and sprouts the mushrooms. Two players chase it away, and its mushrooms
## follow it home.


func _play() -> void:
    appear(0, Vector2(760, 950))
    appear(1, Vector2(1160, 950))
    await wait(3.0)
    chase(0, func(): return _below_oak(-110.0), 80.0)
    await chase(1, func(): return _below_oak(110.0), 80.0)


func _below_oak(offset: float) -> Variant:
    for node in get_tree().get_nodes_in_group(Enemy.GROUP):
        var oak := node as OldOak
        if oak != null and oak.is_alive() and oak.has_arrived():
            return Vector2(oak.global_position.x + offset, 940.0)
    return null
