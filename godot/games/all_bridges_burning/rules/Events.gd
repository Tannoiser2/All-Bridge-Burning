class_name ABBEvents
extends RefCounted

## Stub Eventi ABB. Da popolare a partire da `ABB_CardEdits-download.pdf` e dal
## regolamento (~70 carte evento + carte Crisis).

var state: GameState
var module: RulesModule

func _init(_state: GameState, _module: RulesModule) -> void:
	state = _state
	module = _module
