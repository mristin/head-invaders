extends ScriptedHeads

## Show the creatures on the lava rocks. First the player waits in the corner,
## so that the lizard scurries and spits, the snake rears up and spits a fan,
## the golem's boulder bursts into pebbles, and the volcano's blobs fall in
## arcs. Then the player chases them away.


func _play() -> void:
    appear(0, Vector2(150, 950))
    await wait(14.0)
    await chase(0, func(): return below_nearest_enemy(0, 900.0), 60.0)
