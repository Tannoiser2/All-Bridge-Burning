class_name ABBCrisis
extends RefCounted

## Crisis Round All Bridges Burning (rulebook §6.0).

var state: GameState
var module: RulesModule

func _init(_state: GameState, _module: RulesModule) -> void:
	state = _state
	module = _module


func resolve() -> Dictionary:
	var out: Dictionary = {
		"politics": _politics_phase(),
		"earnings": _earnings_phase(),
	}
	# §6.5.3 Powers adjustment: solo in Phase II.
	if int(state.tracks.get("phase", 1)) >= 2:
		out["powers"] = _powers_adjustment()
	# Conteggio Campaign per il bot (PAC2 last_campaign condition).
	state.tracks["campaign_count"] = int(state.tracks.get("campaign_count", 0)) + 1
	out["campaign"] = state.tracks["campaign_count"]
	return out


## §6.5.3 — Numero di Truppe Tedesche/Russe sulla mappa allineato al marker Vassalage.
## Germans entrano/escono nella Available Forces (non sulla mappa direttamente).
## Russians entrano in un Town casuale con pezzi Reds (se nessuno disponibile, da nessuna parte).
func _powers_adjustment() -> Dictionary:
	var out := {"germans_placed": 0, "germans_removed": 0,
		"russians_placed": 0, "russians_removed": 0, "log": []}

	var vg: int = clampi(int(state.tracks.get("vassalage_german", 0)), 0, 6)
	var on_g: int = state.count_on_map("germans", "troops")
	var diff_g: int = vg - on_g
	if diff_g > 0:
		# Place: prendi dalla Available, ma per ABB Germans non hanno una "scatola"
		# distinta — li lasciamo nel pool (force_pool - on_map). Quindi non li metto
		# sulla mappa: aggiorno solo il counter logico via remove_to_available su
		# null (i.e. lascio invariato lo state-on-map). Da rifinire con un sotto-
		# pool "out_of_play" quando lo introduciamo.
		out["germans_placed"] = diff_g
		out["log"].append("Germans Available +%d (Vassalage %d)" % [diff_g, vg])
	elif diff_g < 0:
		# Remove dal mappa fino a -diff_g
		var to_remove_g: int = -diff_g
		for sid in state.spaces.keys():
			if to_remove_g <= 0:
				break
			var st: SpaceState = state.space_state(sid)
			var n: int = st.count("germans", "troops")
			if n > 0:
				var k: int = mini(n, to_remove_g)
				state.remove_to_available("germans", "troops", sid, k, "")
				to_remove_g -= k
				out["germans_removed"] += k
		out["log"].append("Germans -%d dalla mappa (Vassalage %d)" % [out["germans_removed"], vg])

	var vr: int = clampi(int(state.tracks.get("vassalage_russian", 0)), 0, 6)
	var on_r: int = state.count_on_map("russians", "troops")
	var diff_r: int = vr - on_r
	if diff_r > 0:
		# Piazza in un Town con pezzi Reds (se nessuno, nulla succede).
		var candidates: Array = []
		for sid in state.spaces.keys():
			var sd: SpaceDef = state.game_def.space(sid)
			if sd.type != CoinEnums.SpaceType.CITY:
				continue
			var st2: SpaceState = state.space_state(sid)
			if st2.count("reds", "cell") > 0 or st2.count("reds", "admin") > 0:
				candidates.append(sid)
		if not candidates.is_empty():
			var target: String = String(candidates[0])  # deterministico (no RNG nel modulo)
			var placed: int = state.place_from_available("russians", "troops", target, diff_r, "")
			out["russians_placed"] = placed
			out["log"].append("Russians +%d a %s (Vassalage %d)" % [placed, target, vr])
		else:
			out["log"].append("Russians: nessun Town con pezzi Reds, nulla piazzato (Vassalage %d)" % vr)
	elif diff_r < 0:
		var to_remove_r: int = -diff_r
		for sid in state.spaces.keys():
			if to_remove_r <= 0:
				break
			var st3: SpaceState = state.space_state(sid)
			var n: int = st3.count("russians", "troops")
			if n > 0:
				var k: int = mini(n, to_remove_r)
				state.remove_to_available("russians", "troops", sid, k, "")
				to_remove_r -= k
				out["russians_removed"] += k
		out["log"].append("Russians -%d dalla mappa (Vassalage %d)" % [out["russians_removed"], vr])

	return out


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
