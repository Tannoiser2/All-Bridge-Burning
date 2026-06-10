class_name ABBPoliticalDisplay
extends RefCounted

## Political Display (rulebook §1.11). Tre Issues storici:
##   1. 8h Working Day
##   2. Land Reform
##   3. Social Security
##
## Ogni Issue è Unresolved finché non viene risolto in Politics Phase (§6.2).
## I cubi (Senate=bianco, Reds=rosso) vengono piazzati sull'Issue Unresolved
## corrente. Quando l'Issue viene risolto, prende il colore della fazione
## che ha più cubi (Moderati decidono in caso di pareggio).

const ISSUES: Array = [
	{"id": "working_day",     "name": "8h Working Day"},
	{"id": "land_reform",     "name": "Land Reform"},
	{"id": "social_security", "name": "Social Security"},
]

var state: GameState


func _init(p_state: GameState) -> void:
	state = p_state
	_ensure_keys()


func _ensure_keys() -> void:
	if not state.tracks.has("political_display"):
		state.tracks["political_display"] = {"senate": 0, "reds": 0}
	if not state.tracks.has("issues"):
		var arr: Array = []
		for i in ISSUES:
			arr.append({"id": i["id"], "resolved_by": ""})
		state.tracks["issues"] = arr


## Indice della prossima Issue Unresolved, oppure -1 se tutte risolte.
func current_unresolved_index() -> int:
	var issues: Array = state.tracks.get("issues", [])
	for i in range(issues.size()):
		if String(issues[i].get("resolved_by", "")) == "":
			return i
	return -1


## Piazza N cubi del faction ("senate" o "reds") sull'Issue corrente.
func place_cubes(faction: String, n: int = 1) -> bool:
	if n <= 0:
		return false
	if not (faction in ["senate", "reds"]):
		return false
	if current_unresolved_index() < 0:
		return false
	var pd: Dictionary = state.tracks["political_display"]
	pd[faction] = int(pd.get(faction, 0)) + n
	state.tracks["political_display"] = pd
	return true


## Rimuove N cubi del faction (max disponibili).
func remove_cubes(faction: String, n: int = 1) -> int:
	var pd: Dictionary = state.tracks["political_display"]
	var avail := int(pd.get(faction, 0))
	var actual := mini(n, avail)
	pd[faction] = avail - actual
	state.tracks["political_display"] = pd
	return actual


## §6.2 Politics Phase resolution. dice_seed deterministico per i test.
func resolve_politics(dice_seed: int = -1) -> Dictionary:
	var out: Dictionary = {"log": []}
	var idx := current_unresolved_index()
	if idx < 0:
		out["log"].append("Tutte le Issues già risolte.")
		return out
	var pd: Dictionary = state.tracks["political_display"]
	var senate_cubes := int(pd.get("senate", 0))
	var reds_cubes := int(pd.get("reds", 0))
	var total := senate_cubes + reds_cubes
	if total == 0:
		out["log"].append("Politics: nessun cubo, niente da risolvere.")
		return out
	# 1d6 ≤ total → resolve
	var rng := RandomNumberGenerator.new()
	if dice_seed >= 0:
		rng.seed = dice_seed
	else:
		rng.randomize()
	var roll := rng.randi_range(1, 6)
	out["roll"] = roll
	out["total_cubes"] = total
	if roll > total:
		out["log"].append("Politics: roll %d > %d cubi totali, no effect." % [roll, total])
		return out
	# Resolve
	var resolved_by := ""
	if senate_cubes > reds_cubes:
		resolved_by = "senate"
	elif reds_cubes > senate_cubes:
		resolved_by = "reds"
	else:
		resolved_by = "moderates"   # tie → Moderati decidono; default Moderates
	var issues: Array = state.tracks["issues"]
	issues[idx]["resolved_by"] = resolved_by
	state.tracks["issues"] = issues
	# Rimuovi tutti i cubi
	pd["senate"] = 0
	pd["reds"] = 0
	state.tracks["political_display"] = pd
	# Il track issues_networks è DERIVATO (resolved_by è il primitivo): viene
	# ricalcolato da ABBModule._refresh_victory_tracks / issues_networks_expr.
	out["resolved"] = ISSUES[idx]["name"]
	out["by"] = resolved_by
	out["log"].append("Politics: Issue '%s' risolta dal %s (roll %d ≤ %d cubi)." % [
		ISSUES[idx]["name"], resolved_by, roll, total])
	return out


## Conteggio Resolved Issues per colore (per cost Agitation §6.2.1).
func resolved_count(by: String) -> int:
	var n := 0
	for i in state.tracks.get("issues", []):
		if String(i.get("resolved_by", "")) == by:
			n += 1
	return n
