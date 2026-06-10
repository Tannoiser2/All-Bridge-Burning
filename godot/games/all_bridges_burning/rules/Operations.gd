class_name ABBOperations
extends RefCounted

## Operazioni All Bridges Burning (rulebook §3.0).
## Rally, March, Attack, Terror — logica core (varianti fazione-specifiche TODO).

var state: GameState
var module: RulesModule

func _init(_state: GameState, _module: RulesModule) -> void:
	state = _state
	module = _module


## Rally (§3.2.1): piazza 1 Cell/Admin/Network in uno spazio.
## Costo: 1 Risorsa (Moderati: 3 Risorse se Polarization ≥ 6 — §3.3.1).
func rally(fid: String, sid: String, mode: String = "cell") -> Dictionary:
	if not state.spaces.has(sid):
		return _err("spazio sconosciuto: %s" % sid)
	var fdef: FactionDef = state.game_def.faction(fid)
	if fdef == null:
		return _err("fazione sconosciuta: %s" % fid)
	if not _can_place(fid, mode):
		return _err("forze esaurite (%s/%s)" % [fid, mode])
	# Costo Rally: 1 default; per Moderati 3 quando Polarization ≥ 6 (§3.3.1).
	# §8.1.2: solo le fazioni player pagano; le Bot non spendono Risorse.
	var cost := 1
	if fid == "moderates" and int(state.tracks.get("polarization", 0)) >= 6:
		cost = 3
	if state.tracks_resources(fid):
		if state.get_resources(fid) < cost:
			return _err("risorse insufficienti (servono %d)" % cost)
		state.resources[fid] -= cost
	# §3.2.1: numero di Cellule = 1 + modificatori. Senato +1 per livello di
	# Supporto; Reds +1 per livello di Opposizione. Le SOTTRAZIONI (Supporto/
	# Opposizione avversa, Terror) sono pagate per essere offsettate; le Bot le
	# offsettano sempre automaticamente (§8.1.3) → non vengono mai applicate.
	# Admin/Network piazzano sempre 1.
	var n := 1
	if mode == "cell":
		var sup := int(state.space_state(sid).support)
		if fid == "senate":
			n += maxi(sup, 0)
		elif fid == "reds":
			n += maxi(-sup, 0)
		var pool_left: int = state.available(fid, mode)
		n = clampi(n, 0, maxi(pool_left, 1))
	var pt_state: String = "underground" if mode == "cell" else ""
	state.spaces[sid].add_piece(fid, mode, n, pt_state)
	state.recompute_control(sid)
	return _ok({"cost": cost, "placed": n})


## March (§3.2.5): sposta pezzi verso spazio adiacente. Phase II only per
## Reds/Senate; sempre disponibile per Germans/Russians (via flowchart §3.4).
## Sabotage su bordo (§3.2.5): blocca March attraverso quel bordo.
func march(fid: String, from_sid: String, to_sid: String, piece_type: String = "cell", count: int = 1) -> Dictionary:
	if fid in ["reds", "senate", "moderates"] and int(state.tracks.get("phase", 1)) < 2:
		return _err("March disponibile solo in Phase II (§3.2.5)")
	if not state.spaces.has(from_sid) or not state.spaces.has(to_sid):
		return _err("spazio non valido")
	if _border_sabotaged(from_sid, to_sid):
		return _err("bordo %s↔%s sabotato (§3.2.5)" % [from_sid, to_sid])
	var sd: SpaceDef = state.game_def.space(from_sid)
	if not (to_sid in sd.adjacent):
		return _err("spazi non adiacenti")
	var from_state: String = "underground" if piece_type == "cell" else ""
	if state.space_state(from_sid).count(fid, piece_type, from_state) < count:
		return _err("pezzi insufficienti")
	# §3.2.5: "pay one Resource per each three Cells (round up) moving into a
	# selected space." §8.1.2: solo i player pagano (Powers/Bot no).
	if state.tracks_resources(fid):
		var march_cost := int(ceil(count / 3.0))
		if state.get_resources(fid) < march_cost:
			return _err("risorse insufficienti per March (§3.2.5)")
		state.resources[fid] = int(state.get_resources(fid)) - march_cost
	state.spaces[from_sid].remove_piece(fid, piece_type, count, from_state)
	var to_state: String = ""
	if piece_type == "cell":
		to_state = "active" if _has_enemy(to_sid, fid) else "underground"
	state.spaces[to_sid].add_piece(fid, piece_type, count, to_state)
	state.recompute_control(from_sid)
	state.recompute_control(to_sid)
	return _ok()


## Attack (§3.2.4): 1d6 vs Attack Strength. Phase II only per Reds/Senate;
## Germans usano l'Attack via flowchart §3.4 in Phase II (gating Bot).
func attack(fid: String, sid: String, rng_seed: int = -1) -> Dictionary:
	if fid in ["reds", "senate", "moderates"] and int(state.tracks.get("phase", 1)) < 2:
		return _err("Attack disponibile solo in Phase II (§3.2.4)")
	if not state.spaces.has(sid):
		return _err("spazio sconosciuto")
	var st: SpaceState = state.space_state(sid)
	var strength: int = st.count(fid, "cell") + st.count(fid, "troops")
	if strength <= 0:
		return _err("nessun pezzo attaccante")
	# §8.1.3 (eccezioni Non-player): per i BOT la forza d'Attack non è il
	# conteggio dei pezzi ma un valore base FISSO — Senato 7, Reds 5 — a cui
	# si sommano/sottraggono i modificatori (Capability, Prepared difensore).
	if String(state.roles.get(fid, "player")) == "bot":
		if fid == "senate":
			strength = 7
		elif fid == "reds":
			strength = 5
	# §5.3 Capability bonuses: +2 Attack Strength per Jaeger/Commander/Cannons/Trains.
	strength += _capability_attack_bonus(fid, st)
	# §3.2.4: marker Prepared del DIFENSORE → −2 alla forza d'attacco.
	var enemy_pre: String = _first_enemy(sid, fid)
	if enemy_pre in ["senate", "reds"] and st.marker("prepared_" + enemy_pre) > 0:
		strength -= 2
	if strength <= 0:
		return _ok({"roll": 0, "strength": strength, "hit": false})
	# §3.2.4: "pay one Resource per selected space." §8.1.2: solo i player pagano
	# (Powers e Bot non spendono Risorse).
	if state.tracks_resources(fid):
		if state.get_resources(fid) < 1:
			return _err("risorse insufficienti per Attack (§3.2.4)")
		state.resources[fid] = int(state.get_resources(fid)) - 1
	var rng := RandomNumberGenerator.new()
	if rng_seed >= 0:
		rng.seed = rng_seed
	else:
		rng.randomize()
	var roll: int = (rng.randi() % 6) + 1
	if roll > strength:
		return _ok({"roll": roll, "strength": strength, "hit": false})
	var enemy_fid: String = _first_enemy(sid, fid)
	if enemy_fid == "":
		return _ok({"roll": roll, "strength": strength, "hit": true, "removed": 0})
	for pair in [["cell", "active"], ["troops", ""], ["cell", "underground"], ["admin", ""], ["network", ""]]:
		if st.count(enemy_fid, pair[0], pair[1]) > 0:
			st.remove_piece(enemy_fid, pair[0], 1, pair[1])
			state.recompute_control(sid)
			# Personality transfer (§4.3.1): se rimuovi l'ultima Cellula
			# Moderati e c'è Personality, Moderati -3 Risorse alla Fazione attaccante.
			var transferred := _maybe_transfer_personality(sid, enemy_fid, fid)
			# Attack-to-Prison §3.2.4: Cellule Senato/Reds rimosse vanno in
			# Prisoners of War; piazza un News marker sullo spazio.
			if pair[0] == "cell" and enemy_fid in ["senate", "reds"]:
				if state.count_marker_on_map("news") < 2:
					st.set_marker("news", st.marker("news") + 1)
				var prisoners: Dictionary = state.tracks.get("prisoners", {"senate": 0, "reds": 0})
				prisoners[enemy_fid] = int(prisoners.get(enemy_fid, 0)) + 1
				state.tracks["prisoners"] = prisoners
			return _ok({"roll": roll, "strength": strength, "hit": true, "removed": 1,
				"target": enemy_fid, "piece": pair[0],
				"personality_transferred": transferred})
	return _ok({"roll": roll, "strength": strength, "hit": true, "removed": 0})


## §4.3.1 / §3.2.4: rimossa l'ultima Cellula Moderati con Personality →
## Personality va Available, Moderati Risorse -3 → Fazione esecutrice +3.
func _maybe_transfer_personality(sid: String, enemy_fid: String, exec_fid: String) -> bool:
	if enemy_fid != "moderates":
		return false
	var st: SpaceState = state.space_state(sid)
	if st.count("moderates", "cell") > 0:
		return false  # Moderati hanno ancora Cellule
	if st.marker("personality") <= 0:
		return false
	# Rimuovi Personality
	st.set_marker("personality", 0)
	# Trasferisci 3 Risorse da Moderati a Fazione esecutrice
	var delta := mini(3, int(state.get_resources("moderates")))
	state.resources["moderates"] = int(state.get_resources("moderates")) - delta
	state.resources[exec_fid] = int(state.get_resources(exec_fid)) + delta
	return true


## Activism (§3.2.2): in uno spazio con una Cellula amica, capovolge una Cellula
## nemica Attiva (→ Inattiva) oppure attiva una propria Cellula Inattiva; in
## entrambi i casi riduce Polarization di 1. Implementazione semplificata:
## preferisce la prima Cellula nemica Attiva trovata; se nessuna, attiva una
## propria Inattiva.
func activism(fid: String, sid: String) -> Dictionary:
	if not state.spaces.has(sid):
		return _err("spazio sconosciuto")
	var st: SpaceState = state.space_state(sid)
	if st.count(fid, "cell") <= 0:
		return _err("serve una Cellula amica in %s" % sid)
	# §3.2.2: "Pay one Resource per selected space." §8.1.2: solo i player pagano.
	if state.tracks_resources(fid):
		if state.get_resources(fid) < 1:
			return _err("risorse insufficienti per Activism (§3.2.2)")
		state.resources[fid] = int(state.get_resources(fid)) - 1
	# Cerca una Cellula nemica Attiva da capovolgere.
	for f in state.game_def.factions:
		if f.id == fid:
			continue
		if st.count(f.id, "cell", "active") > 0:
			st.remove_piece(f.id, "cell", 1, "active")
			st.add_piece(f.id, "cell", 1, "underground")
			_polarize(-1)
			return _ok({"flipped": f.id})
	# Altrimenti attiva una propria Inattiva.
	if st.count(fid, "cell", "underground") > 0:
		st.remove_piece(fid, "cell", 1, "underground")
		st.add_piece(fid, "cell", 1, "active")
		_polarize(-1)
		return _ok({"activated": fid})
	return _err("nessuna Cellula da capovolgere o attivare")


func _polarize(delta: int) -> void:
	var cur: int = int(state.tracks.get("polarization", 0))
	state.tracks["polarization"] = clampi(cur + delta, 0, 10)


## Sabotage borders: chiave canonica "a↔b" (ordinata alfabeticamente).
static func _border_key(a: String, b: String) -> String:
	return "%s↔%s" % [a, b] if a < b else "%s↔%s" % [b, a]


func _border_sabotaged(a: String, b: String) -> bool:
	var key := _border_key(a, b)
	var arr: Array = state.tracks.get("sabotaged_borders", [])
	return key in arr


## §5.3 Capability bonus: +2 Attack Strength per marker amico nello spazio.
## Senate: Jaeger / Cannons / Trains. Reds: Commander / Cannons / Trains.
## (Cannons/Trains globali contano se la fazione ha la Capability attiva.)
func _capability_attack_bonus(fid: String, st: SpaceState) -> int:
	var bonus := 0
	if fid == "senate":
		if st.marker("jaeger_senate") > 0:
			bonus += 2
		if int(state.tracks.get("cannons", 0)) > 0:
			bonus += 2
		if int(state.tracks.get("trains", 0)) > 0:
			bonus += 2
	elif fid == "reds":
		if st.marker("commander_reds") > 0:
			bonus += 2
		if int(state.tracks.get("cannons", 0)) > 0:
			bonus += 2
		if int(state.tracks.get("trains", 0)) > 0:
			bonus += 2
	return bonus


## Piazza Sabotage su un bordo (§4.2.3 Prepare Phase II only).
## Richiede una Cellula amica in uno dei due spazi adiacenti.
func sabotage_border(fid: String, sid_a: String, sid_b: String) -> Dictionary:
	if int(state.tracks.get("phase", 1)) < 2:
		return _err("Sabotage solo in Phase II (§4.2.3)")
	if not (sid_b in state.game_def.space(sid_a).adjacent):
		return _err("spazi non adiacenti")
	if state.space_state(sid_a).count(fid, "cell") <= 0 \
		and state.space_state(sid_b).count(fid, "cell") <= 0:
		return _err("nessuna Cellula amica adiacente")
	var key := _border_key(sid_a, sid_b)
	var arr: Array = state.tracks.get("sabotaged_borders", [])
	if not (key in arr):
		arr.append(key)
		state.tracks["sabotaged_borders"] = arr
	return _ok({"border": key})


## Politics (§3.3.4, Moderati only): piazza 1 cubo nel Political Display
## (colore scelto: "senate" o "reds"). Costo basato sulla Polarization track.
## Polarization 0-1 → 1, 2-3 → 2, 4-5 → 3, ≥6 → impossibile.
func politics(fid: String, cube_color: String) -> Dictionary:
	if fid != "moderates":
		return _err("Politics: solo Moderati")
	var pol := int(state.tracks.get("polarization", 0))
	if pol >= 6:
		return _err("Politics impossibile con Polarization ≥ 6")
	if not (cube_color in ["senate", "reds"]):
		return _err("colore cubo non valido")
	# Moderati richiedono pezzi sulla mappa.
	if state.count_on_map("moderates", "cell") + state.count_on_map("moderates", "network") <= 0:
		return _err("Moderati non hanno pezzi sulla mappa")
	var pd := ABBPoliticalDisplay.new(state)
	if pd.current_unresolved_index() < 0:
		return _err("nessuna Issue Unresolved")
	# §8.1.2: solo i player pagano il costo (1 + pol/2); le Bot no.
	var cost := 1 + int(pol / 2)
	if state.tracks_resources(fid):
		if state.get_resources(fid) < cost:
			return _err("risorse insufficienti (servono %d)" % cost)
		state.resources[fid] -= cost
	pd.place_cubes(cube_color, 1)
	return _ok({"cost": cost, "cube": cube_color})


## Terror (§3.2.3): poni un Terror marker e RIMUOVI pezzi nemici (fino a 1, o 2 se
## Polarization ≥ 6). NON sposta il Supporto/Opposizione — quello è compito di
## Agitate (§3.2.2) / Agitation (§6.4.2). Serve una Cellula ATTIVA della fazione.
## In Phase II, il 2° marker piazza anche un News. Max 2 Terror per spazio (§1.4.3).
func terror(fid: String, sid: String) -> Dictionary:
	if not state.spaces.has(sid):
		return _err("spazio sconosciuto")
	var st: SpaceState = state.space_state(sid)
	if st.count(fid, "cell", "active") <= 0:
		return _err("serve una Cellula Attiva in %s (§3.2.3)" % sid)
	if st.marker("terror") >= 2:
		return _err("massimo 2 Terror per spazio (§1.4.3)")
	# §3.2.3: "Pay one Resource per selected space." §8.1.2: solo i player pagano.
	if state.tracks_resources(fid):
		if state.get_resources(fid) < 1:
			return _err("risorse insufficienti per Terror (§3.2.3)")
		state.resources[fid] = int(state.get_resources(fid)) - 1
	var prev := st.marker("terror")
	st.set_marker("terror", prev + 1)
	# News marker §3.2.3: il 2° Terror in Phase II piazza un News.
	if prev == 1 and int(state.tracks.get("phase", 1)) >= 2 and state.count_marker_on_map("news") < 2:
		st.set_marker("news", st.marker("news") + 1)
	# §3.2.3: rimuovi fino a 1 pezzo nemico (2 se Polarization ≥ 6). Ordine: Cellule
	# (Attive prima), Truppe, Admin/Network. Cellule Senate/Reds → Prigione + News.
	var max_rem: int = 2 if int(state.tracks.get("polarization", 0)) >= 6 else 1
	var removed: int = 0
	for _k in range(max_rem):
		var efid := _first_enemy(sid, fid)
		if efid == "":
			break
		for pair in [["cell", "active"], ["troops", ""], ["cell", "underground"], ["admin", ""], ["network", ""]]:
			if st.count(efid, pair[0], pair[1]) > 0:
				st.remove_piece(efid, pair[0], 1, pair[1])
				removed += 1
				_maybe_transfer_personality(sid, efid, fid)
				if pair[0] == "cell" and efid in ["senate", "reds"]:
					var prisoners: Dictionary = state.tracks.get("prisoners", {"senate": 0, "reds": 0})
					prisoners[efid] = int(prisoners.get(efid, 0)) + 1
					state.tracks["prisoners"] = prisoners
				break
	state.recompute_control(sid)
	# Polarization +1 per ogni Terror piazzato.
	_polarize(1)
	return _ok({"removed": removed, "news_placed": prev == 1 and int(state.tracks.get("phase", 1)) >= 2})


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _can_place(fid: String, piece_type: String) -> bool:
	var fdef: FactionDef = state.game_def.faction(fid)
	if fdef == null:
		return false
	if int(fdef.force_pool.get(piece_type, 0)) <= 0:
		return false
	# Forze Disponibili = pool − su mappa − Out of Play (§6.5.5).
	return state.available(fid, piece_type) > 0


func _has_enemy(sid: String, fid: String) -> bool:
	var st: SpaceState = state.space_state(sid)
	for f in state.game_def.factions:
		if f.id == fid:
			continue
		for pt in ["cell", "troops", "admin", "network"]:
			if st.count(f.id, pt) > 0:
				return true
	return false


func _first_enemy(sid: String, fid: String) -> String:
	var st: SpaceState = state.space_state(sid)
	for f in state.game_def.factions:
		if f.id == fid:
			continue
		for pt in ["cell", "troops", "admin", "network"]:
			if st.count(f.id, pt) > 0:
				return f.id
	return ""


func _shift_support(sid: String, delta: int) -> void:
	var st: SpaceState = state.space_state(sid)
	var cur: int = int(st.support)
	var new_val: int = clampi(cur + delta, int(CoinEnums.Support.ACTIVE_OPPOSITION), int(CoinEnums.Support.ACTIVE_SUPPORT))
	st.support = new_val as CoinEnums.Support


func _ok(extra: Dictionary = {}) -> Dictionary:
	var d := {"ok": true, "error": ""}
	for k in extra.keys():
		d[k] = extra[k]
	return d

func _err(msg: String) -> Dictionary:
	return {"ok": false, "error": msg}
