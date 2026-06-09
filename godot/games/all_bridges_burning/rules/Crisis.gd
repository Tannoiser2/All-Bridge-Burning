class_name ABBCrisis
extends RefCounted

## Crisis Round All Bridges Burning (rulebook §6.0).

var state: GameState
var module: RulesModule

func _init(_state: GameState, _module: RulesModule) -> void:
	state = _state
	module = _module


func resolve() -> Dictionary:
	return {"politics": _politics_phase(), "earnings": _earnings_phase()}


func _politics_phase() -> Dictionary:
	var cur: int = int(state.tracks.get("issues_networks", 0))
	state.tracks["issues_networks"] = cur + 1
	return {"issues_resolved": 1, "total": state.tracks["issues_networks"]}


func _earnings_phase() -> Dictionary:
	var earnings := {}
	for f in state.game_def.factions:
		var fid: String = f.id
		var gain: int = _earnings_for(fid)
		earnings[fid] = gain
		state.resources[fid] = int(state.get_resources(fid)) + gain
	return earnings


func _earnings_for(fid: String) -> int:
	match fid:
		"reds":
			var gain_r: int = 0
			for sid in state.spaces.keys():
				var st: SpaceState = state.space_state(sid)
				if st.count("reds", "cell") > 0 or st.count("reds", "admin") > 0:
					gain_r += state.game_def.space(sid).pop
			return gain_r
		"senate":
			var gain_s: int = 0
			for sid in state.spaces.keys():
				var st: SpaceState = state.space_state(sid)
				if st.count("senate", "cell") > 0:
					gain_s += state.game_def.space(sid).pop
			return gain_s
		"moderates":
			return 1 + state.count_on_map("moderates", "network")
		"germans":
			return int(state.tracks.get("vassalage_german", 0)) / 2
		_:
			return 0
