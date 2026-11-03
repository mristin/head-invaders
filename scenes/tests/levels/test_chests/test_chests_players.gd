extends ScriptedHeads

## Show the treasure chests: they float down, the player shoots them open, and
## catches the boosters, among them the bubble. The level has no enemies, so it
## never ends.


func _play() -> void:
    appear(0, Vector2(960, 950))
    await wait(1.0)
    await chase(0, _next_treasure, 30.0)


## Stay below the nearest chest, or catch the nearest falling booster.
func _next_treasure() -> Variant:
    var pickup: Variant = nearest_pickup(0)
    if pickup != null:
        return pickup

    for node in get_tree().get_nodes_in_group(Chest.GROUP):
        var chest := node as Chest
        if chest != null and not chest.is_open():
            return Vector2(chest.global_position.x, 920.0)
    return null
