extends ScriptedHeads

## Show the giant walrus: it claps the fans of snowballs, belly-flops with
## the rings of ice chunks and raises the ice walls. Two players chase it away,
## and shoot down the walls in their way. Like careful children, they step
## aside once it has clapped, until the snowballs have passed, and stay out
## from under the shadow where it will flop.

## How long the players stay aside after a clap, in seconds.
const _STAY_ASIDE: float = 2.6

## How far the players step aside, in pixels.
const _ASIDE: float = 420.0

var _aside_left: float = 0.0
var _claps_seen: int = 0


func _process(delta: float) -> void:
    _aside_left = maxf(0.0, _aside_left - delta)


func _play() -> void:
    appear(0, Vector2(760, 950))
    appear(1, Vector2(1160, 950))
    await wait(2.0)
    chase(0, func(): return _below_walrus(-60.0), 110.0)
    await chase(1, func(): return _below_walrus(60.0), 110.0)


func _below_walrus(offset: float) -> Variant:
    for node in get_tree().get_nodes_in_group(Enemy.GROUP):
        var walrus := node as GiantWalrus
        if walrus == null or not walrus.is_alive() or not walrus.has_arrived():
            continue

        if walrus.claps() != _claps_seen:
            _claps_seen = walrus.claps()
            _aside_left = _STAY_ASIDE

        var x := walrus.global_position.x + offset
        if walrus.action() in [GiantWalrus.Action.FLOP_WINDUP, GiantWalrus.Action.FLOP]:
            x = walrus.landing_spot().x + offset
        if _aside_left > 0.0:
            # NOTE: Step aside, away from the edge of the screen if needed.
            var away := signf(offset)
            if x + away * _ASIDE > 1820.0:
                away = -1.0
            elif x + away * _ASIDE < 100.0:
                away = 1.0
            x += away * _ASIDE
        return Vector2(clampf(x, 100.0, 1820.0), 950.0)
    return null
