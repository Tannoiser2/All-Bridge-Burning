class_name ABBOperations
extends RefCounted

## Stub Operazioni All Bridges Burning. Le 4 Operazioni standard COIN per ABB
## sono (da rulebook): Rally, March, Attack, Terror — con varianti gioco-specifiche.
## TODO: implementare al primo PR "Operazioni".

var state: GameState
var module: RulesModule

func _init(_state: GameState, _module: RulesModule) -> void:
	state = _state
	module = _module
