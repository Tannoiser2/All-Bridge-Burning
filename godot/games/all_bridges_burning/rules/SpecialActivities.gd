class_name ABBSpecialActivities
extends RefCounted

## Stub Attività Speciali ABB.
## TODO: implementare al PR "Attività Speciali".

var state: GameState
var module: RulesModule

func _init(_state: GameState, _module: RulesModule) -> void:
	state = _state
	module = _module
