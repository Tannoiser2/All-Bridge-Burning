class_name ABBBot
extends RefCounted

## Bot ABB (rulebook §8.0) — priority-based planner per fazione + PAC2 deck.

var state: GameState
var module: RulesModule
## Quando true, il bot prova PAC2 (carte Solitaire 49-65) prima del priority planner.
var use_pac2: bool = true
var _pac2_dice_seed: int = -1


func _init(_state: GameState, _module: RulesModule) -> void:
	state = _state
	module = _module


func take_turn(faction_id: String, _allow_special: bool = true, _limited: bool = false) -> Dictionary:
	var trace: Array = []
	var fdef: FactionDef = state.game_def.faction(faction_id)
	if fdef == null or fdef.operations.is_empty():
		return {"action": "pass", "trace": ["pass: no ops"]}
	# 1. Prova PAC2 (solo per Reds/Senate/Moderates, le 3 fazioni con bot deck).
	if use_pac2 and faction_id in ["reds", "senate", "moderates"]:
		var pac2 := ABBBotPAC2.new(state, module, _pac2_dice_seed)
		var r2 := pac2.take_turn(faction_id)
		if not r2.is_empty():
			trace.append("PAC2 #%d" % int(r2.get("card", 0)))
			trace.append_array(r2.get("trace", []))
			return {"action": String(r2.get("action", "pac2")), "trace": trace}
		trace.append("PAC2: nessuna carta applicabile, fallback priority planner")
	# 2. Fallback: priority planner originale.
	var ops := ABBOperations.new(state, module)
	var plan: Array = _plan(faction_id)
	for step in plan:
		var op_id: String = String(step["op"])
		var result: Dictionary = _execute_step(ops, faction_id, step)
		var lbl: String = "%s @ %s" % [op_id, step.get("target", step.get("to", "?"))]
		trace.append("%s: %s" % [lbl, "OK" if result.get("ok", false) else result.get("error", "?")])
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
	var ph2 := int(state.tracks.get("phase", 1)) >= 2
	# Attack solo in Phase II (§3.2.4)
	if ph2:
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
	var ph2 := int(state.tracks.get("phase", 1)) >= 2
	# Attack solo in Phase II (§3.2.4)
	if ph2:
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


## Landing Sites: Town su cui i Germans possono atterrare (rulebook playbook).
## Vassal map: Helsinki, Turku, Vaasa.
const GERMAN_LANDING_SITES := ["helsinki", "turku", "vaasa"]


## §3.4: 1d6 Senate roll. 1-3 = Germans agiscono prima delle Fazioni; 4-6 = dopo.
## Salvato in state.tracks.german_eligibility_roll per UI / debug.
func roll_german_eligibility(rng_seed: int = -1) -> int:
	var rng := RandomNumberGenerator.new()
	if rng_seed >= 0:
		rng.seed = rng_seed
	else:
		rng.randomize()
	var roll := rng.randi_range(1, 6)
	state.tracks["german_eligibility_roll"] = roll
	state.tracks["germans_act_first"] = 1 if roll <= 3 else 0
	return roll


## Senate ha piazzato il marker Coordinate sul cilindro German Eligibility?
## (Quando true, è il giocatore Senate a decidere l'azione dei Germans — qui
## il bot continua a fare la sua scelta, ma il flag è esposto per la UI.)
func germans_coordinated() -> bool:
	return int(state.tracks.get("coordinate_marker", 0)) > 0


func _plan_germans() -> Array:
	# §3.4: i Germans agiscono SOLO in Phase II (dopo Red Revolt!).
	if int(state.tracks.get("phase", 1)) < 2:
		return []
	# Flowchart §3.4 (PAC2):
	# 1. Se nessuna Truppa Tedesca (mappa + Available) -> No Action
	# 2. Se Available > 0 e nessuna sulla mappa -> Landing (Available → primo Landing Site)
	# 3. Se Available > 0 e già sulla mappa -> Reinforce (Available → spazio con Germans)
	# 4. Altrimenti, Germans + nemico (Reds/Russians) nello stesso spazio -> Attack
	# 5. Altrimenti, March: gruppo Germans → adiacente con Reds Cells
	var avail_g: int = state.available("germans", "troops")
	var on_map_g: int = state.count_on_map("germans", "troops")
	if avail_g + on_map_g == 0:
		return []
	# Step 2: Landing
	if avail_g > 0 and on_map_g == 0:
		var site: String = _first_present(GERMAN_LANDING_SITES)
		if site != "":
			return [{"op": "land", "target": site, "count": avail_g}]
	# Step 3: Reinforce
	if avail_g > 0 and on_map_g > 0:
		var target: String = _first_with_germans()
		if target != "":
			return [{"op": "land", "target": target, "count": avail_g}]
	# Step 4: Attack su spazio con Reds o Russians
	for sid in state.spaces.keys():
		var st: SpaceState = state.space_state(sid)
		if st.count("germans", "troops") <= 0:
			continue
		if st.count("reds", "cell") > 0 or st.count("russians", "troops") > 0:
			return [{"op": "attack", "target": sid}]
	# Step 5: March verso Reds Cells più vicine
	for sid in state.spaces.keys():
		var st2: SpaceState = state.space_state(sid)
		if st2.count("germans", "troops") <= 0:
			continue
		var sd: SpaceDef = state.game_def.space(sid)
		for adj in sd.adjacent:
			if not state.spaces.has(String(adj)):
				continue
			if state.space_state(String(adj)).count("reds", "cell") > 0:
				return [{"op": "march", "from": sid, "to": String(adj),
					"count": st2.count("germans", "troops")}]
	return []


func _first_present(sids: Array) -> String:
	for sid in sids:
		if state.spaces.has(String(sid)):
			return String(sid)
	return ""


func _first_with_germans() -> String:
	for sid in state.spaces.keys():
		if state.space_state(sid).count("germans", "troops") > 0:
			return String(sid)
	return ""


# Helpers
func _execute_step(ops: ABBOperations, fid: String, step: Dictionary) -> Dictionary:
	var op_id: String = String(step["op"])
	match op_id:
		"rally":
			return ops.rally(fid, String(step["target"]), "cell")
		"terror":
			return ops.terror(fid, String(step["target"]))
		"attack":
			return ops.attack(fid, String(step["target"]))
		"march":
			# Germans flowchart: muove troops da `from` a `to`.
			var pt: String = String(step.get("piece_type", "troops" if fid == "germans" or fid == "russians" else "cell"))
			return ops.march(fid, String(step["from"]), String(step["to"]), pt, int(step.get("count", 1)))
		"land":
			# Germans flowchart §3.4 step 1: piazza tutte le Truppe Available a `target`.
			# Niente Resources, niente Vassalage shift — è già stato fatto in §6.5.3.
			if not state.spaces.has(String(step["target"])):
				return {"ok": false, "error": "Landing Site non valido"}
			var count: int = int(step.get("count", state.available(fid, "troops")))
			var placed: int = state.place_from_available(fid, "troops", String(step["target"]), count, "")
			if placed <= 0:
				return {"ok": false, "error": "nessuna truppa Available"}
			state.recompute_control(String(step["target"]))
			# §3.4 Landing piazza anche un News marker (per Moderates Personality SA).
			if fid == "germans":
				var st_land: SpaceState = state.space_state(String(step["target"]))
				st_land.set_marker("news", st_land.marker("news") + 1)
			return {"ok": true, "log": ["Landing %s × %d a %s (+News)" % [fid, placed, step["target"]]]}
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
