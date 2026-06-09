class_name ABBBot
extends RefCounted

## Sistema Non-giocatore (NP) All Bridges Burning (rulebook §8.0).
##
## ABB usa il sistema PAC2 (Priority Algorithm Card 2) — 2 flowchart con
## priorità nidificate per fazione — più 17 carte Bot. Il pieno sistema
## è grosso; qui implementiamo una versione **priority-based** che
## migliora il bot random precedente:
##
## - Per ogni fazione abbiamo una lista ordinata di tentativi
##   `(operazione, target_selector)`.
## - Il bot prova nell'ordine; il primo che ritorna ok=true viene applicato.
## - Se nessuno è eseguibile, pass.
##
## Punti TODO (per PR PAC2 completo):
## - Decisione Cmd vs Cmd+SA vs Limited Cmd basata su Risorse e flowchart.
## - Selezione Special Activity dopo l'Operazione.
## - Carte Bot (17) per scenari speciali (8.2 Non-player cards).
## - Eligibility check (1-3 prima/dopo per Germans, §3.4).

var state: GameState
var module: RulesModule

func _init(_state: GameState, _module: RulesModule) -> void:
	state = _state
	module = _module


## Punto d'ingresso. Restituisce {"action": String, "result": Dict, "trace": Array}.
func take_turn(faction_id: String, _allow_special: bool = true, _limited: bool = false) -> Dictionary:
	var trace: Array = []
	var fdef: FactionDef = state.game_def.faction(faction_id)
	if fdef == null or fdef.operations.is_empty():
		return {"action": "pass", "trace": ["fazione senza operazioni → pass"]}

	var ops := ABBOperations.new(state, module)
	var plan: Array = _priority_plan(faction_id)
	trace.append("piano (%d step)" % plan.size())

	for step in plan:
		var op_id: String = String(step["op"])
		var target: Variant = step.get("target")
		var result: Dictionary = _execute(ops, faction_id, op_id, target)
		trace.append("%s @ %s → %s" % [op_id, target, "OK" if result.get("ok", false) else result.get("error", "?")])
		if result.get("ok", false):
			return {"action": op_id, "result": result, "trace": trace, "target": target}

	return {"action": "pass", "trace": trace}


## Event choice — il bot non gioca eventi nel scaffold.
## TODO: leggere indicazione `Ineffective Event` (8.1.5) dalla carta corrente.
func event_choice(_faction_id: String, _card_number: int) -> Dictionary:
	return {"play_event": false, "side": "unshaded", "trace": ["scaffold: niente eventi"]}


# ---------------------------------------------------------------------------
# Priorità per fazione
# ---------------------------------------------------------------------------

func _priority_plan(faction_id: String) -> Array:
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


## Piano Reds (PAC2 §Reds): Attack → Terror → Rally → March.
func _plan_reds() -> Array:
	var plan: Array = []
	# 1) Attack dove ho ≥2 cellule e ci sono nemici
	for sid in _spaces_with_my_cells("reds", 2):
		if _has_any_enemy(sid, "reds"):
			plan.append({"op": "attack", "target": sid})
	# 2) Terror dove ho cellula e Support attivo nemico
	for sid in _spaces_with_my_cells("reds", 1):
		var st: SpaceState = state.space_state(sid)
		if st.support > CoinEnums.Support.NEUTRAL:
			plan.append({"op": "terror", "target": sid})
	# 3) Rally in città/province dove non controllo
	for sid in _spaces_uncontrolled_by("reds"):
		plan.append({"op": "rally", "target": sid})
	# 4) March da uno spazio amico verso uno spazio nemico adiacente
	plan += _march_plan("reds")
	return plan


## Piano Senate: Attack su Reds → Rally in città a controllo Senate → Terror (Patrol).
func _plan_senate() -> Array:
	var plan: Array = []
	for sid in _spaces_with_my_cells("senate", 2):
		if _has_any_enemy(sid, "senate"):
			plan.append({"op": "attack", "target": sid})
	for sid in _city_ids():
		var st: SpaceState = state.space_state(sid)
		if st.control == "senate":
			plan.append({"op": "rally", "target": sid})
	for sid in _spaces_with_my_cells("senate", 1):
		var st: SpaceState = state.space_state(sid)
		if st.support < CoinEnums.Support.PASSIVE_SUPPORT:
			plan.append({"op": "terror", "target": sid})
	plan += _march_plan("senate")
	return plan


## Piano Moderates: Rally (verso Pop alto), poi Message/Activism quando supportato.
func _plan_moderates() -> Array:
	var plan: Array = []
	# 1) Rally in spazi con Pop alto e senza nostra Cellula
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
	# 2) Activism (se disponibile) per spostare il Supporto verso Neutral
	for sid in _spaces_with_my_cells("moderates", 1):
		plan.append({"op": "activism", "target": sid})
	return plan


## Piano Germans (Phase II): Attack su Reds, March per posizionarsi.
func _plan_germans() -> Array:
	var plan: Array = []
	for sid in state.spaces.keys():
		var st: SpaceState = state.space_state(sid)
		if st.count("germans", "troops") > 0 and st.count("reds", "cell") > 0:
			plan.append({"op": "attack", "target": sid})
	plan += _march_plan("germans")
	return plan


# ---------------------------------------------------------------------------
# Helpers di selezione spazi
# ---------------------------------------------------------------------------

func _execute(ops: ABBOperations, fid: String, op_id: String, target: Variant) -> Dictionary:
	match op_id:
		"rally":
			return ops.rally(fid, String(target), "cell")
		"terror":
			return ops.terror(fid, String(target))
		"attack":
			return ops.attack(fid, String(target))
		"march":
			# `target` è {"from": sid, "to": sid}
			if typeof(target) != TYPE_DICTIONARY:
				return {"ok": false, "error": "march senza target"}
			return ops.march(fid, String(target["from"]), String(target["to"]), "cell", 1)
		"activism":
			# Per ora trattata come Terror tipico Moderates: TODO Operazione vera
			return ops.terror(fid, String(target))
		"message":
			return {"ok": false, "error": "message TODO"}
		_:
			return {"ok": false, "error": "op sconosciuta: " + op_id}


func _spaces_with_my_cells(fid: String, min_count: int) -> Array:
	var out: Array = []
	for sid in state.spaces.keys():
		if state.space_state(sid).count(fid, "cell") >= min_count:
			out.append(sid)
	return out


func _spaces_uncontrolled_by(fid: String) -> Array:
	var out: Array = []
	for sid in state.spaces.keys():
		var ctrl: String = state.space_state(sid).control
		if ctrl != fid:
			out.append(sid)
	return out


func _city_ids() -> Array:
	var out: Array = []
	for sid in state.spaces.keys():
		var sd: SpaceDef = state.game_def.space(sid)
		if sd != null and sd.type == CoinEnums.SpaceType.CITY:
			out.append(sid)
	return out


func _has_any_enemy(sid: String, fid: String) -> bool:
	var st: SpaceState = state.space_state(sid)
	for f in state.game_def.factions:
		if f.id == fid:
			continue
		for pt in ["cell", "troops", "admin", "network"]:
			if st.count(f.id, pt) > 0:
				return true
	return false


func _march_plan(fid: String) -> Array:
	var plan: Array = []
	for from_sid in state.spaces.keys():
		var st: SpaceState = state.space_state(from_sid)
		if st.count(fid, "cell") <= 0:
			continue
		var sd: SpaceDef = state.game_def.space(from_sid)
		for to_sid in sd.adjacent:
			if _has_any_enemy(String(to_sid), fid):
				plan.append({"op": "march", "target": {"from": from_sid, "to": String(to_sid)}})
				break
	return plan
