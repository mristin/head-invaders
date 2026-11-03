extends ScriptedHeads

## Show the pickups: the supply drops rain down, and two players catch them and
## try the weapons on the dummy saucers.


func _play() -> void:
    appear(0, Vector2(700, 850))
    appear(1, Vector2(1220, 850))
    chase(1, func(): return _catch(1), 30.0)
    await chase(0, func(): return _catch(0), 30.0)


## Go for the nearest pickup, but stay in the lower half of the screen.
func _catch(id: int) -> Variant:
    var pickup: Variant = nearest_pickup(id)
    if pickup == null:
        return null
    return Vector2(pickup.x, maxf(pickup.y, 600.0))
