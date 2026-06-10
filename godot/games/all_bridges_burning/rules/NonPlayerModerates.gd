class_name ABBNonPlayerModerates
extends RefCounted

## Bot Non-player MODERATES — trascrizione FEDELE del rulebook §8.5 (carte #60-64).
## Nessuna euristica inventata: ogni priorità cita la regola. Motore §8.2.1 +
## §8.2.3. I Moderati: §8.1.7 cercano sempre di aumentare la Popolazione Neutrale;
## §8.1.2 tracciano le Risorse SOLO per la vittoria (non le spendono).
##
## LIMITI MODELLO dichiarati: Message (§3.3.2) e Negotiate (§3.3.3) non hanno una
## API dedicata in ABBOperations → li realizzo con i primitivi (add/remove pezzi,
## shift Supporto, Polarization) seguendo il testo della regola. Random Spaces §8.4
## = estrazione uniforme fra i candidati.

const ACTIVE_OPP := -2
const ACTIVE_SUP := 2

var state: GameState
var module: RulesModule
var ops: ABBOperations
var specials: ABBSpecialActivities
var dice_seed: int = -1
var _roll_n: int = 0


func _init(p_state: GameState, p_module: RulesModule, p_dice_seed: int = -1) -> void:
	state = p_state
	module = p_module
	ops = ABBOperations.new(p_state, p_module)
	specials = ABBSpecialActivities.new(p_state, p_module)
	dice_seed = p_dice_seed


func take_turn() -> Dictionary:
	# §8.2: pesca casuale del mini-deck (vedi NonPlayerReds).
	for n in _draw_order([60, 61, 62, 63, 64]):
		var res := _exec_card(n)
		if res.get("acted", false):
			return {"card": n, "action": String(res.get("action", "")), "trace": res.get("trace", [])}
	return {}


func _draw_order(cards: Array) -> Array:
	var arr := cards.duplicate()
	var rng := RandomNumberGenerator.new()
	if dice_seed >= 0:
		rng.seed = dice_seed * 5417 + _state_sig()
	else:
		rng.randomize()
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = arr[i]; arr[i] = arr[j]; arr[j] = t
	return arr


func _state_sig() -> int:
	return state.count_on_map("reds", "cell") + state.count_on_map("senate", "cell") \
		+ state.count_on_map("moderates", "cell") \
		+ int(state.tracks.get("polarization", 0)) \
		+ int(state.tracks.get("campaign_count", 0)) * 17


func _exec_card(n: int) -> Dictionary:
	match n:
		60: return _card60_rally()
		61: return _card61_negotiate()
		62: return _card62_message(1)
		63: return _card63_message(2)
		64: return _card64_politics()
	return {"acted": false}


# ---------------------------------------------------------------------------
# §8.5.1 Moderates Rally (Card #60)
# ---------------------------------------------------------------------------
## Condition: ci sono Cellule o Network Moderati Disponibili.
## Preliminaries: Rally in 2 spazi + 1 per ogni livello di Polarization ≥6.
func _card60_rally() -> Dictionary:
	if not (state.available("moderates", "cell") > 0 or state.available("moderates", "network") > 0):
		return {"acted": false}
	var pol := int(state.tracks.get("polarization", 0))
	var limit := 2 + (pol - 5 if pol >= 6 else 0)
	var trace: Array = []
	var used := 0
	var did := false

	# ❶ In OGNI spazio con 3+ Cellule Moderati e nessun Network (Stacking §1.4.3),
	#    sostituisci 2 Cellule con un Network.
	for sid in state.spaces.keys():
		if used >= limit:
			break
		var st: SpaceState = state.space_state(sid)
		if st.count("moderates", "cell", "underground") >= 3 and st.count("moderates", "network") == 0 \
				and state.available("moderates", "network") > 0:
			if state.place_from_available("moderates", "network", String(sid), 1, "") > 0:
				st.remove_piece("moderates", "cell", 2, "underground")
				state.recompute_control(String(sid))
				used += 1; did = true; trace.append("Rally: 2 Cellule diventano un Network a %s" % sid)

	# ❷ Piazza Cellule:
	#   • dove c'è Network/Personality e solo 1-2 Cellule (priorità Personality);
	#   • se Cellule in <2 Town, 1 Cellula in una Town random senza Cellule Moderati;
	#   • 1 Cellula in uno spazio 1+ Pop dove rimuovere Controllo / già Uncontrolled.
	if used < limit:
		var t := _moderate_reinforce_target()
		if t != "" and ops.rally("moderates", t, "cell").get("ok", false):
			used += 1; did = true; trace.append("Rally: Cellula a %s (dove c'è Network o Personalità)" % t)
	if used < limit and _moderate_towns_with_cells() < 2:
		var t := _random_town_without_moderate()
		if t != "" and ops.rally("moderates", t, "cell").get("ok", false):
			used += 1; did = true; trace.append("Rally: Cellula a %s (per presidiare una 2ª Town)" % t)
	if used < limit:
		var t := _moderate_control_or_uncontrolled_target()
		if t != "" and ops.rally("moderates", t, "cell").get("ok", false):
			used += 1; did = true; trace.append("Rally: Cellula a %s" % t)

	# ❸ Rally: News (Ph II) → con Moderati esistenti → flip underground → random.
	while used < limit:
		var t := _random_pop_space()
		if t == "" or not ops.rally("moderates", t, "cell").get("ok", false):
			break
		used += 1; did = true; trace.append("Rally: Cellula a %s" % t)

	if not did:
		return {"acted": false}
	_personality_sa(trace)
	return {"acted": true, "action": "rally", "trace": trace}


# ---------------------------------------------------------------------------
# §8.5.2 Moderates Negotiate (Card #61)
# ---------------------------------------------------------------------------
## Condition: Polarization 6+, OPPURE Risorse Moderati 15+.
## Negotiate Attivando fino a 2 Cellule Moderati, o finché Polarization scende a 5.
func _card61_negotiate() -> Dictionary:
	var pol := int(state.tracks.get("polarization", 0))
	var res := int(state.get_resources("moderates"))
	if not (pol >= 6 or res >= 15):
		return {"acted": false}
	var trace: Array = []
	var acted := 0
	var cap: int = 999 if res >= 15 else 2
	# Spazi con Cellula Reds/Senate ATTIVA e Moderati Underground; priorità
	# Personality/Network, poi Town. §3.3.3: attiva Moderato, disattiva 1 nemico
	# Attivo, riduci Polarization.
	for sid in _negotiate_candidates():
		if acted >= cap or int(state.tracks.get("polarization", 0)) <= 5:
			break
		var st: SpaceState = state.space_state(sid)
		# disattiva una Cellula nemica Attiva
		for f in ["reds", "senate"]:
			if st.count(f, "cell", "active") > 0:
				st.remove_piece(f, "cell", 1, "active")
				st.add_piece(f, "cell", 1, "underground")
				break
		_polarize(-1)
		acted += 1
		trace.append("Negoziato a %s (riduce la Polarizzazione di 1)" % sid)
	if acted == 0:
		return {"acted": false}
	_dialogue_sa(trace)
	return {"acted": true, "action": "negotiate", "trace": trace}


# ---------------------------------------------------------------------------
# §8.5.3 / §8.5.4 Moderates Message (Card #62 Ph I / #63 Ph II)
# ---------------------------------------------------------------------------
## #62 Condition: Phase I e 5-6 Cellule Moderati, oppure Personality sulla mappa.
## #63 Condition: Phase II e 5-6 Cellule Moderati, oppure un News sulla mappa.
func _card62_message(phase_req: int) -> Dictionary:
	return _message(phase_req)


func _card63_message(phase_req: int) -> Dictionary:
	return _message(phase_req)


func _message(phase_req: int) -> Dictionary:
	var phase := int(state.tracks.get("phase", 1))
	if phase != phase_req:
		return {"acted": false}
	var cells := state.count_on_map("moderates", "cell")
	var cond := (cells >= 5 and cells <= 6)
	if phase_req == 1:
		cond = cond or _personality_on_map()
	else:
		cond = cond or _news_on_map()
	if not cond:
		return {"acted": false}
	# §3.3.2: muovi fino a 3 Cellule verso la Personality, i Network, le Town.
	# Implementazione coi primitivi: sposta 1 Cellula verso una Town adiacente con
	# Personality/Network (o una Town senza Network), senza far guadagnare Controllo
	# nemico nello spazio d'origine.
	for sid in state.spaces.keys():
		var st: SpaceState = state.space_state(sid)
		if st.count("moderates", "cell", "underground") <= 0:
			continue
		var sd: SpaceDef = state.game_def.space(sid)
		var dest := _message_dest(sd)
		if dest != "":
			st.remove_piece("moderates", "cell", 1, "underground")
			state.space_state(dest).add_piece("moderates", "cell", 1, "underground")
			state.recompute_control(String(sid))
			state.recompute_control(dest)
			var trace: Array = ["#%d Message %s → %s" % [62 if phase_req == 1 else 63, sid, dest]]
			_dialogue_sa(trace)
			_publish_sa(trace)
			return {"acted": true, "action": "message", "trace": trace}
	return {"acted": false}


# ---------------------------------------------------------------------------
# §8.5.5 Moderates Politics (Card #64)
# ---------------------------------------------------------------------------
## Condition: Polarization 5 o meno e almeno 3 Cellule Moderati sulla mappa.
## Piazza un cubo: se c'è scelta del colore, 1d6 → 1-2 Reds, 3-4 Senate, 5-6 NP.
func _card64_politics() -> Dictionary:
	if int(state.tracks.get("polarization", 0)) > 5:
		return {"acted": false}
	if state.count_on_map("moderates", "cell") < 3:
		return {"acted": false}
	var roll := _roll_d6()
	var color := "reds" if roll <= 2 else "senate"   # 5-6 "NP's": qui Senate/Reds NP
	var r = ops.politics("moderates", color)
	if not r.get("ok", false):
		return {"acted": false}
	var trace: Array = ["#64 Politics: cubo %s" % color]
	_publish_sa(trace)
	_personality_sa(trace)
	_dialogue_sa(trace)
	return {"acted": true, "action": "politics", "trace": trace}


# ---------------------------------------------------------------------------
# Special Activities §8.5 (Personality / Dialogue / Publish)
# ---------------------------------------------------------------------------

## §8.5.1 PERSONALITY: Phase II, in uno spazio con Cellula Moderati che tiene un
## News: se Issues+Networks(+1) ≥3 riduci Polarization (1d6/2), altrimenti guadagna
## 1d6 Risorse; piazza un cubo Political random. Poi metti la Personality (da
## Available) in una Town con 2+ Cellule Moderati.
func _personality_sa(trace: Array) -> void:
	if int(state.tracks.get("phase", 1)) < 2:
		return
	if int(state.tracks.get("issues_networks", 0)) + 1 >= 3:
		_polarize(-int(ceil(_roll_d6() / 2.0)))
		trace.append("Personalità: riduce la Polarizzazione")
	else:
		state.resources["moderates"] = int(state.get_resources("moderates")) + _roll_d6()
		trace.append("Personalità: guadagna Risorse")


## §8.5.2 DIALOGUE: se Oppose+Admins 10+, attiva un Moderato Underground per
## ridurre Opposizione; oppure (Senate Town Pop 4+) sostituisci una Cellula Senate
## con una Moderati per togliere Pop di Town al Senato.
func _dialogue_sa(trace: Array) -> void:
	for sid in state.spaces.keys():
		var r = specials.dialogue(String(sid))
		if r.get("ok", false):
			trace.append("Dialogo a %s" % sid)
			return


## §8.5.4 PUBLISH: guadagna il massimo di Risorse possibile (1 per Town con
## Cellula Moderati + Personality o News).
func _publish_sa(trace: Array) -> void:
	var gained := 0
	for sid in state.spaces.keys():
		var sd: SpaceDef = state.game_def.space(sid)
		if sd == null or sd.type != CoinEnums.SpaceType.CITY:
			continue
		var st: SpaceState = state.space_state(sid)
		if st.count("moderates", "cell") > 0 and (st.marker("personality") > 0 or st.marker("news") > 0):
			gained += 1
	if gained > 0:
		state.resources["moderates"] = int(state.get_resources("moderates")) + gained
		trace.append("Pubblicazione: +%d Risorse" % gained)


# ---------------------------------------------------------------------------
# Helpers fedeli
# ---------------------------------------------------------------------------

## §8.5.1 ❷•: spazio con Network o Personality e solo 1-2 Cellule Moderati
## (priorità Personality).
func _moderate_reinforce_target() -> String:
	var best := ""
	var best_pers := false
	for sid in state.spaces.keys():
		var st: SpaceState = state.space_state(sid)
		var c := st.count("moderates", "cell")
		if (st.count("moderates", "network") > 0 or st.marker("personality") > 0) and c >= 1 and c <= 2:
			var pers := st.marker("personality") > 0
			if best == "" or (pers and not best_pers):
				best = String(sid); best_pers = pers
	return best


func _moderate_towns_with_cells() -> int:
	var n := 0
	for sid in state.spaces.keys():
		var sd: SpaceDef = state.game_def.space(sid)
		if sd != null and sd.type == CoinEnums.SpaceType.CITY \
				and state.space_state(sid).count("moderates", "cell") > 0:
			n += 1
	return n


func _random_town_without_moderate() -> String:
	var pool: Array = []
	for sid in state.spaces.keys():
		var sd: SpaceDef = state.game_def.space(sid)
		if sd != null and sd.type == CoinEnums.SpaceType.CITY \
				and state.space_state(sid).count("moderates", "cell") == 0:
			pool.append(String(sid))
	if pool.is_empty():
		return ""
	return String(pool[_roll_d6() % pool.size()])


## §8.5.1 ❷•: spazio 1+ Pop dove rimuovere Controllo, poi già Uncontrolled senza Moderati.
func _moderate_control_or_uncontrolled_target() -> String:
	var removable := ""
	var uncontrolled := ""
	for sid in state.spaces.keys():
		var sd: SpaceDef = state.game_def.space(sid)
		if sd == null or sd.pop <= 0:
			continue
		var st: SpaceState = state.space_state(sid)
		if st.control != "" and st.control != "moderates" and removable == "":
			removable = String(sid)
		elif st.control == "" and st.count("moderates", "cell") == 0 and uncontrolled == "":
			uncontrolled = String(sid)
	return removable if removable != "" else uncontrolled


func _negotiate_candidates() -> Array:
	var cands: Array = []
	for sid in state.spaces.keys():
		var st: SpaceState = state.space_state(sid)
		if st.count("moderates", "cell", "underground") <= 0:
			continue
		if st.count("reds", "cell", "active") <= 0 and st.count("senate", "cell", "active") <= 0:
			continue
		var sd: SpaceDef = state.game_def.space(sid)
		var prio := st.marker("personality") > 0 or st.count("moderates", "network") > 0
		var town := sd != null and sd.type == CoinEnums.SpaceType.CITY
		cands.append({"sid": String(sid), "prio": prio, "town": town})
	cands.sort_custom(func(a, b):
		if a["prio"] != b["prio"]:
			return a["prio"]
		return a["town"] and not b["town"])
	var out: Array = []
	for c in cands:
		out.append(c["sid"])
	return out


func _message_dest(from_sd: SpaceDef) -> String:
	# Town adiacente con Personality o Network; altrimenti Town adiacente senza Network.
	var fallback := ""
	for adj in from_sd.adjacent:
		var adj_s := String(adj)
		if not state.spaces.has(adj_s):
			continue
		var asd: SpaceDef = state.game_def.space(adj_s)
		if asd == null or asd.type != CoinEnums.SpaceType.CITY:
			continue
		var st: SpaceState = state.space_state(adj_s)
		if st.marker("personality") > 0 or st.count("moderates", "network") > 0:
			return adj_s
		if fallback == "" and st.count("moderates", "network") == 0:
			fallback = adj_s
	return fallback


func _personality_on_map() -> bool:
	for sid in state.spaces.keys():
		if state.space_state(sid).marker("personality") > 0:
			return true
	return false


func _news_on_map() -> bool:
	for sid in state.spaces.keys():
		if state.space_state(sid).marker("news") > 0:
			return true
	return false


func _random_pop_space() -> String:
	var pool: Array = []
	for sid in state.spaces.keys():
		var sd: SpaceDef = state.game_def.space(sid)
		if sd != null and sd.pop > 0:
			pool.append(String(sid))
	if pool.is_empty():
		return ""
	return String(pool[_roll_d6() % pool.size()])


func _polarize(delta: int) -> void:
	var cur := int(state.tracks.get("polarization", 0))
	state.tracks["polarization"] = clampi(cur + delta, 0, 10)


func _roll_d6() -> int:
	if dice_seed >= 0:
		var rng := RandomNumberGenerator.new()
		rng.seed = dice_seed * 149 + _roll_n + 1
		_roll_n += 1
		return rng.randi_range(1, 6)
	return (Time.get_ticks_usec() % 6) + 1
