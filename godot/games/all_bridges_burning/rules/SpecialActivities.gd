class_name ABBSpecialActivities
extends RefCounted

## Attività Speciali All Bridges Burning (rulebook §4.0).
##
## Ogni Attività Speciale richiede aver svolto una specifica Operazione nello
## stesso turno (vedi rulebook §4.1.1 Accompanying). Questo livello del PR
## implementa la mutazione minima dello stato; le pre-condizioni precise
## (Operazione di accompagnamento, costi avanzati, target legali) sono TODO
## annotato sopra ogni funzione.
##
## Convenzioni di ritorno: `{"ok": bool, "error": String, ...}`.

var state: GameState
var module: RulesModule

func _init(_state: GameState, _module: RulesModule) -> void:
	state = _state
	module = _module


# ---------------------------------------------------------------------------
# Reds (rulebook §4.x)
# ---------------------------------------------------------------------------

## **Agitate** (§4.2.5 — analogo al Cuba "Agit"): spende Risorse per
## diminuire 1 step di Supporto in uno spazio dove i Reds hanno una Cell.
func agitate(sid: String) -> Dictionary:
	if not _has_cell("reds", sid):
		return _err("serve una Cellula Reds in %s" % sid)
	if state.get_resources("reds") < 1:
		return _err("risorse Reds insufficienti")
	state.resources["reds"] -= 1
	_shift_support(sid, -1)  # verso Opposition
	return _ok()


## **Ambush** (§4.x): in uno spazio scelto per Attack, rimuovi 2 pezzi nemici
## ignorando il tiro di dado.
func ambush(sid: String) -> Dictionary:
	var st: SpaceState = state.space_state(sid)
	if st.count("reds", "cell", "underground") <= 0:
		return _err("serve una Cellula Reds clandestina in %s" % sid)
	# Attiva la Cellula
	st.remove_piece("reds", "cell", 1, "underground")
	st.add_piece("reds", "cell", 1, "active")
	# Rimuove fino a 2 pezzi nemici (priorità: cell active → troops)
	var removed: int = 0
	for pair in [["senate", "cell", "active"], ["moderates", "cell", "active"], ["senate", "cell", "underground"], ["russians", "troops", ""], ["germans", "troops", ""]]:
		while removed < 2 and st.count(pair[0], pair[1], pair[2]) > 0:
			st.remove_piece(pair[0], pair[1], 1, pair[2])
			removed += 1
		if removed >= 2:
			break
	state.recompute_control(sid)
	return _ok({"removed": removed})


# ---------------------------------------------------------------------------
# Senate (rulebook §4.x)
# ---------------------------------------------------------------------------

## **Crackdown** (§4.x — analogo al Cuba "Crackdown"): rimuovi 1 marker
## Terror e sposta 1 Risorsa Senate per ogni Cellula attiva tua nello spazio.
func crackdown(sid: String) -> Dictionary:
	var st: SpaceState = state.space_state(sid)
	if st.count("senate", "cell") <= 0:
		return _err("serve una Cellula Senate in %s" % sid)
	var t: int = st.marker("terror")
	if t > 0:
		st.set_marker("terror", t - 1)
	# Costo: 1 Risorsa Senate
	if state.get_resources("senate") >= 1:
		state.resources["senate"] -= 1
	_shift_support(sid, +1)
	return _ok()


## **Coordinate** (§4.x): coordina le Truppe Russe/Tedesche con le Cellule
## Senate. Stub: muove 1 Russian Troop verso uno spazio adiacente.
func coordinate(from_sid: String, to_sid: String) -> Dictionary:
	if not state.spaces.has(from_sid) or not state.spaces.has(to_sid):
		return _err("spazio non valido")
	var sd: SpaceDef = state.game_def.space(from_sid)
	if not (to_sid in sd.adjacent):
		return _err("spazi non adiacenti")
	var st: SpaceState = state.space_state(from_sid)
	if st.count("russians", "troops") <= 0 and st.count("germans", "troops") <= 0:
		return _err("nessuna Truppa Russa o Tedesca da spostare")
	var power: String = "russians" if st.count("russians", "troops") > 0 else "germans"
	st.remove_piece(power, "troops", 1, "")
	state.space_state(to_sid).add_piece(power, "troops", 1, "")
	state.recompute_control(from_sid)
	state.recompute_control(to_sid)
	return _ok({"power": power})


# ---------------------------------------------------------------------------
# Moderates (rulebook §4.x)
# ---------------------------------------------------------------------------

## **Dialogue** (§4.x): sposta Supporto/Opposizione verso Neutral in uno
## spazio dove i Moderates hanno una Cell.
func dialogue(sid: String) -> Dictionary:
	if not _has_cell("moderates", sid):
		return _err("serve una Cellula Moderates in %s" % sid)
	var st: SpaceState = state.space_state(sid)
	# Verso Neutral
	if st.support > CoinEnums.Support.NEUTRAL:
		st.support = (st.support - 1) as CoinEnums.Support
	elif st.support < CoinEnums.Support.NEUTRAL:
		st.support = (st.support + 1) as CoinEnums.Support
	return _ok()


## **Foreign Relations** (§4.2.2): cambia la Vassalage di Germania o Russia.
func foreign_relations(power: String, delta: int) -> Dictionary:
	if not (power == "germans" or power == "russians"):
		return _err("power non valido: %s" % power)
	var key: String = "vassalage_" + ("german" if power == "germans" else "russian")
	var cur: int = int(state.tracks.get(key, 3))
	state.tracks[key] = clampi(cur + delta, 0, 6)
	return _ok({"new_value": state.tracks[key]})


# ---------------------------------------------------------------------------
# Comuni
# ---------------------------------------------------------------------------

## **Tax** (Reds & Senate): incassa Risorse pari alla Popolazione dello spazio
## dove la fazione ha una Cell (Senate) o Cell+Admin (Reds).
func tax(fid: String, sid: String) -> Dictionary:
	if not _has_cell(fid, sid):
		return _err("serve una Cellula %s in %s" % [fid, sid])
	var sd: SpaceDef = state.game_def.space(sid)
	var gain: int = sd.pop
	if gain <= 0:
		return _err("Pop=0 — niente da incassare")
	state.resources[fid] = int(state.get_resources(fid)) + gain
	return _ok({"gain": gain})


## **Negotiate** (Senate / Moderates): negoziato → +1 vassalage Germania.
func negotiate(_fid: String) -> Dictionary:
	var cur: int = int(state.tracks.get("vassalage_german", 3))
	state.tracks["vassalage_german"] = clampi(cur + 1, 0, 6)
	return _ok()


## **Subvert** (Reds): rimuovi 1 Cellula nemica in uno spazio dove i Reds hanno
## una Cellula clandestina.
func subvert(sid: String) -> Dictionary:
	var st: SpaceState = state.space_state(sid)
	if st.count("reds", "cell", "underground") <= 0:
		return _err("serve una Cellula Reds clandestina in %s" % sid)
	for f in ["senate", "moderates"]:
		if st.count(f, "cell") > 0:
			# Rimuovi una Cellula attiva se possibile, altrimenti clandestina
			if st.count(f, "cell", "active") > 0:
				st.remove_piece(f, "cell", 1, "active")
			else:
				st.remove_piece(f, "cell", 1, "underground")
			state.recompute_control(sid)
			return _ok({"target": f})
	return _err("nessuna Cellula avversaria")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

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
