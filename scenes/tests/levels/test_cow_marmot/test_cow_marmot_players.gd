extends ScriptedHeads

## Show the bell cow and the marmot. First two players wait at the sides, so
## that the cow rings its bell and moos its rings of notes, and the marmot
## whistles, stands up and throws its snowballs from its burrows. Then they
## chase them away: the marmot ducks into its burrows when hit a few times,
## and pops up out of another one.


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
