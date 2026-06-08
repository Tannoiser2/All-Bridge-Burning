class_name ABBModule
extends RulesModule

## Modulo di gioco "All Bridges Burning" (Serie COIN Vol. IX, GMT 2020).
##
## Scheletro iniziale: carica le definizioni base (fazioni, spazi, carte) dai file
## JSON in `data/`. I file sono attualmente stub vuoti — vanno popolati a partire
## dal regolamento e dal modulo Vassal in `Materiale ABB/`.

const DATA_DIR := "res://games/all_bridges_burning/data/"


func build_game_def() -> GameDef:
	var gd := GameDef.new()
	gd.title = "All Bridges Burning"

	_register_piece_types(gd)

	# Spazi mappa
	var spaces_data: Dictionary = _load_json(DATA_DIR + "spaces.json")
	for s in spaces_data.get("spaces", []):
		gd.add_space(SpaceDef.from_dict(s))

	# Fazioni
	var factions_data: Dictionary = _load_json(DATA_DIR + "factions.json")
	for f in factions_data.get("factions", []):
		gd.add_faction(FactionDef.from_dict(f))

	# Carte evento (ABB ha 70+ carte — TODO da rulebook)
	var cards_data: Dictionary = _load_json(DATA_DIR + "cards.json")
	for c in cards_data.get("cards", []):
		gd.add_card(CardDef.from_dict(c))

	return gd


func apply_setup(state: GameState, scenario_id: String = "standard") -> void:
	# TODO: implementare lo schieramento iniziale (Russian Revolution / Finnish
	# Civil War 1917-18). Per ora no-op così il motore può istanziare lo stato vuoto.
	var _setup: Dictionary = _load_json(DATA_DIR + "setup_%s.json" % scenario_id)


func victory_status(_state: GameState) -> Dictionary:
	# TODO: condizioni di vittoria ABB (Crisis check / Coup, ecc.).
	return {}


# ---------------------------------------------------------------------------
# Helpers privati
# ---------------------------------------------------------------------------

func _register_piece_types(_gd: GameDef) -> void:
	# TODO: registrare i tipi pezzo ABB (Police, Troops, Guerrilla, Base — nomi
	# specifici della Finlandia 1917-18 da confermare dal regolamento).
	pass


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var raw := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(raw)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
