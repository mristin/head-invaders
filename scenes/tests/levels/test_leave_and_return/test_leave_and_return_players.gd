extends ScriptedHeads

## Show that a returning player keeps the damage and the color: the player takes
## a few rockets, leaves, and comes back elsewhere. Then a new player arrives,
## with full health and a new color.


func _play() -> void:
    appear(0, Vector2(960, 950))
    await wait(5.0)

    lose(0)
    await wait(2.0)
    appear(0, Vector2(500, 950))
    await wait(3.0)

    appear(1, Vector2(1420, 950))
    await wait(3.0)
