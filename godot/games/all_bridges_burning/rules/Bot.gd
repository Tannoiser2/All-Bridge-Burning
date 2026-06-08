class_name ABBBot
extends RefCounted

## Sistema Non-giocatore (NP) All Bridges Burning (rulebook §8.0).
##
## ABB usa 17 carte "Solitaire system cards" + il flowchart PAC2 per le
## decisioni di ogni fazione NP. Questo PR fornisce uno SCAFFOLD del bot:
## decide casualmente fra le Operazioni legali e ne applica una.
##
## Il pieno motore PAC2 (priorità nidificate, sliding-window, condizioni
## per Operation+Special Activity) sarà implementato in PR successivi sulla
## base di:
##   - Materiale ABB/ABBPAC2FlowchartsLivingOct-20.pdf
##   - Materiale ABB/All Bridges Burning Carte Bot.pdf
##   - Materiale ABB/All Bridges Burning Tabelle.pdf

var state: GameState
var module: RulesModule

func _init(_state: GameState, _module: RulesModule) -> void:
	state = _state
	module = _module


## Punto d'ingresso usato da GameController. Decide e applica un turno
## per `faction_id`. Restituisce: {"action": String, "trace": Array, ...}.
func take_turn(faction_id: String, _allow_special: bool = true, _limited: bool = false) -> Dictionary:
	var trace: Array = []
	# Scaffold: tira un dado, scegli Op casuale fra Rally / March / Attack / Terror
	# (saltando quelle che la fazione non possiede in factions.json).
	var fdef: FactionDef = state.game_def.faction(faction_id)
	if fdef == null or fdef.operations.is_empty():
		return {"action": "pass", "trace": ["fazione senza operazioni → pass"]}

	var ops := ABBOperations.new(state, module)
	var op_id: String = String(fdef.operations[randi() % fdef.operations.size()])
	trace.append("scelgo %s" % op_id)

	var target_sid: String = _pick_random_space()
	var result: Dictionary = {}
	match op_id:
		"rally":
			result = ops.rally(faction_id, target_sid, "cell")
		"march":
			# Per March serve from→to: scegli uno spazio con pezzi della fazione,
			# se non c'è cade su Rally.
			var from_sid: String = _find_space_with(faction_id, "cell")
			if from_sid == "":
				result = ops.rally(faction_id, target_sid, "cell")
				trace.append("nessun pezzo da muovere → ripiego Rally")
			else:
				var adj: PackedStringArray = state.game_def.space(from_sid).adjacent
				if adj.is_empty():
					result = ops.rally(faction_id, target_sid, "cell")
				else:
					result = ops.march(faction_id, from_sid, String(adj[0]), "cell", 1)
		"attack":
			result = ops.attack(faction_id, target_sid)
		"terror":
			result = ops.terror(faction_id, target_sid)
		_:
			result = {"ok": false, "error": "Op non supportata: " + op_id}

	trace.append("risultato: %s" % JSON.stringify(result))
	return {"action": op_id, "result": result, "trace": trace}


## Event choice (mock): il bot non sceglie eventi nel scaffold; passa
## indicando lato "unshaded" come placeholder.
func event_choice(_faction_id: String, _card_number: int) -> Dictionary:
	return {"play_event": false, "side": "unshaded", "trace": ["scaffold: niente eventi"]}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _pick_random_space() -> String:
	var keys: Array = state.spaces.keys()
	if keys.is_empty():
		return ""
	return String(keys[randi() % keys.size()])


func _find_space_with(faction_id: String, piece_type: String) -> String:
	for sid in state.spaces.keys():
		if state.space_state(sid).count(faction_id, piece_type) > 0:
			return String(sid)
	return ""
