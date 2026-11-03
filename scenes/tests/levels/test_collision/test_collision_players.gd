extends ScriptedHeads

## Show the damage of bumping into an enemy: the player rams a dummy saucer and
## stays inside. The spaceship blinks after each hit, the ring shrinks, and
## the spaceship eventually gets dizzy, which restarts the level.


func _play() -> void:
    appear(0, Vector2(960, 950))
    await wait(1.5)
    for i in range(3):
        await glide(0, Vector2(960, 430), 1.0)
        await wait(3.5)
        await glide(0, Vector2(960, 950), 1.0)
        await wait(1.0)
