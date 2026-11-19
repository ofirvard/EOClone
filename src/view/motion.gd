extends RefCounted
## Small battle animations shared by the hero cards and the monster picture.
## Each moves a Control away from `rest` and back, and returns its tween so
## the caller can stop it before starting the next one.

const HOP_DISTANCE := 14.0       ## Pixels for a hop (attacking).
const HOP_TIME := 0.3            ## Seconds for the hop out and back.
const SHAKE_DISTANCE := 7.0      ## Pixels for a shake (getting hit).
const SHAKE_TIME := 0.3          ## Seconds for the whole shake.


## A quick hop along `direction` (e.g. Vector2.UP) and back.
static func hop(node: Control, rest: Vector2, direction: Vector2) -> Tween:
	var tween := node.create_tween()
	tween.tween_property(node, "position", rest + direction * HOP_DISTANCE, HOP_TIME * 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "position", rest, HOP_TIME * 0.6) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	return tween


## A side-to-side shake that dies down, ending back at `rest`.
static func shake(node: Control, rest: Vector2) -> Tween:
	var tween := node.create_tween()
	var steps := [1.0, -1.0, 0.6, -0.4, 0.0]
	for s in steps:
		tween.tween_property(node, "position", rest + Vector2(s * SHAKE_DISTANCE, 0), SHAKE_TIME / steps.size())
	return tween
