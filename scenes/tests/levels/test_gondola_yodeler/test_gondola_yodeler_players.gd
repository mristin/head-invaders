extends ScriptedHeads

## Show the gondola and the yodeler. First two players wait at the sides, so
## that the gondola slides along its cable from station to station and its
## passengers throw snowballs, and the yodeler yodels and the mountains echo
## his tune from the far side. Then they chase them away.


func _play() -> void:
    appear(0, Vector2(150, 950))
    appear(1, Vector2(1770, 950))
    await wait(14.0)
    chase(0, func(): return below_nearest_enemy(0, 930.0), 80.0)
    await chase(1, func(): return _beside_nearest_enemy(1), 80.0)


## Return the position a bit beside the nearest enemy, so that the two players
## do not overlap.
func _beside_nearest_enemy(id: int) -> Variant:
    var below: Variant = below_nearest_enemy(id, 930.0)
    if below == null:
        return null
    return below + Vector2(140.0, 0.0)
