class_name ABBBot
extends RefCounted

## Bot ABB (rulebook §8.0) — priority-based planner per fazione.

var state: GameState
var module: RulesModule

func _init(_state: GameState, _module: RulesModule) -> void:
	state = _state
	module = _module


func take_turn(faction_id: String, _allow_special: bool = true, _limited: bool = false) -> Dictionary:
	var trace: Array = []
	var fdef: FactionDef = state.game_def.faction(faction_id)
	if fdef == null or fdef.operations.is_empty():
		return {"action": "pass", "trace": ["pass: no ops"]}
	var ops := ABBOperations.new(state, module)
	var plan: Array = _plan(faction_id)
	for step in plan:
		var op_id: String = String(step["op"])
		var target = step.get("target")
		var result: Dictionary = _execute(ops, faction_id, op_id, target)
		trace.append("%s @ %s: %s" % [op_id, target, "OK" if result.get("ok", false) else result.get("error", "?")])
		if result.get("ok", false):
			return {"action": op_id, "result": result, "trace": trace}
	return {"action": "pass", "trace": trace}


func event_choice(_faction_id: String, _card_number: int) -> Dictionary:
	return {"play_event": false, "side": "unshaded", "trace": ["scaffold: niente eventi"]}


# Planner
func _plan(faction_id: String) -> Array:
	match faction_id:
		"reds":
			return _plan_reds()
		"senate":
			return _plan_senate()
		"moderates":
			return _plan_moderates()
		"germans":
			return _plan_germans()
		_:
			return []


func _plan_reds() -> Array:
	var plan: Array = []
	for sid in _spaces_with_cells("reds", 2):
		if _has_enemy(sid, "reds"):
			plan.append({"op": "attack", "target": sid})
	for sid in _spaces_with_cells("reds", 1):
		var st: SpaceState = state.space_state(sid)
		if st.support > CoinEnums.Support.NEUTRAL:
			plan.append({"op": "terror", "target": sid})
	for sid in _uncontrolled_by("reds"):
		plan.append({"op": "rally", "target": sid})
	return plan


func _plan_senate() -> Array:
	var plan: Array = []
	for sid in _spaces_with_cells("senate", 2):
		if _has_enemy(sid, "senate"):
			plan.append({"op": "attack", "target": sid})
	for sid in _city_ids():
		var st: SpaceState = state.space_state(sid)
		if st.control == "senate":
			plan.append({"op": "rally", "target": sid})
	return plan


func _plan_moderates() -> Array:
	var plan: Array = []
	var by_pop: Array = []
	for sid in state.spaces.keys():
		var sd: SpaceDef = state.game_def.space(sid)
		if sd.pop <= 0:
			continue
		var st: SpaceState = state.space_state(sid)
		if st.count("moderates", "cell") == 0:
			by_pop.append({"sid": sid, "pop": sd.pop})
	by_pop.sort_custom(func(a, b): return int(a["pop"]) > int(b["pop"]))
	for entry in by_pop:
		plan.append({"op": "rally", "target": entry["sid"]})
	return plan


func _plan_germans() -> Array:
	var plan: Array = []
	for sid in state.spaces.keys():
		var st: SpaceState = state.space_state(sid)
		if st.count("germans", "troops") > 0 and st.count("reds", "cell") > 0:
			plan.append({"op": "attack", "target": sid})
	return plan


# Helpers
func _execute(ops: ABBOperations, fid: String, op_id: String, target) -> Dictionary:
	match op_id:
		"rally":
			return ops.rally(fid, String(target), "cell")
		"terror":
			return ops.terror(fid, String(target))
		"attack":
			return ops.attack(fid, String(target))
		_:
			return {"ok": false, "error": "op non supportata: " + op_id}


func _spaces_with_cells(fid: String, min_count: int) -> Array:
	var out: Array = []
	for sid in state.spaces.keys():
		if state.space_state(sid).count(fid, "cell") >= min_count:
			out.append(sid)
	return out


func _uncontrolled_by(fid: String) -> Array:
	var out: Array = []
	for sid in state.spaces.keys():
		if state.space_state(sid).control != fid:
			out.append(sid)
	return out


func _city_ids() -> Array:
	var out: Array = []
	for sid in state.spaces.keys():
		var sd: SpaceDef = state.game_def.space(sid)
		if sd != null and sd.type == CoinEnums.SpaceType.CITY:
			out.append(sid)
	return out


func _has_enemy(sid: String, fid: String) -> bool:
	var st: SpaceState = state.space_state(sid)
	for f in state.game_def.factions:
		if f.id == fid:
			continue
		for pt in ["cell", "troops", "admin", "network"]:
			if st.count(f.id, pt) > 0:
				return true
	return false
