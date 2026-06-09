class_name ABBBotPAC2
extends RefCounted

## Solo Bot PAC2 — 17 carte (49-65) per Reds/Senate/Moderates dal
## ABB_CardEdits-download.pdf. Caricato da data/pac2_deck.json.
##
## Funzionamento:
##   1. take_turn(faction) itera il deck in ordine
##   2. Per ciascuna carta filtrata per faction, valuta la `condition`
##   3. La prima carta che match esegue le `actions` in sequenza
##   4. Se nessuna match (o tutte le actions falliscono), ritorna null per
##      lasciar fallback al priority planner di ABBBot
##
## L'evaluator delle condizioni e gli handler delle azioni sono volutamente
## minimali — la libreria cresce in PR incrementali.

const DECK_PATH := "res://games/all_bridges_burning/data/pac2_deck.json"

var state: GameState
var module: RulesModule
var _deck: Array = []
var _dice_seed: int = -1


func _init(p_state: GameState, p_module: RulesModule, p_dice_seed: int = -1) -> void:
	state = p_state
	module = p_module
	_dice_seed = p_dice_seed
	_load_deck()


func _load_deck() -> void:
	var f := FileAccess.open(DECK_PATH, FileAccess.READ)
	if f == null:
		push_warning("PAC2: deck non trovato a " + DECK_PATH)
		return
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		_deck = d.get("cards", [])


## Restituisce {"card": int, "action": String, "trace": Array} se ha agito, null altrimenti.
func take_turn(faction_id: String) -> Dictionary:
	var trace: Array[String] = []
	for entry in _deck:
		if String(entry.get("faction", "")) != faction_id:
			continue
		var card_num: int = int(entry.get("number", 0))
		var cond: String = String(entry.get("condition", ""))
		if not _eval_condition(cond, faction_id):
			trace.append("#%d skip: condizione falsa (%s)" % [card_num, cond])
			continue
		trace.append("#%d match: %s" % [card_num, cond])
		var ops := ABBOperations.new(state, module)
		var specials := ABBSpecialActivities.new(state, module)
		for act in entry.get("actions", []):
			var res := _exec_action(ops, specials, faction_id, act, trace)
			if res.get("ok", false):
				trace.append_array(res.get("log", []))
				return {"card": card_num, "action": String(act.get("op", "")), "trace": trace}
		trace.append("#%d: nessuna action eseguibile, prosegui" % card_num)
	return {}


# ---------------------------------------------------------------------------
# Condition evaluator (espressione minimale)
# ---------------------------------------------------------------------------

func _eval_condition(expr: String, fid: String) -> bool:
	var s := expr.strip_edges()
	if s == "" or s.to_lower() == "always":
		return true
	# Supporta OR sui rami top-level; AND ricorsivo dentro.
	for branch in s.split(" OR "):
		if _eval_and(String(branch).strip_edges(), fid):
			return true
	return false


func _eval_and(expr: String, fid: String) -> bool:
	for token in expr.split(" AND "):
		if not _eval_atom(String(token).strip_edges(), fid):
			return false
	return true


func _eval_atom(atom: String, fid: String) -> bool:
	# Espressioni supportate:
	#   phase == N / phase >= N
	#   d6 > active_<faction>_on_map
	#   no_admin_without_reds
	#   available_<faction>_cells > 0
	#   german_vassal >= N / russian_vassal >= N
	#   senate_town_pop >= N / oppose_plus_admins >= N
	#   polarization < N
	#   moderates_on_map >= N
	#   germans_on_map > 0
	#   personality_on_map
	#   last_campaign
	if atom == "":
		return true
	# phase
	var m := _match2(atom, "^phase\\s*(==|>=|<=|>|<)\\s*(\\d+)$")
	if not m.is_empty():
		return _cmp_int(int(state.tracks.get("phase", 1)), m[0], int(m[1]))
	# d6 > active_<faction>_on_map (deterministico: usa modulo seed)
	m = _match2(atom, "^d6\\s*>\\s*active_([a-z]+)_on_map$")
	if not m.is_empty():
		var d6: int = _roll_d6()
		return d6 > _count_active(String(m[0]))
	# no_admin_without_reds: tutti gli Admin Reds hanno almeno una Reds Cell?
	if atom == "no_admin_without_reds":
		for sid in state.spaces.keys():
			var st: SpaceState = state.space_state(sid)
			if st.count("reds", "admin") > 0 and st.count("reds", "cell") == 0:
				return true   # esiste un Admin senza Reds → condizione vera
		return false
	# available_<faction>_cells > 0
	m = _match2(atom, "^available_([a-z]+)_cells\\s*>\\s*(\\d+)$")
	if not m.is_empty():
		return state.available(String(m[0]), "cell") > int(m[1])
	# german_vassal / russian_vassal
	m = _match2(atom, "^german_vassal\\s*(==|>=|<=|>|<)\\s*(\\d+)$")
	if not m.is_empty():
		return _cmp_int(int(state.tracks.get("vassalage_german", 0)), m[0], int(m[1]))
	m = _match2(atom, "^russian_vassal\\s*(==|>=|<=|>|<)\\s*(\\d+)$")
	if not m.is_empty():
		return _cmp_int(int(state.tracks.get("vassalage_russian", 0)), m[0], int(m[1]))
	# senate_town_pop
	m = _match2(atom, "^senate_town_pop\\s*(==|>=|<=|>|<)\\s*(\\d+)$")
	if not m.is_empty():
		return _cmp_int(int(state.tracks.get("senate_town_pop", 0)), m[0], int(m[1]))
	m = _match2(atom, "^oppose_plus_admins\\s*(==|>=|<=|>|<)\\s*(\\d+)$")
	if not m.is_empty():
		return _cmp_int(int(state.tracks.get("oppose_admins", 0)), m[0], int(m[1]))
	m = _match2(atom, "^polarization\\s*(==|>=|<=|>|<)\\s*(\\d+)$")
	if not m.is_empty():
		return _cmp_int(int(state.tracks.get("polarization", 0)), m[0], int(m[1]))
	m = _match2(atom, "^moderates_on_map\\s*(==|>=|<=|>|<)\\s*(\\d+)$")
	if not m.is_empty():
		var cnt := state.count_on_map("moderates", "cell") + state.count_on_map("moderates", "network")
		return _cmp_int(cnt, m[0], int(m[1]))
	if atom == "germans_on_map > 0":
		return state.count_on_map("germans", "troops") > 0
	if atom == "personality_on_map":
		for sid in state.spaces.keys():
			if state.space_state(sid).marker("personality") > 0:
				return true
		return false
	if atom == "last_campaign":
		# Conteggio Crisis Round risolti (incrementato in ABBCrisis.resolve).
		# In ABB ci sono 4 Round di Propaganda: l'ultimo è il 4°.
		return int(state.tracks.get("campaign_count", 0)) >= 3
	# fallback: ignora atomi non riconosciuti (registra ma considera "vero" per
	# non bloccare le carte sui dettagli non implementati).
	return true


# Esegue una regex e ritorna le capture groups o [] se non match.
func _match2(s: String, pattern: String) -> Array:
	var re := RegEx.new()
	re.compile(pattern)
	var r := re.search(s)
	if r == null:
		return []
	var out: Array = []
	for i in range(1, r.get_group_count() + 1):
		out.append(r.get_string(i))
	return out


func _cmp_int(a: int, op: String, b: int) -> bool:
	match op:
		"==": return a == b
		">=": return a >= b
		"<=": return a <= b
		">":  return a > b
		"<":  return a < b
		_:    return false


func _count_active(faction_id: String) -> int:
	var cnt := 0
	for sid in state.spaces.keys():
		var st: SpaceState = state.space_state(sid)
		cnt += st.count(faction_id, "cell", "active")
	return cnt


func _roll_d6() -> int:
	# Deterministico per i test: usa il seed del modulo se fornito.
	if _dice_seed >= 0:
		var rng := RandomNumberGenerator.new()
		rng.seed = _dice_seed
		return rng.randi_range(1, 6)
	return 1 + int(Time.get_ticks_msec()) % 6


# ---------------------------------------------------------------------------
# Action dispatch — handler minimali; molti sono STUB con TODO.
# ---------------------------------------------------------------------------

func _exec_action(ops: ABBOperations, specials: ABBSpecialActivities,
		fid: String, act: Dictionary, trace: Array) -> Dictionary:
	var op_id := String(act.get("op", ""))
	match op_id:
		"foreign_relations":
			return _do_foreign_relations(specials, fid, act.get("params", {}))
		"rally":
			return _do_rally(ops, fid, act.get("params", {}))
		"march":
			return _do_march(ops, fid, act.get("params", {}))
		"attack":
			return _do_attack(ops, fid, act.get("params", {}))
		"terror":
			return _do_terror(ops, fid, act.get("params", {}))
		"crackdown":
			return _do_crackdown(specials, fid)
		"activism":
			return _do_activism(ops, fid)
		"prepare":
			return _do_prepare(fid)
		"dialogue":
			return _do_dialogue(specials, fid)
		"publish":
			return _do_publish(fid)
		"message":
			return _do_message(fid)
		_:
			trace.append("  %s: handler non riconosciuto (fall-through)" % op_id)
			return {"ok": false}


## §4.2.3 Prepare: piazza un marker Prepared in uno spazio con Cellula amica.
## In Phase II può anche piazzare/rimuovere Sabotage su un bordo (semplificato).
func _do_prepare(fid: String) -> Dictionary:
	if not (fid in ["reds", "senate"]):
		return {"ok": false}
	var marker_name := "prepared_" + fid
	for sid in state.spaces.keys():
		var st: SpaceState = state.space_state(sid)
		if st.count(fid, "cell") <= 0:
			continue
		if st.marker(marker_name) > 0:
			continue
		st.set_marker(marker_name, 1)
		return {"ok": true, "log": ["Prepared %s a %s" % [fid, sid]]}
	return {"ok": false}


## §3.3.3 / §4.3.2 Dialogue (Moderates): rimuove Opposition o gira nemico Inattivo.
## Implementazione: shift di un livello verso Neutral in primo spazio con
## Moderates Cell + supporto/opposizione non-Neutral.
func _do_dialogue(specials: ABBSpecialActivities, fid: String) -> Dictionary:
	if fid != "moderates":
		return {"ok": false}
	for sid in state.spaces.keys():
		var res = specials.dialogue(String(sid))
		if res.get("ok", false):
			return res
	return {"ok": false}


## §4.3.3 Publish (Moderates Personality SA): aggiunge Risorse in base a
## Cellule Moderati su Town con News marker o Personality.
func _do_publish(fid: String) -> Dictionary:
	if fid != "moderates":
		return {"ok": false}
	var gained := 0
	for sid in state.spaces.keys():
		var sd: SpaceDef = state.game_def.space(sid)
		if sd.type != CoinEnums.SpaceType.CITY:
			continue
		var st: SpaceState = state.space_state(sid)
		if st.count("moderates", "cell") <= 0:
			continue
		# 1 Risorsa per Town con Moderates Cell + Personality o News.
		if st.marker("personality") > 0 or st.marker("news") > 0:
			gained += 1
	if gained <= 0:
		return {"ok": false}
	state.resources["moderates"] = int(state.get_resources("moderates")) + gained
	return {"ok": true, "log": ["Publish: Moderates +%d Risorse" % gained]}


## §3.3.2 Message (Moderates Cmd): muove fino a 3 Cell amiche fra Town. Qui:
## sposta 1 Cell Moderates verso una Town adiacente senza Network.
func _do_message(fid: String) -> Dictionary:
	if fid != "moderates":
		return {"ok": false}
	for sid in state.spaces.keys():
		var st: SpaceState = state.space_state(sid)
		if st.count("moderates", "cell") <= 0:
			continue
		var sd: SpaceDef = state.game_def.space(sid)
		for adj_v in sd.adjacent:
			var adj := String(adj_v)
			var sd2: SpaceDef = state.game_def.space(adj)
			if sd2 == null or sd2.type != CoinEnums.SpaceType.CITY:
				continue
			var st2: SpaceState = state.space_state(adj)
			if st2.count("moderates", "network") > 0:
				continue
			st.remove_piece("moderates", "cell", 1, "underground")
			st2.add_piece("moderates", "cell", 1, "underground")
			state.recompute_control(sid)
			state.recompute_control(adj)
			return {"ok": true, "log": ["Message: Cell moderates %s → %s" % [sid, adj]]}
	return {"ok": false}


func _do_activism(ops: ABBOperations, fid: String) -> Dictionary:
	# Cerca uno spazio con Cellula amica + nemico Attivo da capovolgere.
	for sid in state.spaces.keys():
		var st: SpaceState = state.space_state(sid)
		if st.count(fid, "cell") <= 0:
			continue
		var res = ops.activism(fid, String(sid))
		if res.get("ok", false):
			return res
	return {"ok": false}


func _do_foreign_relations(specials: ABBSpecialActivities, fid: String, params: Dictionary) -> Dictionary:
	var target_faction := String(params.get("faction", "germans"))
	var delta := int(params.get("delta", 1))
	var key := "vassalage_" + ("german" if target_faction == "germans" else "russian")
	var current := int(state.tracks.get(key, 0))
	if params.has("if_vassal_ge"):
		if current < int(params["if_vassal_ge"]):
			return {"ok": false, "log": ["foreign_relations: vassalage %d < soglia %d" % [current, params["if_vassal_ge"]]]}
	if params.has("if_vassal_lt"):
		if current >= int(params["if_vassal_lt"]):
			return {"ok": false, "log": ["foreign_relations: vassalage %d ≥ soglia %d" % [current, params["if_vassal_lt"]]]}
	return specials.foreign_relations(target_faction, delta)


## Rally PAC2: itera le priority della carta in ordine. Per ciascuna, applica
## il filtro corrispondente e prova la prima rally riuscita. Onora "max_spaces"
## per limitare il numero di Rally consecutive.
func _do_rally(ops: ABBOperations, fid: String, params: Dictionary) -> Dictionary:
	var max_spaces: int = int(params.get("max_spaces", 1))
	var priority: Array = params.get("priority", [])
	if priority.is_empty():
		priority = ["random_with_pop"]   # fallback minimale, non greedy
	var placed: int = 0
	var log: Array[String] = []
	for prio in priority:
		if placed >= max_spaces:
			break
		var candidates: Array = _rally_filter(fid, String(prio))
		for sid in candidates:
			if placed >= max_spaces:
				break
			var res = ops.rally(fid, String(sid), "cell")
			if res.get("ok", false):
				placed += 1
				log.append("Rally %s @ %s (prio:%s)" % [fid, sid, prio])
	if placed > 0:
		return {"ok": true, "log": log}
	return {"ok": false}


## Filtri di priorità Rally PAC2 (rulebook §8.4.1, §8.4.2, §8.5.3).
## Ognuno restituisce la lista di spazi candidati ordinati per quel criterio.
func _rally_filter(fid: String, priority: String) -> Array:
	var out: Array = []
	match priority:
		# §8.4.1: Town con Senato presente + Supporto, dove Senate < 3
		"sup_with_senate_lt_3":
			for sid in state.spaces.keys():
				var st: SpaceState = state.space_state(sid)
				if st.support > 0 and st.count(fid, "cell") < 3:
					out.append(String(sid))
		"where_senate":
			for sid in state.spaces.keys():
				if state.space_state(sid).count("senate", "cell") > 0:
					out.append(String(sid))
		# §8.4.2: aggiungi Controllo in Town con Pop ≥ 1
		"control_at_pop_town":
			for sid in state.spaces.keys():
				var sd: SpaceDef = state.game_def.space(sid)
				if sd.type == CoinEnums.SpaceType.CITY and sd.pop >= 1:
					var st: SpaceState = state.space_state(sid)
					if st.control != fid:
						out.append(String(sid))
		"senate_capability_space":
			for sid in state.spaces.keys():
				var st: SpaceState = state.space_state(sid)
				if st.marker("jaeger_senate") > 0:
					out.append(String(sid))
		"largest_senate_groups":
			var groups: Array = []
			for sid in state.spaces.keys():
				var n: int = state.space_state(sid).count("senate", "cell")
				if n > 0:
					groups.append({"sid": String(sid), "n": n})
			groups.sort_custom(func(a, b): return int(a["n"]) > int(b["n"]))
			for g in groups:
				out.append(g["sid"])
		# §8.5.3 Moderates Rally: Town senza Personality
		"town_no_personality":
			for sid in state.spaces.keys():
				var sd: SpaceDef = state.game_def.space(sid)
				if sd.type != CoinEnums.SpaceType.CITY:
					continue
				if state.space_state(sid).marker("personality") <= 0:
					out.append(String(sid))
		"active_support":
			for sid in state.spaces.keys():
				if state.space_state(sid).support >= 2:
					out.append(String(sid))
		"uncontrolled":
			for sid in state.spaces.keys():
				if state.space_state(sid).control == "":
					out.append(String(sid))
		"active_opp":
			for sid in state.spaces.keys():
				if state.space_state(sid).support <= -2:
					out.append(String(sid))
		# Pop ordinata desc (anti-piling via fallback)
		"random_with_pop", "random":
			var by_pop: Array = []
			for sid in state.spaces.keys():
				var sd: SpaceDef = state.game_def.space(sid)
				if sd.pop > 0:
					by_pop.append({"sid": String(sid), "pop": sd.pop})
			by_pop.sort_custom(func(a, b): return int(a["pop"]) > int(b["pop"]))
			for e in by_pop:
				out.append(e["sid"])
		_:
			pass
	return out


func _do_march(ops: ABBOperations, fid: String, _params: Dictionary) -> Dictionary:
	# March greedy: cerca uno spazio con pezzi della fazione che ha adiacente con nemico.
	for sid in state.spaces.keys():
		var st: SpaceState = state.space_state(sid)
		if st.count(fid, "cell") <= 0:
			continue
		var sd: SpaceDef = state.game_def.space(sid)
		for adj in sd.adjacent:
			var res = ops.march(fid, String(sid), String(adj), "cell", 1)
			if res.get("ok", false):
				return res
	return {"ok": false}


func _do_attack(ops: ABBOperations, fid: String, _params: Dictionary) -> Dictionary:
	for sid in state.spaces.keys():
		var st: SpaceState = state.space_state(sid)
		if st.count(fid, "cell") + st.count(fid, "troops") <= 0:
			continue
		var res = ops.attack(fid, String(sid))
		if res.get("ok", false):
			return res
	return {"ok": false}


func _do_terror(ops: ABBOperations, fid: String, _params: Dictionary) -> Dictionary:
	for sid in state.spaces.keys():
		var st: SpaceState = state.space_state(sid)
		if st.count(fid, "cell", "active") <= 0:
			continue
		var res = ops.terror(fid, String(sid))
		if res.get("ok", false):
			return res
	return {"ok": false}


func _do_crackdown(specials: ABBSpecialActivities, _fid: String) -> Dictionary:
	for sid in state.spaces.keys():
		var res = specials.crackdown(String(sid))
		if res.get("ok", false):
			return res
	return {"ok": false}
