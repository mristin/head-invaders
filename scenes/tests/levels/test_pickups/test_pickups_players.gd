extends ScriptedHeads

## Show the pickups: the chests float down with the weapons, and two players
## shoot them open, catch the weapons and try them on the dummy saucers.


func _play() -> void:
    appear(0, Vector2(700, 850))
    appear(1, Vector2(1220, 850))
    chase(1, func(): return _catch(1), 30.0)
    await chase(0, func(): return _catch(0), 30.0)


## Go for the nearest pickup, or stay below the nearest chest, but stay in
## the lower half of the screen.
func _catch(id: int) -> Variant:
    var pickup: Variant = nearest_pickup(id)
    if pickup != null:
        return Vector2(pickup.x, maxf(pickup.y, 600.0))

    for node in get_tree().get_nodes_in_group(Chest.GROUP):
        var chest := node as Chest
        if chest != null and not chest.is_open():
            return Vector2(chest.global_position.x, 850.0)
    return null
