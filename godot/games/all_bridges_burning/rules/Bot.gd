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
			trace.append("Carta NP #%d" % int(r2.get("card", 0)))
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


## Cache decisione capability per coerenza fra le due chiamate per turno
## (_ev_crit_eff + ramo Evento in GameController).
var _event_decision_cache: Dictionary = {}


## §8.1: è "Critical" (la tabella Eligibility preferisce l'Evento) quando la carta
## è una Capability che giova a fid. L'effettivo gioco è poi deciso in
## event_choice() col tiro §8.1.5.
func is_event_critical(faction_id: String, card_number: int) -> bool:
	# Red Revolt! (#24): i Reds la giocano per attivare la Phase II (§3.4 / 2.4),
	# che sblocca March/Attack e la guerra civile. Senza, la partita resta in
	# Phase I per sempre (Germani inattivi, niente combattimenti).
	if card_number == 24 and faction_id == "reds":
		return int(state.tracks.get("phase", 1)) < 2
	if _capability_side_for(faction_id, card_number) != "":
		return true
	return _event_play_decision(faction_id, card_number).get("play", false)


## Ritorna {"play": bool, "side": "unshaded"|"shaded", "trace": []}.
## GameController legge la chiave "play". Per ora il bot gioca SOLO le Capability
## che gli competono, seguendo §8.1.5; gli altri Eventi li lascia (ripiega su Op).
func event_choice(faction_id: String, card_number: int) -> Dictionary:
	# Red Revolt! (#24): i Reds la giocano (unshaded) per far partire la Phase II.
	if card_number == 24 and faction_id == "reds" and int(state.tracks.get("phase", 1)) < 2:
		return {"play": true, "play_event": true, "side": "unshaded",
			"trace": ["Red Revolt! → attiva Phase II"]}
	# §8.1.4 Event Instructions (Solitaire Play Aid pag. 2): eventi con una
	# condizione NP chiara di "Play if ...". Gli altri eventi NON si giocano: il
	# bot ripiega su Comando (Select Cmd+SA) — comportamento di default.
	var ei := _event_play_decision(faction_id, card_number)
	if ei.get("play", false):
		return {"play": true, "play_event": true, "side": String(ei.get("side", "unshaded")),
			"trace": ["§8.1.4 Event Instructions #%d → gioca (%s)" % [card_number, ei.get("side", "unshaded")]]}
	var side := _capability_side_for(faction_id, card_number)
	if side == "":
		return {"play": false, "play_event": false, "side": "unshaded",
			"trace": ["nessun Evento conveniente per %s su #%d" % [faction_id, card_number]]}
	# §8.1.4: il Senato gioca SEMPRE i Treni (#15/#17), senza tiro §8.1.5.
	if faction_id == "senate" and (card_number == 15 or card_number == 17):
		return {"play": true, "play_event": true, "side": side,
			"trace": ["§8.1.4: Senato gioca sempre i Treni (#%d)" % card_number]}
	var key := "%d:%s" % [card_number, faction_id]
	if not _event_decision_cache.has(key):
		_event_decision_cache[key] = _roll_capability(faction_id)
	if _event_decision_cache[key]:
		return {"play": true, "play_event": true, "side": side,
			"trace": ["§8.1.5: gioca Capability #%d lato %s" % [card_number, side]]}
	return {"play": false, "play_event": false, "side": "unshaded",
		"trace": ["§8.1.5: NON gioca la Capability #%d (troppe già possedute)" % card_number]}


## §8.1.4 Event Instructions — decisione NP di giocare un Evento, per gli eventi
## con condizione di stato CHIARA e verificabile. Ritorna {"play":bool,"side":...}.
## Gli eventi marcati "Play per X card, otherwise Cmd(+SA)" o "Play if able to ..."
## (che richiedono valutare l'effetto dell'evento) NON sono qui: il bot ripiega su
## Comando (default conservativo, mai gioca un Evento a sproposito).
func _event_play_decision(fid: String, card_number: int) -> Dictionary:
	var pol := int(state.tracks.get("polarization", 0))
	var vg := int(state.tracks.get("vassalage_german", 0))
	var res_m := int(state.get_resources("moderates"))
	var last_campaign := int(state.tracks.get("campaign_count", 0)) >= 3
	var no_play := {"play": false, "side": "unshaded"}
	match card_number:
		18:  # Mobilization in the Periphery — Senate: gioca solo in Phase I.
			if fid == "senate" and int(state.tracks.get("phase", 1)) == 1:
				return {"play": true, "side": "unshaded"}
		19:  # Political Struggle — Moderates: unshaded se 5-6 cubi nel PD, altrimenti shaded.
			if fid == "moderates":
				return {"play": true, "side": ("unshaded" if _pd_cube_total() >= 5 else "shaded")}
		28:  # Hennala — Moderates: gioca se Risorse Moderati 10-14.
			if fid == "moderates" and res_m >= 10 and res_m <= 14:
				return {"play": true, "side": "unshaded"}
		29:  # War with Many Names — Moderates: gioca se Polarization 6+.
			if fid == "moderates" and pol >= 6:
				return {"play": true, "side": "unshaded"}
		32:  # Armistice Proposal — Moderates: se Polarization 6+.
			if fid == "moderates" and pol >= 6:
				return {"play": true, "side": "unshaded"}
		36:  # Prisoners of War — Moderates: Cellule in prigione, Risorse <15, Pol 6 o 7.
			if fid == "moderates" and _prison_total() > 0 and res_m < 15 and (pol == 6 or pol == 7):
				return {"play": true, "side": "unshaded"}
		38:  # Tanner Abroad — Moderates: Risorse 15+ oppure Polarization 5+.
			if fid == "moderates" and (res_m >= 15 or pol >= 5):
				return {"play": true, "side": "unshaded"}
		44:  # Mannerheim's Victory Parade — Senate: Vassalaggio Tedesco 4+, o =3 e 1d6 5-6.
			if fid == "senate":
				if vg >= 4:
					return {"play": true, "side": "unshaded"}
				if vg == 3 and _roll_capability_die() >= 5:
					return {"play": true, "side": "unshaded"}
		45:  # Fate in the Balance — Senate: ultima Campaign, oppure Vassalaggio Tedesco 4+.
			if fid == "senate" and (last_campaign or vg >= 4):
				return {"play": true, "side": "unshaded"}
	return no_play


func _pd_cube_total() -> int:
	var pd: Dictionary = state.tracks.get("political_display", {"senate": 0, "reds": 0})
	return int(pd.get("senate", 0)) + int(pd.get("reds", 0))


func _prison_total() -> int:
	var p: Dictionary = state.tracks.get("prisoners", {"senate": 0, "reds": 0})
	return int(p.get("senate", 0)) + int(p.get("reds", 0))


func _roll_capability_die() -> int:
	var rng := RandomNumberGenerator.new()
	if _pac2_dice_seed >= 0:
		rng.seed = _pac2_dice_seed * 211 + 7
	else:
		rng.randomize()
	return rng.randi_range(1, 6)


## Pubblico: la carta è una Capability che giova a fid? (per §8.1.4 pass-to-play).
func capability_benefits(faction_id: String, card_number: int) -> bool:
	return _capability_side_for(faction_id, card_number) != ""


## Lato che fid deve giocare per ottenere la propria Capability, "" se nessuna.
## #14 Cannons / #15,#17 Trains / #16 Jaeger(unshaded→Senate) o Commander(shaded→Reds).
func _capability_side_for(fid: String, card_number: int) -> String:
	match card_number:
		14, 15, 17:
			return "unshaded" if fid == "senate" else ""
		16:
			if fid == "senate":
				return "unshaded"
			if fid == "reds":
				return "shaded"
	return ""


## §8.1.5: tira 1d6; se < 2×(Capability già possedute) [Reds +2] NON gioca.
func _roll_capability(fid: String) -> bool:
	var caps := _np_cap_count(fid)
	var threshold := 2 * caps + (2 if fid == "reds" else 0)
	var rng := RandomNumberGenerator.new()
	if _pac2_dice_seed >= 0:
		rng.seed = _pac2_dice_seed * 31 + caps
	else:
		rng.randomize()
	return rng.randi_range(1, 6) >= threshold


## Numero di Capability già possedute dalla fazione Non-player (§8.1.5).
func _np_cap_count(fid: String) -> int:
	var n := 0
	if fid == "senate":
		if int(state.tracks.get("cannons", 0)) > 0:
			n += 1
		if int(state.tracks.get("trains", 0)) > 0:
			n += 1
		n += int(state.tracks.get("pending_jaeger_senate", 0))
		for sid in state.spaces.keys():
			if state.space_state(sid).marker("jaeger_senate") > 0:
				n += 1
	elif fid == "reds":
		n += int(state.tracks.get("pending_commander_reds", 0))
		for sid in state.spaces.keys():
			if state.space_state(sid).marker("commander_reds") > 0:
				n += 1
	return n


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
	# Fallback minimale: questo planner viene chiamato SOLO se nessuna carta
	# PAC2 ha matchato (raro). Le vere priorità sono in pac2_deck.json + BotPAC2.
	var plan: Array = []
	var ph2 := int(state.tracks.get("phase", 1)) >= 2
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
	# Fallback minimale (vedi _plan_reds).
	var plan: Array = []
	var ph2 := int(state.tracks.get("phase", 1)) >= 2
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
	# Fallback minimale (vedi _plan_reds).
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
				if state.count_marker_on_map("news") < 2:
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
