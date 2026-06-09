class_name ABBBot
extends RefCounted

## Stub sistema Non-giocatore (NP) ABB. Il bot ABB usa carte Bot dedicate
## ("All Bridges Burning Carte Bot.pdf" + "PAC2 Flowcharts" in Materiale ABB/).
## TODO: implementare al PR "Bot NP".

var state: GameState
var module: RulesModule

func _init(_state: GameState, _module: RulesModule) -> void:
	state = _state
	module = _module

func think(_faction_id: String) -> Dictionary:
	return {}
