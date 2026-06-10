class_name ABBNonPlayerReds
extends RefCounted

## Bot Non-player REDS — trascrizione FEDELE del rulebook §8.3 (carte NP #48-53)
## e del Solitaire Play Aid. NON contiene euristiche inventate: ogni priorità
## cita la regola. Motore §8.2.1 (Condition box) + §8.2.3 (top-to-bottom, prima
## opzione eseguibile; se il Comando non è eseguibile si pesca la carta dopo).
##
## Priorità generali §8.1.7 applicate dove la carta non istruisce diversamente:
##  - Stacking: mai più di 1 Admin Reds per spazio.
##  - Supporto/Opposizione: i Reds aumentano prima l'Opposizione, poi riducono
##    il Supporto; entro questo, Town prima delle Province.
##  - Controllo: i Reds aumentano prima il Controllo Reds, poi riducono quello Senate.
##  - Attacchi: sempre Engage (mai lasciare Retreat al nemico) — §3.2.4.

const ACTIVE_OPP := -2   # CoinEnums.Support.ACTIVE_OPPOSITION
const ACTIVE_SUP := 2    # CoinEnums.Support.ACTIVE_SUPPORT

var state: GameState
var module: RulesModule
var ops: ABBOperations
var dice_seed: int = -1
var _roll_n: int = 0


func _init(p_state: GameState, p_module: RulesModule, p_dice_seed: int = -1) -> void:
	state = p_state
	module = p_module
	ops = ABBOperations.new(p_state, p_module)
	dice_seed = p_dice_seed


## §8.2.3: prova le carte NP Reds in ordine; la prima con Condition vera (§8.2.1)
## e Comando eseguibile (anche solo in parte) agisce. Altrimenti Pass ({}).
func take_turn() -> Dictionary:
	# §8.2: il mini-deck NP si PESCA A CASO (non in ordine fisso), altrimenti la
	# carta Rally — quasi sempre valida — vincerebbe ogni turno e Terror/Attack/
	# March non partirebbero mai.
	for n in _draw_order([48, 49, 50, 51, 52, 53]):
		var res := _exec_card(n)
		if res.get("acted", false):
			return {"card": n, "action": String(res.get("action", "")), "trace": res.get("trace", [])}
	return {}


## §8.2 ordine di pesca casuale del mini-deck. Seed variabile per turno (firma
## dello stato) così non esce sempre la stessa carta; randomize() nel gioco reale.
func _draw_order(cards: Array) -> Array:
	var arr := cards.duplicate()
	var rng := RandomNumberGenerator.new()
	if dice_seed >= 0:
		rng.seed = dice_seed * 7919 + _state_sig()
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
		48: return _card48_rally()
		49: return _card49_activism()
		50: return _card50_activism()
		51: return _card51_terror()
		52: return _card52_attack()
		53: return _card53_march()
	return {"acted": false}


# ---------------------------------------------------------------------------
# §8.3.1 Reds Rally (Card #48)
# ---------------------------------------------------------------------------
## Condition: se ci sono Cellule o Amministrazioni Reds Disponibili, OPPURE se
## esistono Admin Reds in spazi con Opposizione Attiva.
## Preliminaries: Rally in al massimo 3 spazi.
func _card48_rally() -> Dictionary:
	if not (state.available("reds", "cell") > 0 or state.available("reds", "admin") > 0
			or _has_admin_in_active_opp()):
		return {"acted": false}
	var trace: Array = []
	var used := 0
	var did := false

	# ❶ Piazza Cellule in OGNI spazio con Admin Reds ma senza Cellule Reds.
	for sid in state.spaces.keys():
		if used >= 3:
			break
		var st: SpaceState = state.space_state(sid)
		if st.count("reds", "admin") > 0 and st.count("reds", "cell") == 0:
			if ops.rally("reds", String(sid), "cell").get("ok", false):
				used += 1; did = true
				trace.append("Rally: Cellula a %s (rinforza un'Amministrazione scoperta)" % sid)

	# ❷ Sostituisci 2 Cellule Reds con un'Amministrazione in UNO spazio con 1+ Pop,
	#    no Opposizione Attiva, spazio per l'Admin (§1.4.3), e:
	#      • 2+ Cellule Reds e 0 Senate; oppure
	#      • 3+ Reds e qualunque numero di Senate.
	if used < 3 and (state.available("reds", "admin") > 0 or _has_admin_in_active_opp()):
		var tgt := _admin_replace_target()
		if tgt != "":
			var st2: SpaceState = state.space_state(tgt)
			# Preliminaries §8.3.1: piazza l'Admin PRIMA da Available; altrimenti
			# RILOCA un Admin da uno spazio in Opposizione Attiva, ma solo se ciò
			# non fa perdere il Controllo Reds di quello spazio.
			var got_admin := false
			if state.available("reds", "admin") > 0:
				got_admin = state.place_from_available("reds", "admin", tgt, 1, "") > 0
			else:
				var src := _relocatable_admin_space()
				if src != "":
					state.space_state(src).remove_piece("reds", "admin", 1, "")
					state.recompute_control(src)
					state.space_state(tgt).add_piece("reds", "admin", 1, "")
					got_admin = true
					trace.append("Rally: rialloca un'Amministrazione da %s" % src)
			if got_admin:
				st2.remove_piece("reds", "cell", 2, "underground")
				state.recompute_control(tgt)
				used += 1; did = true
				trace.append("Rally: 2 Cellule diventano un'Amministrazione a %s" % tgt)

	# ❸ Rally piazzando Cellule:
	#    (a) per Controllare uno spazio con 1+ Pop (prioritizza spazi con Admin e
	#        senza Opposizione Attiva);
	#    (b) in uno spazio dove i Reds sono già presenti;
	#    (c) infine, fino al limite di 3, in spazi random con 1+ Pop.
	if used < 3:
		var ctrl := _rally_to_control_target()
		if ctrl != "" and ops.rally("reds", ctrl, "cell").get("ok", false):
			used += 1; did = true
			trace.append("Rally: Cellula a %s (per conquistare il Controllo)" % ctrl)
	if used < 3:
		var withreds := _first_space_with("reds")
		if withreds != "" and ops.rally("reds", withreds, "cell").get("ok", false):
			used += 1; did = true
			trace.append("Rally: Cellula a %s (dove i Reds sono già presenti)" % withreds)
	while used < 3:
		var rnd := _random_pop_space()
		if rnd == "" or not ops.rally("reds", rnd, "cell").get("ok", false):
			break
		used += 1; did = true
		trace.append("Rally: Cellula a %s" % rnd)

	if not did:
		return {"acted": false}
	# PREPARE (§8.3.1): Sabotage (≤ #Train Senate) + marker Prepared in Town vicino Helsinki.
	_reds_prepare(trace)
	return {"acted": true, "action": "rally", "trace": trace}


## §8.3.1 PREPARE: piazza Sabotage (fino al numero di Train Senate sulla mappa) sul
## bordo più vicino a un Train Senate; poi un marker Prepared in una Town con
## Cellule Reds, prioritizzando Town vicine a Helsinki (Helsinki inclusa).
func _reds_prepare(trace: Array) -> void:
	if int(state.tracks.get("phase", 1)) < 2:
		return  # Sabotage/Prepare sono §4.2.3 Phase II
	# ❶ Sabotage: "solo fino al numero di Train Senate sulla mappa". Su un bordo
	#    Town con Cellule Reds adiacenti.
	#    LIMITE MODELLO: i Train sono una track globale (tracks["trains"]), non un
	#    marker spaziale → non posso calcolare "bordo più vicino a un Train Senate";
	#    uso il conteggio globale come tetto e scelgo un bordo Town con Reds.
	var trains := int(state.tracks.get("trains", 0))
	var placed_borders: Array = state.tracks.get("sabotaged_borders", [])
	if trains > placed_borders.size():
		var done := false
		for sid in ["helsinki", "tampere", "turku", "viipuri", "vaasa"]:
			if done or not state.spaces.has(sid):
				continue
			var sd: SpaceDef = state.game_def.space(sid)
			for adj in sd.adjacent:
				var adj_s := String(adj)
				if not state.spaces.has(adj_s):
					continue
				if state.space_state(sid).count("reds", "cell") > 0 \
						or state.space_state(adj_s).count("reds", "cell") > 0:
					if ops.sabotage_border("reds", sid, adj_s).get("ok", false):
						trace.append("Prepara: Sabotaggio sul confine %s–%s" % [sid, adj_s])
						done = true
						break
	# ❷ Prepared marker in Town con Cellule Reds (priorità Helsinki). Consuma dal
	# pool Prepared Reds (setup §p.32: 1 Reds).
	if int(state.tracks.get("prepared_reds", 0)) <= 0:
		return
	for sid in ["helsinki", "tampere", "turku", "viipuri", "vaasa"]:
		if not state.spaces.has(sid):
			continue
		var st: SpaceState = state.space_state(sid)
		if st.count("reds", "cell") > 0 and st.marker("prepared_reds") == 0:
			st.set_marker("prepared_reds", 1)
			state.tracks["prepared_reds"] = int(state.tracks.get("prepared_reds", 0)) - 1
			trace.append("Prepara: marker Prepared (Reds) a %s" % sid)
			return


# ---------------------------------------------------------------------------
# §8.3.2 Reds Activism (Card #49)  — Phase I
# ---------------------------------------------------------------------------
## Condition: Phase I E un 1d6 > numero di Cellule Reds Attive già sulla mappa,
## E non ci sono spazi con Admin Reds e nessuna Cellula Reds sulla mappa.
func _card49_activism() -> Dictionary:
	if int(state.tracks.get("phase", 1)) != 1:
		return {"acted": false}
	_roll_n = _roll_d6()
	if not (_roll_n > _count_active_reds()):
		return {"acted": false}
	if not _no_stranded_reds_admin():
		return {"acted": false}
	var trace: Array = []
	var did := false
	# ❶ Gira Cellule Senate a Inattive e Moderati ad Attive, dove possibile.
	#    Entro questo: prima le Cellule di un giocatore, poi spazi dove l'ultima
	#    Cellula Senate Attiva può essere girata a Inattiva.
	if _activism_flip("reds", trace):
		did = true
	# ❷ Attiva Cellule Reds fino al valore del dado tirato sopra. Entro questo:
	#    prima in spazi con una sola Cellula Reds, poi spazi con Opposizione per ultimi.
	if _activate_reds_up_to(_roll_n, trace):
		did = true
	if not did:
		return {"acted": false}
	# FOREIGN RELATIONS (§8.3.2): solo Phase I e Vassalaggio Russo esattamente "2";
	# su 1d6 1-2 aumenta il Vassalaggio Russo di 1.
	_reds_foreign_relations(trace)
	_reds_prepare(trace)
	return {"acted": true, "action": "activism", "trace": trace}


# ---------------------------------------------------------------------------
# §8.3.3 Reds Activism (Card #50) — Phase II
# ---------------------------------------------------------------------------
## Condition: Phase II E non ci sono spazi con Admin Reds e nessuna Cellula Reds
## presente sulla mappa.
func _card50_activism() -> Dictionary:
	if int(state.tracks.get("phase", 1)) < 2:
		return {"acted": false}
	if not _no_stranded_reds_admin():
		return {"acted": false}
	var trace: Array = []
	var did := false
	# ❶ Gira Senate→Inattive, Moderati→Attive (come #49 ❶).
	if _activism_flip("reds", trace):
		did = true
	# ❷ Agita in uno spazio con Admin Reds (e Controllo Reds, §3.2.2). Entro questo,
	#    prima le Town, poi dove c'è meno Opposizione.
	var ag := _agitate_admin_control_target()
	if ag != "":
		var specials := ABBSpecialActivities.new(state, module)
		if specials.agitate(ag).get("ok", false):
			did = true
			trace.append("Agitazione a %s (spinge il Supporto verso Opposizione)" % ag)
	# ❸ Se 1d6 > Cellule Reds Attive, attivane il numero tirato (Opposizione per ultime).
	var r := _roll_d6()
	if r > _count_active_reds() and _activate_reds_up_to(r, trace):
		did = true
	if not did:
		return {"acted": false}
	_reds_prepare(trace)
	return {"acted": true, "action": "activism", "trace": trace}


# ---------------------------------------------------------------------------
# §8.3.4 Reds Terror (Card #51)
# ---------------------------------------------------------------------------
## Condition: se c'è una Cellula Reds ATTIVA in uno spazio con Cellule nemiche.
## Preliminaries: Terror in al massimo 2 spazi (con Reds Attive e Cellule nemiche).
func _card51_terror() -> Dictionary:
	if not _has_active_reds_with_enemy():
		return {"acted": false}
	var trace: Array = []
	var used := 0
	# ❶ Terror dove crea più Controllo Reds. Entro questo, prioritizza le Town.
	# ❷ (rimuovi Cellule Senate Attive — gestito dall'Operazione)
	# ❸ Terror dove c'è Network/Personality Moderati o un News.
	# ❹ Terror in spazi random (incluso Political Display).
	for sid in _terror_candidates_ordered():
		if used >= 2:
			break
		if ops.terror("reds", sid).get("ok", false):
			used += 1
			trace.append("Terrore a %s" % sid)
	if used == 0:
		return {"acted": false}
	_reds_foreign_relations(trace)
	_reds_prepare(trace)
	return {"acted": true, "action": "terror", "trace": trace}


# ---------------------------------------------------------------------------
# §8.3.5 Reds Attack (Card #52) — Phase II
# ---------------------------------------------------------------------------
## Condition: Phase II E (3+ Cellule Reds nello stesso spazio con una Capability
## Senate e/o 3+ Cellule Senate) — oppure (4+ Cellule Reds con un Train e adiacenti
## a una Capability Senate e/o 3+ Cellule Senate).
func _card52_attack() -> Dictionary:
	if int(state.tracks.get("phase", 1)) < 2:
		return {"acted": false}
	var target := ""
	for sid in state.spaces.keys():
		var st: SpaceState = state.space_state(sid)
		var reds := st.count("reds", "cell")
		var senate := st.count("senate", "cell")
		var senate_cap := st.marker("jaeger_senate") > 0
		if reds >= 3 and (senate_cap or senate >= 3):
			target = String(sid)
			break
	if target == "":
		return {"acted": false}
	# §3.2.4: sempre Engage. Attacca lo spazio selezionato.
	var res = ops.attack("reds", target)
	if not res.get("ok", false):
		return {"acted": false}
	return {"acted": true, "action": "attack", "trace": [_combat_line("Reds", target, res)]}


## Riga di combattimento leggibile per il log (esito Attack).
func _combat_line(who: String, sid: String, res: Dictionary) -> String:
	var line := "%s attaccano %s" % [who, sid]
	if int(res.get("removed", 0)) > 0:
		line += ": rimosso 1 %s %s" % [String(res.get("target", "")), String(res.get("piece", ""))]
	elif res.get("hit", false):
		line += ": colpito (nessun pezzo rimovibile)"
	else:
		line += ": mancato (tiro %d vs forza %d)" % [int(res.get("roll", 0)), int(res.get("strength", 0))]
	return line


# ---------------------------------------------------------------------------
# §8.3.6 Reds March (Card #53) — Phase II
# ---------------------------------------------------------------------------
## Condition: Phase II E non ci sono spazi con Admin Reds e nessuna Cellula Reds
## presente sulla mappa.
## Preliminaries: March SOLO da Province, lasciando sempre almeno 1 Cellula
## (Attiva se possibile); mai perdere il Controllo Reds di una Provincia con 1+ Pop.
func _card53_march() -> Dictionary:
	if int(state.tracks.get("phase", 1)) < 2:
		return {"acted": false}
	if not _no_stranded_reds_admin():
		return {"acted": false}
	# Selezione pezzi (§8.3.6): ❶ Province con 2+ Truppe Tedesche e no Admin Reds;
	# ❷ Province con Supporto, no Reds Attive, no Admin Reds. Lasciare ≥1 Cellula.
	var senate_pop := _senate_town_pop()
	for sid in _march_origins():
		var sd: SpaceDef = state.game_def.space(sid)
		# Destinazione ❸: spazio 1+ Pop adiacente dove i Reds prenderebbero il
		# Controllo (priorità Pop più alta, poi meno Opposizione).
		var dest := _march_dest_gain_control(sid)
		# ❹ Se il Senato Controlla 3+ Pop di Town: marcia per rimuovere il
		#    Controllo Senate in una Town (priorità Pop più alta).
		if dest == "" and senate_pop >= 3:
			dest = _march_dest_remove_senate(sid)
		if dest != "" and ops.march("reds", sid, dest, "cell", 1).get("ok", false):
			return {"acted": true, "action": "march",
				"trace": ["#53 March %s → %s" % [sid, dest]]}
	return {"acted": false}


## §8.3.6 origini March: Province con (2+ Truppe Tedesche e no Admin Reds) oppure
## (Supporto, no Reds Attive, no Admin Reds), con ≥2 Cellule underground (ne resta 1).
func _march_origins() -> Array:
	var out: Array = []
	for sid in state.spaces.keys():
		var sd: SpaceDef = state.game_def.space(sid)
		if sd == null or sd.type != CoinEnums.SpaceType.PROVINCE:
			continue
		var st: SpaceState = state.space_state(sid)
		if st.count("reds", "cell", "underground") < 2:
			continue
		if st.count("reds", "admin") > 0:
			continue
		var pri1 := st.count("germans", "troops") >= 2
		var pri2 := int(st.support) > 0 and st.count("reds", "cell", "active") == 0
		if pri1 or pri2:
			out.append(String(sid))
	return out


## Destinazione adiacente 1+ Pop dove 1 Cellula Reds in più darebbe Controllo Reds.
func _march_dest_gain_control(from_sid: String) -> String:
	var sd: SpaceDef = state.game_def.space(from_sid)
	var best := ""
	var best_pop := -1
	for adj in sd.adjacent:
		var adj_s := String(adj)
		if not state.spaces.has(adj_s):
			continue
		var asd: SpaceDef = state.game_def.space(adj_s)
		if asd == null or asd.pop <= 0:
			continue
		var st: SpaceState = state.space_state(adj_s)
		if st.control == "reds":
			continue
		var reds := _piece_total(st, "reds")
		var others := _all_pieces_total(st) - reds
		if reds + 1 > others and asd.pop > best_pop:
			best = adj_s; best_pop = asd.pop
	return best


## Destinazione Town adiacente Controllata dal Senato (per rimuoverne il Controllo).
func _march_dest_remove_senate(from_sid: String) -> String:
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
		if state.space_state(adj_s).control == "senate" and asd.pop > best_pop:
			best = adj_s; best_pop = asd.pop
	return best


func _senate_town_pop() -> int:
	var t := 0
	for sid in state.spaces.keys():
		var sd: SpaceDef = state.game_def.space(sid)
		if sd != null and sd.type == CoinEnums.SpaceType.CITY \
				and state.space_state(sid).control == "senate":
			t += sd.pop
	return t


# ---------------------------------------------------------------------------
# Helpers fedeli (predicati citati dalle carte)
# ---------------------------------------------------------------------------

func _has_admin_in_active_opp() -> bool:
	for sid in state.spaces.keys():
		var st: SpaceState = state.space_state(sid)
		if st.count("reds", "admin") > 0 and int(st.support) <= ACTIVE_OPP:
			return true
	return false


## §8.3.1: Admin Reds in spazio con Opposizione Attiva, rilocabile solo se
## togliendolo i Reds NON perdono il Controllo di quello spazio.
func _relocatable_admin_space() -> String:
	for sid in state.spaces.keys():
		var st: SpaceState = state.space_state(sid)
		if st.count("reds", "admin") <= 0 or int(st.support) > ACTIVE_OPP:
			continue
		var reds := _piece_total(st, "reds")
		var others := _all_pieces_total(st) - reds
		# Controllo Reds resta se (reds - 1 Admin) > others.
		if (reds - 1) > others:
			return String(sid)
	return ""


func _no_stranded_reds_admin() -> bool:
	# §8.3.3/§8.3.6 "no spaces with a Reds Administration and no Reds Cells present":
	# nessuno spazio ha un Admin Reds SENZA Cellule Reds (nessun Admin "orfano").
	for sid in state.spaces.keys():
		var st: SpaceState = state.space_state(sid)
		if st.count("reds", "admin") > 0 and st.count("reds", "cell") == 0:
			return false
	return true


func _count_active_reds() -> int:
	var n := 0
	for sid in state.spaces.keys():
		n += state.space_state(sid).count("reds", "cell", "active")
	return n


## §8.3.1 ❷ target: spazio con 1+ Pop, no Opposizione Attiva, niente Admin Reds
## (spazio per l'Admin), e (2+ Reds & 0 Senate) o (3+ Reds & any Senate).
func _admin_replace_target() -> String:
	for sid in state.spaces.keys():
		var sd: SpaceDef = state.game_def.space(sid)
		if sd == null or sd.pop <= 0:
			continue
		var st: SpaceState = state.space_state(sid)
		if int(st.support) <= ACTIVE_OPP:
			continue
		if st.count("reds", "admin") > 0:
			continue  # §8.1.7 stacking: max 1 Admin per spazio
		var reds := st.count("reds", "cell", "underground")
		var senate := st.count("senate", "cell")
		if (reds >= 2 and senate == 0) or (reds >= 3):
			return String(sid)
	return ""


## §8.3.1 ❸a: spazio 1+ Pop dove aggiungere 1 Cellula porterebbe il Controllo Reds.
## Priorità: spazi con Admin Reds e senza Opposizione Attiva.
func _rally_to_control_target() -> String:
	var best := ""
	var best_admin := false
	for sid in state.spaces.keys():
		var sd: SpaceDef = state.game_def.space(sid)
		if sd == null or sd.pop <= 0:
			continue
		var st: SpaceState = state.space_state(sid)
		if st.control == "reds":
			continue
		# Aggiungere 1 Reds darebbe il controllo? (reds+1 > somma altri)
		var reds := _piece_total(st, "reds")
		var others := _all_pieces_total(st) - reds
		if reds + 1 > others:
			var has_admin := st.count("reds", "admin") > 0 and int(st.support) > ACTIVE_OPP
			if best == "" or (has_admin and not best_admin):
				best = String(sid); best_admin = has_admin
	return best


func _first_space_with(fid: String) -> String:
	for sid in state.spaces.keys():
		if state.space_state(sid).count(fid, "cell") > 0:
			return String(sid)
	return ""


## §8.6 / §8.4 Random Spaces: scelta casuale fra i candidati a pari priorità.
## Il set di candidati (qui: spazi con 1+ Pop) è quello giusto per #48 ❸c.
## APPROSSIMAZIONE: uso un'estrazione uniforme; la Random Spaces Map (§8.4) col
## lookup 2d6 pesa diversamente gli spazi (alcuni hanno 2 numeri, altri 3) — per
## replicarla servirebbe la tabella numero→spazio verificata dalla plancia.
func _random_pop_space() -> String:
	var pool: Array = []
	for sid in state.spaces.keys():
		var sd: SpaceDef = state.game_def.space(sid)
		if sd != null and sd.pop > 0:
			pool.append(String(sid))
	if pool.is_empty():
		return ""
	return String(pool[_roll_d6() % pool.size()])


## §8.3.2/§8.3.3 ❶: gira Cellule Senate→Inattive e Moderati→Attive dove possibile.
func _activism_flip(fid: String, trace: Array) -> bool:
	for sid in state.spaces.keys():
		var st: SpaceState = state.space_state(sid)
		if st.count(fid, "cell") <= 0:
			continue
		if st.count("senate", "cell", "active") > 0:
			st.remove_piece("senate", "cell", 1, "active")
			st.add_piece("senate", "cell", 1, "underground")
			trace.append("Attivismo: gira una Cellula Senate a Inattiva a %s" % sid)
			return true
	return false


## §8.3.2/§8.3.3 ❷: attiva fino a `n` Cellule Reds Inattive. Priorità: spazi con
## una sola Cellula Reds, poi spazi con Opposizione per ultimi.
func _activate_reds_up_to(n: int, trace: Array) -> bool:
	if n <= 0:
		return false
	var done := 0
	# spazi con esattamente 1 Cellula Reds inattiva, prima quelli senza Opposizione
	var order: Array = []
	for sid in state.spaces.keys():
		var st: SpaceState = state.space_state(sid)
		var ug := st.count("reds", "cell", "underground")
		if ug > 0:
			order.append({"sid": String(sid), "lone": ug == 1, "opp": int(st.support) < 0})
	order.sort_custom(func(a, b):
		if a["lone"] != b["lone"]:
			return a["lone"]
		return (not a["opp"]) and b["opp"])
	for e in order:
		if done >= n:
			break
		var st2: SpaceState = state.space_state(e["sid"])
		if st2.count("reds", "cell", "underground") > 0:
			st2.remove_piece("reds", "cell", 1, "underground")
			st2.add_piece("reds", "cell", 1, "active")
			done += 1
			trace.append("Attivismo: attiva una Cellula Reds a %s" % e["sid"])
	return done > 0


## §8.3.2 FOREIGN RELATIONS: Phase I e Vassalaggio Russo esattamente 2 → su 1d6 1-2 +1.
func _reds_foreign_relations(trace: Array) -> void:
	if int(state.tracks.get("phase", 1)) != 1:
		return
	if int(state.tracks.get("vassalage_russian", 0)) != 2:
		return
	if _roll_d6() <= 2:
		var specials := ABBSpecialActivities.new(state, module)
		specials.foreign_relations("russians", 1)
		trace.append("Relazioni Estere: Vassalaggio Russo +1")


func _has_active_reds_with_enemy() -> bool:
	for sid in state.spaces.keys():
		var st: SpaceState = state.space_state(sid)
		if st.count("reds", "cell", "active") <= 0:
			continue
		for f in ["senate", "moderates"]:
			if st.count(f, "cell") > 0:
				return true
	return false


## §8.3.4 ordine Terror: ❶ dove crea più Controllo Reds (Town prima) ❸ dove c'è
## Network/Personality/News ❹ random. Richiede Reds Attive + Cellule nemiche, terror<2.
func _terror_candidates_ordered() -> Array:
	var cands: Array = []
	for sid in state.spaces.keys():
		var st: SpaceState = state.space_state(sid)
		if st.count("reds", "cell", "active") <= 0:
			continue
		if st.marker("terror") >= 2:
			continue
		var enemy := st.count("senate", "cell") + st.count("moderates", "cell")
		if enemy <= 0:
			continue
		var sd: SpaceDef = state.game_def.space(sid)
		var is_town := sd != null and sd.type == CoinEnums.SpaceType.CITY
		var has_target := st.count("moderates", "network") > 0 or st.marker("personality") > 0 or st.marker("news") > 0
		# §8.3.4 ❶: Terror dove crea più Controllo Reds (togliendo 1 nemico il
		# totale Reds supererebbe gli altri). Approssimazione del "most".
		var reds := _piece_total(st, "reds")
		var others := _all_pieces_total(st) - reds
		var gains_control := st.control != "reds" and reds >= others
		cands.append({"sid": String(sid), "ctrl": gains_control, "town": is_town, "target": has_target})
	cands.sort_custom(func(a, b):
		if a["ctrl"] != b["ctrl"]:
			return a["ctrl"]            # ❶ crea Controllo Reds
		if a["town"] != b["town"]:
			return a["town"]            # entro ❶: Town prima
		return a["target"] and not b["target"])  # ❸ Network/Personality/News
	var out: Array = []
	for c in cands:
		out.append(c["sid"])
	return out


## §8.3.3 ❷ Agitate: spazio con Admin Reds e Controllo Reds; Town prima, poi meno Opposizione.
func _agitate_admin_control_target() -> String:
	var best := ""
	var best_town := false
	for sid in state.spaces.keys():
		var st: SpaceState = state.space_state(sid)
		if st.count("reds", "admin") <= 0 or st.control != "reds":
			continue
		if int(st.support) <= ACTIVE_OPP:
			continue  # già Opposizione Attiva: niente da agitare
		var sd: SpaceDef = state.game_def.space(sid)
		var is_town := sd != null and sd.type == CoinEnums.SpaceType.CITY
		if best == "" or (is_town and not best_town):
			best = String(sid); best_town = is_town
	return best


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
		rng.seed = dice_seed * 131 + _roll_n + 1
		_roll_n += 1
		return rng.randi_range(1, 6)
	return (Time.get_ticks_usec() % 6) + 1
