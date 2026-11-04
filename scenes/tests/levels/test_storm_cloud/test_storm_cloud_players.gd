extends ScriptedHeads

## Show the grumpy storm cloud: the glowing lanes and the lightning, the rain
## and the gusts of wind, which push the raindrops sideways, and the little
## rain clouds it sneezes out when low on energy. Two players chase it away,
## like careful children would: they step out of a glowing lane before
## the lightning strikes, keep out from under the cloud while it rains, on
## the side the wind comes from, and step aside when a little rain cloud above
## them gathers its rain.

## How long the players keep out from under the cloud after the rain, until
## the last raindrops have fallen, in seconds.
const _STAY_ASIDE: float = 2.2

## How far the players keep out of a glowing lane and from under the rain.
const _LANE_CLEARANCE: float = 330.0
const _RAIN_CLEARANCE: float = 400.0

var _aside_left: float = 0.0
var _aside_side: float = 1.0


func _process(delta: float) -> void:
    _aside_left = maxf(0.0, _aside_left - delta)


func _play() -> void:
    appear(0, Vector2(760, 950))
    appear(1, Vector2(1160, 950))
    await wait(2.0)
    chase(0, func(): return _around_cloud(-50.0), 100.0)
    await chase(1, func(): return _around_cloud(50.0), 100.0)


func _storm_cloud() -> StormCloud:
    for node in get_tree().get_nodes_in_group(Enemy.GROUP):
        var cloud := node as StormCloud
        if cloud != null and cloud.is_alive() and cloud.has_arrived():
            return cloud
    return null


func _around_cloud(offset: float) -> Variant:
    var cloud := _storm_cloud()
    if cloud == null:
        return null

    var x := cloud.global_position.x + offset

    # NOTE: Keep out from under the rain, on the side the wind comes from.
    if cloud.is_raining():
        if _aside_left <= 0.0:
            _aside_side = -cloud.wind()
            if _aside_side == 0.0:
                _aside_side = -1.0 if cloud.global_position.x > 960.0 else 1.0
        if cloud.wind() != 0.0:
            _aside_side = -cloud.wind()
        _aside_left = _STAY_ASIDE
    if _aside_left > 0.0:
        x = cloud.global_position.x + _aside_side * _RAIN_CLEARANCE + offset * 0.5

    # NOTE: Step aside when a little rain cloud above gathers its rain.
    for node in get_tree().get_nodes_in_group(Enemy.GROUP):
        var little := node as RainCloud
        if little == null or not little.is_raining():
            continue
        if absf(little.global_position.x - x) < 200.0:
            var side := 1.0 if little.global_position.x < x else -1.0
            x = little.global_position.x + side * 280.0

    # NOTE: Step out of the glowing lanes before the lightning strikes.
    var lanes := cloud.lightning_lanes()
    if _in_lanes(x, lanes):
        var best := x
        var best_distance := INF
        for lane in lanes:
            for side: float in [-1.0, 1.0]:
                var candidate := clampf(lane + side * _LANE_CLEARANCE, 100.0, 1820.0)
                if _in_lanes(candidate, lanes):
                    continue
                var distance := absf(candidate - position_of(_id_of(offset)).x)
                if distance < best_distance:
                    best_distance = distance
                    best = candidate
        x = best

    return Vector2(clampf(x, 100.0, 1820.0), 950.0)


func _in_lanes(x: float, lanes: Array[float]) -> bool:
    for lane in lanes:
        if absf(x - lane) < _LANE_CLEARANCE - 40.0:
            return true
    return false


func _id_of(offset: float) -> int:
    return 0 if offset < 0.0 else 1
