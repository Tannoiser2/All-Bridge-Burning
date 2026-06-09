class_name ABBOperations
extends RefCounted

## Operazioni All Bridges Burning (rulebook §3.0).
## Rally, March, Attack, Terror — logica core (varianti fazione-specifiche TODO).

var state: GameState
var module: RulesModule

func _init(_state: GameState, _module: RulesModule) -> void:
	state = _state
	module = _module


## Rally (§3.2.1): piazza 1 Cell/Admin/Network in uno spazio. Costo: 1 Risorsa.
func rally(fid: String, sid: String, mode: String = "cell") -> Dictionary:
	if not state.spaces.has(sid):
		return _err("spazio sconosciuto: %s" % sid)
	var fdef: FactionDef = state.game_def.faction(fid)
	if fdef == null:
		return _err("fazione sconosciuta: %s" % fid)
	if not _can_place(fid, mode):
		return _err("forze esaurite (%s/%s)" % [fid, mode])
	if state.get_resources(fid) < 1:
		return _err("risorse insufficienti")
	state.resources[fid] -= 1
	var pt_state: String = "underground" if mode == "cell" else ""
	state.spaces[sid].add_piece(fid, mode, 1, pt_state)
	state.recompute_control(sid)
	return _ok()


## March (§3.2.5): sposta pezzi verso spazio adiacente.
func march(fid: String, from_sid: String, to_sid: String, piece_type: String = "cell", count: int = 1) -> Dictionary:
	if not state.spaces.has(from_sid) or not state.spaces.has(to_sid):
		return _err("spazio non valido")
	var sd: SpaceDef = state.game_def.space(from_sid)
	if not (to_sid in sd.adjacent):
		return _err("spazi non adiacenti")
	var from_state: String = "underground" if piece_type == "cell" else ""
	if state.space_state(from_sid).count(fid, piece_type, from_state) < count:
		return _err("pezzi insufficienti")
	state.spaces[from_sid].remove_piece(fid, piece_type, count, from_state)
	var to_state: String = ""
	if piece_type == "cell":
		to_state = "active" if _has_enemy(to_sid, fid) else "underground"
	state.spaces[to_sid].add_piece(fid, piece_type, count, to_state)
	state.recompute_control(from_sid)
	state.recompute_control(to_sid)
	return _ok()


## Attack (§3.2.4): 1d6 vs Attack Strength.
func attack(fid: String, sid: String, rng_seed: int = -1) -> Dictionary:
	if not state.spaces.has(sid):
		return _err("spazio sconosciuto")
	var st: SpaceState = state.space_state(sid)
	var strength: int = st.count(fid, "cell") + st.count(fid, "troops")
	if strength <= 0:
		return _err("nessun pezzo attaccante")
	var rng := RandomNumberGenerator.new()
	if rng_seed >= 0:
		rng.seed = rng_seed
	else:
		rng.randomize()
	var roll: int = (rng.randi() % 6) + 1
	if roll > strength:
		return _ok({"roll": roll, "strength": strength, "hit": false})
	var enemy_fid: String = _first_enemy(sid, fid)
	if enemy_fid == "":
		return _ok({"roll": roll, "strength": strength, "hit": true, "removed": 0})
	for pair in [["cell", "active"], ["troops", ""], ["cell", "underground"], ["admin", ""], ["network", ""]]:
		if st.count(enemy_fid, pair[0], pair[1]) > 0:
			st.remove_piece(enemy_fid, pair[0], 1, pair[1])
			state.recompute_control(sid)
			return _ok({"roll": roll, "strength": strength, "hit": true, "removed": 1, "target": enemy_fid, "piece": pair[0]})
	return _ok({"roll": roll, "strength": strength, "hit": true, "removed": 0})


## Terror (§3.2.3): poni Terror marker; sposta Supporto/Opposizione.
func terror(fid: String, sid: String) -> Dictionary:
	if not state.spaces.has(sid):
		return _err("spazio sconosciuto")
	var st: SpaceState = state.space_state(sid)
	if st.count(fid, "cell") <= 0:
		return _err("serve una Cellula in %s" % sid)
	st.set_marker("terror", st.marker("terror") + 1)
	if fid == "reds":
		_shift_support(sid, -1)
	elif fid == "senate":
		_shift_support(sid, +1)
	return _ok()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _can_place(fid: String, piece_type: String) -> bool:
	var fdef: FactionDef = state.game_def.faction(fid)
	if fdef == null:
		return false
	var max_count: int = int(fdef.force_pool.get(piece_type, 0))
	if max_count <= 0:
		return false
	return state.count_on_map(fid, piece_type) < max_count


func _has_enemy(sid: String, fid: String) -> bool:
	var st: SpaceState = state.space_state(sid)
	for f in state.game_def.factions:
		if f.id == fid:
			continue
		for pt in ["cell", "troops", "admin", "network"]:
			if st.count(f.id, pt) > 0:
				return true
	return false


func _first_enemy(sid: String, fid: String) -> String:
	var st: SpaceState = state.space_state(sid)
	for f in state.game_def.factions:
		if f.id == fid:
			continue
		for pt in ["cell", "troops", "admin", "network"]:
			if st.count(f.id, pt) > 0:
				return f.id
	return ""


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
