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
	# Effetti atomici per le carte più frequenti.
	var handled := _apply_basic_effect(number, side, faction, log)
	if not handled:
		log.append("Evento %s [%s] non ancora implementato." % [title, side])
	return {"ok": true, "log": log}


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
				state.tracks["issues_networks"] = maxi(0, int(state.tracks.get("issues_networks", 0)) - 1)
				log.append("Rimosso Resolved Issue: %s." % ABBPoliticalDisplay.ISSUES[i]["name"])
				return true
	return false


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
	log.append("Red Revolt! (%s) giocata da %s: parte la Phase II — i Germans ora agiscono via flowchart (§3.4)." % [side, faction])
	return {"ok": true, "log": log}
