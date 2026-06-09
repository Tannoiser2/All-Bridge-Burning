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
	log.append("Evento %s [%s] non implementato (stub)." % [title, side])
	return {"ok": true, "log": log}


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
