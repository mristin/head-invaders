extends ScriptedHeads

## Show the alligator and the giant clam drifting with the current. First
## the player waits at the side, so that the alligator snaps and spits bubbles,
## and the clam opens and spits a pearl. Then the player chases them: the bullets
## bounce off the closed clam until it opens.


func _play() -> void:
    appear(0, Vector2(150, 950))
    await wait(14.0)
    await chase(0, func(): return below_nearest_enemy(0, 920.0), 50.0)
