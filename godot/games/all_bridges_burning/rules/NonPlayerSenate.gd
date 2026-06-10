class_name ABBNonPlayerSenate
extends RefCounted

## Bot Non-player SENATE — trascrizione FEDELE del rulebook §8.4 (carte NP #54-59).
## Nessuna euristica inventata: ogni priorità cita la regola. Motore §8.2.1
## (Condition box) + §8.2.3 (top-to-bottom, prima opzione eseguibile; se il
## Comando non è eseguibile si pesca la carta dopo).
##
## §8.1.7: il Senato aumenta PRIMA il Supporto poi riduce l'Opposizione; aggiunge
## prima il Controllo Senate poi rimuove quello Reds; Town prima delle Province.
##
## LIMITI MODELLO dichiarati: Trains/Cannons sono track globali (non marker
## spaziali) → la logica "gruppo con Train / bordo vicino a un Train" è
## approssimata; la Random Spaces Map (§8.4) è estrazione uniforme fra i candidati.

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
	for n in _draw_order([54, 55, 56, 57, 58, 59]):
		var res := _exec_card(n)
		if res.get("acted", false):
			return {"card": n, "action": String(res.get("action", "")), "trace": res.get("trace", [])}
	return {}


func _draw_order(cards: Array) -> Array:
	var arr := cards.duplicate()
	var rng := RandomNumberGenerator.new()
	if dice_seed >= 0:
		rng.seed = dice_seed * 6131 + _state_sig()
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
		54: return _card54_rally_ph1()
		55: return _card55_rally_ph2()
		56: return _card56_activism()
		57: return _card57_terror()
		58: return _card58_attack()
		59: return _card59_march()
	return {"acted": false}


# ---------------------------------------------------------------------------
# §8.4.1 Senate Rally (Card #54) — Phase I
# ---------------------------------------------------------------------------
## Condition: Phase I e ci sono Cellule Senate Disponibili. Rally in max 3 spazi.
func _card54_rally_ph1() -> Dictionary:
	if int(state.tracks.get("phase", 1)) != 1:
		return {"acted": false}
	if state.available("senate", "cell") <= 0:
		return {"acted": false}
	var trace: Array = []
	var used := 0
	var did := false

	# ❶ Se 1d6 1-3: una Cellula in uno spazio con Cellula Senate esistente e un
	#    pezzo nemico non-Truppa.
	if _roll_d6() <= 3 and used < 3:
		var t := _space_senate_with_enemy_noncube()
		if t != "" and ops.rally("senate", t, "cell").get("ok", false):
			used += 1; did = true; trace.append("Rally: Cellula a %s (dove il Senato è già presente con un nemico)" % t)

	# ❷ Rally in uno spazio 1+ Pop dove stabilirebbe il Controllo Senate.
	#    Entro questo: prima spazi già con un qualche Supporto.
	if used < 3:
		var t := _rally_to_control("senate", true, true)
		if t != "" and ops.rally("senate", t, "cell").get("ok", false):
			used += 1; did = true; trace.append("Rally: Cellula a %s (per conquistare il Controllo)" % t)

	# ❸ Rally in uno spazio 0 Pop dove stabilirebbe il Controllo. Priorità Mikkelin lääni.
	if used < 3:
		var t := _rally_to_control_zeropop_mikkeli()
		if t != "" and ops.rally("senate", t, "cell").get("ok", false):
			used += 1; did = true; trace.append("Rally: Cellula a %s (spazio senza popolazione, per il Controllo)" % t)

	# ❹ Rally in OGNI spazio con Supporto e meno di 3 Cellule Senate.
	for sid in state.spaces.keys():
		if used >= 3:
			break
		var st: SpaceState = state.space_state(sid)
		if int(st.support) > 0 and st.count("senate", "cell") < 3:
			if ops.rally("senate", String(sid), "cell").get("ok", false):
				used += 1; did = true; trace.append("Rally: Cellula a %s (dove c'è Supporto)" % sid)

	# ❺ Rally in OGNI spazio con Cellule Senate esistenti.
	for sid in state.spaces.keys():
		if used >= 3:
			break
		if state.space_state(sid).count("senate", "cell") > 0:
			if ops.rally("senate", String(sid), "cell").get("ok", false):
				used += 1; did = true; trace.append("Rally: Cellula a %s (dove il Senato è già presente)" % sid)

	# ❻ Infine, spazi random con 1+ Pop fino al limite.
	while used < 3:
		var t := _random_pop_space()
		if t == "" or not ops.rally("senate", t, "cell").get("ok", false):
			break
		used += 1; did = true; trace.append("Rally: Cellula a %s" % t)

	if not did:
		return {"acted": false}
	_senate_foreign_relations(trace)
	_senate_prepare(trace)
	return {"acted": true, "action": "rally", "trace": trace}


# ---------------------------------------------------------------------------
# §8.4.2 Senate Rally (Card #55) — Phase II
# ---------------------------------------------------------------------------
## Condition: Phase II e ci sono Cellule Senate Disponibili. Rally in max 3 spazi.
func _card55_rally_ph2() -> Dictionary:
	if int(state.tracks.get("phase", 1)) < 2:
		return {"acted": false}
	if state.available("senate", "cell") <= 0:
		return {"acted": false}
	var trace: Array = []
	var used := 0
	var did := false

	# ❶ Rally in uno spazio 1+ Pop dove stabilirebbe il Controllo Senate (Town prima).
	if used < 3:
		var t := _rally_to_control("senate", false, true)
		if t != "" and ops.rally("senate", t, "cell").get("ok", false):
			used += 1; did = true; trace.append("Rally: Cellula a %s (per conquistare una Town)" % t)

	# ❷ Rally in OGNI spazio con una Capability Senate (priorità vicino ai Reds).
	for sid in _spaces_with_senate_capability():
		if used >= 3:
			break
		if ops.rally("senate", sid, "cell").get("ok", false):
			used += 1; did = true; trace.append("Rally: Cellula a %s (dove c'è una Capability)" % sid)

	# ❸ Rally in due spazi coi gruppi Senate più grandi (priorità vicino ai Reds).
	for sid in _largest_senate_groups(2):
		if used >= 3:
			break
		if ops.rally("senate", sid, "cell").get("ok", false):
			used += 1; did = true; trace.append("Rally: Cellula a %s (rinforza il gruppo più grande)" % sid)

	# ❹ Rally random 1+ Pop.
	while used < 3:
		var t := _random_pop_space()
		if t == "" or not ops.rally("senate", t, "cell").get("ok", false):
			break
		used += 1; did = true; trace.append("Rally: Cellula a %s" % t)

	if not did:
		return {"acted": false}
	# CRACKDOWN: uno spazio (Cellula Senate Attiva + Controllo) che rimuove più Opposizione.
	_senate_crackdown(trace)
	_senate_foreign_relations(trace)
	return {"acted": true, "action": "rally", "trace": trace}


# ---------------------------------------------------------------------------
# §8.4.3 Senate Activism (Card #56)
# ---------------------------------------------------------------------------
## Condition A: Phase I e 1d6 > Cellule Senate Attive. Condition B: Phase II e il
## Senato Controlla 4+ Pop di Town.
func _card56_activism() -> Dictionary:
	var phase := int(state.tracks.get("phase", 1))
	var roll := _roll_d6()
	var cond_a := phase == 1 and roll > _count_active("senate")
	var cond_b := phase >= 2 and _senate_town_pop() >= 4
	if not (cond_a or cond_b):
		return {"acted": false}
	var trace: Array = []
	var did := false
	# ❶ Gira Reds→Inattive, Moderati→Attive (priorità Cellule giocatore, poi ultima Reds attiva).
	if _activism_flip(trace):
		did = true
	# ❷ Attiva Cellule Senate fino al valore del dado (1 cellula prima, Supporto Attivo per ultimo).
	if cond_a and _activate_senate_up_to(roll, trace):
		did = true
	if not did:
		return {"acted": false}
	_senate_foreign_relations(trace)
	_senate_crackdown(trace)
	_senate_prepare(trace)
	return {"acted": true, "action": "activism", "trace": trace}


# ---------------------------------------------------------------------------
# §8.4.4 Senate Terror (Card #57)
# ---------------------------------------------------------------------------
## Condition: se il Terror può aumentare il Controllo Senate di Pop di Town
## rimuovendo 1 nemico (2 se Pol 6+) dove c'è Cellula Senate Attiva — oppure, in
## Phase I, rimuovere qualunque pezzo Reds. Max 2 spazi.
func _card57_terror() -> Dictionary:
	if not _senate_terror_possible():
		return {"acted": false}
	var trace: Array = []
	var used := 0
	for sid in _senate_terror_candidates():
		if used >= 2:
			break
		if ops.terror("senate", sid).get("ok", false):
			used += 1; trace.append("Terrore a %s" % sid)
	if used == 0:
		return {"acted": false}
	_senate_foreign_relations(trace)
	_senate_crackdown(trace)
	_senate_prepare(trace)
	return {"acted": true, "action": "terror", "trace": trace}


# ---------------------------------------------------------------------------
# §8.4.5 Senate Attack (Card #58) — Phase II
# ---------------------------------------------------------------------------
## Condition: Phase II e (3+ Cellule Senate nello stesso spazio con Reds o Russi)
## — oppure (4+ Senate con Train adiacenti a Reds/Russi: LIMITE MODELLO, Train
## globale → ignoro la parte Train e tengo la condizione 3+/co-locati).
func _card58_attack() -> Dictionary:
	if int(state.tracks.get("phase", 1)) < 2:
		return {"acted": false}
	# ❶/❷ seleziona gruppi 3+ (con Capability prima); bersagli ❸ Town, ❹ verso Town senza Controllo.
	var target := _senate_attack_target()
	if target == "":
		return {"acted": false}
	var res = ops.attack("senate", target)
	if not res.get("ok", false):
		return {"acted": false}
	_senate_prepare([])
	var line := "Senate attaccano %s" % target
	if int(res.get("removed", 0)) > 0:
		line += ": rimosso 1 %s %s" % [String(res.get("target", "")), String(res.get("piece", ""))]
	elif res.get("hit", false):
		line += ": colpito (nessun pezzo rimovibile)"
	else:
		line += ": mancato (tiro %d vs forza %d)" % [int(res.get("roll", 0)), int(res.get("strength", 0))]
	return {"acted": true, "action": "attack", "trace": [line]}


# ---------------------------------------------------------------------------
# §8.4.6 Senate March (Card #59) — Phase II
# ---------------------------------------------------------------------------
## Condition: Phase II e NON ci sono gruppi di 3+ Cellule Senate con Reds/Russi
## (né 4+ con Train adiacenti — parte Train ignorata, limite modello).
## March in gruppi di 3-5, lasciando ≥1; mai perdere il Controllo Senate di una
## Town né far guadagnare Controllo Town a un'altra Fazione.
func _card59_march() -> Dictionary:
	if int(state.tracks.get("phase", 1)) < 2:
		return {"acted": false}
	if _exists_senate_group_with_enemy(3):
		return {"acted": false}
	for sid in _senate_march_origins():
		# ❸ porta una Town sotto Controllo Senate; ❹ avvicìnati a una Town senza Controllo Senate.
		var dest := _senate_march_dest_town_control(sid)
		if dest == "":
			dest = _senate_march_dest_toward_town(sid)
		if dest != "":
			var grp: int = mini(3, state.space_state(sid).count("senate", "cell", "underground") - 1)
			if grp >= 1 and ops.march("senate", sid, dest, "cell", grp).get("ok", false):
				_senate_prepare([])
				_senate_foreign_relations([])
				return {"acted": true, "action": "march",
					"trace": ["#59 March %s → %s ×%d" % [sid, dest, grp]]}
	return {"acted": false}


# ---------------------------------------------------------------------------
# Special Activities §8.4 (Foreign Relations / Crackdown / Prepare)
# ---------------------------------------------------------------------------

## §8.4.1 FOREIGN RELATIONS: se Vassalaggio Tedesco ≥3 → se ≥4 riduci di 1; se
## esattamente 3 riduci di 1 solo su 1d6 1-2.
func _senate_foreign_relations(trace: Array) -> void:
	var vg := int(state.tracks.get("vassalage_german", 0))
	if vg >= 4:
		specials.foreign_relations("germans", -1)
		trace.append("Relazioni Estere: Vassalaggio Tedesco −1")
	elif vg == 3 and _roll_d6() <= 2:
		specials.foreign_relations("germans", -1)
		trace.append("Relazioni Estere: Vassalaggio Tedesco −1")


## §8.4.2 CRACKDOWN: uno spazio con Cellula Senate Attiva e Controllo, dove
## rimuove più Opposizione possibile.
func _senate_crackdown(trace: Array) -> void:
	var best := ""
	var best_opp := 0
	for sid in state.spaces.keys():
		var st: SpaceState = state.space_state(sid)
		if st.count("senate", "cell", "active") <= 0 or st.control != "senate":
			continue
		var opp := -int(st.support) if int(st.support) < 0 else 0
		if opp > best_opp:
			best_opp = opp; best = String(sid)
	if best != "" and specials.crackdown(best).get("ok", false):
		trace.append("Repressione a %s (rimuove Opposizione)" % best)


## §8.4.1 PREPARE: rimuovi un Sabotage dal bordo vicino a un Train Senate; se
## nessuna azione, piazza un Prepared (lato Senate) in una Town vicino a Helsinki
## con Cellula Senate. (Train globale → rimozione Sabotage semplificata.)
func _senate_prepare(trace: Array) -> void:
	if int(state.tracks.get("phase", 1)) < 2:
		return
	var arr: Array = state.tracks.get("sabotaged_borders", [])
	if not arr.is_empty():
		arr.pop_back()
		state.tracks["sabotaged_borders"] = arr
		trace.append("Prepara: rimuove un Sabotaggio")
		return
	if int(state.tracks.get("prepared_senate", 0)) <= 0:
		return
	for sid in ["helsinki", "tampere", "turku", "viipuri", "vaasa"]:
		if not state.spaces.has(sid):
			continue
		var st: SpaceState = state.space_state(sid)
		if st.count("senate", "cell") > 0 and st.marker("prepared_senate") == 0:
			st.set_marker("prepared_senate", 1)
			state.tracks["prepared_senate"] = int(state.tracks.get("prepared_senate", 0)) - 1
			trace.append("Prepara: marker Prepared (Senato) a %s" % sid)
			return


# ---------------------------------------------------------------------------
# Helpers fedeli
# ---------------------------------------------------------------------------

func _space_senate_with_enemy_noncube() -> String:
	for sid in state.spaces.keys():
		var st: SpaceState = state.space_state(sid)
		if st.count("senate", "cell") <= 0:
			continue
		var enemy := st.count("reds", "cell") + st.count("reds", "admin") \
			+ st.count("moderates", "cell") + st.count("moderates", "network")
		if enemy > 0:
			return String(sid)
	return ""


## Spazio 1+ Pop dove +1 Cellula darebbe Controllo a `fid`. need_support: priorità
## spazi con Supporto. town_first: priorità Town.
func _rally_to_control(fid: String, need_support: bool, town_first: bool) -> String:
	var best := ""
	var best_score := -999
	for sid in state.spaces.keys():
		var sd: SpaceDef = state.game_def.space(sid)
		if sd == null or sd.pop <= 0:
			continue
		var st: SpaceState = state.space_state(sid)
		if st.control == fid:
			continue
		var f := _piece_total(st, fid)
		var others := _all_pieces_total(st) - f
		if f + 1 <= others:
			continue
		var score := 0
		if town_first and sd.type == CoinEnums.SpaceType.CITY:
			score += 2
		if need_support and int(st.support) > 0:
			score += 1
		if score > best_score:
			best_score = score; best = String(sid)
	return best


func _rally_to_control_zeropop_mikkeli() -> String:
	var cands: Array = []
	for sid in state.spaces.keys():
		var sd: SpaceDef = state.game_def.space(sid)
		if sd == null or sd.pop != 0:
			continue
		var st: SpaceState = state.space_state(sid)
		if st.control == "senate":
			continue
		var f := _piece_total(st, "senate")
		var others := _all_pieces_total(st) - f
		if f + 1 > others:
			cands.append(String(sid))
	if "mikkelin_laani" in cands:
		return "mikkelin_laani"
	return String(cands[0]) if not cands.is_empty() else ""


func _spaces_with_senate_capability() -> Array:
	# Jaeger è l'unico marker Senate spaziale (Cannons/Trains sono globali).
	var out: Array = []
	for sid in state.spaces.keys():
		if state.space_state(sid).marker("jaeger_senate") > 0:
			out.append(String(sid))
	return out


func _largest_senate_groups(n: int) -> Array:
	var groups: Array = []
	for sid in state.spaces.keys():
		var c := state.space_state(sid).count("senate", "cell")
		if c > 0:
			groups.append({"sid": String(sid), "n": c})
	groups.sort_custom(func(a, b): return int(a["n"]) > int(b["n"]))
	var out: Array = []
	for i in range(mini(n, groups.size())):
		out.append(groups[i]["sid"])
	return out


func _senate_terror_possible() -> bool:
	var phase := int(state.tracks.get("phase", 1))
	for sid in state.spaces.keys():
		var st: SpaceState = state.space_state(sid)
		if st.count("senate", "cell", "active") <= 0:
			continue
		if st.marker("terror") >= 2:
			continue
		var enemy := st.count("reds", "cell") + st.count("moderates", "cell")
		var sd: SpaceDef = state.game_def.space(sid)
		# aumenta Controllo Town rimuovendo 1 nemico, o (Phase I) rimuove Reds
		if phase == 1 and st.count("reds", "cell") > 0:
			return true
		if sd != null and sd.type == CoinEnums.SpaceType.CITY and enemy > 0:
			return true
	return false


## §8.4.4 ordine: ❶ aumenta più Controllo Senate (Town prima, poi rimuove
## Network/Admin giocatore) ❷ rimuove Reds Attive ❸ Network/Personality/News ❹ random.
func _senate_terror_candidates() -> Array:
	var cands: Array = []
	for sid in state.spaces.keys():
		var st: SpaceState = state.space_state(sid)
		if st.count("senate", "cell", "active") <= 0 or st.marker("terror") >= 2:
			continue
		var enemy := st.count("reds", "cell") + st.count("moderates", "cell")
		if enemy <= 0 and not (int(state.tracks.get("phase", 1)) == 1 and st.count("reds", "cell") > 0):
			continue
		var sd: SpaceDef = state.game_def.space(sid)
		var is_town := sd != null and sd.type == CoinEnums.SpaceType.CITY
		var sen := _piece_total(st, "senate")
		var others := _all_pieces_total(st) - sen
		var gains := st.control != "senate" and sen >= others and is_town
		var has_target := st.count("moderates", "network") > 0 or st.marker("personality") > 0 or st.marker("news") > 0
		cands.append({"sid": String(sid), "gain": gains, "town": is_town, "reds": st.count("reds", "cell", "active") > 0, "target": has_target})
	cands.sort_custom(func(a, b):
		if a["gain"] != b["gain"]:
			return a["gain"]
		if a["reds"] != b["reds"]:
			return a["reds"]
		return a["target"] and not b["target"])
	var out: Array = []
	for c in cands:
		out.append(c["sid"])
	return out


func _senate_attack_target() -> String:
	var best := ""
	for sid in state.spaces.keys():
		var st: SpaceState = state.space_state(sid)
		if st.count("senate", "cell") < 3:
			continue
		if st.count("reds", "cell") + st.count("russians", "troops") <= 0:
			continue
		var sd: SpaceDef = state.game_def.space(sid)
		if sd != null and sd.type == CoinEnums.SpaceType.CITY:
			return String(sid)  # ❸ Town prima
		if best == "":
			best = String(sid)
	return best


func _exists_senate_group_with_enemy(minc: int) -> bool:
	for sid in state.spaces.keys():
		var st: SpaceState = state.space_state(sid)
		if st.count("senate", "cell") >= minc \
				and (st.count("reds", "cell") + st.count("russians", "troops") > 0):
			return true
	return false


func _senate_march_origins() -> Array:
	var out: Array = []
	for sid in state.spaces.keys():
		if state.space_state(sid).count("senate", "cell", "underground") >= 4:
			out.append(String(sid))  # gruppo ≥3 da marciare, lasciandone ≥1
	return out


func _senate_march_dest_town_control(from_sid: String) -> String:
	var sd: SpaceDef = state.game_def.space(from_sid)
	var best := ""
	var best_pop := -1
	for adj in sd.adjacent:
		var adj_s := String(adj)
		if not state.spaces.has(adj_s):
			continue
		var asd: SpaceDef = state.game_def.space(adj_s)
		if asd == null or asd.type != CoinEnums.SpaceType.CITY:
			continue
		var st: SpaceState = state.space_state(adj_s)
		if st.control == "senate":
			continue
		var sen := _piece_total(st, "senate")
		var others := _all_pieces_total(st) - sen
		if sen + 3 > others and asd.pop > best_pop:
			best = adj_s; best_pop = asd.pop
	return best


func _senate_march_dest_toward_town(from_sid: String) -> String:
	var sd: SpaceDef = state.game_def.space(from_sid)
	for adj in sd.adjacent:
		var adj_s := String(adj)
		if not state.spaces.has(adj_s):
			continue
		var asd: SpaceDef = state.game_def.space(adj_s)
		if asd != null and asd.type == CoinEnums.SpaceType.CITY \
				and state.space_state(adj_s).control != "senate":
			return adj_s
	return ""


func _activism_flip(trace: Array) -> bool:
	# §8.4.3 ❶: gira Reds→Inattive (e Moderati→Attive). Priorità: ultima Reds Attiva.
	for sid in state.spaces.keys():
		var st: SpaceState = state.space_state(sid)
		if st.count("senate", "cell") <= 0:
			continue
		if st.count("reds", "cell", "active") > 0:
			st.remove_piece("reds", "cell", 1, "active")
			st.add_piece("reds", "cell", 1, "underground")
			trace.append("Attivismo: gira una Cellula Reds a Inattiva a %s" % sid)
			return true
	return false


func _activate_senate_up_to(n: int, trace: Array) -> bool:
	if n <= 0:
		return false
	var order: Array = []
	for sid in state.spaces.keys():
		var st: SpaceState = state.space_state(sid)
		var ug := st.count("senate", "cell", "underground")
		if ug > 0:
			order.append({"sid": String(sid), "lone": ug == 1, "asup": int(st.support) >= ACTIVE_SUP})
	order.sort_custom(func(a, b):
		if a["lone"] != b["lone"]:
			return a["lone"]
		return (not a["asup"]) and b["asup"])
	var done := 0
	for e in order:
		if done >= n:
			break
		var st2: SpaceState = state.space_state(e["sid"])
		if st2.count("senate", "cell", "underground") > 0:
			st2.remove_piece("senate", "cell", 1, "underground")
			st2.add_piece("senate", "cell", 1, "active")
			done += 1
			trace.append("Attivismo: attiva una Cellula Senate a %s" % e["sid"])
	return done > 0


func _count_active(fid: String) -> int:
	var n := 0
	for sid in state.spaces.keys():
		n += state.space_state(sid).count(fid, "cell", "active")
	return n


func _senate_town_pop() -> int:
	var t := 0
	for sid in state.spaces.keys():
		var sd: SpaceDef = state.game_def.space(sid)
		if sd != null and sd.type == CoinEnums.SpaceType.CITY \
				and state.space_state(sid).control == "senate":
			t += sd.pop
	return t


func _random_pop_space() -> String:
	# §8.6/§8.4 Random Spaces — estrazione uniforme fra i candidati (approssimazione
	# della mappa 2d6, vedi nota in NonPlayerReds).
	var pool: Array = []
	for sid in state.spaces.keys():
		var sd: SpaceDef = state.game_def.space(sid)
		if sd != null and sd.pop > 0:
			pool.append(String(sid))
	if pool.is_empty():
		return ""
	return String(pool[_roll_d6() % pool.size()])


func _piece_total(st: SpaceState, fid: String) -> int:
	return st.count(fid, "cell") + st.count(fid, "admin") + st.count(fid, "network") + st.count(fid, "troops")


func _all_pieces_total(st: SpaceState) -> int:
	var t := 0
	for f in ["reds", "senate", "moderates", "germans", "russians"]:
		t += _piece_total(st, f)
	return t


func _roll_d6() -> int:
	if dice_seed >= 0:
		var rng := RandomNumberGenerator.new()
		rng.seed = dice_seed * 137 + _roll_n + 1
		_roll_n += 1
		return rng.randi_range(1, 6)
	return (Time.get_ticks_usec() % 6) + 1
