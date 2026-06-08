class_name ABBCrisis
extends RefCounted

## Crisis Round All Bridges Burning (rulebook §6.0).
##
## Equivalente della Propaganda di Cuba Libre. Si attiva quando viene
## pescata una carta Propaganda (numeri 22, 23, 46, 47). Tre fasi:
##
## 1. **Politics Phase** (§6.2): risolvi una Issue sul Political Display.
##    La fazione con più cubi politici sull'Issue corrente la "risolve".
## 2. **Earnings** (§6.3): ogni fazione guadagna Risorse pari ai propri
##    Score totals (rulebook §6.3.x).
## 3. **Phase II adjustment** (§6.5): se siamo dopo Red Revolt, le
##    truppe Russe/Tedesche sulla mappa vengono adattate alle Vassalage.
##
## Questo PR implementa Earnings e una versione semplificata di Politics
## (avanza solo l'Issue corrente). Phase II adjustment è TODO.

var state: GameState
var module: RulesModule

func _init(_state: GameState, _module: RulesModule) -> void:
	state = _state
	module = _module


## Esegue l'intero Crisis Round. Restituisce un dict riassuntivo.
func resolve() -> Dictionary:
	var report := {"politics": _politics_phase(), "earnings": _earnings_phase()}
	# TODO: Phase II adjustment (§6.5) dopo Red Revolt
	return report


# ---------------------------------------------------------------------------
# Politics Phase (§6.2)
# ---------------------------------------------------------------------------

func _politics_phase() -> Dictionary:
	# Stub: incrementa il numero di Issues + Networks risolti di 1.
	var cur: int = int(state.tracks.get("issues_networks", 0))
	state.tracks["issues_networks"] = cur + 1
	return {"issues_resolved": 1, "total": state.tracks["issues_networks"]}


# ---------------------------------------------------------------------------
# Earnings Phase (§6.3)
# ---------------------------------------------------------------------------
##
## Earnings per fazione (regole semplificate dal rulebook):
## - Reds: +Pop totale dove hanno Cellule + Admin (Underground o Active)
## - Senate: +Pop totale dove hanno Cellule + Russian/German Troops alleate
## - Moderates: +1 per ogni News marker risolta + 1 per ogni Network sulla mappa
## - Germans: +1 per ogni Vassalage Tedesca attiva (dopo Phase II)
## - Russians: nessun guadagno (Power)

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
			var gain: int = 0
			for sid in state.spaces.keys():
				var st: SpaceState = state.space_state(sid)
				if st.count("reds", "cell") > 0 or st.count("reds", "admin") > 0:
					gain += state.game_def.space(sid).pop
			return gain
		"senate":
			var gain: int = 0
			for sid in state.spaces.keys():
				var st: SpaceState = state.space_state(sid)
				if st.count("senate", "cell") > 0:
					gain += state.game_def.space(sid).pop
			return gain
		"moderates":
			# Stub: +1 per ogni Network + 1 fisso
			return 1 + state.count_on_map("moderates", "network")
		"germans":
			# Stub: +1 per livello Vassalage tedesca / 2
			return int(state.tracks.get("vassalage_german", 0)) / 2
		_:
			return 0
