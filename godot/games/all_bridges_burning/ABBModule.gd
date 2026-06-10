class_name ABBModule
extends RulesModule

## Modulo di gioco "All Bridges Burning" (Serie COIN Vol. IX, GMT 2020).

const DATA_DIR := "res://games/all_bridges_burning/data/"

## Mappatura chiavi nel setup_*.json → (faction_id, piece_type, state).
const SETUP_FORCE_MAP := {
	"reds_cell":      ["reds",      "cell",   "underground"],
	"senate_cell":    ["senate",    "cell",   "underground"],
	"moderates_cell": ["moderates", "cell",   "underground"],
	"reds_admin":     ["reds",      "admin",  ""],
	"moderates_network": ["moderates", "network", ""],
	"german_troop":   ["germans",   "troops", ""],
	"russian_troop":  ["russians",  "troops", ""],
}

const SUPPORT_KEY_MAP := {
	"active_support":     CoinEnums.Support.ACTIVE_SUPPORT,
	"passive_support":    CoinEnums.Support.PASSIVE_SUPPORT,
	"neutral":            CoinEnums.Support.NEUTRAL,
	"passive_opposition": CoinEnums.Support.PASSIVE_OPPOSITION,
	"active_opposition":  CoinEnums.Support.ACTIVE_OPPOSITION,
}


# ---------------------------------------------------------------------------
# Costruzione GameDef
# ---------------------------------------------------------------------------

func build_game_def() -> GameDef:
	var gd := GameDef.new()
	gd.title = "All Bridges Burning"

	_register_piece_types(gd)

	var spaces_data: Dictionary = _load_json(DATA_DIR + "spaces.json")
	for s in spaces_data.get("spaces", []):
		gd.add_space(SpaceDef.from_dict(s))

	var factions_data: Dictionary = _load_json(DATA_DIR + "factions.json")
	for f in factions_data.get("factions", []):
		gd.add_faction(FactionDef.from_dict(f))
	# §1.7: solo Reds e Senate possono Controllare. Moderati e Powers (Germani/
	# Russi) non controllano mai (ma negano il Controllo col loro conteggio).
	for fd in gd.factions:
		fd.can_control = fd.id in ["reds", "senate"]

	# Carte evento: TODO (PR Eventi).
	var cards_data: Dictionary = _load_json(DATA_DIR + "cards.json")
	for c in cards_data.get("cards", []):
		gd.add_card(CardDef.from_dict(c))

	gd.tracks = {
		"polarization":      {"min": 0, "max": 10},
		"vassalage_german":  {"min": 0, "max": 6},
		"vassalage_russian": {"min": 0, "max": 6},
		"senate_town_pop":   {"min": 0, "max": 30},
		"oppose_admins":     {"min": 0, "max": 30},
		"cells_on_map":      {"min": 0, "max": 50},
		"issues_networks":   {"min": 0, "max": 30},
		# Phase I = pre-Red Revolt!; Phase II = Germans giocano via flowchart (§3.4).
		"phase":             {"min": 1, "max": 2, "default": 1},
	}
	return gd


func _register_piece_types(gd: GameDef) -> void:
	# Truppe (cubi) — Germania (grigio) e Russia (marrone).
	# §1.7: le Truppe dei Powers sono ESCLUSE dal conteggio del Controllo.
	var troops := PieceTypeDef.new("troops", "Truppe")
	troops.category = CoinEnums.PieceCategory.CUBE
	troops.counts_for_control = false
	gd.add_piece_type(troops)

	# Cellule (ottagoni) — Reds, Senate, Moderates. Active / Underground (§1.4.1).
	var cell := PieceTypeDef.new("cell", "Cellula")
	cell.category = CoinEnums.PieceCategory.GUERRILLA
	cell.states = PackedStringArray(["underground", "active"])
	cell.default_state = "underground"
	gd.add_piece_type(cell)

	# Amministrazioni (dischi rossi) — Reds. Equivalente "base" per Controllo e Vittoria.
	var admin := PieceTypeDef.new("admin", "Amministrazione")
	admin.category = CoinEnums.PieceCategory.BASE
	admin.is_base = true
	gd.add_piece_type(admin)

	# Network (dischi blu) — Moderates. Equivalente "base" per Controllo e Vittoria.
	var network := PieceTypeDef.new("network", "Network")
	network.category = CoinEnums.PieceCategory.BASE
	network.is_base = true
	gd.add_piece_type(network)


# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

func apply_setup(state: GameState, scenario_id: String = "standard") -> void:
	var setup: Dictionary = _load_json(DATA_DIR + "setup_%s.json" % scenario_id)
	if setup.is_empty():
		push_warning("ABB apply_setup: setup non trovato per scenario '%s'" % scenario_id)
		return

	# Risorse
	var res: Dictionary = setup.get("resources", {})
	for fid in res.keys():
		state.resources[fid] = int(res[fid])

	# Tracciati globali (default Phase I se non specificato).
	if not state.tracks.has("phase"):
		state.tracks["phase"] = 1
	var tracks: Dictionary = setup.get("tracks", {})
	for tk in tracks.keys():
		state.tracks[tk] = int(tracks[tk])

	# Spazi: forze + supporto + controllo iniziale (override; il controllo viene
	# poi ricalcolato dalle forze, ma nel setup iniziale può precedere le pedine).
	var spaces_setup: Dictionary = setup.get("spaces", {})
	for sid in spaces_setup.keys():
		if not state.spaces.has(sid):
			push_warning("ABB setup: spazio sconosciuto '%s'" % sid)
			continue
		var entry: Dictionary = spaces_setup[sid]
		_place_forces(state, sid, entry.get("forces", {}))
		var sup: String = String(entry.get("support", ""))
		if sup != "" and SUPPORT_KEY_MAP.has(sup):
			state.spaces[sid].support = SUPPORT_KEY_MAP[sup]
		# Marker (Personality, News, Prepared) piazzati da setup.
		var markers: Dictionary = entry.get("markers", {})
		for mk in markers.keys():
			state.spaces[sid].set_marker(String(mk), int(markers[mk]))

	# Piazzamenti casuali (Senate Cell in Viipuri/Turku, Moderates Cell in Viipuri/Turku/Tampere).
	_apply_random_placements(state, setup.get("random_placements", []))

	# Disponibilità: tutte le fazioni iniziano Disponibili.
	for f in state.game_def.factions:
		state.eligibility[f.id] = CoinEnums.Eligibility.ELIGIBLE

	# Ricalcolo controllo dalle forze.
	state.recompute_all_control()


func _place_forces(state: GameState, sid: String, forces: Dictionary) -> void:
	for key in forces.keys():
		if not SETUP_FORCE_MAP.has(key):
			push_warning("ABB setup: chiave forza sconosciuta '%s'" % key)
			continue
		var mapping: Array = SETUP_FORCE_MAP[key]
		var count := int(forces[key])
		if count <= 0:
			continue
		state.spaces[sid].add_piece(mapping[0], mapping[1], count, mapping[2])


func _apply_random_placements(state: GameState, placements: Array) -> void:
	# RNG deterministico (seed 0) per test riproducibili. In partita reale,
	# seed verrà sostituito da rand_from_seed o da Time.get_unix_time_from_system().
	var rng := RandomNumberGenerator.new()
	rng.seed = 0
	for p in placements:
		var key := String(p.get("force", ""))
		if not SETUP_FORCE_MAP.has(key):
			continue
		var mapping: Array = SETUP_FORCE_MAP[key]
		var count := int(p.get("count", 1))
		var options: Array = p.get("options", [])
		if options.is_empty():
			continue
		var pick_idx := _roll_pick(rng, p.get("rule", ""), options.size())
		var sid := String(options[pick_idx])
		if state.spaces.has(sid):
			state.spaces[sid].add_piece(mapping[0], mapping[1], count, mapping[2])


## Risolve la regola D6 testuale (es. "d6_1_3=turku,4_6=viipuri") in un indice
## nell'array delle opzioni. Se la regola non è leggibile, distribuisce uniforme.
func _roll_pick(rng: RandomNumberGenerator, rule: String, n_options: int) -> int:
	var roll := (rng.randi() % 6) + 1
	if rule == "":
		return roll % n_options
	# Parser semplice: d6_<a>_<b>=<id>, separati da virgola; restituisce indice
	# del primo intervallo che contiene roll. Se nulla matcha, fallback uniforme.
	var parts := rule.split(",")
	# Ricostruiamo solo gli intervalli (gli id sono già negli options[]).
	var idx := 0
	for part in parts:
		var seg := String(part).strip_edges()
		# es. "d6_1_3=turku"  -> low=1, high=3
		var eq := seg.find("=")
		if eq < 0:
			idx += 1
			continue
		var lhs := seg.substr(0, eq)
		var nums := lhs.replace("d6_", "").split("_")
		if nums.size() >= 2:
			var lo := int(nums[0])
			var hi := int(nums[1])
			if roll >= lo and roll <= hi:
				return idx
		idx += 1
	return roll % n_options


# ---------------------------------------------------------------------------
# Vittoria (TODO: PR Propaganda / Round periodico)
# ---------------------------------------------------------------------------

## Stato di vittoria (rulebook §7.2/§7.3).
func victory_status(state: GameState) -> Dictionary:
	var pol: int = int(state.tracks.get("polarization", 0))
	var vass_g: int = int(state.tracks.get("vassalage_german", 0))
	var vass_r: int = int(state.tracks.get("vassalage_russian", 0))

	var reds_value: int = state.total_opposition() + state.count_on_map("reds", "admin")
	if vass_r + pol > 5:
		reds_value = 0
	var senate_value: int = _senate_town_pop(state)
	if vass_g + pol > 5:
		senate_value = 0
	# §7.3 Moderati: margine = min(Risorse − 14, Issues+Networks+1 − Pol). Con
	# soglia 14, value = min(Risorse, Issues+Networks+1 − Pol + 14) riproduce
	# esattamente quel margine (e richiede margine strettamente positivo per la
	# vittoria, come da §7.3).
	var mod_res: int = state.get_resources("moderates")
	var mod_inw: int = int(state.tracks.get("issues_networks", 0)) + 1
	var mod_alt: int = mod_inw - pol + 14
	var mod_value: int = min(mod_res, mod_alt)

	return {
		"reds":      _vstat(reds_value, 11),
		"senate":    _vstat(senate_value, 3),
		"moderates": _vstat(mod_value, 14),
		"germans":   _vstat(vass_g, 6),
		"russians":  _vstat(vass_r, 6),
	}


func _vstat(value: int, threshold: int) -> Dictionary:
	return {
		"value": value,
		"threshold": threshold,
		"margin": value - threshold,
		"won": value > threshold,
	}


func _senate_town_pop(state: GameState) -> int:
	var total: int = 0
	for sid in state.spaces.keys():
		var sd: SpaceDef = state.game_def.space(sid)
		if sd == null or sd.type != CoinEnums.SpaceType.CITY:
			continue
		if state.space_state(sid).control == "senate":
			total += sd.pop
	return total


## Aggiorna i marker-traccia DERIVATI mostrati sui tracciati di vittoria (§1.12).
## Chiamato da GameController dopo ogni azione/evento/propaganda. Senza questo
## metodo il controller andava in errore ("Nonexistent function") e il flusso
## carta si bloccava. `issues_networks` NON è derivato (è un contatore mantenuto
## da PoliticalDisplay/Eventi) e quindi non va ricalcolato qui.
func _refresh_victory_tracks(state: GameState) -> void:
	state.tracks["senate_town_pop"] = _senate_town_pop(state)
	state.tracks["oppose_admins"] = state.total_opposition() + state.count_on_map("reds", "admin")


func tiebreak_order() -> PackedStringArray:
	return PackedStringArray(["reds", "moderates", "senate", "germans", "russians"])


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var raw := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(raw)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
