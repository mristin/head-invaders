extends ScriptedHeads

## Show the critters on the forest floor. First the player only watches from
## the side: the mushroom and the ladybug slide down with the ground, pass
## below the spaceship without clashing, and come around from the top. Then
## the player chases them away.


func _play() -> void:
    appear(0, Vector2(150, 1000))
    await wait(30.0)
    await chase(0, func(): return below_nearest_enemy(0, 900.0), 40.0)
