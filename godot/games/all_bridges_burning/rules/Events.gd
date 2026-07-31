class_name ABBEvents
extends RefCounted

## Eventi ABB. Per ora gestiamo solo la Pivotal "Red Revolt!" (#24) che fa partire
## la Phase II del gioco (Germans agiscono via flowchart, §3.4). Gli effetti
## unshaded/shaded delle 47 carte sono da popolare dal regolamento /
## `ABB_CardEdits-download.pdf`.

var state: GameState
var module: RulesModule

func _init(_state: GameState, _module: RulesModule) -> void:
	state = _state
	module = _module


## Risolve l'evento `number` per `faction` sul lato `side` ("unshaded"/"shaded").
## Restituisce {ok, log[]}. Effetti generici stub; gli unici effetti reali sono
## quelli della Pivotal Red Revolt!.
func apply(number: int, side: String, faction: String, _params: Dictionary = {}) -> Dictionary:
	var log: Array[String] = []
	if number == 24:
		return _red_revolt(side, faction)
	var card: CardDef = state.game_def.card(number)
	var title := card.title if card != null else "#%d" % number
	# Capacità: il titolo entra in active_capabilities + marker su mappa.
	if card != null and card.is_capability:
		if not state.active_capabilities.has(title):
			state.active_capabilities.append(title)
			log.append("Capacità attivata: %s." % title)
			_place_capability_marker(number, side, log)
		else:
			log.append("Capacità %s già attiva." % title)
		return {"ok": true, "log": log}
	# Non-player Event Instructions (§8.1.4, play-aid pag. 2): quando un BOT
	# gioca l'evento, l'esecuzione segue la tabella (spesso "per la carta NP X").
	if String(state.roles.get(faction, "player")) == "bot" \
			and _np_instruction_effect(number, side, faction, log):
		return {"ok": true, "log": log}
	# Effetti atomici per le carte più frequenti.
	var handled := _apply_basic_effect(number, side, faction, log)
	if not handled:
		log.append("Evento %s [%s] non ancora implementato." % [title, side])
	return {"ok": true, "log": log}


# ---------------------------------------------------------------------------
# Non-player Event Instructions (§8.1.4) — ESECUZIONE per i bot
# ---------------------------------------------------------------------------

## Esegue l'evento per il bot secondo la Event Instructions sheet. Ritorna true
## se la riga della tabella copre (number, faction) e l'effetto è stato eseguito.
func _np_instruction_effect(number: int, side: String, faction: String, log: Array[String]) -> bool:
	match number:
		4, 43:  # per la carta NP Terror (Senate #57 / Reds #51).
			if faction == "senate": return _run_np_card("senate", 57, log)
			if faction == "reds": return _run_np_card("reds", 51, log)
		5, 6, 9:  # shift di uno spazio 1+ Pop (Senate → Supporto, Reds → Opposizione, Pop più alta).
			if faction == "senate": return _shift_best_pop(1, log)
			if faction == "reds": return _shift_best_pop(-1, log)
		7:  # We Demand — Moderates: cubo per la carta Politics #64; Reds: Rally #48.
			if faction == "moderates": return _run_np_card("moderates", 64, log)
			if faction == "reds": return _run_np_card("reds", 48, log)
		8:  # General Strike — S/R: Terror; M: Network dove più Cellule (Town prima).
			if faction == "senate": return _run_np_card("senate", 57, log)
			if faction == "reds": return _run_np_card("reds", 51, log)
			if faction == "moderates": return _place_network_most_cells(log)
		10:  # Weapons and Jaeger — Moderates: Cellule per la carta Rally #60.
			if faction == "moderates": return _run_np_card("moderates", 60, log)
		11:  # Weapons from Lenin? — procedura 1d6 della tabella.
			return _lenin_procedure(log)
		12:  # Food Supply — S/R: Terror.
			if faction == "senate": return _run_np_card("senate", 57, log)
			if faction == "reds": return _run_np_card("reds", 51, log)
		13:  # Joblessness — S/R: Cellula ATTIVA per guadagnare Town Pop Control; M: cubo #64.
			if faction in ["senate", "reds"]: return _place_active_cell_gain_town(faction, log)
			if faction == "moderates": return _run_np_card("moderates", 64, log)
		20:  # Tokoi's Chair — Controlla 1+ Pop, oppure rimuovi ultima Cellula nemica/Prepared.
			if faction in ["senate", "reds"]:
				if _place_active_cell_gain_town(faction, log): return true
				return _remove_lone_enemy_cell(faction, log)
		21:  # Worker's Halls — Reds: Amministrazione in Provincia con 1+ Cellule (meno Opposizione).
			if faction == "reds": return _place_admin_province(log)
		27:  # Major Reds Offensive — Senate: Attack #58; Reds: Attack #52 poi March #53.
			if faction == "senate": return _run_np_card("senate", 58, log)
			if faction == "reds":
				if _run_np_card("reds", 52, log): return true
				return _run_np_card("reds", 53, log)
		29:  # War with Many Names — Senate: Rally (#54/#55); Moderates: Rally #60.
			if faction == "senate":
				var n := 55 if int(state.tracks.get("phase", 1)) >= 2 else 54
				return _run_np_card("senate", n, log)
			if faction == "moderates": return _run_np_card("moderates", 60, log)
		32, 34, 35:  # Armistice / Political Arrests / Home Front — Moderates: Rally #60.
			if faction == "moderates": return _run_np_card("moderates", 60, log)
			if number == 35 and faction == "reds":  # Home Front Reds: shift dove NIENTE Admin Reds.
				return _shift_best_pop(-1, log, true)
		37:  # VATO — Senate: Helsinki se Neutrale, poi riduci più Opposizione; Reds: alza Opposizione.
			if faction == "senate":
				if state.spaces.has("helsinki") and int(state.space_state("helsinki").support) == 0:
					return _shift_space("helsinki", 1, log)
				return _shift_most_opposition(1, log)
			if faction == "reds": return _shift_best_pop(-1, log)
		39, 45:  # Parliament / Fate in the Balance — Moderates: Lim Cmd dal mazzo NP (blocca l'evento).
			if faction == "moderates":
				var r: Dictionary = ABBNonPlayerModerates.new(state, module).take_turn()
				log.append_array(r.get("trace", []))
				log.append("Moderati giocano la carta per bloccarla (Lim Cmd dal mazzo NP).")
				return true
		40:  # Battle of Tampere — Senate: rimuovi 1 Admin o 2 Cellule Reds; Reds: 2 Cellule Senate.
			if faction == "senate": return _battle_removals("senate", log)
			if faction == "reds": return _battle_removals("reds", log)
		41:  # Battle of Lahti — Senate: Attack in Uusimaa (3+ Senate) o rimuovi 1 German (3+).
			if faction == "senate": return _battle_of_lahti(log)
		42:  # Battle of Viipuri — Senate: Cellula per guadagnare Town Pop Control.
			if faction == "senate": return _place_active_cell_gain_town("senate", log)
		44:  # Mannerheim — Reds: shift Helsinki verso l'Opposizione, altrimenti Rally lì.
			if faction == "reds":
				if state.spaces.has("helsinki") and int(state.space_state("helsinki").support) > -2:
					return _shift_space("helsinki", -1, log)
				var rr: Dictionary = ABBOperations.new(state, module).rally("reds", "helsinki", "cell")
				if rr.get("ok", false):
					log.append("Reds Rally a Helsinki (#44).")
					return true
	return false


## Esegue la carta NP n per la fazione come effetto dell'evento.
func _run_np_card(fid: String, n: int, log: Array[String]) -> bool:
	var r: Dictionary = {}
	match fid:
		"reds": r = ABBNonPlayerReds.new(state, module)._exec_card(n)
		"senate": r = ABBNonPlayerSenate.new(state, module)._exec_card(n)
		"moderates": r = ABBNonPlayerModerates.new(state, module)._exec_card(n)
	if bool(r.get("acted", false)):
		log.append("Evento eseguito per la carta NP #%d:" % n)
		for t in r.get("trace", []):
			log.append("  %s" % t)
		return true
	return false


func _shift_space(sid: String, delta: int, log: Array[String]) -> bool:
	var st: SpaceState = state.space_state(sid)
	var cur := int(st.support)
	var nv := clampi(cur + delta, -2, 2)
	if nv == cur:
		return false
	st.support = nv as CoinEnums.Support
	state.recompute_control(sid)
	log.append("Shift %s: Supporto %d → %d." % [sid, cur, nv])
	return true


## Shift sullo spazio 1+ Pop a Pop più alta con margine; skip_admin=true esclude
## gli spazi con Amministrazione Reds (#35 Home Front).
func _shift_best_pop(delta: int, log: Array[String], skip_admin: bool = false) -> bool:
	var best := ""
	var bp := 0
	for sid in state.spaces.keys():
		var sd: SpaceDef = state.game_def.space(sid)
		if sd == null or sd.pop < 1:
			continue
		var st: SpaceState = state.space_state(sid)
		if skip_admin and st.count("reds", "admin") > 0:
			continue
		var s := int(st.support)
		if (delta > 0 and s >= 2) or (delta < 0 and s <= -2):
			continue
		if sd.pop > bp:
			bp = sd.pop
			best = String(sid)
	return best != "" and _shift_space(best, delta, log)


## Shift +1 dove c'è più Opposizione (per il Crackdown-evento del Senato, #37).
func _shift_most_opposition(delta: int, log: Array[String]) -> bool:
	var best := ""
	var bo := 0
	for sid in state.spaces.keys():
		var st: SpaceState = state.space_state(sid)
		if int(st.support) < 0 and -int(st.support) > bo:
			bo = -int(st.support)
			best = String(sid)
	return best != "" and _shift_space(best, delta, log)


## Cellula ATTIVA nella Town dove fid otterrebbe il Controllo (Pop più alta).
func _place_active_cell_gain_town(fid: String, log: Array[String]) -> bool:
	if state.available(fid, "cell") <= 0:
		return false
	var best := ""
	var bp := 0
	for sid in state.spaces.keys():
		var sd: SpaceDef = state.game_def.space(sid)
		if sd == null or sd.type != CoinEnums.SpaceType.CITY or sd.pop < 1:
			continue
		var st: SpaceState = state.space_state(sid)
		if st.control == fid:
			continue
		var mine := st.count(fid, "cell") + st.count(fid, "admin")
		var others := 0
		for f in state.game_def.factions:
			if f.id == fid or f.id in ["germans", "russians"]:
				continue
			others += st.count(f.id, "cell") + st.count(f.id, "admin") + st.count(f.id, "network")
		if mine + 1 > others and sd.pop > bp:
			bp = sd.pop
			best = String(sid)
	if best == "":
		return false
	state.space_state(best).add_piece(fid, "cell", 1, "active")
	state.recompute_control(best)
	log.append("Cellula %s ATTIVA a %s (Town Pop Control)." % [fid, best])
	return true


func _remove_lone_enemy_cell(fid: String, log: Array[String]) -> bool:
	var enemy := "reds" if fid == "senate" else "senate"
	for sid in state.spaces.keys():
		var st: SpaceState = state.space_state(sid)
		if st.count(enemy, "cell") == 1:
			if st.count(enemy, "cell", "active") > 0:
				st.remove_piece(enemy, "cell", 1, "active")
			else:
				st.remove_piece(enemy, "cell", 1, "underground")
			state.recompute_control(String(sid))
			log.append("Rimossa l'ultima Cellula %s a %s." % [enemy, sid])
			return true
	return false


func _place_admin_province(log: Array[String]) -> bool:
	if state.available("reds", "admin") <= 0:
		return false
	var best := ""
	var bo := 99
	for sid in state.spaces.keys():
		var sd: SpaceDef = state.game_def.space(sid)
		if sd == null or sd.type == CoinEnums.SpaceType.CITY:
			continue
		var st: SpaceState = state.space_state(sid)
		if st.count("reds", "cell") >= 1 and st.count("reds", "admin") == 0:
			var opp := -int(st.support)
			if opp < bo:
				bo = opp
				best = String(sid)
	if best == "":
		return false
	state.space_state(best).add_piece("reds", "admin", 1, "")
	state.recompute_control(best)
	log.append("Amministrazione Reds a %s (#21)." % best)
	return true


func _place_network_most_cells(log: Array[String]) -> bool:
	if state.available("moderates", "network") <= 0:
		return false
	var best := ""
	var bc := 0
	for sid in state.spaces.keys():
		var sd: SpaceDef = state.game_def.space(sid)
		var st: SpaceState = state.space_state(sid)
		if st.count("moderates", "network") > 0:
			continue
		var c := st.count("moderates", "cell")
		# ⓐ priorità Town a parità di Cellule.
		if c > bc or (c == bc and c > 0 and sd != null and sd.type == CoinEnums.SpaceType.CITY and best != "" and state.game_def.space(best).type != CoinEnums.SpaceType.CITY):
			bc = c
			best = String(sid)
	if best == "" or bc == 0:
		return false
	state.space_state(best).add_piece("moderates", "network", 1, "")
	state.recompute_control(best)
	log.append("Network Moderati a %s (#8)." % best)
	return true


## #11 Weapons from Lenin?: 1d6 → 1-2 Vass.Russo +1; 3-4 Vass.Tedesco −1;
## 5 se il Senato è player Vass.Tedesco +1, altrimenti ritira; 6 nessun effetto.
func _lenin_procedure(log: Array[String]) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for _i in range(6):
		var roll := rng.randi_range(1, 6)
		if roll <= 2:
			_adjust_vassal("russian", 1, log)
			return true
		if roll <= 4:
			_adjust_vassal("german", -1, log)
			return true
		if roll == 5:
			if String(state.roles.get("senate", "bot")) == "player":
				_adjust_vassal("german", 1, log)
				return true
			continue  # ritira
		log.append("#11: 1d6=6 → nessun effetto (Cmd al posto dell'evento).")
		return true
	return true


func _battle_removals(fid: String, log: Array[String]) -> bool:
	if fid == "senate":
		# ❶ un'Amministrazione Reds, ❷ altrimenti 2 Cellule Reds dallo stack più grande.
		for sid in state.spaces.keys():
			var st: SpaceState = state.space_state(sid)
			if st.count("reds", "admin") > 0:
				st.remove_piece("reds", "admin", 1, "")
				state.recompute_control(String(sid))
				log.append("Rimossa Amministrazione Reds a %s (#40)." % sid)
				return true
	var enemy := "reds" if fid == "senate" else "senate"
	var best := ""
	var bc := 0
	for sid in state.spaces.keys():
		var c := state.space_state(sid).count(enemy, "cell")
		if c > bc:
			bc = c
			best = String(sid)
	if best == "" or bc < 2:
		return false
	var st2: SpaceState = state.space_state(best)
	for _k in range(2):
		if st2.count(enemy, "cell", "active") > 0:
			st2.remove_piece(enemy, "cell", 1, "active")
		elif st2.count(enemy, "cell", "underground") > 0:
			st2.remove_piece(enemy, "cell", 1, "underground")
	state.recompute_control(best)
	log.append("Rimosse 2 Cellule %s a %s (#40)." % [enemy, best])
	return true


func _battle_of_lahti(log: Array[String]) -> bool:
	if not state.spaces.has("uusimaa"):
		return false
	var uu: SpaceState = state.space_state("uusimaa")
	if uu.count("senate", "cell") >= 3:
		var r: Dictionary = ABBOperations.new(state, module).attack("senate", "uusimaa")
		if r.get("ok", false):
			log.append("Senate Attack in Uusimaa (#41): tiro %d vs forza %d." % [int(r.get("roll", 0)), int(r.get("strength", 0))])
			return true
		return false
	if uu.count("germans", "troops") >= 3:
		uu.remove_piece("germans", "troops", 1, "")
		state.recompute_control("uusimaa")
		log.append("Rimossa 1 Truppa Tedesca da Uusimaa (#41).")
		return true
	return false


## Effetti atomici per carte con effetto semplice (Resources / Polarization /
## Vassalage / cell flip). Ritorna true se la carta è gestita.
func _apply_basic_effect(number: int, side: String, faction: String, log: Array[String]) -> bool:
	# #2 "July Days": flip 1d6 cellule amiche; shaded: Moderati Risorse +3
	if number == 2 and side == "shaded":
		state.resources["moderates"] = mini(30, int(state.get_resources("moderates")) + 3)
		log.append("Moderati Risorse +3.")
		return true
	# #3 October Revolution: adjust Russian Vassalage
	if number == 3 and side == "unshaded":
		_adjust_vassal("russian", 1, log)
		return true
	# #5 "Powers Act" shaded: shift one space toward Active Support/Opposition
	if number == 5 and side == "shaded":
		log.append("Sposta uno spazio di un livello (manuale).")
		return true
	# #7 "We Demand" unshaded: Senate Resources +3
	if number == 7 and side == "unshaded":
		state.resources["senate"] = mini(30, int(state.get_resources("senate")) + 3)
		log.append("Senato Risorse +3.")
		return true
	# #11 Weapons from Lenin: Russian Vassalage shift (player choice)
	if number == 11:
		_adjust_vassal("russian", 1 if side == "unshaded" else -1, log)
		return true
	# #12 Food Supply Issues: Moderates -3 (unshaded) o Limited Cmd gratis (shaded)
	if number == 12 and side == "unshaded":
		state.resources["moderates"] = maxi(0, int(state.get_resources("moderates")) - 3)
		log.append("Moderati Risorse -3.")
		return true
	# #19 Political Struggle: gestito in _politics_dispatch
	if number == 19:
		var pd := ABBPoliticalDisplay.new(state)
		if side == "unshaded":
			pd.remove_cubes("senate", 1)
			pd.remove_cubes("reds", 1)
			log.append("Rimosso un cubo dal Political Display; Politics Phase ora.")
			pd.resolve_politics(-1)
		else:
			# 1d6 ≤ 4 → +1 cubo
			var rng := RandomNumberGenerator.new(); rng.randomize()
			var roll := rng.randi_range(1, 6)
			if roll <= 4:
				pd.place_cubes("senate" if faction == "senate" else "reds", 1)
				log.append("Roll %d ≤ 4 → +1 cubo." % roll)
			else:
				log.append("Roll %d > 4 → nessun effetto." % roll)
		return true
	# #25 Disarming Russian Garrisons: sostituisci Russian Troops con Senate Cells
	if number == 25 and side == "unshaded":
		for sid in state.spaces.keys():
			var st: SpaceState = state.space_state(sid)
			while st.count("russians", "troops") > 0 \
				and st.count("senate", "cell") < 20 \
				and state.available("senate", "cell") > 0:
				st.remove_piece("russians", "troops", 1, "")
				st.add_piece("senate", "cell", 1, "underground")
		log.append("Russian Troops → Senate Cells (spazi con entrambi).")
		return true
	# #29 War with Many Names shaded: Polarization -1
	if number == 29 and side == "shaded":
		state.tracks["polarization"] = clampi(int(state.tracks.get("polarization", 0)) - 1, 0, 10)
		log.append("Polarization -1.")
		return true
	# #30 Meetings in the Catacombs shaded: Moderati +3 o cubo PD
	if number == 30 and side == "shaded":
		state.resources["moderates"] = mini(30, int(state.get_resources("moderates")) + 3)
		log.append("Moderati Risorse +3 (o piazza cubo PD — scelta del giocatore).")
		return true
	# #36 Prisoners shaded: rimozione 2 Cellule (gestito manualmente)
	# #37 VATO: shift Senate space
	# #44 Mannerheim's Victory Parade unshaded: Senate +3, German Vassal -1
	if number == 44 and side == "unshaded":
		state.resources["senate"] = mini(30, int(state.get_resources("senate")) + 3)
		_adjust_vassal("german", -1, log)
		return true
	# #45 Fate in the Balance unshaded: decrease Vassalage by up to 2
	if number == 45 and side == "unshaded":
		_adjust_vassal("german", -2, log)
		return true
	# #45 shaded: rimuovi Resolved Issue marker
	if number == 45 and side == "shaded":
		var issues: Array = state.tracks.get("issues", [])
		for i in range(issues.size()):
			if String(issues[i].get("resolved_by", "")) != "":
				issues[i]["resolved_by"] = ""
				state.tracks["issues"] = issues
				log.append("Rimosso Resolved Issue: %s." % ABBPoliticalDisplay.ISSUES[i]["name"])
				return true
		log.append("Nessuna Issue risolta da rimuovere: nessun effetto.")
		return true
	# #4 shaded: Place Available Moderates Cell anywhere (first eligible)
	if number == 4 and side == "shaded":
		for sid in state.spaces.keys():
			if state.place_from_available("moderates", "cell", String(sid), 1, "underground") > 0:
				log.append("Cellula Moderati piazzata a %s." % sid)
				return true
		log.append("Nessuna Cellula Moderati disponibile.")
		return true
	# #9 shaded: Polarization -1 + Resources +3 + cube PD
	if number == 9 and side == "shaded":
		state.tracks["polarization"] = clampi(int(state.tracks.get("polarization", 0)) - 1, 0, 10)
		state.resources[faction] = mini(30, int(state.get_resources(faction)) + 3)
		var pd9 := ABBPoliticalDisplay.new(state)
		var cube_color := "senate" if faction == "senate" else "reds"
		pd9.place_cubes(cube_color, 1)
		log.append("Polarization -1, %s Risorse +3, +1 cubo PD." % faction)
		return true
	# #18 unshaded: Place up to 2 Cells in 0-pop Province (greedy: prima Provincia 0-pop)
	if number == 18 and side == "unshaded":
		var placed_total := 0
		for sid in state.spaces.keys():
			var sd: SpaceDef = state.game_def.space(sid)
			if sd.pop != 0 or sd.type != CoinEnums.SpaceType.PROVINCE:
				continue
			while placed_total < 2:
				if state.place_from_available(faction, "cell", String(sid), 1, "underground") <= 0:
					break
				placed_total += 1
			if placed_total >= 2:
				break
		log.append("Piazzate %d Cellule %s in Provincia 0-Pop." % [placed_total, faction])
		return true
	# #18 shaded: Conduct Politics Phase
	if number == 18 and side == "shaded":
		var pd18 := ABBPoliticalDisplay.new(state)
		var rp := pd18.resolve_politics(-1)
		log.append_array(rp.get("log", []))
		return true
	# #21 unshaded: Flip 2 Cells anywhere (toggle stato)
	if number == 21 and side == "unshaded":
		var flipped := 0
		for sid in state.spaces.keys():
			if flipped >= 2:
				break
			var st: SpaceState = state.space_state(sid)
			for f in state.game_def.factions:
				if flipped >= 2:
					break
				if st.count(f.id, "cell", "underground") > 0:
					st.remove_piece(f.id, "cell", 1, "underground")
					st.add_piece(f.id, "cell", 1, "active")
					flipped += 1
				elif st.count(f.id, "cell", "active") > 0:
					st.remove_piece(f.id, "cell", 1, "active")
					st.add_piece(f.id, "cell", 1, "underground")
					flipped += 1
		log.append("Capovolte %d Cellule." % flipped)
		return true
	# #21 shaded: Reds Administration in Reds-controlled Province with friendly Cell
	if number == 21 and side == "shaded":
		for sid in state.spaces.keys():
			var st: SpaceState = state.space_state(sid)
			if st.control == "reds" and st.count("reds", "cell") > 0:
				if state.place_from_available("reds", "admin", String(sid), 1, "") > 0:
					log.append("Reds Administration piazzata a %s." % sid)
					return true
		return true
	# #27 unshaded: Senate free Attack +2
	if number == 27 and side == "unshaded":
		log.append("Senate Attack gratis con +2 Strength (manuale dall'UI).")
		return true
	# #28 shaded: Prisoners step + Resources adjust
	if number == 28 and side == "shaded":
		var prisoners: Dictionary = state.tracks.get("prisoners", {"senate": 0, "reds": 0})
		var total := int(prisoners.get("senate", 0)) + int(prisoners.get("reds", 0))
		if total >= 2:
			var bump := int(total / 2)
			state.tracks["polarization"] = clampi(int(state.tracks.get("polarization", 0)) + bump, 0, 10)
			log.append("Prisoners step: Polarization +%d." % bump)
		# Resources transfer: +1d6 a fazione esecutrice o -1d6 a un avversario
		var rng28 := RandomNumberGenerator.new(); rng28.randomize()
		var roll := rng28.randi_range(1, 6)
		state.resources[faction] = mini(30, int(state.get_resources(faction)) + roll)
		log.append("%s Risorse +%d." % [faction, roll])
		return true
	# #32 unshaded: Remove 1 Moderates Cell (first eligible) + Personality check
	if number == 32 and side == "unshaded":
		for sid in state.spaces.keys():
			var st32: SpaceState = state.space_state(sid)
			if st32.count("moderates", "cell") > 0:
				st32.remove_piece("moderates", "cell", 1, "underground" if st32.count("moderates","cell","underground")>0 else "active")
				if st32.count("moderates", "cell") == 0 and st32.marker("personality") > 0:
					st32.set_marker("personality", 0)
					state.resources["moderates"] = maxi(0, int(state.get_resources("moderates")) - 3)
					state.resources[faction] = mini(30, int(state.get_resources(faction)) + 3)
					log.append("Personality rimossa, 3 Risorse transferite a %s." % faction)
				log.append("Cellula Moderati rimossa a %s." % sid)
				return true
		return true
	# #36 shaded: Polarization +1 per ogni 2 Cellule in Prison
	if number == 36 and side == "shaded":
		var pris36: Dictionary = state.tracks.get("prisoners", {"senate": 0, "reds": 0})
		var tot36 := int(pris36.get("senate", 0)) + int(pris36.get("reds", 0))
		var pol_b := int(tot36 / 2)
		state.tracks["polarization"] = clampi(int(state.tracks.get("polarization", 0)) + pol_b, 0, 10)
		log.append("Polarization +%d (prigionieri totali %d)." % [pol_b, tot36])
		return true
	# #39 unshaded: Conduct Politics Phase
	if number == 39 and side == "unshaded":
		var pd39 := ABBPoliticalDisplay.new(state)
		var rp39 := pd39.resolve_politics(-1)
		log.append_array(rp39.get("log", []))
		return true
	# #43 unshaded: Place Terror in up to 2 spaces with friendly Cells, ignore max
	if number == 43 and side == "unshaded":
		var placed_terror := 0
		for sid in state.spaces.keys():
			if placed_terror >= 2:
				break
			var st43: SpaceState = state.space_state(sid)
			if st43.count(faction, "cell") > 0:
				st43.set_marker("terror", st43.marker("terror") + 1)
				state.tracks["polarization"] = clampi(int(state.tracks.get("polarization", 0)) + 1, 0, 10)
				placed_terror += 1
		log.append("Terror piazzato in %d spazi, Polarization +%d." % [placed_terror, placed_terror])
		return true
	# #43 shaded: remove 1 Terror from a space, Polarization -1
	if number == 43 and side == "shaded":
		for sid in state.spaces.keys():
			var st43s: SpaceState = state.space_state(sid)
			if st43s.marker("terror") > 0:
				st43s.set_marker("terror", st43s.marker("terror") - 1)
				state.tracks["polarization"] = clampi(int(state.tracks.get("polarization", 0)) - 1, 0, 10)
				log.append("Terror rimosso a %s, Polarization -1." % sid)
				return true
		return true
	# #6: A power shift — place 1 Available enemy Cell in a Town + shift space
	if number == 6:
		# Cerca prima Town valida per piazzare Cellula nemica
		for sid in state.spaces.keys():
			var sd6: SpaceDef = state.game_def.space(sid)
			if sd6.type != CoinEnums.SpaceType.CITY:
				continue
			# Enemy faction = la più "forte" non-faction
			var enemy_id := "reds" if faction == "senate" else "senate"
			if state.place_from_available(enemy_id, "cell", String(sid), 1, "underground") > 0:
				log.append("Cellula %s piazzata a %s (manuale: shift spazio)." % [enemy_id, sid])
				return true
		return true
	# #8 unshaded: Terror gratis + Moderates +3 / shaded: violence erupts
	if number == 8:
		state.resources["moderates"] = mini(30, int(state.get_resources("moderates")) + 3)
		log.append("Moderati Risorse +3 (Terror manuale).")
		return true
	# #13 unshaded: 2 Cellule amiche in spazio senza Supporto Attivo nemico
	if number == 13 and side == "unshaded":
		var placed13 := 0
		for sid in state.spaces.keys():
			if placed13 >= 2:
				break
			var st13: SpaceState = state.space_state(sid)
			if abs(st13.support) >= 2:
				continue
			if state.place_from_available(faction, "cell", String(sid), 1, "underground") > 0:
				placed13 += 1
		log.append("Piazzate %d Cellule %s." % [placed13, faction])
		return true
	# #13 shaded: Conduct Politics Phase + cubo PD per Moderati
	if number == 13 and side == "shaded":
		var pd13 := ABBPoliticalDisplay.new(state)
		pd13.place_cubes("senate", 1)
		pd13.resolve_politics(-1)
		log.append("Politics Phase eseguita + 1 cubo Senato piazzato.")
		return true
	# #20 shaded: Flip any one Active Cell
	if number == 20 and side == "shaded":
		for sid in state.spaces.keys():
			var st20: SpaceState = state.space_state(sid)
			for f in state.game_def.factions:
				if st20.count(f.id, "cell", "active") > 0:
					st20.remove_piece(f.id, "cell", 1, "active")
					st20.add_piece(f.id, "cell", 1, "underground")
					log.append("Cellula %s capovolta a %s." % [f.id, sid])
					return true
		return true
	# #26 shaded: Moderati/Reds Rally free
	if number == 26 and side == "shaded":
		var target_fac := "moderates" if state.get_resources("moderates") > state.get_resources("reds") else "reds"
		for sid in state.spaces.keys():
			if state.place_from_available(target_fac, "cell", String(sid), 1, "underground") > 0:
				log.append("Rally gratis: %s Cellula a %s." % [target_fac, sid])
				return true
		return true
	# #29 unshaded: Senate Rally + March (logged - manuale)
	if number == 29 and side == "unshaded":
		log.append("Senate Rally + March gratis (manuale dall'UI).")
		return true
	# #31 unshaded: German forces arrive — Senate Coordinate
	if number == 31 and side == "unshaded":
		if int(state.tracks.get("phase", 1)) >= 2:
			state.tracks["coordinate_marker"] = 1
			log.append("Coordinate marker attivato (Senato decide Germans).")
		else:
			log.append("Coordinate solo in Phase II.")
		return true
	# #33 unshaded: Senate Coordinate / Senate free Rally Helsinki
	if number == 33 and side == "unshaded":
		if state.place_from_available("senate", "cell", "helsinki", 1, "underground") > 0:
			log.append("Senato Rally gratis a Helsinki.")
		return true
	# #34 unshaded: Remove Personality (where present)
	if number == 34 and side == "unshaded":
		for sid in state.spaces.keys():
			var st34: SpaceState = state.space_state(sid)
			if st34.marker("personality") > 0:
				st34.set_marker("personality", 0)
				state.resources["moderates"] = maxi(0, int(state.get_resources("moderates")) - 3)
				log.append("Personality rimossa a %s, Moderati -3." % sid)
				return true
		return true
	# #35 unshaded: Senate Rally in spazi con Support
	if number == 35 and side == "unshaded":
		var placed35 := 0
		for sid in state.spaces.keys():
			if placed35 >= 2:
				break
			var st35: SpaceState = state.space_state(sid)
			if st35.support > 0:
				if state.place_from_available("senate", "cell", String(sid), 1, "underground") > 0:
					placed35 += 1
		log.append("Senate Rally gratis in %d spazi con Support." % placed35)
		return true
	# #35 shaded: Moderati Rally
	if number == 35 and side == "shaded":
		var placed35s := 0
		for sid in state.spaces.keys():
			if placed35s >= 2:
				break
			if state.place_from_available("moderates", "cell", String(sid), 1, "underground") > 0:
				placed35s += 1
		log.append("Moderati Rally gratis in %d spazi." % placed35s)
		return true
	# #37: Sposta uno spazio con pezzo Senato verso Active Sup/Opp (manuale)
	if number == 37:
		for sid in state.spaces.keys():
			var st37: SpaceState = state.space_state(sid)
			if st37.count("senate", "cell") > 0:
				_shift_support(st37, 1)
				log.append("%s spostato verso Active Support." % sid)
				return true
		return true
	# #38 unshaded: Remove 2 Moderati Cells
	if number == 38 and side == "unshaded":
		var removed38 := 0
		for sid in state.spaces.keys():
			if removed38 >= 2:
				break
			var st38: SpaceState = state.space_state(sid)
			while st38.count("moderates", "cell") > 0 and removed38 < 2:
				var st_kind := "underground" if st38.count("moderates","cell","underground")>0 else "active"
				st38.remove_piece("moderates", "cell", 1, st_kind)
				removed38 += 1
		log.append("Rimosse %d Cellule Moderati." % removed38)
		return true
	# #40, #41, #42: Battle free Attack — logged manuale
	if number in [40, 41, 42]:
		var locs := {"40": "Tampere/Häme", "41": "Lahti", "42": "Viipuri"}
		log.append("Senate/Reds Attack gratis a %s (manuale dall'UI)." % locs[str(number)])
		return true
	return _apply_extended_effect(number, side, faction, log)


## Effetti delle carte prima "stub" per il giocatore umano. Dove il testo
## richiede la SCELTA di uno spazio, la scelta è AUTOMATICA con le priorità
## generali §8.1.7 (e viene loggata) — LIMITE MODELLO dichiarato.
func _apply_extended_effect(number: int, side: String, faction: String, log: Array[String]) -> bool:
	var ops := ABBOperations.new(state, module)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	# #2 unshaded / #3 shaded: capovolgi fino a 1d6 Cellule amiche (auto:
	# Attive → Clandestine, la scelta protettiva).
	if (number == 2 and side == "unshaded") or (number == 3 and side == "shaded"):
		var n := rng.randi_range(1, 6)
		var flipped := 0
		for sid in state.spaces.keys():
			var st: SpaceState = state.space_state(sid)
			while flipped < n and st.count(faction, "cell", "active") > 0:
				st.remove_piece(faction, "cell", 1, "active")
				st.add_piece(faction, "cell", 1, "underground")
				flipped += 1
		log.append("Capovolte %d/%d Cellule %s Attive → Clandestine (scelta automatica)." % [flipped, n, faction])
		return true
	# #4 unshaded / #12 shaded (parte S/R): Terrore gratis in uno spazio con
	# Cellula amica (anche Inattiva), rimuovendo 1 Cellula nemica.
	if (number == 4 and side == "unshaded") or (number == 12 and side == "shaded" and faction in ["senate", "reds"]):
		var enemy := "reds" if faction == "senate" else "senate"
		var best := ""
		var bc := 0
		for sid in state.spaces.keys():
			var st: SpaceState = state.space_state(sid)
			if st.count(faction, "cell") > 0 and st.count(enemy, "cell") > bc:
				bc = st.count(enemy, "cell")
				best = String(sid)
		if best == "":
			log.append("Nessuno spazio con Cellula amica e nemica: nessun effetto.")
			return true
		var stt: SpaceState = state.space_state(best)
		if stt.marker("terror") < 2:
			stt.set_marker("terror", stt.marker("terror") + 1)
		if stt.count(enemy, "cell", "active") > 0:
			stt.remove_piece(enemy, "cell", 1, "active")
		else:
			stt.remove_piece(enemy, "cell", 1, "underground")
		var pris: Dictionary = state.tracks.get("prisoners", {"senate": 0, "reds": 0})
		pris[enemy] = int(pris.get(enemy, 0)) + 1
		state.tracks["prisoners"] = pris
		state.recompute_control(best)
		log.append("Terrore gratis a %s: rimossa 1 Cellula %s (in Prigione)." % [best, enemy])
		if number == 12:
			state.resources["moderates"] = maxi(0, int(state.get_resources("moderates")) - 3)
			log.append("Moderati Risorse -3.")
		return true
	# #5 unshaded: piazza 2 Cellule amiche (o 1 Attiva) senza Supporto Attivo nemico.
	if number == 5 and side == "unshaded":
		var best5 := ""
		var bp5 := -1
		for sid in state.spaces.keys():
			var sd: SpaceDef = state.game_def.space(sid)
			var sup := int(state.space_state(sid).support)
			var blocked := (faction == "senate" and sup <= -2) or (faction == "reds" and sup >= 2) \
				or (faction == "moderates" and absi(sup) >= 2)
			if not blocked and sd != null and sd.pop > bp5:
				bp5 = sd.pop
				best5 = String(sid)
		var placed5 := 0
		if best5 != "":
			placed5 = state.place_from_available(faction, "cell", best5, 2, "underground")
			state.recompute_control(best5)
		log.append("Piazzate %d Cellule %s a %s (scelta automatica)." % [placed5, faction, best5])
		return true
	# #9 unshaded: sposta uno spazio di un livello verso Supporto/Opposizione Attiva.
	if number == 9 and side == "unshaded":
		if faction == "reds":
			return _shift_best_pop(-1, log)
		if faction == "senate":
			return _shift_best_pop(1, log)
		return _shift_most_opposition(1, log)   # Moderati: riduci l'Opposizione più forte
	# #20 unshaded: rimuovi un Prepared o una Cellula da una Città.
	if number == 20 and side == "unshaded":
		var enemy20 := "reds" if faction == "senate" else "senate"
		for sid in state.spaces.keys():
			var sd: SpaceDef = state.game_def.space(sid)
			if sd == null or sd.type != CoinEnums.SpaceType.CITY:
				continue
			var st20: SpaceState = state.space_state(sid)
			if st20.marker("prepared_" + enemy20) > 0:
				st20.set_marker("prepared_" + enemy20, 0)
				log.append("Rimosso il marker Prepared %s a %s." % [enemy20, sid])
				return true
			if st20.count(enemy20, "cell") > 1:   # mai l'ultima (proteggerebbe marker)
				st20.remove_piece(enemy20, "cell", 1, "underground" if st20.count(enemy20, "cell", "underground") > 0 else "active")
				state.recompute_control(String(sid))
				log.append("Rimossa 1 Cellula %s a %s." % [enemy20, sid])
				return true
		log.append("Nessun bersaglio valido in Città: nessun effetto.")
		return true
	# #28 unshaded: conduci la fase Prigionieri di Guerra (§6.5.1).
	if number == 28 and side == "unshaded":
		var pris28: Dictionary = state.tracks.get("prisoners", {"senate": 0, "reds": 0})
		var tot := int(pris28.get("senate", 0)) + int(pris28.get("reds", 0))
		if int(state.tracks.get("polarization", 0)) >= 6:
			state.tracks["prisoners"] = {"senate": 0, "reds": 0}
			log.append("Prigionieri (§6.5.1): tutti rilasciati (Polarization ≥ 6).")
		elif tot >= 2:
			var bump := int(tot / 2)
			state.tracks["polarization"] = clampi(int(state.tracks.get("polarization", 0)) + bump, 0, 10)
			log.append("Prigionieri (§6.5.1): Polarization +%d." % bump)
		else:
			log.append("Prigionieri (§6.5.1): nessun effetto (%d in prigione)." % tot)
		return true
	# #30 unshaded: in uno spazio con pezzi amici, rimuovi fino a 2 Cellule Moderati.
	if number == 30 and side == "unshaded":
		var best30 := ""
		var bc30 := 0
		for sid in state.spaces.keys():
			var st30: SpaceState = state.space_state(sid)
			if st30.count(faction, "cell") + st30.count(faction, "admin") + st30.count(faction, "troops") > 0 \
					and st30.count("moderates", "cell") > bc30:
				bc30 = st30.count("moderates", "cell")
				best30 = String(sid)
		if best30 == "":
			log.append("Nessuno spazio con pezzi amici e Cellule Moderati.")
			return true
		var stm: SpaceState = state.space_state(best30)
		for _k in range(mini(2, bc30)):
			stm.remove_piece("moderates", "cell", 1, "active" if stm.count("moderates", "cell", "active") > 0 else "underground")
		state.recompute_control(best30)
		log.append("Rimosse %d Cellule Moderati a %s." % [mini(2, bc30), best30])
		return true
	# #36 unshaded: rimuovi 2 Cellule Senato e/o Reds dalla mappa (in Disponibili).
	if number == 36 and side == "unshaded":
		var removed36 := 0
		for enemy36 in (["senate", "reds"] if faction == "moderates" else [("reds" if faction == "senate" else "senate")]):
			var best36 := ""
			var bc36 := 1   # mai l'ultima Cellula (proteggerebbe marker)
			for sid in state.spaces.keys():
				if state.space_state(sid).count(String(enemy36), "cell") > bc36:
					bc36 = state.space_state(sid).count(String(enemy36), "cell")
					best36 = String(sid)
			if best36 != "" and removed36 < 2:
				var ste: SpaceState = state.space_state(best36)
				ste.remove_piece(String(enemy36), "cell", 1, "underground" if ste.count(String(enemy36), "cell", "underground") > 0 else "active")
				state.recompute_control(best36)
				removed36 += 1
				log.append("Rimossa 1 Cellula %s a %s (in Disponibili)." % [enemy36, best36])
		if removed36 == 0:
			log.append("Nessuna Cellula rimovibile.")
		return true
	# #7 shaded: Moderati e poi Reds piazzano 1 Cellula ciascuno; poi 1 cubo PD.
	if number == 7 and side == "shaded":
		for f7 in ["moderates", "reds"]:
			var best7 := ""
			var bp7 := -1
			for sid in state.spaces.keys():
				var sd7: SpaceDef = state.game_def.space(sid)
				if int(state.space_state(sid).support) < 2 and sd7 != null and sd7.pop > bp7:
					bp7 = sd7.pop
					best7 = String(sid)
			if best7 != "" and state.place_from_available(String(f7), "cell", best7, 1, "underground") > 0:
				state.recompute_control(best7)
				log.append("Cellula %s piazzata a %s." % [f7, best7])
		var pd7 := ABBPoliticalDisplay.new(state)
		var color7 := "senate" if faction == "senate" else "reds"
		pd7.place_cubes(color7, 1)
		log.append("+1 cubo %s nel Political Display." % color7)
		return true
	# #12 shaded (Moderati): SA o Lim Cmd gratis → Dialogue sullo spazio più estremo.
	if number == 12 and side == "shaded" and faction == "moderates":
		return _free_moderates_dialogue(log)
	# #25/#27/#32: shaded = stesso effetto del Chiaro.
	if number == 25 and side == "shaded":
		return _apply_basic_effect(25, "unshaded", faction, log)
	if number == 27 and side == "shaded":
		return _free_senate_attack_plus2(log)
	if number == 32 and side == "shaded":
		return _remove_moderates_cell_anywhere(log, faction)
	# #31 shaded: Moderati o Reds — Lim Cmd gratis in Uusimaa (escl. Attack).
	if number == 31 and side == "shaded":
		var f31 := faction if faction in ["moderates", "reds"] else "reds"
		if state.place_from_available(f31, "cell", "uusimaa", 1, "underground") > 0:
			state.recompute_control("uusimaa")
			log.append("Lim Cmd gratis: Cellula %s a Uusimaa." % f31)
		else:
			log.append("Nessuna Cellula %s disponibile per Uusimaa." % f31)
		return true
	# #33 shaded: Fazione non-Senato — Lim Cmd gratis a Helsinki o adiacente.
	if number == 33 and side == "shaded":
		var f33 := faction if faction != "senate" else "reds"
		if state.place_from_available(f33, "cell", "helsinki", 1, "underground") > 0:
			state.recompute_control("helsinki")
			log.append("Lim Cmd gratis: Cellula %s a Helsinki." % f33)
		else:
			log.append("Nessuna Cellula %s disponibile per Helsinki." % f33)
		return true
	# #34 shaded: Moderati — Rally gratis in uno spazio.
	if number == 34 and side == "shaded":
		var best34 := ""
		var bc34 := -1
		for sid in state.spaces.keys():
			if state.space_state(sid).count("moderates", "cell") > bc34:
				bc34 = state.space_state(sid).count("moderates", "cell")
				best34 = String(sid)
		if best34 != "" and state.place_from_available("moderates", "cell", best34, 1, "underground") > 0:
			state.recompute_control(best34)
			log.append("Rally Moderati gratis a %s." % best34)
		else:
			log.append("Nessuna Cellula Moderati disponibile.")
		return true
	# #38 shaded: Moderati — SA gratis → Dialogue.
	if number == 38 and side == "shaded":
		return _free_moderates_dialogue(log)
	# #39 shaded: Moderati piazzano un Network Disponibile.
	if number == 39 and side == "shaded":
		if not _place_network_most_cells(log):
			log.append("Nessun Network Moderati disponibile.")
		return true
	# #44 shaded: se Reds a Helsinki → shift verso Opposizione o Rally Reds lì.
	if number == 44 and side == "shaded":
		if state.spaces.has("helsinki") and state.space_state("helsinki").count("reds", "cell") > 0:
			if int(state.space_state("helsinki").support) > -2:
				return _shift_space("helsinki", -1, log)
			var r44: Dictionary = ops.rally("reds", "helsinki", "cell")
			if r44.get("ok", false):
				log.append("Rally Reds gratis a Helsinki.")
			return true
		log.append("Nessun pezzo Reds a Helsinki: nessun effetto.")
		return true
	return false


## Dialogue gratuito dei Moderati sullo spazio col Supporto/Opposizione più estremo.
func _free_moderates_dialogue(log: Array[String]) -> bool:
	var best := ""
	var bd := 0
	for sid in state.spaces.keys():
		var st: SpaceState = state.space_state(sid)
		if st.count("moderates", "cell") > 0 and absi(int(st.support)) > bd:
			bd = absi(int(st.support))
			best = String(sid)
	if best == "":
		log.append("Dialogue: nessuno spazio con Cellula Moderati e Supporto/Opposizione.")
		return true
	var sp := ABBSpecialActivities.new(state, module)
	sp.dialogue(best)
	log.append("Dialogue Moderati gratis a %s." % best)
	return true


## #27: Attack gratuito del Senato con +2 alla Forza, nello spazio migliore.
func _free_senate_attack_plus2(log: Array[String]) -> bool:
	var best := ""
	var bc := 0
	for sid in state.spaces.keys():
		var st: SpaceState = state.space_state(sid)
		var mine := st.count("senate", "cell")
		if mine > 0 and (st.count("reds", "cell") > 0 or st.count("russians", "troops") > 0) and mine > bc:
			bc = mine
			best = String(sid)
	if best == "":
		log.append("#27: nessuno spazio con pezzi Senato e nemici.")
		return true
	var st27: SpaceState = state.space_state(best)
	var strength := st27.count("senate", "cell") + 2
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var roll := rng.randi_range(1, 6)
	if roll > strength:
		log.append("#27 Attack gratis a %s: mancato (tiro %d vs forza %d)." % [best, roll, strength])
		return true
	for pair in [["reds", "cell", "active"], ["russians", "troops", ""], ["reds", "cell", "underground"], ["reds", "admin", ""]]:
		if st27.count(pair[0], pair[1], pair[2]) > 0:
			st27.remove_piece(pair[0], pair[1], 1, pair[2])
			state.recompute_control(best)
			log.append("#27 Attack gratis a %s: rimosso 1 %s %s (tiro %d vs forza %d)." % [best, pair[0], pair[1], roll, strength])
			return true
	log.append("#27 Attack gratis a %s: colpito, nessun pezzo rimovibile." % best)
	return true


## #32: rimuovi una Cellula Moderati ovunque (transfer Personality se ultima).
func _remove_moderates_cell_anywhere(log: Array[String], exec_fid: String) -> bool:
	var best := ""
	var bc := 0
	for sid in state.spaces.keys():
		if state.space_state(sid).count("moderates", "cell") > bc:
			bc = state.space_state(sid).count("moderates", "cell")
			best = String(sid)
	if best == "":
		log.append("Nessuna Cellula Moderati sulla mappa.")
		return true
	var st: SpaceState = state.space_state(best)
	st.remove_piece("moderates", "cell", 1, "active" if st.count("moderates", "cell", "active") > 0 else "underground")
	# Personality transfer (§4.3.1) se era l'ultima con Personality.
	if st.count("moderates", "cell") == 0 and st.marker("personality") > 0:
		st.set_marker("personality", 0)
		var delta := mini(3, int(state.get_resources("moderates")))
		state.resources["moderates"] = int(state.get_resources("moderates")) - delta
		if exec_fid in ["reds", "senate"]:
			state.resources[exec_fid] = int(state.get_resources(exec_fid)) + delta
		log.append("Personality rimossa: Moderati trasferiscono %d Risorse a %s." % [delta, exec_fid])
	state.recompute_control(best)
	log.append("Rimossa 1 Cellula Moderati a %s." % best)
	return true


## Helper: shift Sup/Opp di uno spazio.
func _shift_support(st: SpaceState, delta: int) -> void:
	st.support = clampi(st.support + delta, -2, 2)


func _adjust_vassal(power: String, delta: int, log: Array[String]) -> void:
	var key := "vassalage_" + power
	var cur := int(state.tracks.get(key, 0))
	state.tracks[key] = clampi(cur + delta, 0, 6)
	log.append("Vassalaggio %s %s%d → %d." % [power, "+" if delta >= 0 else "", delta, state.tracks[key]])


## Piazza il marker Capability associato al numero della carta + side.
## Cards 1/10/16/26 = Jaeger Senato (Phase II → Vaasa o Town con Senate Cell).
## Card 16 shaded = Commander Reds (Phase II → Town con Reds Cell).
## Cards 14/15/17 = Cannons / Trains: global capability marker, no spazio specifico.
func _place_capability_marker(number: int, side: String, log: Array[String]) -> void:
	var ph := int(state.tracks.get("phase", 1))
	if number == 24:
		return  # Red Revolt non è capability classica
	# Determina chi e che tipo di marker.
	var marker_key := ""
	var preferred_space := ""
	var faction := "senate"
	if number == 16 and side == "shaded":
		marker_key = "commander_reds"
		faction = "reds"
	elif number in [1, 10, 16, 26]:
		marker_key = "jaeger_senate"
		preferred_space = "vaasa"
	elif number == 14:
		marker_key = "cannons"
	elif number in [15, 17]:
		marker_key = "trains"
	else:
		return
	# Cannons/Trains: marker globale non spaziale per ora.
	if marker_key in ["cannons", "trains"]:
		state.tracks[marker_key] = int(state.tracks.get(marker_key, 0)) + 1
		log.append("Marker %s globale +1." % marker_key)
		return
	# Jaeger/Commander richiedono Phase II e uno spazio con Cellula amica.
	if ph < 2:
		log.append("Marker %s prenotato — verrà piazzato in Phase II." % marker_key)
		state.tracks["pending_" + marker_key] = int(state.tracks.get("pending_" + marker_key, 0)) + 1
		return
	var target := preferred_space
	if target == "" or state.space_state(target).count(faction, "cell") <= 0:
		# Cerca prima Town poi Provincia con Cellula amica.
		for sid in state.spaces.keys():
			if state.space_state(sid).count(faction, "cell") > 0:
				target = String(sid)
				break
	if target == "":
		log.append("Marker %s: nessuna Cellula %s disponibile, non piazzato." % [marker_key, faction])
		return
	var st: SpaceState = state.space_state(target)
	st.set_marker(marker_key, st.marker(marker_key) + 1)
	log.append("Marker %s piazzato a %s." % [marker_key, target])


## Red Revolt! (Pivotal, #24): trigger Phase II — i Germans cominciano ad agire
## via flowchart, e la carta esce dal mazzo.
func _red_revolt(side: String, faction: String) -> Dictionary:
	var log: Array[String] = []
	var prev := int(state.tracks.get("phase", 1))
	if prev >= 2:
		log.append("Red Revolt! ha già attivato la Phase II — nessun effetto.")
		return {"ok": true, "log": log}
	state.tracks["phase"] = 2
	log.append("Red Revolt! (%s): parte la Phase II — i Germans ora agiscono via flowchart (§3.4)." % side)
	# §2.4.1 ❷ — azione gratuita dei Reds. Per i bot, instruction sheet #24:
	# ❶ rimuovi le Cellule Senato (e i Prepared) a Helsinki, ❷ altrimenti Rally lì.
	if String(state.roles.get("reds", "player")) == "bot" and state.spaces.has("helsinki"):
		var hl: SpaceState = state.space_state("helsinki")
		var sen := hl.count("senate", "cell")
		if hl.count("reds", "cell") > 0 and sen > 0:
			for st_name in ["active", "underground"]:
				while hl.count("senate", "cell", st_name) > 0:
					hl.remove_piece("senate", "cell", 1, st_name)
			hl.set_marker("prepared_senate", 0)
			state.recompute_control("helsinki")
			log.append("§2.4.1: rimosse %d Cellule Senato (e Prepared) a Helsinki." % sen)
		else:
			var rr: Dictionary = ABBOperations.new(state, module).rally("reds", "helsinki", "cell")
			if rr.get("ok", false):
				log.append("§2.4.1: Rally Reds gratuito a Helsinki.")
	# §2.4.1 ❸ — i marker Capability "prenotati" in Phase I (Jaeger/Commander,
	# §5.3) si piazzano ORA (prima Reds, poi Senato — Jaeger su Vaasa).
	_deploy_pending_capabilities(log)
	# §2.4.1 ❹ — Powers allineati al Vassalaggio (Germans in Available; Russi
	# in una Town casuale con pezzi Reds). Riusa la logica §6.5.3 del Crisis.
	var pw: Dictionary = ABBCrisis.new(state, module)._powers_adjustment()
	for line in pw.get("log", []):
		log.append("§2.4.1: %s" % line)
	return {"ok": true, "log": log}


## Piazza i marker Capability prenotati in Phase I (pending_*): Jaeger su Vaasa
## (o spazio con Cellula Senato), Commander su uno spazio con Cellula Reds.
func _deploy_pending_capabilities(log: Array[String]) -> void:
	for spec in [["jaeger_senate", "senate", "vaasa"], ["commander_reds", "reds", ""]]:
		var key: String = spec[0]
		var faction: String = spec[1]
		var n := int(state.tracks.get("pending_" + key, 0))
		if n <= 0:
			continue
		state.tracks["pending_" + key] = 0
		for _i in range(n):
			var target: String = spec[2]
			if target == "" or state.space_state(target).count(faction, "cell") <= 0:
				target = ""
				for sid in state.spaces.keys():
					if state.space_state(sid).count(faction, "cell") > 0:
						target = String(sid)
						break
			if target == "":
				log.append("Marker %s: nessuna Cellula %s sulla mappa, non piazzato." % [key, faction])
				continue
			var st: SpaceState = state.space_state(target)
			st.set_marker(key, st.marker(key) + 1)
			log.append("Marker %s piazzato a %s (Phase II)." % [key, target])
