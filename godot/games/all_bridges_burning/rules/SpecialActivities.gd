class_name ABBSpecialActivities
extends RefCounted

## Attività Speciali ABB (rulebook §4.0).

var state: GameState
var module: RulesModule

func _init(_state: GameState, _module: RulesModule) -> void:
	state = _state
	module = _module


# Reds
func agitate(sid: String) -> Dictionary:
	if not _has_cell("reds", sid):
		return _err("serve una Cellula Reds in %s" % sid)
	# §8.1.2: solo i player pagano; le Bot non spendono Risorse.
	if state.tracks_resources("reds"):
		if state.get_resources("reds") < 1:
			return _err("risorse Reds insufficienti")
		state.resources["reds"] -= 1
	_shift_support(sid, -1)
	return _ok()


func ambush(sid: String) -> Dictionary:
	var st: SpaceState = state.space_state(sid)
	if st.count("reds", "cell", "underground") <= 0:
		return _err("serve una Cellula Reds clandestina")
	st.remove_piece("reds", "cell", 1, "underground")
	st.add_piece("reds", "cell", 1, "active")
	var removed: int = 0
	for pair in [["senate", "cell", "active"], ["moderates", "cell", "active"], ["senate", "cell", "underground"], ["russians", "troops", ""], ["germans", "troops", ""]]:
		while removed < 2 and st.count(pair[0], pair[1], pair[2]) > 0:
			st.remove_piece(pair[0], pair[1], 1, pair[2])
			removed += 1
		if removed >= 2:
			break
	state.recompute_control(sid)
	return _ok({"removed": removed})


func subvert(sid: String) -> Dictionary:
	var st: SpaceState = state.space_state(sid)
	if st.count("reds", "cell", "underground") <= 0:
		return _err("serve una Cellula Reds clandestina")
	for f in ["senate", "moderates"]:
		if st.count(f, "cell") > 0:
			if st.count(f, "cell", "active") > 0:
				st.remove_piece(f, "cell", 1, "active")
			else:
				st.remove_piece(f, "cell", 1, "underground")
			state.recompute_control(sid)
			return _ok({"target": f})
	return _err("nessuna Cellula avversaria")


# Senate
func crackdown(sid: String) -> Dictionary:
	var st: SpaceState = state.space_state(sid)
	if st.count("senate", "cell") <= 0:
		return _err("serve una Cellula Senate")
	var t: int = st.marker("terror")
	if t > 0:
		st.set_marker("terror", t - 1)
	# §8.1.2: solo i player pagano; le Bot non spendono Risorse.
	if state.tracks_resources("senate") and state.get_resources("senate") >= 1:
		state.resources["senate"] -= 1
	_shift_support(sid, +1)
	return _ok()


# Moderates
func dialogue(sid: String) -> Dictionary:
	if not _has_cell("moderates", sid):
		return _err("serve una Cellula Moderates in %s" % sid)
	var st: SpaceState = state.space_state(sid)
	if st.support > CoinEnums.Support.NEUTRAL:
		st.support = (st.support - 1) as CoinEnums.Support
	elif st.support < CoinEnums.Support.NEUTRAL:
		st.support = (st.support + 1) as CoinEnums.Support
	return _ok()


func foreign_relations(power: String, delta: int) -> Dictionary:
	if not (power == "germans" or power == "russians"):
		return _err("power non valido: %s" % power)
	var key: String = "vassalage_" + ("german" if power == "germans" else "russian")
	var cur: int = int(state.tracks.get(key, 3))
	state.tracks[key] = clampi(cur + delta, 0, 6)
	return _ok({"new_value": state.tracks[key]})


## Coordinate (§4.2.4, SOLO Senato, Phase II): piazza il marker Coordinate sul
## cilindro tedesco — la PROSSIMA azione tedesca del flowchart è decisa dal
## Senato. LIMITE MODELLO: il bot German consuma il marker loggandolo; le
## scelte di dettaglio restano quelle del flowchart.
func coordinate(fid: String) -> Dictionary:
	if fid != "senate":
		return _err("Coordinate: solo il Senato (§4.2.4)")
	if int(state.tracks.get("phase", 1)) < 2:
		return _err("Coordinate disponibile solo in Phase II")
	if int(state.tracks.get("coordinate_marker", 0)) == 1:
		return _err("marker Coordinate già piazzato")
	state.tracks["coordinate_marker"] = 1
	return _ok()


# Common
func tax(fid: String, sid: String) -> Dictionary:
	if not _has_cell(fid, sid):
		return _err("serve una Cellula %s in %s" % [fid, sid])
	var sd: SpaceDef = state.game_def.space(sid)
	var gain: int = sd.pop
	if gain <= 0:
		return _err("Pop=0")
	state.resources[fid] = int(state.get_resources(fid)) + gain
	return _ok({"gain": gain})


# Helpers
func _has_cell(fid: String, sid: String) -> bool:
	if not state.spaces.has(sid):
		return false
	return state.space_state(sid).count(fid, "cell") > 0


func _shift_support(sid: String, delta: int) -> void:
	var st: SpaceState = state.space_state(sid)
	var cur: int = int(st.support)
	var new_val: int = clampi(cur + delta, int(CoinEnums.Support.ACTIVE_OPPOSITION), int(CoinEnums.Support.ACTIVE_SUPPORT))
	st.support = new_val as CoinEnums.Support


func _ok(extra: Dictionary = {}) -> Dictionary:
	var d := {"ok": true, "error": ""}
	for k in extra.keys():
		d[k] = extra[k]
	return d

func _err(msg: String) -> Dictionary:
	return {"ok": false, "error": msg}
