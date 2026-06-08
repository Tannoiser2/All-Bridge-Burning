class_name ABBCrisis
extends RefCounted

## Stub round periodico ("Crisis" in ABB, equivalente della Propaganda di Cuba Libre).
## TODO: implementare al PR "round periodico".

var state: GameState
var module: RulesModule

func _init(_state: GameState, _module: RulesModule) -> void:
	state = _state
	module = _module
