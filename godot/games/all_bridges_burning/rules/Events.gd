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
	# Capacità: il titolo entra in active_capabilities + un marker viene
	# piazzato su uno spazio amico (in Phase II per Jaeger; Phase I per Cannons/Trains
	# che vivono come token globali). Per ABB:
	#  - Cannons (#14), Trains (#15, #17): marker globale (Senate Capability)
	#  - Jaeger (#1, #10, #16, #26): Senate Jaeger marker — Vaasa Phase II
	#  - Commander (#16 shaded): Reds Commander marker
	if card != null and card.is_capability:
		if not state.active_capabilities.has(title):
			state.active_capabilities.append(title)
			log.append("Capacità attivata: %s." % title)
			_place_capability_marker(number, side, log)
		else:
			log.append("Capacità %s già attiva." % title)
		return {"ok": true, "log": log}
	log.append("Evento %s [%s] non implementato (stub)." % [title, side])
	return {"ok": true, "log": log}


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
